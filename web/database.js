// Browser-side schema mirrors the Flutter SQLite v6 domain and publication rules.
const DB_NAME='al-tafawuq', DB_VERSION=5;
const DEFINITIONS={
 grades:{keyPath:'id'},
 study_tracks:{keyPath:'id',indexes:[['grade_id','grade_id']]},
 subjects:{keyPath:'id',indexes:[['grade_id','grade_id'],['track_id','track_id']]},
 curriculum_releases:{keyPath:'id',indexes:[['grade_id','grade_id']]},
 curriculum_release_subjects:{keyPath:'id',indexes:[['release_id','release_id'],['subject_id','subject_id']]},
 curriculum_units:{keyPath:'id',indexes:[['subject_id','subject_id'],['release_subject_id','release_subject_id'],['package_id','package_id']]},
 lessons:{keyPath:'id',indexes:[['unit_id','unit_id']]},
 exams:{keyPath:'id',indexes:[['subject_id','subject_id'],['package_id','package_id']]},
 questions:{keyPath:'id',indexes:[['subject_id','subject_id'],['package_id','package_id']]},
 exam_questions:{keyPath:['exam_id','question_id'],indexes:[['exam_id','exam_id']]},
 exam_attempts:{keyPath:'id',indexes:[['exam_id','exam_id']]},
 attempt_answers:{keyPath:'id',indexes:[['attempt_id','attempt_id'],['question_pair',['attempt_id','question_id'],true]]},
 bookmarks:{keyPath:'id',indexes:[['item_type','item_type']]},
 study_progress:{keyPath:'lesson_id'},
 student_profiles:{keyPath:'id'},
 content_packages:{keyPath:'id',indexes:[['package_code','package_code'],['review_status','review_status']]},
 content_package_reviews:{keyPath:'id',indexes:[['package_id','package_id']]},
 package_assets:{keyPath:['package_id','path'],indexes:[['package_id','package_id']]},
 study_sessions:{keyPath:'id',indexes:[['started_at','started_at'],['subject_id','subject_id']]}
};
let opening;
export function openDb(){if(opening)return opening;opening=new Promise((resolve,reject)=>{const req=indexedDB.open(DB_NAME,DB_VERSION);req.onupgradeneeded=event=>{const db=req.result,tx=req.transaction;let legacyAnswers=null;if(event.oldVersion<4&&db.objectStoreNames.contains('attempt_answers')){legacyAnswers=tx.objectStore('attempt_answers').getAll();db.deleteObjectStore('attempt_answers');}for(const [name,spec] of Object.entries(DEFINITIONS)){const store=db.objectStoreNames.contains(name)?tx.objectStore(name):db.createObjectStore(name,{keyPath:spec.keyPath,autoIncrement:name!=='grades'&&name!=='study_progress'&&name!=='student_profiles'&&name!=='exam_questions'&&name!=='package_assets'});for(const [index,key,unique=false] of spec.indexes||[])if(!store.indexNames.contains(index))store.createIndex(index,key,{unique});}if(legacyAnswers){legacyAnswers.onsuccess=()=>{const store=tx.objectStore('attempt_answers');for(const row of legacyAnswers.result){const copy={...row};delete copy.id;store.put(copy);}};}const grades=tx.objectStore('grades');for(const row of [{id:1,code:'secondary_1',name_ar:'الصف الأول الثانوي',sort_order:1,is_active:1},{id:2,code:'secondary_2',name_ar:'الصف الثاني الثانوي',sort_order:2,is_active:1},{id:3,code:'secondary_3',name_ar:'الصف الثالث الثانوي',sort_order:3,is_active:1}])grades.put(row);};req.onsuccess=()=>resolve(req.result);req.onerror=()=>{opening=null;reject(req.error)};});return opening;}
export async function getAll(name){const db=await openDb();return new Promise((resolve,reject)=>{const req=db.transaction(name).objectStore(name).getAll();req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);});}
export async function getRecord(name,key){const db=await openDb();return new Promise((resolve,reject)=>{const req=db.transaction(name).objectStore(name).get(key);req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);});}
export async function putRecord(name,value){const db=await openDb();return new Promise((resolve,reject)=>{const tx=db.transaction(name,'readwrite');tx.objectStore(name).put(value);tx.oncomplete=()=>resolve(true);tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error||new Error('تعذر حفظ البيانات'));});}
export async function addRecord(name,value){const db=await openDb();return new Promise((resolve,reject)=>{const tx=db.transaction(name,'readwrite'),req=tx.objectStore(name).add(value);req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);});}
export async function getStudentProfile(){return getRecord('student_profiles',1);}
export async function saveStudentProfile({name,gradeId,trackId=null}){const grade=await getRecord('grades',Number(gradeId));if(!grade||!grade.is_active)throw new Error('الصف الدراسي غير صالح');if(trackId!==null){const track=await getRecord('study_tracks',Number(trackId));if(!track||track.grade_id!==Number(gradeId)||!track.is_active)throw new Error('المسار لا يتبع الصف المختار');}return putRecord('student_profiles',{id:1,display_name:(name||'').trim()||null,grade_id:Number(gradeId),track_id:trackId===null?null:Number(trackId),updated_at:new Date().toISOString()});}
export async function getTracksForGrade(gradeId){return (await getAll('study_tracks')).filter(t=>t.grade_id===Number(gradeId)&&t.is_active!==0).sort((a,b)=>(a.name_ar||'').localeCompare(b.name_ar||'','ar'));}
export async function getApprovedUnits({gradeId,trackId=null,subjectId=null}){const [units,subjects,releases,mappings,packages]=await Promise.all(['curriculum_units','subjects','curriculum_releases','curriculum_release_subjects','content_packages'].map(getAll));const sm=new Map(subjects.map(x=>[x.id,x])),rm=new Map(releases.map(x=>[x.id,x])),mm=new Map(mappings.map(x=>[x.id,x])),pm=new Map(packages.map(x=>[x.id,x]));return units.filter(u=>{const s=sm.get(u.subject_id),m=mm.get(u.release_subject_id),r=m&&rm.get(m.release_id),p=pm.get(u.package_id);return s&&s.grade_id===Number(gradeId)&&(trackId===null?s.track_id==null:(s.track_id==null||s.track_id===Number(trackId)))&&(!subjectId||s.id===Number(subjectId))&&p?.review_status==='approved'&&m?.verification_status==='verified'&&r?.verification_status==='verified';}).map(u=>({...u,subject_name:sm.get(u.subject_id)?.name_ar})).sort((a,b)=>(a.subject_name||'').localeCompare(b.subject_name||'','ar')||(a.sort_order||0)-(b.sort_order||0));}
export async function getApprovedLessons(unitId){const [lessons,units,packages,mappings,releases]=await Promise.all(['lessons','curriculum_units','content_packages','curriculum_release_subjects','curriculum_releases'].map(getAll));const um=new Map(units.map(x=>[x.id,x])),pm=new Map(packages.map(x=>[x.id,x])),mm=new Map(mappings.map(x=>[x.id,x])),rm=new Map(releases.map(x=>[x.id,x]));return lessons.filter(l=>{const u=um.get(l.unit_id),p=u&&pm.get(u.package_id),m=u&&mm.get(u.release_subject_id),r=m&&rm.get(m.release_id);return l.unit_id===Number(unitId)&&p?.review_status==='approved'&&m?.verification_status==='verified'&&r?.verification_status==='verified';}).map(l=>({...l,package_id:um.get(l.unit_id)?.package_id})).sort((a,b)=>(a.sort_order||0)-(b.sort_order||0));}
export async function saveLessonProgress(lessonId,percent=100){const lessons=await getApprovedLessonsForLesson(lessonId);if(!lessons)throw new Error('هذا الدرس غير منشور للطلاب');const n=Math.max(0,Math.min(100,Number(percent)||0)),now=new Date().toISOString();return putRecord('study_progress',{lesson_id:Number(lessonId),status:n>=100?'completed':n>0?'in_progress':'not_started',progress_percent:n,last_opened_at:now,completed_at:n>=100?now:null});}
async function getApprovedLessonsForLesson(id){const [lessons,units,packages,mappings,releases]=await Promise.all(['lessons','curriculum_units','content_packages','curriculum_release_subjects','curriculum_releases'].map(getAll));const l=lessons.find(x=>x.id===Number(id)),u=l&&units.find(x=>x.id===l.unit_id),p=u&&packages.find(x=>x.id===u.package_id),m=u&&mappings.find(x=>x.id===u.release_subject_id),r=m&&releases.find(x=>x.id===m.release_id);return Boolean(l&&p?.review_status==='approved'&&m?.verification_status==='verified'&&r?.verification_status==='verified');}
export async function getPublishedExams({gradeId,trackId=null,subjectId=null}){const [exams,subjects,packages,units,mappings,releases,links,questions]=await Promise.all(['exams','subjects','content_packages','curriculum_units','curriculum_release_subjects','curriculum_releases','exam_questions','questions'].map(getAll));const result=[];for(const e of exams){const s=subjects.find(x=>x.id===e.subject_id),p=packages.find(x=>x.id===e.package_id);if(!s||s.grade_id!==Number(gradeId)||p?.review_status!=='approved'||(subjectId&&s.id!==Number(subjectId))||(trackId===null?s.track_id!=null:(s.track_id!=null&&s.track_id!==Number(trackId))))continue;const mapped=units.some(u=>u.package_id===p.id&&mappings.some(m=>m.id===u.release_subject_id&&m.subject_id===s.id&&m.verification_status==='verified'&&releases.some(r=>r.id===m.release_id&&r.verification_status==='verified')));const count=links.filter(x=>x.exam_id===e.id&&questions.some(q=>q.id===x.question_id&&q.package_id===e.package_id)).length;if(mapped&&count)result.push({...e,subject_name:s.name_ar,question_count:count});}return result.sort((a,b)=>b.id-a.id);}


