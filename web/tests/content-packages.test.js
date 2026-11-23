import test from 'node:test';
import assert from 'node:assert/strict';
import { validateManifest } from '../content-packages.js';

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
