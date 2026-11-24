// Browser-side schema mirrors the Flutter SQLite v6 domain and publication rules.
const DB_NAME='al-tafawuq', DB_VERSION=9;
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
 content_packages:{keyPath:'id',indexes:[['package_code','package_code',true],['review_status','review_status']]},
 content_package_reviews:{keyPath:'id',indexes:[['package_id','package_id']]},
 answer_key_reviews:{keyPath:'id',indexes:[['question_id','question_id'],['package_id','package_id']]},
 curriculum_review_history:{keyPath:'id',indexes:[['entity_type','entity_type'],['entity_id','entity_id']]},
 package_assets:{keyPath:['package_id','path'],indexes:[['package_id','package_id']]},
 study_notes:{keyPath:'id',indexes:[['package_id','package_id'],['subject_id','subject_id']]},
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
export async function getApprovedUnits({gradeId,trackId=null,subjectId=null}){const [units,subjects,releases,mappings,packages]=await Promise.all(['curriculum_units','subjects','curriculum_releases','curriculum_release_subjects','content_packages'].map(getAll));const sm=new Map(subjects.map(x=>[x.id,x])),rm=new Map(releases.map(x=>[x.id,x])),mm=new Map(mappings.map(x=>[x.id,x])),pm=new Map(packages.map(x=>[x.id,x]));return units.filter(u=>{const s=sm.get(u.subject_id),m=mm.get(u.release_subject_id),r=m&&rm.get(m.release_id),p=pm.get(u.package_id);return s&&s.grade_id===Number(gradeId)&&(trackId===null?s.track_id==null:(s.track_id==null||s.track_id===Number(trackId)))&&(!subjectId||s.id===Number(subjectId))&&p?.review_status==='approved'&&m?.subject_id===s.id&&m?.verification_status==='verified'&&r?.verification_status==='verified'&&r.grade_id===s.grade_id;}).map(u=>({...u,subject_name:sm.get(u.subject_id)?.name_ar})).sort((a,b)=>(a.subject_name||'').localeCompare(b.subject_name||'','ar')||(a.sort_order||0)-(b.sort_order||0));}
export async function getApprovedLessons(unitId){const [lessons,units,packages,mappings,releases,subjects]=await Promise.all(['lessons','curriculum_units','content_packages','curriculum_release_subjects','curriculum_releases','subjects'].map(getAll));const um=new Map(units.map(x=>[x.id,x])),pm=new Map(packages.map(x=>[x.id,x])),mm=new Map(mappings.map(x=>[x.id,x])),rm=new Map(releases.map(x=>[x.id,x])),sm=new Map(subjects.map(x=>[x.id,x]));return lessons.filter(l=>{const u=um.get(l.unit_id),p=u&&pm.get(u.package_id),m=u&&mm.get(u.release_subject_id),r=m&&rm.get(m.release_id),s=u&&sm.get(u.subject_id);return l.unit_id===Number(unitId)&&p?.review_status==='approved'&&s&&m?.subject_id===s.id&&m?.verification_status==='verified'&&r?.verification_status==='verified'&&r.grade_id===s.grade_id;}).map(l=>({...l,package_id:um.get(l.unit_id)?.package_id})).sort((a,b)=>(a.sort_order||0)-(b.sort_order||0));}
export async function saveLessonProgress(lessonId,percent=100){const lessons=await getApprovedLessonsForLesson(lessonId);if(!lessons)throw new Error('هذا الدرس غير منشور للطلاب');const n=Math.max(0,Math.min(100,Number(percent)||0)),now=new Date().toISOString();return putRecord('study_progress',{lesson_id:Number(lessonId),status:n>=100?'completed':n>0?'in_progress':'not_started',progress_percent:n,last_opened_at:now,completed_at:n>=100?now:null});}
async function getApprovedLessonsForLesson(id){const [lessons,units,packages,mappings,releases,subjects]=await Promise.all(['lessons','curriculum_units','content_packages','curriculum_release_subjects','curriculum_releases','subjects'].map(getAll));const l=lessons.find(x=>x.id===Number(id)),u=l&&units.find(x=>x.id===l.unit_id),p=u&&packages.find(x=>x.id===u.package_id),m=u&&mappings.find(x=>x.id===u.release_subject_id),r=m&&releases.find(x=>x.id===m.release_id),s=u&&subjects.find(x=>x.id===u.subject_id);return Boolean(l&&p?.review_status==='approved'&&s&&m?.subject_id===s.id&&m?.verification_status==='verified'&&r?.verification_status==='verified'&&r.grade_id===s.grade_id);}
export async function getPublishedExams({gradeId,trackId=null,subjectId=null}){const [exams,subjects,packages,units,mappings,releases,links,questions]=await Promise.all(['exams','subjects','content_packages','curriculum_units','curriculum_release_subjects','curriculum_releases','exam_questions','questions'].map(getAll));const result=[];for(const e of exams){const s=subjects.find(x=>x.id===e.subject_id),p=packages.find(x=>x.id===e.package_id);if(!s||s.grade_id!==Number(gradeId)||p?.review_status!=='approved'||(subjectId&&s.id!==Number(subjectId))||(trackId===null?s.track_id!=null:(s.track_id!=null&&s.track_id!==Number(trackId))))continue;const mapped=units.some(u=>u.package_id===p.id&&mappings.some(m=>m.id===u.release_subject_id&&m.subject_id===s.id&&m.verification_status==='verified'&&releases.some(r=>r.id===m.release_id&&r.verification_status==='verified'&&r.grade_id===s.grade_id)));const count=links.filter(x=>x.exam_id===e.id&&questions.some(q=>q.id===x.question_id&&q.package_id===e.package_id)).length;if(mapped&&count)result.push({...e,subject_name:s.name_ar,question_count:count});}return result.sort((a,b)=>b.id-a.id);}


