import test from 'node:test';
import assert from 'node:assert/strict';
import {filterPublishedBankQuestions,groupBankQuestionsBySubject,getQuestionBankFilterOptions,canShowVerifiedAnswer} from '../question-bank-view.js';
const questions=[
 {id:1,prompt_ar:'ما عاصمة السودان؟',subject_name:'الجغرافيا',question_type:'multiple_choice',difficulty:1,answer_key_verified:1},
 {id:2,prompt_ar:'اشرح قانون نيوتن الأول',subject_name:'الفيزياء',question_type:'short_answer',difficulty:2,answer_key_verified:0},
 {id:3,prompt_ar:'هل الماء مركب؟',subject_name:'الكيمياء',question_type:'true_false',difficulty:1,answer_key_verified:0}
];
test('filters the published bank by prompt and subject',()=>{
 assert.deepEqual(filterPublishedBankQuestions(questions,'السودان').map(q=>q.id),[1]);
 assert.deepEqual(filterPublishedBankQuestions(questions,'الفيزياء').map(q=>q.id),[2]);
 assert.equal(filterPublishedBankQuestions(questions,'غير موجود').length,0);
});
test('filters by question type, difficulty and subject',()=>{
 assert.deepEqual(filterPublishedBankQuestions(questions,'',{type:'true_false'}).map(q=>q.id),[3]);
 assert.deepEqual(filterPublishedBankQuestions(questions,'',{difficulty:'2'}).map(q=>q.id),[2]);
 assert.deepEqual(filterPublishedBankQuestions(questions,'',{subject:'الجغرافيا',type:'multiple_choice'}).map(q=>q.id),[1]);
});
test('creates stable filter options and groups by subject',()=>{
 assert.deepEqual(getQuestionBankFilterOptions(questions),{subjects:['الجغرافيا','الفيزياء','الكيمياء'],types:['multiple_choice','short_answer','true_false'],difficulties:['1','2']});
 assert.deepEqual([...groupBankQuestionsBySubject(questions).keys()],['الجغرافيا','الفيزياء','الكيمياء']);
});
test('only explicitly verified answer keys may be shown',()=>{
 assert.equal(canShowVerifiedAnswer(questions[0]),true);
 assert.equal(canShowVerifiedAnswer(questions[1]),false);
 assert.equal(canShowVerifiedAnswer({answer_key_verified:'1'}),false);
});
