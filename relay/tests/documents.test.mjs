import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const root=new URL('../',import.meta.url);
const docs=JSON.parse(readFileSync(new URL('Still/Resources/documents.json',root),'utf8'));
test('all requested legal pages are bundled with substantial complete text',()=>{
 const minimum={privacy:1200,terms:1200,eula:1200,dataSafety:700,ncl:1000};
 for(const [key,words] of Object.entries(minimum)){
  const d=docs[key];assert.ok(d?.title);assert.ok(d.sections.length>=6);assert.ok(d.sections.map(s=>s.body).join(' ').split(/\s+/).length>=words,key);
  assert.equal(new Set(d.sections.map(s=>s.heading)).size,d.sections.length);
  for(const s of d.sections){assert.ok(s.body.trim());assert.ok(!/TODO|LOREM IPSUM|INSERT YOUR/.test(s.body))}
 }
});
test('public documents exactly match the policies packaged in the app',()=>{
 for(const [key,d] of Object.entries(docs)){
  const expected=`# ${d.title}\n\n${d.effective}\n\n`+d.sections.map(s=>`## ${s.heading}\n\n${s.body}`).join('\n\n')+'\n';
  assert.equal(readFileSync(new URL(`docs/${key}.md`,root),'utf8'),expected,key);
 }
});
test('repository license exactly matches the full offline NCL text',()=>{
 const d=docs.ncl;const expected=d.title+'\n\n'+d.sections.map(s=>s.heading+'\n\n'+s.body).join('\n\n')+'\n';
 assert.equal(readFileSync(new URL('LICENSE',root),'utf8'),expected);
 assert.match(expected,/project-specific/);assert.match(expected,/Earlier copies/);
});
test('privacy describes provider requests and wipe boundaries without implying anonymous streaming',()=>{
 const privacy=docs.privacy.sections.map(s=>s.body).join('\n');const wipe=docs.dataSafety.sections.map(s=>s.body).join('\n');
 assert.match(privacy,/zero developer telemetry/);assert.match(privacy,/YouTube\/Google/);assert.match(privacy,/HTTP and is not encrypted/);assert.match(wipe,/not a certified secure-erasure/);assert.match(wipe,/another device’s browser/);
});

test('Android offline policies match the receiver catalog, including screen transport and recording disclosures',()=>{
 assert.deepEqual(JSON.parse(readFileSync(new URL('android-sender/app/src/main/assets/documents.json',root),'utf8')),docs);
 assert.ok(docs.screenSharing.sections.length>=6);
 assert.match(docs.privacy.sections.map(s=>s.body).join(' '),/TURN/);
});
