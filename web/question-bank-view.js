export function filterPublishedBankQuestions(questions,query='',filters={}){
 const needle=String(query||'').trim().toLocaleLowerCase('ar');
 return questions.filter(question=>{
  const text=[question.prompt_ar,question.subject_name,question.lesson_title,question.source_exam_title].some(value=>String(value??'').toLocaleLowerCase('ar').includes(needle));
  const matchesText=!needle||text;
  const matchesType=!filters.type||String(question.question_type||'')===String(filters.type);
  const matchesDifficulty=!filters.difficulty||String(question.difficulty??'')===String(filters.difficulty);
  const matchesSubject=!filters.subject||String(question.subject_name||'')===String(filters.subject);
  return matchesText&&matchesType&&matchesDifficulty&&matchesSubject;
 });
}
export function groupBankQuestionsBySubject(questions){
 const groups=new Map();
 for(const question of questions){
  const subject=String(question.subject_name||'مادة غير مسماة');
  if(!groups.has(subject))groups.set(subject,[]);
  groups.get(subject).push(question);
 }
 return groups;
}
export function getQuestionBankFilterOptions(questions){
 return {
  subjects:[...new Set(questions.map(q=>String(q.subject_name||'')).filter(Boolean))].sort((a,b)=>a.localeCompare(b,'ar')),
  types:[...new Set(questions.map(q=>String(q.question_type||'')).filter(Boolean))].sort(),
  difficulties:[...new Set(questions.map(q=>q.difficulty).filter(v=>v!==null&&v!==undefined).map(String))].sort((a,b)=>Number(a)-Number(b))
 };
}
export function canShowVerifiedAnswer(question){
 return question?.answer_key_verified===1||question?.answer_key_verified===true;
}
