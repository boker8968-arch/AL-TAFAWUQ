export function filterStudyNotes(notes,query=''){
 const needle=String(query||'').trim().toLocaleLowerCase('ar');
 if(!needle)return notes;
 return notes.filter(note=>[note.title_ar,note.subject_name,note.summary_ar,note.category].some(value=>String(value||'').toLocaleLowerCase('ar').includes(needle)));
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
