export function groupCurriculumUnits(entries){
 const groups=new Map();
 for(const entry of entries){
  const subject=String(entry.unit.subject_name||'مادة غير مسماة');
  if(!groups.has(subject))groups.set(subject,[]);
  groups.get(subject).push(entry);
 }
 return groups;
}
export function filterCurriculumEntries(entries,subject,query=''){
 const needle=String(query||'').trim().toLocaleLowerCase('ar');
 if(!needle)return entries;
 return entries.filter(({unit})=>String(subject||'').toLocaleLowerCase('ar').includes(needle)||String(unit.title_ar||'').toLocaleLowerCase('ar').includes(needle));
}
export function getCurriculumUnitStats(lessons,progressByLesson){
 const completed=lessons.filter(lesson=>progressByLesson.get(lesson.id)?.status==='completed').length;
 return {total:lessons.length,completed,percent:lessons.length?Math.round(completed/lessons.length*100):0};
}
