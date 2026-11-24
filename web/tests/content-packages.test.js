import test from 'node:test';
import assert from 'node:assert/strict';
import { validateManifest, verifyPackageAssets, fileMap } from '../content-packages.js';
import { createHash } from 'node:crypto';
import { projectStudentExamQuestion } from '../database.js';

const good = () => ({
  schema_version:1,package_code:'math-supplement',version:'1.0.0',title:'حزمة تجريبية للاختبار',
  grade_code:'secondary_3',subject_code:'math',academic_year:'2026',edition_code:'test',
  source_label:'supplemental',
  units:[{code:'unit-1',title:'وحدة',lessons:[{code:'lesson-1',title:'درس',body_file:'lessons/one.txt'}]}],
  assets:[{path:'lessons/one.txt',bytes:5,sha256:'a'.repeat(64),media_type:'text/plain'}]
});

test('accepts a valid supplemental package manifest',()=>{
  assert.equal(validateManifest(good()).size,1);
});
test('accepts explicitly typed handouts and summaries',()=>{
  const manifest=good();manifest.notes=[{code:'handout-1',title:'مذكرة',file:'lessons/one.txt',type:'note'},{code:'summary-1',title:'ملخص',file:'lessons/one.txt',type:'summary'}];
  assert.equal(validateManifest(manifest).size,1);
});
test('rejects unknown study content types',()=>{
  const manifest=good();manifest.notes=[{code:'note-1',title:'ملف',file:'lessons/one.txt',type:'video'}];
  assert.throws(()=>validateManifest(manifest),/نوع المحتوى الدراسي غير صالح/);
});
test('rejects path traversal in lesson assets',()=>{
  const manifest=good();manifest.units[0].lessons[0].body_file='../secret.txt';
  assert.throws(()=>validateManifest(manifest),/مسار غير آمن/);
});
test('rejects official packages in the untrusted importer',()=>{
  const manifest=good();manifest.source_label='official';
  assert.throws(()=>validateManifest(manifest),/الحزم التكميلية فقط/);
});
test('rejects lesson body files missing from assets',()=>{
  const manifest=good();manifest.assets=[];
  assert.throws(()=>validateManifest(manifest),/غير مدرج ضمن assets/);
});
test('rejects duplicate lesson codes',()=>{
  const manifest=good();manifest.units[0].lessons.push({code:'lesson-1',title:'مكرر'});
  assert.throws(()=>validateManifest(manifest),/رمز درس مكرر/);
});
test('rejects unsupported question types',()=>{
  const manifest=good();manifest.exams=[{code:'exam-1',title:'امتحان',questions:[{code:'q-1',type:'essay',prompt:'سؤال'}]}];
  assert.throws(()=>validateManifest(manifest),/نوع سؤال غير مدعوم/);
});

test('rejects a note whose file is not declared as an asset',()=>{
  const manifest=good();manifest.notes=[{code:'note-1',title:'مذكرة',file:'notes/one.txt'}];
  assert.throws(()=>validateManifest(manifest),/غير مدرج ضمن assets/);
});
test('rejects malformed MIME types',()=>{
  const manifest=good();manifest.assets[0].media_type='not-a-mime';
  assert.throws(()=>validateManifest(manifest),/نوع الملف غير صالح/);
});
test('rejects negative or non-integer exam durations',()=>{
  const manifest=good();manifest.exams=[{code:'exam-1',title:'امتحان',duration_minutes:-5,questions:[{code:'q-1',type:'short_answer',prompt:'سؤال'}]}];
  assert.throws(()=>validateManifest(manifest),/مدة الامتحان غير صالحة/);
});
test('rejects non-boolean answer key verification flags',()=>{
  const manifest=good();manifest.exams=[{code:'exam-1',title:'امتحان',questions:[{code:'q-1',type:'short_answer',prompt:'سؤال',answer_key_verified:'true'}]}];
  assert.throws(()=>validateManifest(manifest),/قيمة منطقية/);
});
test('rejects duplicate package asset paths',()=>{
  const manifest=good();manifest.assets.push({...manifest.assets[0]});
  assert.throws(()=>validateManifest(manifest),/مسار ملف مكرر/);
});

