'use strict';
const $=id=>document.getElementById(id),params=new URLSearchParams(location.hash.slice(1));
const room=params.get('room')||'',invite=params.get('invite')||'';
history.replaceState(null,'',location.pathname);
let socket,peer,stream,ice=[],pending=[],retry,stopping=false,attempt=0,joining=false;
const valid=/^[a-f0-9]{32}$/.test(room)&&/^[a-f0-9]{32}$/.test(invite);
const presets={balanced:{width:1280,height:720,frameRate:24,bitrate:2500000},sharp:{width:1920,height:1080,frameRate:30,bitrate:5000000},light:{width:854,height:480,frameRate:15,bitrate:1000000}};
function status(text){$('status').textContent=text}
function send(message){if(socket?.readyState===WebSocket.OPEN)socket.send(JSON.stringify(message))}
function resetPeer(){peer?.close();peer=null;pending=[];$('recording').hidden=true}
async function offer(){
 if(!stream)return;resetPeer();const pc=peer=new RTCPeerConnection({iceServers:ice});
 pc.onicecandidate=e=>{if(e.candidate)send({type:'candidate',candidate:e.candidate.candidate,sdpMid:e.candidate.sdpMid,sdpMLineIndex:e.candidate.sdpMLineIndex})};
 pc.onconnectionstatechange=()=>{if(pc!==peer)return;if(pc.connectionState==='connected'){status('Sharing your screen.');attempt=0}else if(pc.connectionState==='failed'){recover()}else if(pc.connectionState==='disconnected')status('Connection interrupted. Waiting for your network…')};
 pc.addTrack(stream.getVideoTracks()[0],stream);
 await pc.setLocalDescription(await pc.createOffer());if(pc===peer)send({type:'offer',sdp:pc.localDescription.sdp});
}
function connect(){
 if(stopping||!stream)return;clearTimeout(retry);retry=null;if(socket){socket.onclose=null;socket.close()}resetPeer();
 const ws=socket=new WebSocket(location.origin.replace(/^http/,'ws')+'/signal');joining=true;
 ws.onopen=()=>{if(ws===socket)send({type:'join',room,invite,allowRecording:$('allowRecording').checked})};
 ws.onmessage=async e=>{if(ws!==socket)return;try{
  const m=JSON.parse(e.data);
  if(m.type==='joined'){joining=false;ice=m.iceServers;await offer()}
  else if(m.type==='answer'&&peer){await peer.setRemoteDescription({type:'answer',sdp:m.sdp});for(const c of pending)await peer.addIceCandidate(c);pending=[];const sender=peer.getSenders().find(s=>s.track?.kind==='video'),selected=presets[$('quality').value];if(sender){const config=sender.getParameters();for(const e of config.encodings){e.maxBitrate=selected.bitrate;e.maxFramerate=selected.frameRate}try{await sender.setParameters(config)}catch{}}}
  else if(m.type==='candidate'&&peer){const c={candidate:m.candidate,sdpMid:m.sdpMid,sdpMLineIndex:m.sdpMLineIndex};if(peer.remoteDescription)await peer.addIceCandidate(c);else pending.push(c)}
  else if(m.type==='receiver-away'){resetPeer();status('The receiving screen disconnected. Waiting briefly…')}
  else if(m.type==='receiver-back'){ice=m.iceServers;await offer()}
  else if(m.type==='recording'){$('recording').hidden=!m.active}
  else if(m.type==='ended'){stop();status('The receiver ended this session.')}
  else if(m.type==='error'){if(joining){stop();status(m.message)}else status(m.message)}
 }catch{status('Could not negotiate this connection. Stop and try again.')}};
 ws.onclose=()=>{if(ws===socket)recover()};
 ws.onerror=()=>{if(ws===socket)status('Connection service unavailable. Check your internet connection.')};
}
function recover(){
 if(stopping||!stream||retry)return;
 if(attempt>=6){stop();status('Couldn’t reconnect. Ask for a new invitation.');return}
 if(socket){socket.onclose=null;socket.close();socket=null}resetPeer();status('Reconnecting…');
 retry=setTimeout(()=>{retry=null;connect()},Math.min(1000*2**attempt++,10000));
}
function stop(){stopping=true;clearTimeout(retry);if(socket){socket.onclose=null;socket.close();socket=null}resetPeer();if(stream){for(const track of stream.getTracks())track.stop();stream=null}$('preview').srcObject=null;$('preview').hidden=true;$('stop').disabled=true;$('start').disabled=!valid;$('start').textContent='Choose a screen';$('allowRecording').disabled=false;$('quality').disabled=false;status('Sharing stopped.')}
$('start').onclick=async()=>{
 if(!valid||stream)return;stopping=false;attempt=0;$('start').disabled=true;
 try{const q=presets[$('quality').value];stream=await navigator.mediaDevices.getDisplayMedia({video:{width:{ideal:q.width},height:{ideal:q.height},frameRate:{ideal:q.frameRate,max:q.frameRate}},audio:false});stream.getVideoTracks()[0].onended=stop;$('preview').srcObject=stream;$('preview').hidden=false;$('stop').disabled=false;$('start').textContent='Sharing screen';$('allowRecording').disabled=true;$('quality').disabled=true;status('Connecting your screen…');connect()}
 catch(e){stop();status(e.name==='NotAllowedError'?'Screen sharing was cancelled. Choose a screen when you’re ready.':'This screen could not be captured. Try another browser or screen.');}
};$('stop').onclick=stop;
if(!valid){$('start').disabled=true;status('Open the full invitation from Still to begin.')}
else if(!navigator.mediaDevices?.getDisplayMedia){$('start').hidden=true;$('unsupported').hidden=false;$('android').hidden=false;$('android').href='stillshare://join#'+new URLSearchParams({server:location.origin,room,invite});status('Use a supported computer browser or the Android sender.')}
window.addEventListener('pagehide',stop);
