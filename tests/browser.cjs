// Browser integration against a controlled receiver fixture, not the iOS service.
const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const token = 'a'.repeat(32);
const html = fs.readFileSync(path.join(__dirname, '../Still/Resources/remote.html'));
const commands = [];
const state = {name:'Muneeb’s iPad', title:'Ready to receive', source:'', playing:false, buffering:false, position:0, duration:0, volume:1, queue:[], error:'',queueOnly:false,theme:'Moss'};
const server = http.createServer((req, res) => {
  if (req.url === '/') {res.writeHead(200, {'Content-Type':'text/html'});res.end(html);return}
  res.setHeader('Content-Type','application/json');
  if(req.headers.authorization !== `Bearer ${token}`) {res.writeHead(401);res.end('{"error":"Pair again"}');return}
  if(req.url === '/api/state') {res.end(JSON.stringify(state));return}
  if(req.url === '/api/command') {
    let body='';req.on('data',x=>body+=x);req.on('end',()=>{const command=JSON.parse(body);commands.push(command);if(command.action==='load'){state.title=command.title||'YouTube video';state.source='YouTube';state.playing=true;state.duration=180}if(command.action==='enqueue')state.queue.push(command.title||'Queued video');if(command.action==='pause')state.playing=false;if(command.action==='play')state.playing=true;if(command.action==='volume')state.volume=command.value;res.end('{"ok":true}')});return;
  }
  res.writeHead(404);res.end('{}');
});
(async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/usr/bin/chromium',headless:true,args:['--no-sandbox']});
  try {
    const page=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:2,colorScheme:'light'});
    const errors=[];page.on('pageerror',error=>errors.push(error.message));
    const url=`http://127.0.0.1:${server.address().port}/#${token}`;
    await page.goto(url);await page.waitForFunction(()=>document.querySelector('#connection').textContent==='Connected');
    assert.equal(new URL(page.url()).hash,'');
    await page.locator('#options').evaluate(x=>x.open=true);
    await page.locator('#url').fill('https://youtu.be/dQw4w9WgXcQ');await page.locator('#name').fill('A moment, shared.');await page.locator('#load').click();
    await page.waitForFunction(()=>document.querySelector('#title').textContent==='A moment, shared.');
    await page.locator('#toggle').click();await page.waitForFunction(()=>document.querySelector('#toggle').textContent==='Play');
    await page.locator('#name').fill('<script>alert("hello")</script>');await page.locator('#enqueue').click();
    await page.waitForFunction(()=>document.querySelector('#queue').children.length===1);
    assert.equal(await page.locator('#queue li').textContent(),'<script>alert("hello")</script>');assert.equal(await page.locator('#queue script').count(),0);
    await page.locator('#name').fill('');
    state.queue=['A walk through Kyoto','Sunday, slowly'];
    await page.evaluate(()=>refresh());
    await page.locator('#name').blur();
    await page.locator('#options').evaluate(x=>x.open=false);
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
    fs.mkdirSync(path.join(__dirname,'../docs/screenshots'),{recursive:true});
    await page.screenshot({path:path.join(__dirname,'../docs/screenshots/remote-light.png'),fullPage:true});
    await page.emulateMedia({colorScheme:'dark',reducedMotion:'reduce'});
    await page.screenshot({path:path.join(__dirname,'../docs/screenshots/remote-dark.png'),fullPage:true});
    state.queueOnly=true;
    await page.evaluate(()=>refresh());
    assert.equal(await page.locator('#load').textContent(),'Add to queue');
    assert.equal(await page.locator('#transport').isVisible(),false);
    await page.locator('#url').fill('https://example.com/next.mp4');await page.locator('#load').click();
    await page.waitForFunction(()=>document.querySelector('#queue').children.length===3);
    assert.equal(commands.at(-1).action,'enqueue');
    assert.equal(await page.evaluate(()=>document.documentElement.dataset.theme),'Moss');
    await page.screenshot({path:path.join(__dirname,'../docs/screenshots/remote-queue-only.png'),fullPage:true});
    await page.setViewportSize({width:1024,height:768});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
    await page.goto(`http://127.0.0.1:${server.address().port}/`);assert.equal(await page.locator('#load').isDisabled(),true);
    assert.deepEqual(errors,[]);assert.deepEqual(commands.map(x=>x.action),['load','pause','enqueue','enqueue']);
    console.log('PASS: mobile pairing, token removal, play, pause, enqueue, injection safety, light/dark, reduced motion, tablet layout, queue-only mode, receiver theme and missing-token state.');
  } finally {await browser.close();await new Promise(resolve=>server.close(resolve))}
})().catch(error=>{console.error(error);server.close();process.exitCode=1});
