import test from 'node:test';
import assert from 'node:assert/strict';
import {filterStudyNotes,groupStudyNotes,countStudyNoteCategories} from '../notes-view.js';

const notes=[
 {id:1,title_ar:'مذكرة الجبر',subject_name:'الرياضيات',summary_ar:'المعادلات',category:'المذكرات'},
 {id:2,title_ar:'ملخص الوراثة',subject_name:'الأحياء',summary_ar:'الصفات الوراثية',category:'الملخصات'},
 {id:3,title_ar:'مراجعة الهندسة',subject_name:'الرياضيات',summary_ar:'الأشكال',category:'المذكرات'}
];

test('filters study notes by title, subject, summary, and category',()=>{
 assert.deepEqual(filterStudyNotes(notes,'الجبر').map(x=>x.id),[1]);
 assert.deepEqual(filterStudyNotes(notes,'الأحياء').map(x=>x.id),[2]);
 assert.deepEqual(filterStudyNotes(notes,'الوراثية').map(x=>x.id),[2]);
 assert.equal(filterStudyNotes(notes,'المذكرات').length,2);
 assert.equal(filterStudyNotes(notes,'غير موجود').length,0);
});
test('filters handouts and summaries independently',()=>{
 assert.deepEqual(filterStudyNotes(notes,'','المذكرات').map(x=>x.id),[1,3]);
 assert.deepEqual(filterStudyNotes(notes,'','الملخصات').map(x=>x.id),[2]);
 assert.deepEqual(countStudyNoteCategories(notes),{all:3,notes:2,summaries:1});
});
test('groups notes by subject and keeps their source order',()=>{
 const groups=groupStudyNotes(notes);
 assert.deepEqual([...groups.keys()],['الرياضيات','الأحياء']);
 assert.deepEqual(groups.get('الرياضيات').map(x=>x.id),[1,3]);
});
test('returns all notes for an empty search',()=>assert.equal(filterStudyNotes(notes,' ').length,3));
