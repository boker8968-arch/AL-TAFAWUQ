export function filterPublishedExams(exams,query='',filters={}){
 const needle=String(query||'').trim().toLocaleLowerCase('ar');
 return exams.filter(exam=>{
  const matchesText=!needle||[exam.title_ar,exam.subject_name,exam.academic_year,exam.exam_type].some(value=>String(value??'').toLocaleLowerCase('ar').includes(needle));
  const year=String(exam.academic_year||exam.year||'');
  const matchesYear=!filters.year||year===String(filters.year);
  const matchesType=!filters.type||String(exam.exam_type||'practice')===String(filters.type);
  return matchesText&&matchesYear&&matchesType;
 });
}
export function groupExamsBySubject(exams){
 const groups=new Map();
 for(const exam of exams){
  const subject=String(exam.subject_name||'مادة غير مسماة');
  if(!groups.has(subject))groups.set(subject,[]);
  groups.get(subject).push(exam);
 }
 return groups;
}
export function getExamFilterOptions(exams){
 const years=[...new Set(exams.map(exam=>String(exam.academic_year||exam.year||'')).filter(Boolean))].sort((a,b)=>b.localeCompare(a,'ar',{numeric:true}));
 const types=[...new Set(exams.map(exam=>String(exam.exam_type||'practice')).filter(Boolean))].sort();
 return {years,types};
}