test('student exam question projection never exposes answer keys or explanations',()=>{
  const question={id:9,package_id:4,question_type:'multiple_choice',prompt_ar:'سؤال',options_json:'[]',answer_json:'"A"',answer_key_verified:1,explanation_ar:'شرح الإجابة',difficulty:2};
  const projected=projectStudentExamQuestion(question,{marks:3},4);
  assert.deepEqual(projected,{id:9,question_type:'multiple_choice',prompt_ar:'سؤال',options_json:'[]',marks:3,difficulty:2});
  assert.equal('answer_json' in projected,false);
  assert.equal('answer_key_verified' in projected,false);
  assert.equal('explanation_ar' in projected,false);
});
test('student question projection rejects a question from another package',()=>{
  assert.equal(projectStudentExamQuestion({id:1,package_id:8},{marks:1},4),null);
});

test('rejects assets larger than the per-file offline import limit',()=>{
  const manifest=good();manifest.assets[0].bytes=50*1024*1024+1;
  assert.throws(()=>validateManifest(manifest),/تجاوز الملف الحد المسموح/);
});
test('accepts a PDF asset MIME type',()=>{
  const manifest=good();manifest.assets[0].media_type='application/pdf';
  assert.equal(validateManifest(manifest).size,1);
});

test('rejects null nested units and lessons instead of throwing raw type errors',()=>{
  const manifest=good();manifest.units[0]=null;
  assert.throws(()=>validateManifest(manifest),/وحدة يجب أن تكون كائناً صالحاً/);
  const second=good();second.units[0].lessons[0]=null;
  assert.throws(()=>validateManifest(second),/درس يجب أن يكون كائناً صالحاً/);
});
test('rejects invalid optional lesson field types',()=>{
  const manifest=good();manifest.units[0].lessons[0].summary={text:'not a string'};
  assert.throws(()=>validateManifest(manifest),/ملخص الدرس يجب أن يكون نصاً/);
});
test('rejects null exam question objects',()=>{
  const manifest=good();manifest.exams=[{code:'exam-1',title:'امتحان',questions:[null]}];
  assert.throws(()=>validateManifest(manifest),/سؤال يجب أن يكون كائناً صالحاً/);
});

test('verifies package asset SHA-256 and size before import',async()=>{
  const file=new File(['hello'],'one.txt',{type:'text/plain'});
  const sha=createHash('sha256').update('hello').digest('hex');
  const verified=await verifyPackageAssets(new Map([['one.txt',{bytes:5,sha256:sha,media_type:'text/plain'}]]),[file]);
  assert.equal(verified.length,1);
  assert.equal(verified[0].path,'one.txt');
});
test('rejects missing package asset files',async()=>{
  await assert.rejects(()=>verifyPackageAssets(new Map([['missing.txt',{bytes:1,sha256:'a'.repeat(64),media_type:'text/plain'}]]),[]),/ملف مفقود/);
});
test('rejects package assets with incorrect SHA-256',async()=>{
  const file=new File(['hello'],'one.txt');
  await assert.rejects(()=>verifyPackageAssets(new Map([['one.txt',{bytes:5,sha256:'a'.repeat(64),media_type:'text/plain'}]]),[file]),/SHA-256/);
});
test('rejects duplicate relative paths in a selected package folder',()=>{
  const first=new File(['a'],'same.txt');
  const second=new File(['b'],'same.txt');
  assert.throws(()=>fileMap([first,second]),/مسار ملف مكرر/);
});
test('rejects package totals above 200 MiB before hashing',async()=>{
  const oversized={name:'large.bin',size:200*1024*1024+1,arrayBuffer:async()=>new ArrayBuffer(0)};
  await assert.rejects(()=>verifyPackageAssets(new Map([['large.bin',{bytes:oversized.size,sha256:'a'.repeat(64),media_type:'application/octet-stream'}]]),[oversized]),/200 ميجابايت/);
});

test('rejects unsupported lesson asset formats before import',()=>{
  const manifest=good();manifest.assets[0].media_type='video/mp4';
  assert.throws(()=>validateManifest(manifest),/نوع ملف الدرس أو المذكرة غير مدعوم/);
});
test('rejects a manifest that is not at the selected package root',()=>{
  const nested={name:'manifest.json',webkitRelativePath:'root/nested/manifest.json'};
  assert.equal(fileMap([nested]).has('manifest.json'),false);
});

test('supports a flat multi-file selection using unique asset basenames',async()=>{
  const file=new File(['hello'],'one.txt',{type:'text/plain'});
  const sha=createHash('sha256').update('hello').digest('hex');
  const verified=await verifyPackageAssets(new Map([['lessons/one.txt',{bytes:5,sha256:sha,media_type:'text/plain'}]]),[file]);
  assert.equal(verified[0].file.name,'one.txt');
});
