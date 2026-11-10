import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes,createHmac} from 'node:crypto';
import {WebSocket} from 'ws';
import {createRelay} from '../server.mjs';
const token=()=>randomBytes(16).toString('hex');
async function fixture(options={}){
 const relay=createRelay({origin:'https://sharing.example.test',...options});await new Promise(resolve=>relay.server.listen(0,'127.0.0.1',resolve));const url=`ws://127.0.0.1:${relay.server.address().port}/signal`;
 const clients=[];
 async function client(){const ws=new WebSocket(url);clients.push(ws);const messages=[];ws.on('message',bytes=>messages.push(JSON.parse(bytes)));await new Promise((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject)});return {ws,send:m=>ws.send(JSON.stringify(m)),read:async type=>{const limit=Date.now()+2000;while(Date.now()<limit){const index=messages.findIndex(m=>m.type===type);if(index>=0)return messages.splice(index,1)[0];await new Promise(r=>setTimeout(r,5))}throw Error('No '+type)},end:()=>new Promise(resolve=>{ws.once('close',resolve);ws.close()})}}
 return {...relay,url,client,cleanup:async()=>{for(const c of clients)c.terminate();await relay.close()}};
}
test('authenticated room exchanges SDP and candidates; owner end revokes invitation',async()=>{
 const f=await fixture();try{const receiver=await f.client(),sender=await f.client();const room=token(),owner=token(),invite=token();receiver.send({type:'create',room,owner,invite});assert.deepEqual((await receiver.read('ready')).iceServers,[]);sender.send({type:'join',room,invite});await sender.read('joined');assert.equal((await receiver.read('peer-joined')).allowRecording,false);sender.send({type:'offer',sdp:'v=0 test'});assert.equal((await receiver.read('offer')).sdp,'v=0 test');receiver.send({type:'answer',sdp:'v=0 answer'});assert.equal((await sender.read('answer')).sdp,'v=0 answer');sender.send({type:'candidate',candidate:'candidate:test',sdpMid:'0',sdpMLineIndex:0});assert.equal((await receiver.read('candidate')).candidate,'candidate:test');receiver.send({type:'end'});await sender.read('ended');assert.equal(f.roomCount(),0);}finally{await f.cleanup()}
});
test('wrong invitation and wrong owner cannot join or take over a room',async()=>{
 const f=await fixture();try{const r=await f.client(),a=await f.client();const room=token(),owner=token(),invite=token();r.send({type:'create',room,owner,invite});await r.read('ready');a.send({type:'join',room,invite:token()});assert.match((await a.read('error')).message,/unavailable/);a.send({type:'create',room,owner:token(),invite});assert.equal((await a.read('error')).message,'Session unavailable');}finally{await f.cleanup()}
});
test('only one sender is accepted and offer/answer roles are enforced',async()=>{
 const f=await fixture();try{const r=await f.client(),s=await f.client(),a=await f.client();const room=token(),owner=token(),invite=token();r.send({type:'create',room,owner,invite});await r.read('ready');s.send({type:'join',room,invite});await s.read('joined');a.send({type:'join',room,invite});assert.match((await a.read('error')).message,/already sharing/);r.send({type:'offer',sdp:'bad'});assert.equal((await r.read('error')).message,'Invalid negotiation');}finally{await f.cleanup()}
});
test('recording notices require sender opt-in',async()=>{
 for(const allowed of [false,true]){const f=await fixture();try{const r=await f.client(),s=await f.client();const room=token(),owner=token(),invite=token();r.send({type:'create',room,owner,invite});await r.read('ready');s.send({type:'join',room,invite,allowRecording:allowed});await s.read('joined');assert.equal((await r.read('peer-joined')).allowRecording,allowed);r.send({type:'recording',active:true});if(allowed)assert.equal((await s.read('recording')).active,true);else assert.match((await r.read('error')).message,/not allowed/);}finally{await f.cleanup()}}
});
test('receiver can resume with its private owner credential and sender can renegotiate',async()=>{
 const f=await fixture();try{const r=await f.client(),s=await f.client();const room=token(),owner=token(),invite=token();r.send({type:'create',room,owner,invite});await r.read('ready');s.send({type:'join',room,invite,allowRecording:true});await s.read('joined');await r.end();await s.read('receiver-away');const replacement=await f.client();replacement.send({type:'create',room,owner,invite});await replacement.read('ready');assert.equal((await replacement.read('peer-joined')).allowRecording,true);await s.read('receiver-back');}finally{await f.cleanup()}
});
test('TURN credentials are temporary HMAC values; secret is not sent',async()=>{
 const secret='test-only-server-secret-at-least-32-bytes';const f=await fixture({turnURLs:['turn:relay.example.test:3478'],turnSecret:secret});try{const r=await f.client();r.send({type:'create',room:token(),owner:token(),invite:token()});const ready=await r.read('ready'),ice=ready.iceServers[0];assert.equal(ice.credential,createHmac('sha1',secret).update(ice.username).digest('base64'));assert.ok(Number(ice.username.split(':')[0])>Date.now()/1000);assert.ok(!JSON.stringify(ready).includes(secret));}finally{await f.cleanup()}
});
test('foreign browser origins are rejected before websocket upgrade',async()=>{const f=await fixture();try{await new Promise((resolve,reject)=>{const ws=new WebSocket(f.url,{origin:'https://attacker.example'});ws.once('unexpected-response',(_,response)=>{assert.equal(response.statusCode,403);response.resume();resolve()});ws.once('open',()=>reject(Error('Unexpected upgrade')));ws.once('error',()=>{});});}finally{await f.cleanup()}});
test('room capacity is bounded and malformed commands do not crash the service',async()=>{const f=await fixture({maxRooms:1});try{const r=await f.client(),a=await f.client();r.send({type:'create',room:token(),owner:token(),invite:token()});await r.read('ready');a.send({type:'create',room:token(),owner:token(),invite:token()});assert.match((await a.read('error')).message,/Too many/);r.ws.send('broken json');assert.equal((await r.read('error')).message,'Invalid message');}finally{await f.cleanup()}});