export async function startExamAttempt(examId,{gradeId,trackId=null}={}){
  const exams=await getPublishedExams({gradeId,trackId});
  const exam=exams.find(x=>x.id===Number(examId));
  if(!exam)throw new Error('هذا الامتحان غير منشور لهذا الصف.');
  return addRecord('exam_attempts',{exam_id:exam.id,started_at:new Date().toISOString(),completed_at:null,score:null,total_marks:null,expires_at:exam.duration_minutes?new Date(Date.now()+Number(exam.duration_minutes)*60000).toISOString():null});
}
export async function getExamAttempt(attemptId){return getRecord('exam_attempts',Number(attemptId));}
export async function getAttemptAnswers(attemptId){return (await getAll('attempt_answers')).filter(x=>x.attempt_id===Number(attemptId));}
export async function getActiveExamAttempts({gradeId,trackId=null}={}){
 const visible=await getPublishedExams({gradeId,trackId});
 const byId=new Map(visible.map(e=>[e.id,e]));
 return (await getAll('exam_attempts')).filter(a=>!a.completed_at&&byId.has(a.exam_id)).map(a=>({...a,exam:byId.get(a.exam_id)})).sort((a,b)=>b.started_at.localeCompare(a.started_at));
}
export function projectStudentExamQuestion(question,link,packageId){
 if(!question||question.package_id!==packageId)return null;
 return {id:question.id,question_type:question.question_type,prompt_ar:question.prompt_ar,options_json:question.options_json,marks:link.marks,difficulty:question.difficulty};
}
export async function getAttemptQuestions(attemptId){
  const attempt=await getRecord('exam_attempts',Number(attemptId));
  if(!attempt||attempt.completed_at)throw new Error('المحاولة غير متاحة أو تم تسليمها.');
  const [exams,links,questions,packages]=await Promise.all(['exams','exam_questions','questions','content_packages'].map(getAll));
  const exam=exams.find(x=>x.id===attempt.exam_id),pkg=exam&&packages.find(x=>x.id===exam.package_id);
  if(!exam||pkg?.review_status!=='approved')throw new Error('الامتحان غير معتمد.');
  const ids=links.filter(x=>x.exam_id===exam.id).sort((a,b)=>(a.sort_order||0)-(b.sort_order||0));
  return ids.map(link=>projectStudentExamQuestion(questions.find(x=>x.id===link.question_id),link,exam.package_id)).filter(Boolean);
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
  const visibleQuestions=await getAttemptQuestions(attemptId);
  const [answers,links,allQuestions]=await Promise.all([getAll('attempt_answers'),getAll('exam_questions'),getAll('questions')]);
  const exam=await getRecord('exams',attempt.exam_id);
  if(!exam)throw new Error('الامتحان غير موجود.');
  const linked=links.filter(link=>link.exam_id===exam.id).sort((a,b)=>(a.sort_order||0)-(b.sort_order||0));
  const questions=linked.map(link=>({link,question:allQuestions.find(q=>q.id===link.question_id&&q.package_id===exam.package_id)})).filter(x=>x.question);
  let score=0,total=0,graded=0;
  for(const item of questions){
    const q=item.question,marks=Number(item.link.marks)||0;
    const canGrade=q.answer_key_verified===1&&q.answer_json!=null&&['multiple_choice','true_false'].includes(q.question_type);
    if(!canGrade)continue;
    total+=marks;graded++;
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
  const started=new Date(attempt.started_at),ended=new Date(now);
  await addRecord('study_sessions',{subject_id:exam.subject_id,session_type:'exam',started_at:started.toISOString(),ended_at:ended.toISOString(),duration_seconds:Math.max(0,Math.floor((ended-started)/1000)),completed_items:visibleQuestions.length});
  return {attempt_id:Number(attemptId),score,total_marks:total,graded_questions:graded,total_questions:visibleQuestions.length};
}
export async function recordLessonStudySession(lessonId,startedAt,endedAt=new Date()){
 const [lessons,units,packages,mappings,releases,subjects]=await Promise.all(['lessons','curriculum_units','content_packages','curriculum_release_subjects','curriculum_releases','subjects'].map(getAll));
 const lesson=lessons.find(x=>x.id===Number(lessonId)),unit=lesson&&units.find(x=>x.id===lesson.unit_id);
 const pkg=unit&&packages.find(x=>x.id===unit.package_id),mapping=unit&&mappings.find(x=>x.id===unit.release_subject_id),release=mapping&&releases.find(x=>x.id===mapping.release_id),subject=unit&&subjects.find(x=>x.id===unit.subject_id);
 if(!lesson||!subject||mapping?.subject_id!==subject.id||pkg?.review_status!=='approved'||mapping?.verification_status!=='verified'||release?.verification_status!=='verified'||release.grade_id!==subject.grade_id)throw new Error('لا يمكن تسجيل جلسة لدرس غير منشور.');
 const start=new Date(startedAt),end=new Date(endedAt);
 const seconds=Math.max(0,Math.floor((end-start)/1000));
 return addRecord('study_sessions',{subject_id:unit.subject_id,session_type:'lesson',started_at:start.toISOString(),ended_at:end.toISOString(),duration_seconds:seconds,completed_items:1});
}
export async function getStudentDashboard({gradeId,trackId=null}={}){
 const units=await getApprovedUnits({gradeId,trackId});
 const [allLessons,progress,sessions,attempts]=await Promise.all(['lessons','study_progress','study_sessions','exam_attempts'].map(getAll));
 const unitIds=new Set(units.map(u=>u.id)),lessonRows=allLessons.filter(l=>unitIds.has(l.unit_id));
 const lessonIds=new Set(lessonRows.map(l=>l.id)),completed=progress.filter(p=>lessonIds.has(p.lesson_id)&&p.status==='completed').length;
 const subjectIds=new Set(units.map(u=>u.subject_id));
 const seconds=sessions.filter(s=>subjectIds.has(s.subject_id)).reduce((n,s)=>n+(Number(s.duration_seconds)||0),0);
 const visibleExamIds=new Set((await getPublishedExams({gradeId,trackId})).map(e=>e.id));
 const completedAttempts=attempts.filter(a=>visibleExamIds.has(a.exam_id)&&a.completed_at).length;
 return {units:units.length,lessons:lessonRows.length,completedLessons:completed,progressPercent:lessonRows.length?Math.round(completed/lessonRows.length*100):0,studySeconds:seconds,completedExams:completedAttempts};
}
export async function getAttemptHistory(examId){
  return (await getAll('exam_attempts')).filter(x=>x.exam_id===Number(examId)&&x.completed_at).sort((a,b)=>b.completed_at.localeCompare(a.completed_at));
}

export async function getPublishedNotes({gradeId,trackId=null}={}){
 const [notes,subjects,packages,units,mappings,releases]=await Promise.all(['study_notes','subjects','content_packages','curriculum_units','curriculum_release_subjects','curriculum_releases'].map(getAll));
 return notes.filter(note=>{
  const subject=subjects.find(s=>s.id===note.subject_id),pkg=packages.find(p=>p.id===note.package_id);
  const unit=units.find(u=>u.package_id===note.package_id&&u.subject_id===note.subject_id);
  const mapping=unit&&mappings.find(m=>m.id===unit.release_subject_id);
  const release=mapping&&releases.find(r=>r.id===mapping.release_id);
  return subject&&subject.grade_id===Number(gradeId)&&
   (trackId===null?subject.track_id==null:(subject.track_id==null||subject.track_id===Number(trackId)))&&
   pkg?.review_status==='approved'&&mapping?.subject_id===subject.id&&mapping?.verification_status==='verified'&&release?.verification_status==='verified'&&release.grade_id===subject.grade_id;
 }).map(note=>({...note,subject_name:subjects.find(s=>s.id===note.subject_id)?.name_ar,category:'المذكرات'}));
}

export async function getPackageAsset(packageId,relativePath){
 const db=await openDb();
 const tx=db.transaction('package_assets','readonly');
 const row=await new Promise((resolve,reject)=>{const request=tx.objectStore('package_assets').get([Number(packageId),relativePath]);request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);});
 if(!row||!(row.blob instanceof Blob))throw new Error('ملف المحتوى غير موجود داخل الحزمة المحلية.');
 return {blob:row.blob,media_type:row.media_type||row.blob.type||'application/octet-stream'};
}

