import test from 'node:test';
import assert from 'node:assert/strict';
import { indexedDB } from 'fake-indexeddb';
import { File } from 'node:buffer';
import { createHash } from 'node:crypto';

globalThis.indexedDB = indexedDB;
globalThis.crypto ??= (await import('node:crypto')).webcrypto;

const db = await import('../database.js');
const importer = await import('../content-packages.js');

function makeFile(name, path, contents, type='application/octet-stream') {
  const file = new File([contents], name, {type});
  Object.defineProperty(file, 'webkitRelativePath', {value:'package-root/'+path});
  return file;
}
function sha(text) { return createHash('sha256').update(text).digest('hex'); }
function manifest(overrides={}) {
  const lesson='هذا نص درس تجريبي.';
  const note='%PDF-1.4\n% fixture';
  return {
    schema_version:1,package_code:'integration-package',version:'1.0.0',title:'حزمة اختبار تكامل',
    grade_code:'secondary_3',subject_code:'math',academic_year:'2026',edition_code:'test-edition',
    source_label:'supplemental',
    units:[{code:'unit-1',title:'الوحدة التجريبية',lessons:[{code:'lesson-1',title:'الدرس التجريبي',summary:'ملخص',body_file:'lessons/one.txt'}]}],
    notes:[{code:'note-1',title:'المذكرة التجريبية',file:'notes/one.pdf'}],
    exams:[{code:'exam-1',title:'امتحان تجريبي',exam_type:'practice',duration_minutes:15,questions:[{code:'q-1',type:'multiple_choice',prompt:'اختر الإجابة',lesson_code:'lesson-1',options:[{value:'A',label:'أ'},{value:'B',label:'ب'}],answer:'A',answer_key_verified:true,marks:2}]}],
    assets:[
      {path:'lessons/one.txt',bytes:Buffer.byteLength(lesson),sha256:sha(lesson),media_type:'text/plain'},
      {path:'notes/one.pdf',bytes:Buffer.byteLength(note),sha256:sha(note),media_type:'application/pdf'}
    ],
    ...overrides
  };
}
function packageFiles(m=manifest()) {
  const lesson='هذا نص درس تجريبي.';
  const note='%PDF-1.4\n% fixture';
  return [
    makeFile('manifest.json','manifest.json',JSON.stringify(m),'application/json'),
    makeFile('one.txt','lessons/one.txt',lesson,'text/plain'),
    makeFile('one.pdf','notes/one.pdf',note,'application/pdf')
  ];
}

test('imports, reviews and publishes a supplemental package without trusting its answer key', async () => {
  const database=await db.openDb();
  const tx=database.transaction(['subjects','curriculum_releases','curriculum_release_subjects'],'readwrite');
  tx.objectStore('subjects').put({id:1,code:'math',name_ar:'الرياضيات',grade_id:3,track_id:null,is_active:1});
  tx.objectStore('curriculum_releases').put({id:1,grade_id:3,academic_year:'2026',edition_code:'test-edition',track_id:null,verification_status:'verified'});
  tx.objectStore('curriculum_release_subjects').put({id:1,release_id:1,subject_id:1,verification_status:'verified'});
  await new Promise((resolve,reject)=>{tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);});

  const result=await importer.importContentPackage(packageFiles());
  assert.equal(result.status,'pending_review');
  assert.equal(result.lessons,1);
  assert.equal((await db.getContentPackages({reviewStatus:'pending_review'})).length,1);
  assert.equal((await db.getApprovedUnits({gradeId:3})).length,0);
  assert.equal((await db.getPublishedNotes({gradeId:3})).length,0);
  assert.equal((await db.getPublishedExams({gradeId:3})).length,0);

  const questions=await db.getAll('questions');
  assert.equal(questions.length,1);
  assert.equal(questions[0].answer_key_verified,0);

  await db.reviewContentPackage({packageId:result.packageId,decision:'approved',reviewerLabel:'مراجع الاختبار',notes:'تمت مراجعة عينة الاختبار.'});
  assert.equal((await db.getApprovedUnits({gradeId:3})).length,1);
  const notes=await db.getPublishedNotes({gradeId:3});
  assert.equal(notes.length,1);
  assert.equal(notes[0].category,'المذكرات');
  assert.equal((await db.getPublishedExams({gradeId:3})).length,1);
  assert.equal((await db.getPackageReviewHistory(result.packageId)).length,1);
  const asset=await db.getPackageAsset(result.packageId,'lessons/one.txt');
  assert.equal(await asset.blob.text(),'هذا نص درس تجريبي.');
});

test('rejects invalid asset hashes before creating any package records', async () => {
  const m=manifest({package_code:'bad-hash-package'});
  m.assets[0]={...m.assets[0],sha256:'0'.repeat(64)};
  await assert.rejects(()=>importer.importContentPackage(packageFiles(m)),/SHA-256/);
  assert.equal((await db.getContentPackages()).some(x=>x.package_code==='bad-hash-package'),false);
});

test('rejects duplicate package codes and refuses a second import', async () => {
  await assert.rejects(()=>importer.importContentPackage(packageFiles()),/مثبتة مسبقاً/);
});
