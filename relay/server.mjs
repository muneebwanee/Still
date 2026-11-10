import http from 'node:http';
import {readFileSync} from 'node:fs';
import {createHmac,randomBytes,timingSafeEqual} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {WebSocketServer,WebSocket} from 'ws';
const assets=new Map([['/', ['text/html; charset=utf-8','index.html']],['/sender.js',['text/javascript; charset=utf-8','sender.js']],['/style.css',['text/css; charset=utf-8','style.css']]].map(([url,[type,file]])=>[url,{type,data:()=>readFileSync(new URL('./public/'+file,import.meta.url))}]));
const validToken=value=>typeof value==='string'&&/^[a-f0-9]{32}$/.test(value);
const equal=(a,b)=>validToken(a)&&validToken(b)&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
export function createRelay({origin,turnURLs=[],turnSecret='',stunURLs=[],maxRooms=100,roomTTL=7200000,reconnectGrace=90000}={}){
 if(!origin||(!origin.startsWith('https://')&&!/^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(origin)))throw Error('PUBLIC_ORIGIN must be an HTTPS origin (HTTP loopback is for tests only).');
 if(new URL(origin).origin!==origin)throw Error('Use an origin without a path or trailing slash.');
 if(turnSecret&&(Buffer.byteLength(turnSecret)<32||turnSecret.startsWith('REPLACE_')))throw Error('Use at least 32 bytes for TURN_SECRET.');
 if(turnURLs.length&&!turnSecret)throw Error('TURN_URLS requires TURN_SECRET.');
 const rooms=new Map(),connections=new Map(),creationBudget=new Map();
 function iceServers(){
  const result=stunURLs.length?[{urls:stunURLs}]:[];
  if(turnURLs.length){const username=`${Math.floor(Date.now()/1000)+10800}:${randomBytes(8).toString('hex')}`;result.push({urls:turnURLs,username,credential:createHmac('sha1',turnSecret).update(username).digest('base64')})}return result;
 }
 const server=http.createServer((req,res)=>{
  const headers={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; media-src blob:; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",'Permissions-Policy':'camera=(), microphone=(), display-capture=(self)'};
  if(req.method!=='GET'){res.writeHead(405,headers);res.end();return}
  if(req.url==='/health'){res.writeHead(200,{...headers,'Content-Type':'application/json'});res.end('{"ok":true}');return}
  const asset=assets.get(req.url);if(!asset){res.writeHead(404,headers);res.end();return}
  res.writeHead(200,{...headers,'Content-Type':asset.type});res.end(asset.data());
 });
 const wss=new WebSocketServer({noServer:true,maxPayload:131072,perMessageDeflate:false});
 const send=(ws,message)=>{if(ws?.readyState===WebSocket.OPEN){if(ws.bufferedAmount>262144){ws.close(1013,'Slow connection');return}ws.send(JSON.stringify(message))}};
 const error=(ws,message)=>send(ws,{type:'error',message});
 function expire(room){rooms.delete(room.id);for(const ws of [room.receiver,room.sender])if(ws){ws.room=null;send(ws,{type:'ended'});ws.close(1000,'Session ended')}}
 server.on('upgrade',(req,socket,head)=>{
  if(req.url!=='/signal'||(req.headers.origin&&req.headers.origin!==origin)){socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');return}
  const ip=req.socket.remoteAddress??'unknown';if((connections.get(ip)??0)>=24||wss.clients.size>=256){socket.end('HTTP/1.1 429 Too Many Requests\r\nConnection: close\r\n\r\n');return}
  wss.handleUpgrade(req,socket,head,ws=>{ws.ip=ip;connections.set(ip,(connections.get(ip)??0)+1);wss.emit('connection',ws)});
 });
 wss.on('connection',ws=>{
  ws.alive=true;ws.window=Date.now();ws.messages=0;ws.room=null;ws.on('pong',()=>ws.alive=true);
  ws.on('error',()=>{});
  ws.on('message',bytes=>{
   if(Date.now()-ws.window>10000){ws.window=Date.now();ws.messages=0}if(++ws.messages>512){ws.close(1008,'Rate limit');return}
   let m;try{m=JSON.parse(bytes.toString())}catch{error(ws,'Invalid message');return}if(!m||typeof m!=='object')return;
   if(m.type==='create'){
    if(ws.room||!validToken(m.room)||!validToken(m.owner)||!validToken(m.invite)){error(ws,'Invalid session');return}
    let room=rooms.get(m.room);
    if(room){if(!equal(room.owner,m.owner)||!equal(room.invite,m.invite)){error(ws,'Session unavailable');return}if(room.receiver&&room.receiver!==ws){error(ws,'Receiver is already connected');return}}
    else {
     const budget=creationBudget.get(ws.ip)??{until:Date.now()+60000,count:0};if(budget.until<Date.now()){budget.until=Date.now()+60000;budget.count=0}creationBudget.set(ws.ip,budget);
     if(++budget.count>12||rooms.size>=maxRooms){error(ws,'Too many sessions. Try later.');return}
     room={id:m.room,owner:m.owner,invite:m.invite,receiver:null,sender:null,allowRecording:false,expires:Date.now()+roomTTL,awayAt:null};rooms.set(room.id,room);
    }
    room.receiver=ws;room.awayAt=null;ws.room=room;ws.role='receiver';send(ws,{type:'ready',iceServers:iceServers()});
    if(room.sender){send(ws,{type:'peer-joined',allowRecording:room.allowRecording});send(room.sender,{type:'receiver-back',iceServers:iceServers()})}return;
   }
   if(m.type==='join'){
    const room=rooms.get(m.room);if(ws.room||!room||!equal(room.invite,m.invite)||room.expires<=Date.now()||!room.receiver){error(ws,'This invitation is unavailable. Ask for a new link.');return}
    if(room.sender){error(ws,'Another screen is already sharing. Stop it before joining.');return}
    room.sender=ws;room.allowRecording=m.allowRecording===true;ws.room=room;ws.role='sender';
    send(room.receiver,{type:'peer-joined',allowRecording:room.allowRecording});send(ws,{type:'joined',iceServers:iceServers()});return;
   }
   const room=ws.room;if(!room){error(ws,'Join a session first');return}
   if(m.type==='end'&&ws.role==='receiver'){expire(room);return}
   const other=ws.role==='receiver'?room.sender:room.receiver;
   if(m.type==='offer'||m.type==='answer'){
    if((m.type==='offer'&&ws.role!=='sender')||(m.type==='answer'&&ws.role!=='receiver')||typeof m.sdp!=='string'||m.sdp.length>100000){error(ws,'Invalid negotiation');return}
    send(other,{type:m.type,sdp:m.sdp});return;
   }
   if(m.type==='candidate'){
    if(typeof m.candidate!=='string'||m.candidate.length>8192||!Number.isInteger(m.sdpMLineIndex)||m.sdpMLineIndex<0||m.sdpMLineIndex>16||(m.sdpMid!==null&&(typeof m.sdpMid!=='string'||m.sdpMid.length>64))){error(ws,'Invalid candidate');return}
    send(other,{type:'candidate',candidate:m.candidate,sdpMid:m.sdpMid,sdpMLineIndex:m.sdpMLineIndex});return;
   }
   if(m.type==='recording'&&ws.role==='receiver'){
    if(typeof m.active!=='boolean'||(m.active&&!room.allowRecording)){error(ws,'Recording was not allowed by the sender');return}
    send(other,{type:'recording',active:m.active});return;
   }
   error(ws,'Unsupported message');
  });
  ws.on('close',()=>{
   const count=(connections.get(ws.ip)??1)-1;if(count<=0)connections.delete(ws.ip);else connections.set(ws.ip,count);
   const room=ws.room;if(!room||!rooms.has(room.id))return;
   if(room.receiver===ws){room.receiver=null;room.awayAt=Date.now();send(room.sender,{type:'receiver-away'})}
   if(room.sender===ws){room.sender=null;room.allowRecording=false;send(room.receiver,{type:'peer-left'})}
  });
 });
 const heartbeat=setInterval(()=>{
  for(const ws of wss.clients){if(!ws.alive){ws.terminate();continue}ws.alive=false;ws.ping()}
  const now=Date.now();for(const room of rooms.values())if(room.expires<=now||(room.awayAt&&now-room.awayAt>reconnectGrace))expire(room);
  for(const [ip,budget] of creationBudget)if(budget.until<now)creationBudget.delete(ip);
 },10000);heartbeat.unref();
 return {server,close:async()=>{clearInterval(heartbeat);for(const room of [...rooms.values()])expire(room);for(const ws of wss.clients)ws.terminate();await new Promise(resolve=>wss.close(resolve));await new Promise(resolve=>server.close(resolve))},roomCount:()=>rooms.size};
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const csv=name=>(process.env[name]??'').split(',').map(v=>v.trim()).filter(Boolean);
 const relay=createRelay({origin:process.env.PUBLIC_ORIGIN,turnURLs:csv('TURN_URLS'),turnSecret:process.env.TURN_SECRET,stunURLs:csv('STUN_URLS')});
 relay.server.listen(Number(process.env.PORT??8080),process.env.BIND_ADDRESS??'127.0.0.1');
 for(const sig of ['SIGTERM','SIGINT'])process.on(sig,()=>relay.close().then(()=>process.exit(0)));
}