export async function startExamAttempt(examId,{gradeId,trackId=null}={}){
  const exams=await getPublishedExams({gradeId,trackId});
  const exam=exams.find(x=>x.id===Number(examId));
  if(!exam)throw new Error('هذا الامتحان غير منشور لهذا الصف.');
  return addRecord('exam_attempts',{exam_id:exam.id,started_at:new Date().toISOString(),completed_at:null,score:null,total_marks:null});
}
export async function getAttemptQuestions(attemptId){
  const attempt=await getRecord('exam_attempts',Number(attemptId));
  if(!attempt||attempt.completed_at)throw new Error('المحاولة غير متاحة أو تم تسليمها.');
  const [exams,links,questions,packages]=await Promise.all(['exams','exam_questions','questions','content_packages'].map(getAll));
  const exam=exams.find(x=>x.id===attempt.exam_id),pkg=exam&&packages.find(x=>x.id===exam.package_id);
  if(!exam||pkg?.review_status!=='approved')throw new Error('الامتحان غير معتمد.');
  const ids=links.filter(x=>x.exam_id===exam.id).sort((a,b)=>(a.sort_order||0)-(b.sort_order||0));
  return ids.map(link=>{const q=questions.find(x=>x.id===link.question_id);return q&&q.package_id===exam.package_id?{...q,marks:link.marks}:null;}).filter(Boolean);
}
export async function saveAttemptAnswer(attemptId,questionId,answer){
  const attempt=await getRecord('exam_attempts',Number(attemptId));
  if(!attempt||attempt.completed_at)throw new Error('المحاولة مغلقة.');
  const questions=await getAttemptQuestions(attemptId);
  if(!questions.some(q=>q.id===Number(questionId)))throw new Error('السؤال لا يتبع هذه المحاولة.');
  const all=await getAll('attempt_answers');
  const old=all.find(x=>x.attempt_id===Number(attemptId)&&x.question_id===Number(questionId));
  const row={...(old||{}),attempt_id:Number(attemptId),question_id:Number(questionId),answer_json:JSON.stringify(answer)};
  if(old)await putRecord('attempt_answers',row);else await addRecord('attempt_answers',row);
}
export async function submitExamAttempt(attemptId){
  const attempt=await getRecord('exam_attempts',Number(attemptId));
  if(!attempt||attempt.completed_at)throw new Error('تم تسليم هذه المحاولة مسبقاً.');
  const [questions,answers]=await Promise.all([getAttemptQuestions(attemptId),getAll('attempt_answers')]);
  let score=0,total=0,graded=0;
  for(const q of questions){
    const canGrade=q.answer_key_verified===1&&q.answer_json!=null&&['multiple_choice','true_false'].includes(q.question_type);
    if(!canGrade)continue;
    const marks=Number(q.marks)||0;total+=marks;graded++;
    const answer=answers.find(x=>x.attempt_id===Number(attemptId)&&x.question_id===q.id);
    let correct=false;
    if(answer){try{correct=JSON.stringify(JSON.parse(answer.answer_json))===JSON.stringify(JSON.parse(q.answer_json));}catch{}}
    const row=answer||{attempt_id:Number(attemptId),question_id:q.id};
    row.is_correct=correct?1:0;row.awarded_marks=correct?marks:0;
    if(answer)await putRecord('attempt_answers',row);else await addRecord('attempt_answers',row);
    if(correct)score+=marks;
  }
  const now=new Date().toISOString();
  await putRecord('exam_attempts',{...attempt,completed_at:now,score,total_marks:total});
  return {attempt_id:Number(attemptId),score,total_marks:total,graded_questions:graded,total_questions:questions.length};
}
export async function getAttemptHistory(examId){
  return (await getAll('exam_attempts')).filter(x=>x.exam_id===Number(examId)&&x.completed_at).sort((a,b)=>b.completed_at.localeCompare(a.completed_at));
}