export async function getContentPackages({reviewStatus=null}={}){
 if(reviewStatus!==null&&!['pending_review','approved','rejected'].includes(reviewStatus))throw new Error('حالة المراجعة غير صالحة.');
 const rows=await getAll('content_packages');
 return rows.filter(row=>reviewStatus===null||row.review_status===reviewStatus)
  .sort((a,b)=>String(b.imported_at||'').localeCompare(String(a.imported_at||''))||(b.id-a.id));
}
export async function getPackageReviewHistory(packageId){
 return (await getAll('content_package_reviews')).filter(row=>row.package_id===Number(packageId))
  .sort((a,b)=>String(b.reviewed_at||'').localeCompare(String(a.reviewed_at||''))||(b.id-a.id));
}
export async function reviewContentPackage({packageId,decision,reviewerLabel,notes=null}){
 if(!['approved','rejected'].includes(decision))throw new Error('قرار المراجعة غير صالح.');
 const reviewer=String(reviewerLabel||'').trim();
 if(!reviewer)throw new Error('اسم المراجع مطلوب.');
 const cleanNotes=String(notes||'').trim()||null;
 if(decision==='rejected'&&!cleanNotes)throw new Error('يجب كتابة سبب الرفض.');
 const db=await openDb();
 return new Promise((resolve,reject)=>{
  const tx=db.transaction(['content_packages','content_package_reviews'],'readwrite');
  const packages=tx.objectStore('content_packages');
  const request=packages.get(Number(packageId));
  let failure=null;
  request.onsuccess=()=>{
   const pkg=request.result;
   if(!pkg){failure=new Error('حزمة المحتوى غير موجودة.');tx.abort();return;}
   if(pkg.review_status!=='pending_review'){failure=new Error('لا يمكن مراجعة حزمة ليست قيد المراجعة.');tx.abort();return;}
   if(decision==='approved'&&pkg.source_label==='official'){failure=new Error('لا يمكن اعتماد حزمة رسمية قبل التحقق المستقل من مصدرها.');tx.abort();return;}
   const now=new Date().toISOString();
   packages.put({...pkg,review_status:decision,reviewed_at:now,reviewer_label:reviewer,review_notes:cleanNotes});
   tx.objectStore('content_package_reviews').add({package_id:Number(packageId),decision,reviewer_label:reviewer,notes:cleanNotes,reviewed_at:now});
  };
  tx.oncomplete=()=>resolve(true);
  tx.onabort=()=>reject(failure||tx.error||new Error('تعذر حفظ قرار المراجعة.'));
  tx.onerror=()=>reject(failure||tx.error||new Error('تعذر حفظ قرار المراجعة.'));
 });
}

