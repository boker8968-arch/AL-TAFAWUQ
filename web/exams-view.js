export function filterPublishedExams(exams,query=''){
 const needle=String(query||'').trim().toLocaleLowerCase('ar');
 if(!needle)return exams;
 return exams.filter(exam=>[exam.title_ar,exam.subject_name,exam.academic_year,exam.exam_type].some(value=>String(value??'').toLocaleLowerCase('ar').includes(needle)));
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
