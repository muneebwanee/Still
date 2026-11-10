// Real WebRTC transport between two Chromium pages; capture is an explicit canvas fixture.
let chromium;try{({chromium}=require('playwright'))}catch{({chromium}=require('../relay/node_modules/playwright'))}
const {randomBytes}=require('node:crypto');
const assert=require('node:assert/strict');
const {pathToFileURL}=require('node:url');
const path=require('node:path');
const fs=require('node:fs');
(async()=>{
 const {createRelay}=await import(pathToFileURL(path.join(__dirname,'../relay/server.mjs')));
 const origin='http://127.0.0.1:18769';const relay=createRelay({origin,turnURLs:process.env.STILL_TEST_TURN_URL?[process.env.STILL_TEST_TURN_URL]:[],turnSecret:process.env.STILL_TEST_TURN_SECRET||''});await new Promise(r=>relay.server.listen(18769,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||(fs.existsSync('/usr/bin/chromium')?'/usr/bin/chromium':chromium.executablePath()),args:['--no-sandbox','--disable-features=WebRtcHideLocalIpsWithMdns']});
 try{
  const room=randomBytes(16).toString('hex'),owner=randomBytes(16).toString('hex'),invite=randomBytes(16).toString('hex');
  const receiver=await browser.newPage();await receiver.goto(origin);
  await receiver.evaluate(({room,owner,invite})=>{
   window.connectReceiver=()=>{
    const ws=window.ownerSocket=new WebSocket(location.origin.replace('http','ws')+'/signal');let chain=Promise.resolve(),pending=[];
    ws.onopen=()=>ws.send(JSON.stringify({type:'create',room,owner,invite}));
    ws.onmessage=e=>{chain=chain.then(async()=>{
     const m=JSON.parse(e.data);
     if(m.type==='ready'){window.ownerReady=true;window.ice=m.iceServers}
     if(m.type==='peer-left')window.senderLeft=true;
     if(m.type==='peer-joined'){window.allowed=m.allowRecording;window.pc?.close();window.pc=new RTCPeerConnection({iceServers:window.ice});window.pc.onicecandidate=e=>{if(e.candidate)ws.send(JSON.stringify({type:'candidate',candidate:e.candidate.candidate,sdpMid:e.candidate.sdpMid,sdpMLineIndex:e.candidate.sdpMLineIndex}))};window.pc.ontrack=e=>{const video=document.querySelector('#preview');video.hidden=false;video.srcObject=new MediaStream([e.track]);video.play()};pending=[]}
     if(m.type==='offer'){await window.pc.setRemoteDescription({type:'offer',sdp:m.sdp});for(const c of pending)await window.pc.addIceCandidate(c);pending=[];await window.pc.setLocalDescription(await window.pc.createAnswer());ws.send(JSON.stringify({type:'answer',sdp:window.pc.localDescription.sdp}))}
     if(m.type==='candidate'){const c={candidate:m.candidate,sdpMid:m.sdpMid,sdpMLineIndex:m.sdpMLineIndex};if(window.pc?.remoteDescription)await window.pc.addIceCandidate(c);else pending.push(c)}
    }).catch(e=>{window.negotiationError=e.message})}
   };window.connectReceiver();
  },{room,owner,invite});
  await receiver.waitForFunction(()=>window.ownerReady);
  const sender=await browser.newPage({viewport:{width:390,height:844},colorScheme:'dark'});
  const signaling=[];sender.on('websocket',ws=>{ws.on('framesent',f=>{try{signaling.push('sent '+JSON.parse(f.payload).type)}catch{}});ws.on('framereceived',f=>{try{signaling.push('received '+JSON.parse(f.payload).type)}catch{}})});
  const errors=[];sender.on('pageerror',e=>errors.push(e.message));
  await sender.addInitScript(()=>{
   window.captureCalls=0;
   navigator.mediaDevices.getDisplayMedia=async options=>{
    window.captureCalls++;window.captureOptions=options;
    const canvas=document.createElement('canvas');canvas.width=640;canvas.height=360;const context=canvas.getContext('2d');let count=0;
    const draw=()=>{context.fillStyle=count++%2?'#405938':'#354b30';context.fillRect(0,0,640,360);context.fillStyle='#fff';context.font='32px sans-serif';context.fillText('Still · screen-sharing test',50,180)};draw();const interval=setInterval(draw,100);
    const stream=canvas.captureStream(10);stream.getVideoTracks()[0].addEventListener('ended',()=>clearInterval(interval));return stream;
   };
  });
  await sender.goto(`${origin}/#room=${room}&invite=${invite}`);
  assert.equal(new URL(sender.url()).hash,'');assert.equal(await sender.evaluate(()=>window.captureCalls),0);
  await sender.locator('#allowRecording').check();await sender.locator('#start').click();
  try { await receiver.waitForFunction(()=>document.querySelector('#preview').videoWidth>0,{},{timeout:20000}); }
  catch(error) { console.error('Receiver diagnostics:',await receiver.evaluate(()=>({error:window.negotiationError,peer:window.pc?.connectionState,signal:window.pc?.signalingState,video:document.querySelector('#preview').videoWidth})));console.error('Sender diagnostics:',await sender.locator('#status').textContent(),await sender.evaluate(()=>({state:peer?.connectionState,signaling:peer?.signalingState,local:!!peer?.localDescription,track:stream?.getVideoTracks()[0]?.readyState})),signaling.slice(-30));throw error; }
  assert.equal(await receiver.evaluate(()=>window.allowed),true);
  assert.equal(await sender.evaluate(()=>window.captureOptions.audio),false);
  await receiver.evaluate(()=>window.ownerSocket.send(JSON.stringify({type:'recording',active:true})));
  await sender.waitForFunction(()=>!document.querySelector('#recording').hidden);
  assert.equal(await sender.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  fs.mkdirSync(path.join(__dirname,'../docs/screenshots'),{recursive:true});
  await sender.screenshot({path:path.join(__dirname,'../docs/screenshots/screen-sender.png'),fullPage:true});
  await receiver.evaluate(()=>{window.ownerReady=false;window.ownerSocket.close();window.pc.close()});
  await sender.waitForFunction(()=>document.querySelector('#status').textContent.includes('disconnected'));
  await receiver.evaluate(()=>window.connectReceiver());
  await sender.waitForFunction(()=>document.querySelector('#status').textContent==='Sharing your screen.',{},{timeout:20000});
  assert.equal(await sender.evaluate(()=>window.captureCalls),1);
  await sender.locator('#stop').click();await receiver.waitForFunction(()=>window.senderLeft);
  assert.equal(await sender.evaluate(()=>document.querySelector('#preview').srcObject),null);
  assert.deepEqual(errors,[]);
  console.log('PASS: explicit capture action, real WebRTC video frames, private link removal, recording opt-in and notice, receiver reconnect without recapture, mobile layout and stop cleanup. Capture used a canvas fixture, not the OS screen picker.');
 }finally{await browser.close();await relay.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
