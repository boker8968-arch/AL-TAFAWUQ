import test from 'node:test';
import assert from 'node:assert/strict';
import {groupCurriculumUnits,filterCurriculumEntries,getCurriculumUnitStats} from '../curriculum-view.js';

const entries=[
 {unit:{id:1,subject_name:'الرياضيات',title_ar:'الجبر'},lessons:[{id:11},{id:12}]},
 {unit:{id:2,subject_name:'الرياضيات',title_ar:'الهندسة'},lessons:[{id:13}]},
 {unit:{id:3,subject_name:'اللغة العربية',title_ar:'النحو'},lessons:[]}
];

test('groups approved curriculum units under their subject names',()=>{
 const groups=groupCurriculumUnits(entries);
 assert.deepEqual([...groups.keys()],['الرياضيات','اللغة العربية']);
 assert.equal(groups.get('الرياضيات').length,2);
});
test('filters curriculum by Arabic subject or unit title',()=>{
 const math=filterCurriculumEntries(entries,'الرياضيات','الجبر');
 assert.deepEqual(math.map(x=>x.unit.id),[1]);
 const subject=filterCurriculumEntries(entries,'الرياضيات','الرياضيات');
 assert.deepEqual(subject.map(x=>x.unit.id),[1,2]);
});
test('returns all entries for an empty search and tolerates missing titles',()=>{
 assert.equal(filterCurriculumEntries(entries,'الرياضيات','  ').length,3);
 const missing=[{unit:{subject_name:'علوم'},lessons:[]}];
 assert.equal(filterCurriculumEntries(missing,'علوم','درس').length,0);
});
test('calculates completed lessons and rounded unit progress',()=>{
 const progress=new Map([[11,{status:'completed'}],[12,{status:'in_progress'}],[13,{status:'completed'}]]);
 assert.deepEqual(getCurriculumUnitStats(entries[0].lessons,progress),{total:2,completed:1,percent:50});
 assert.deepEqual(getCurriculumUnitStats(entries[2].lessons,progress),{total:0,completed:0,percent:0});
});
test('does not count in-progress lessons as completed',()=>{
 const progress=new Map([[11,{status:'in_progress'}],[12,{status:'not_started'}]]);
 assert.deepEqual(getCurriculumUnitStats(entries[0].lessons,progress),{total:2,completed:0,percent:0});
});
