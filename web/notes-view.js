export function filterStudyNotes(notes,query='',category='all'){
 const needle=String(query||'').trim().toLocaleLowerCase('ar');
 return notes.filter(note=>{
  const categoryMatches=category==='all'||(note.category||'المذكرات')===category;
  const textMatches=!needle||[note.title_ar,note.subject_name,note.summary_ar,note.category].some(value=>String(value||'').toLocaleLowerCase('ar').includes(needle));
  return categoryMatches&&textMatches;
 });
}
export function groupStudyNotes(notes){
 const groups=new Map();
 for(const note of notes){
  const subject=String(note.subject_name||'مادة غير مسماة');
  if(!groups.has(subject))groups.set(subject,[]);
  groups.get(subject).push(note);
 }
 return groups;
}
export function countStudyNoteCategories(notes){
 return {all:notes.length,notes:notes.filter(note=>(note.category||'المذكرات')==='المذكرات').length,summaries:notes.filter(note=>note.category==='الملخصات').length};
}
