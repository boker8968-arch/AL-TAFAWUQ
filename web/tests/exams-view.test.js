import test from 'node:test';
import assert from 'node:assert/strict';
import {filterPublishedExams,groupExamsBySubject,getExamFilterOptions} from '../exams-view.js';
const exams=[
 {id:1,title_ar:'امتحان الرياضيات 2024',subject_name:'الرياضيات',academic_year:'2024',exam_type:'previous'},
 {id:2,title_ar:'امتحان الأحياء 2023',subject_name:'الأحياء',academic_year:'2023',exam_type:'practice'},
 {id:3,title_ar:'مراجعة الرياضيات 2022',subject_name:'الرياضيات',academic_year:'2022',exam_type:'previous'}
];
test('filters exams by title, subject and year text',()=>{
 assert.deepEqual(filterPublishedExams(exams,'2023').map(x=>x.id),[2]);
 assert.deepEqual(filterPublishedExams(exams,'الرياضيات').map(x=>x.id),[1,3]);
 assert.equal(filterPublishedExams(exams,'غير موجود').length,0);
 assert.equal(filterPublishedExams(exams,'').length,3);
});
test('filters by selected academic year and exam type',()=>{
 assert.deepEqual(filterPublishedExams(exams,'',{year:'2024'}).map(x=>x.id),[1]);
 assert.deepEqual(filterPublishedExams(exams,'',{type:'previous'}).map(x=>x.id),[1,3]);
 assert.deepEqual(filterPublishedExams(exams,'رياضيات',{year:'2024',type:'previous'}).map(x=>x.id),[1]);
 assert.equal(filterPublishedExams(exams,'',{year:'2020'}).length,0);
});
test('builds distinct year and type options',()=>{
 assert.deepEqual(getExamFilterOptions(exams),{years:['2024','2023','2022'],types:['practice','previous']});
});
test('groups exams by subject without changing their order',()=>{
 const groups=groupExamsBySubject(exams);
 assert.deepEqual([...groups.keys()],['الرياضيات','الأحياء']);
 assert.deepEqual(groups.get('الرياضيات').map(x=>x.id),[1,3]);
});