export async function getQuestionsForAnswerReview(){
 const [questions,packages,subjects]=await Promise.all(['questions','content_packages','subjects'].map(getAll));
 return questions.filter(q=>q.answer_json!=null&&['multiple_choice','true_false'].includes(q.question_type))
  .map(q=>{const pkg=packages.find(p=>p.id===q.package_id),subject=subjects.find(s=>s.id===q.subject_id);return {...q,package_title:pkg?.title||pkg?.package_code||'',package_status:pkg?.review_status,subject_name:subject?.name_ar||''};})
  .filter(q=>q.package_status==='approved')
  .sort((a,b)=>(a.package_title||'').localeCompare(b.package_title||'','ar')||a.id-b.id);
}
export async function getAnswerKeyReviewHistory(questionId){
 return (await getAll('answer_key_reviews')).filter(row=>row.question_id===Number(questionId))
  .sort((a,b)=>String(b.reviewed_at||'').localeCompare(String(a.reviewed_at||'')));
}
export async function reviewAnswerKey({questionId,decision,reviewerLabel,sourceReference=null,notes=null}){
 if(!['verified','rejected'].includes(decision))throw new Error('قرار مراجعة مفتاح الإجابة غير صالح.');
 const reviewer=String(reviewerLabel||'').trim(),source=String(sourceReference||'').trim(),comment=String(notes||'').trim()||null;
 if(!reviewer)throw new Error('اسم المراجع مطلوب.');
 if(decision==='verified'&&!source)throw new Error('مرجع الإجابة مطلوب قبل اعتماد المفتاح.');
 if(decision==='rejected'&&!comment)throw new Error('سبب رفض مفتاح الإجابة مطلوب.');
 const db=await openDb();
 return new Promise((resolve,reject)=>{
  const tx=db.transaction(['questions','content_packages','answer_key_reviews'],'readwrite');
  const qStore=tx.objectStore('questions'),request=qStore.get(Number(questionId));
  let failure=null;
  request.onsuccess=()=>{
   const q=request.result;
   if(!q||q.answer_json==null||!['multiple_choice','true_false'].includes(q.question_type)){failure=new Error('السؤال غير موجود أو لا يدعم التصحيح الآلي.');tx.abort();return;}
   let parsedAnswer,parsedOptions=[];
   try{parsedAnswer=JSON.parse(q.answer_json);parsedOptions=q.options_json?JSON.parse(q.options_json):[];}catch{failure=new Error('بيانات مفتاح الإجابة أو خيارات السؤال غير صالحة.');tx.abort();return;}
   if(!Array.isArray(parsedOptions)){failure=new Error('خيارات السؤال غير صالحة.');tx.abort();return;}
   const optionValues=parsedOptions.map(option=>option&&typeof option==='object'&&Object.prototype.hasOwnProperty.call(option,'value')?option.value:option);
   if(q.question_type==='true_false'&&!parsedOptions.length)optionValues.push(true,false);
   if(!optionValues.some(value=>JSON.stringify(value)===JSON.stringify(parsedAnswer))){failure=new Error('مفتاح الإجابة لا يطابق أي خيار متاح في السؤال.');tx.abort();return;}
   const packageRequest=tx.objectStore('content_packages').get(q.package_id);
   packageRequest.onsuccess=()=>{
    const pkg=packageRequest.result;
    if(pkg?.review_status!=='approved'){failure=new Error('يجب اعتماد حزمة المحتوى أولاً.');tx.abort();return;}
    const now=new Date().toISOString(),verified=decision==='verified'?1:0;
    qStore.put({...q,answer_key_verified:verified,answer_key_reviewed_at:now});
    tx.objectStore('answer_key_reviews').add({question_id:q.id,package_id:q.package_id,decision,reviewer_label:reviewer,source_reference:source||null,notes:comment,reviewed_at:now});
   };
  };
  tx.oncomplete=()=>resolve(true);
  tx.onabort=()=>reject(failure||tx.error||new Error('تعذر حفظ مراجعة مفتاح الإجابة.'));
  tx.onerror=()=>reject(failure||tx.error||new Error('تعذر حفظ مراجعة مفتاح الإجابة.'));
 });
}

