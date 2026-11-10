import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const html=readFileSync(new URL('../Still/Resources/remote.html',import.meta.url),'utf8');
const source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const token='a'.repeat(32);
function harness({hash='#'+token,response,status=200}={}){
 const ids=[...html.matchAll(/id="([^"]+)"/g)].map(x=>x[1]);
 const elements=Object.fromEntries(ids.map(id=>[id,{id,textContent:'',value:'',hidden:false,disabled:false,children:[],addEventListener(name,fn){this[name]=fn},replaceChildren(...nodes){this.children=nodes},reportValidity(){return true}}]));
 const calls=[];const buttons=['load','enqueue','toggle','next','stop'].map(x=>elements[x]);
 const document={documentElement:{dataset:{}},hidden:false,activeElement:null,getElementById:id=>elements[id],querySelectorAll:()=>buttons,createElement:()=>({textContent:''}),addEventListener(){}};
 const state={name:'Living room',title:'Test video',source:'YouTube',playing:true,buffering:false,position:10,duration:120,volume:.5,queue:['Next video'],error:''};
 const context=vm.createContext({document,location:{hash,pathname:'/'},history:{replaceState(...args){calls.push({history:args})}},AbortSignal,Error,Number,Math,String,JSON,setTimeout:()=>0,fetch:async(path,options)=>{calls.push({path,options});return{status,ok:status===200,json:async()=>response??(options.method==='POST'?{ok:true}:state)}}});
 vm.runInContext(source,context);
 return {elements,calls,run:code=>vm.runInContext(code,context)};
}
test('missing pairing token disables control and sends no requests',()=>{const h=harness({hash:''});assert.match(h.elements.notice.textContent,/Scan the QR/);assert.equal(h.calls.filter(x=>x.path).length,0);assert.ok(h.elements.load.disabled)});
test('pairing token is removed from browser address and attached to API only',async()=>{const h=harness();await h.run('refresh()');assert.equal(h.calls[0].history[2],'/');assert.equal(h.calls.find(x=>x.path).options.headers.Authorization,`Bearer ${token}`);assert.equal(h.elements.connection.textContent,'Connected');assert.equal(h.elements.toggle.textContent,'Pause')});
test('play and queue send validated UI values with distinct actions',async()=>{const h=harness();h.elements.url.value=' https://youtu.be/dQw4w9WgXcQ ';h.elements.name.value=' My video ';await h.run("send('load')");await h.run("send('enqueue')");const posts=h.calls.filter(x=>x.options?.method==='POST').map(x=>JSON.parse(x.options.body));assert.deepEqual(posts,[{action:'load',url:'https://youtu.be/dQw4w9WgXcQ',title:'My video'},{action:'enqueue',url:'https://youtu.be/dQw4w9WgXcQ',title:'My video'}])});
test('remote titles render as plain text, including HTML-like input',async()=>{const malicious='<img src=x onerror=alert(1)>';const h=harness({response:{name:malicious,title:malicious,source:'',playing:false,buffering:false,position:0,duration:0,volume:1,queue:[malicious],error:''}});await h.run('refresh()');assert.equal(h.elements.title.textContent,malicious);assert.equal(h.elements.queue.children[0].textContent,malicious);assert.ok(h.elements.timeline.hidden)});
test('expired session halts polling and commands',async()=>{const h=harness({status:401,response:{error:'Expired'}});await h.run('refresh()');const before=h.calls.length;await h.run("command('play')");await h.run('refresh()');assert.equal(h.calls.length,before);assert.equal(h.elements.connection.textContent,'Pair again');assert.match(h.elements.notice.textContent,/Session ended/)});
test('server validation errors are visible and controls re-enable',async()=>{const h=harness({status:422,response:{error:'The queue is full.'}});await h.run("command('enqueue',{url:'https://example.com/a.mp4'})");assert.equal(h.elements.notice.textContent,'The queue is full.');assert.equal(h.elements.enqueue.disabled,false)});
test('time labels handle hour-long videos and negative positions',()=>{const h=harness({hash:''});assert.equal(h.run('time(3661)'),'1:01:01');assert.equal(h.run('time(-1)'),'0:00')});

test('queue-only session exposes one safe action and routes submits to enqueue',async()=>{const h=harness({response:{queueOnly:true,theme:'Moss',name:'Guest screen',title:'Video',source:'',playing:true,position:0,duration:0,volume:1,queue:[],error:''}});await h.run('refresh()');assert.equal(h.elements.load.textContent,'Add to queue');assert.equal(h.elements.enqueue.hidden,true);assert.equal(h.elements.transport.hidden,true);h.elements.url.value='https://example.com/video.mp4';await h.run("send('load')");const command=h.calls.find(x=>x.options?.method==='POST');assert.equal(JSON.parse(command.options.body).action,'enqueue')});
test('receiver-selected theme is restricted to known values',async()=>{const h=harness({response:{queueOnly:false,theme:'bad-value',name:'Screen',title:'Video',source:'',playing:false,position:0,duration:0,volume:1,queue:[],error:''}});await h.run('refresh()');assert.equal(h.run('document.documentElement.dataset.theme'),'Graphite')});