export async function getCurriculumCatalog(){
 const [subjects,releases,mappings,grades]=await Promise.all(['subjects','curriculum_releases','curriculum_release_subjects','grades'].map(getAll));
 return {grades,subjects,releases,mappings};
}
export async function createCurriculumSubject({gradeId,code,nameAr,descriptionAr=null,sortOrder=0,trackId=null}){
 const grade=await getRecord('grades',Number(gradeId));
 if(!grade||grade.is_active!==1)throw new Error('الصف الدراسي غير صالح.');
 const cleanCode=String(code||'').trim(),name=String(nameAr||'').trim();
 if(!/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(cleanCode))throw new Error('رمز المادة غير صالح.');
 if(!name)throw new Error('اسم المادة مطلوب.');
 if(!Number.isInteger(Number(sortOrder)))throw new Error('ترتيب المادة غير صالح.');
 if(trackId!==null){const track=await getRecord('study_tracks',Number(trackId));if(!track||track.grade_id!==Number(gradeId)||track.is_active!==1)throw new Error('المسار لا يتبع الصف المحدد.');}
 const subjects=await getAll('subjects');
 if(subjects.some(s=>s.grade_id===Number(gradeId)&&s.track_id===(trackId===null?null:Number(trackId))&&s.code===cleanCode))throw new Error('رمز المادة موجود مسبقاً لهذا الصف والمسار.');
 return addRecord('subjects',{grade_id:Number(gradeId),track_id:trackId===null?null:Number(trackId),code:cleanCode,name_ar:name,description_ar:String(descriptionAr||'').trim()||null,sort_order:Number(sortOrder),is_active:1});
}
export async function createCurriculumRelease({gradeId,trackId=null,academicYear,editionCode,editionLabel,issuingAuthority,sourceTitle,sourceUrl=null,publishedAt=null,notes=null}){
 const grade=await getRecord('grades',Number(gradeId));
 if(!grade||grade.is_active!==1)throw new Error('الصف الدراسي غير صالح.');
 if(trackId!==null){const track=await getRecord('study_tracks',Number(trackId));if(!track||track.grade_id!==Number(gradeId)||track.is_active!==1)throw new Error('المسار لا يتبع الصف المحدد.');}
 const year=String(academicYear||'').trim(),code=String(editionCode||'').trim(),label=String(editionLabel||'').trim();
 const authority=String(issuingAuthority||'').trim(),source=String(sourceTitle||'').trim();
 if(!year||!code||!label||!authority||!source)throw new Error('السنة ورمز الطبعة واسمها والجهة المصدرة واسم المصدر مطلوبة.');
 if(!/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(code))throw new Error('رمز الطبعة غير صالح.');
 const releases=await getAll('curriculum_releases');
 if(releases.some(r=>r.grade_id===Number(gradeId)&&r.academic_year===year&&r.edition_code===code))throw new Error('إصدار المنهج موجود مسبقاً لهذا الصف.');
 return addRecord('curriculum_releases',{grade_id:Number(gradeId),track_id:trackId===null?null:Number(trackId),academic_year:year,edition_code:code,edition_label:label,issuing_authority:authority,source_title:source,source_url:String(sourceUrl||'').trim()||null,published_at:publishedAt||null,verification_status:'pending',notes:String(notes||'').trim()||null,created_at:new Date().toISOString(),updated_at:new Date().toISOString()});
}
export async function createCurriculumReleaseSubject({releaseId,subjectId,requirementType='unclassified',selectionGroup=null,sortOrder=0,sourceReference}){
 const [release,subject,mappings]=await Promise.all([getRecord('curriculum_releases',Number(releaseId)),getRecord('subjects',Number(subjectId)),getAll('curriculum_release_subjects')]);
 if(!release||!subject)throw new Error('إصدار المنهج أو المادة غير موجود.');
 if(release.verification_status==='rejected')throw new Error('لا يمكن ربط مادة بإصدار منهج مرفوض.');
 if(release.grade_id!==subject.grade_id||(release.track_id!==null&&subject.track_id!==null&&release.track_id!==subject.track_id))throw new Error('المادة وإصدار المنهج لا يتبعان الصف أو المسار نفسه.');
 if(!['mandatory','elective','unclassified'].includes(requirementType))throw new Error('نوع المقرر غير صالح.');
 if(!Number.isInteger(Number(sortOrder)))throw new Error('ترتيب المادة في المنهج غير صالح.');
 if(!String(sourceReference||'').trim())throw new Error('مرجع ربط المادة بالمقرر مطلوب.');
 if(mappings.some(m=>m.release_id===Number(releaseId)&&m.subject_id===Number(subjectId)))throw new Error('المادة مرتبطة بهذا الإصدار مسبقاً.');
 return addRecord('curriculum_release_subjects',{release_id:Number(releaseId),subject_id:Number(subjectId),requirement_type:requirementType,selection_group:String(selectionGroup||'').trim()||null,sort_order:Number(sortOrder),verification_status:'pending',source_reference:String(sourceReference).trim(),notes:null});
}
export async function reviewCurriculumRecord({entityType,entityId,decision,reviewerLabel,sourceReference,notes=null}){
 if(!['release','mapping'].includes(entityType)||!['verified','rejected'].includes(decision))throw new Error('بيانات مراجعة المنهج غير صالحة.');
 const reviewer=String(reviewerLabel||'').trim(),source=String(sourceReference||'').trim(),comment=String(notes||'').trim()||null;
 if(!reviewer||!source)throw new Error('اسم المراجع ومرجع المصدر مطلوبان.');
 if(decision==='rejected'&&!comment)throw new Error('سبب الرفض مطلوب.');
 const storeName=entityType==='release'?'curriculum_releases':'curriculum_release_subjects';
 const db=await openDb();
 return new Promise((resolve,reject)=>{
  const names=[...new Set([storeName,'curriculum_review_history','subjects','curriculum_releases'])];
  const tx=db.transaction(names,'readwrite');
  const store=tx.objectStore(storeName),request=store.get(Number(entityId));
  let failure=null;
  request.onsuccess=()=>{
   const row=request.result;
   if(!row){failure=new Error('سجل المنهج غير موجود.');tx.abort();return;}
   if(row.verification_status!=='pending'){failure=new Error('لا يمكن مراجعة سجل ليس قيد المراجعة.');tx.abort();return;}
   const save=()=>{
    const now=new Date().toISOString();
    store.put({...row,verification_status:decision,updated_at:now,verification_reference:source,verification_reviewer:reviewer,verification_notes:comment});
    tx.objectStore('curriculum_review_history').add({entity_type:entityType,entity_id:Number(entityId),decision,reviewer_label:reviewer,source_reference:source,notes:comment,reviewed_at:now});
   };
   if(entityType==='release'&&decision==='verified'){
    if(!String(row.issuing_authority||'').trim()||!String(row.source_title||'').trim()){failure=new Error('بيانات الجهة المصدرة والمصدر مطلوبة قبل التوثيق.');tx.abort();return;}
    save();
   }else if(entityType==='mapping'&&decision==='verified'){
    const releaseRequest=tx.objectStore('curriculum_releases').get(row.release_id);
    const subjectRequest=tx.objectStore('subjects').get(row.subject_id);
    let releaseReady=false,subjectReady=false,releaseValue,subjectValue;
    const maybeSave=()=>{if(!releaseReady||!subjectReady)return;if(releaseValue?.verification_status!=='verified'||!subjectValue||releaseValue.grade_id!==subjectValue.grade_id||(releaseValue.track_id!==null&&subjectValue.track_id!==null&&releaseValue.track_id!==subjectValue.track_id)){failure=new Error('يجب توثيق إصدار المنهج والتأكد من توافق الصف والمسار قبل توثيق ربط المادة.');tx.abort();return;}save();};
    releaseRequest.onsuccess=()=>{releaseValue=releaseRequest.result;releaseReady=true;maybeSave();};
    subjectRequest.onsuccess=()=>{subjectValue=subjectRequest.result;subjectReady=true;maybeSave();};
   }else save();
  };
  tx.oncomplete=()=>resolve(true);
  tx.onabort=()=>reject(failure||tx.error||new Error('تعذر حفظ مراجعة المنهج.'));
  tx.onerror=()=>reject(failure||tx.error||new Error('تعذر حفظ مراجعة المنهج.'));
 });
}
export async function getCurriculumReviewHistory(entityType,entityId){
 return (await getAll('curriculum_review_history')).filter(row=>row.entity_type===entityType&&row.entity_id===Number(entityId))
  .sort((a,b)=>String(b.reviewed_at||'').localeCompare(String(a.reviewed_at||'')));
}
