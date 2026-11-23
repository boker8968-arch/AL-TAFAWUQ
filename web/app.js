import {renderPdfAsset} from './pdf-viewer.js';
import {getStudentProfile,saveStudentProfile,getTracksForGrade,getApprovedUnits,getApprovedLessons,getPublishedExams,getAll,saveLessonProgress,startExamAttempt,getExamAttempt,getAttemptAnswers,getActiveExamAttempts,getAttemptQuestions,saveAttemptAnswer,submitExamAttempt,getAttemptHistory,getPublishedNotes,getStudentDashboard,recordLessonStudySession,getPackageAsset} from './database.js';
const dialog=document.querySelector('#setup'),form=document.querySelector('#profile-form'),trackField=document.querySelector('#track-field'),trackSelect=form.elements.track;
const grades=[{id:1,name:'الصف الأول الثانوي'},{id:2,name:'الصف الثاني الثانوي'},{id:3,name:'الصف الثالث الثانوي'}];
function showMessage(message){const el=document.querySelector('#notice');el.textContent=message;el.hidden=false;}
function hideMessage(){const el=document.querySelector('#notice');el.hidden=true;el.textContent='';}
async function loadTracks(gradeId,selected=null){const tracks=await getTracksForGrade(gradeId);trackSelect.replaceChildren(new Option('المسار المشترك / لم أحدد مساراً',''));for(const t of tracks)trackSelect.add(new Option(t.name_ar,t.id));trackSelect.value=selected==null?'':String(selected);trackField.hidden=tracks.length===0;}
async function openSetup(){hideMessage();const p=await getStudentProfile();form.elements.name.value=p?.display_name||'';form.elements.grade.value=String(p?.grade_id||'');if(p?.grade_id)await loadTracks(p.grade_id,p.track_id);else{trackSelect.replaceChildren(new Option('اختر الصف أولاً',''));trackField.hidden=true;}dialog.showModal();}
document.querySelector('#setup-open').addEventListener('click',openSetup);
form.elements.grade.addEventListener('change',async()=>{if(form.elements.grade.value)await loadTracks(form.elements.grade.value);else trackField.hidden=true;});
form.addEventListener('submit',async e=>{if(e.submitter?.id!=='save-profile')return;e.preventDefault();hideMessage();try{await saveStudentProfile({name:form.elements.name.value,gradeId:form.elements.grade.value,trackId:trackSelect.value||null});dialog.close();await renderProfile();showMessage('تم حفظ بيانات الطالب على هذا الجهاز.');}catch(error){showMessage(error.message||'تعذر حفظ البيانات.');}});
async function renderProfile(){const p=await getStudentProfile(),el=document.querySelector('#progress');if(!p){el.textContent='سيظهر تقدمك هنا بعد إعداد بيانات الطالب.';return;}const grade=grades.find(g=>g.id===p.grade_id);const stats=await getStudentDashboard({gradeId:p.grade_id,trackId:p.track_id});const hours=Math.floor(stats.studySeconds/3600),minutes=Math.floor((stats.studySeconds%3600)/60);el.textContent='مرحباً '+(p.display_name||'بك')+' — '+(grade?.name||'الصف الدراسي')+'.\nالوحدات المنشورة: '+stats.units+' | الدروس: '+stats.completedLessons+' من '+stats.lessons+' مكتملة ('+stats.progressPercent+'%).\nجلسات الدراسة: '+hours+' ساعة و'+minutes+' دقيقة | محاولات الامتحان المكتملة: '+stats.completedExams+'.';}
const views={curriculum:'المناهج',lessons:'الشروحات',notes:'المذكرات والملخصات',exams:'الامتحانات'};
const contentList=document.querySelector('#content-list');let examTimer=null;let pdfCleanup=null;let contentGeneration=0;
function stopExamTimer(){if(examTimer!==null){clearInterval(examTimer);examTimer=null;}}
function clearContent(){contentGeneration++;stopExamTimer();if(pdfCleanup){const dispose=pdfCleanup;pdfCleanup=null;dispose().catch(()=>{});}contentList.replaceChildren();contentList.hidden=true;}
async function displayPackageAsset(packageId,path,kind){
 const generation=contentGeneration;
 try{
  const asset=await getPackageAsset(packageId,path);
  if(generation!==contentGeneration)return;
  if(asset.media_type==='application/pdf'){
   const dispose=await renderPdfAsset(asset.blob,contentList);
   if(generation!==contentGeneration)await dispose();else pdfCleanup=dispose;
  }else if(asset.media_type.startsWith('text/')){
   const body=document.createElement('p');body.className='lesson-body';body.textContent=await asset.blob.text();
   if(generation===contentGeneration)contentList.append(body);
  }else{
   const message=document.createElement('p');message.textContent='نوع هذا الملف غير مدعوم في '+kind+' حالياً: '+asset.media_type;
   if(generation===contentGeneration)contentList.append(message);
  }
 }catch(error){
  if(generation!==contentGeneration)return;
  const message=document.createElement('p');message.textContent=error.message||'تعذر فتح الملف المحلي.';contentList.append(message);
 }
}
function addContentButton(label,detail,onClick){const b=document.createElement('button');b.className='content-item';const strong=document.createElement('strong');strong.textContent=label;b.append(strong);if(detail){const small=document.createElement('small');small.textContent=detail;b.append(small);}if(onClick)b.addEventListener('click',onClick);contentList.append(b);}
async function showContent(view){const p=await getStudentProfile();if(!p){showMessage('يرجى إعداد بيانات الطالب واختيار الصف أولاً.');await openSetup();return;}if(view==='curriculum'||view==='lessons'){clearContent();const units=await getApprovedUnits({gradeId:p.grade_id,trackId:p.track_id});if(!units.length){showMessage('لا يوجد محتوى منشور ومعتمد لهذا الصف حتى الآن. ستظهر المواد بعد استيراد حزمة موثقة واعتمادها.');return;}hideMessage();contentList.hidden=false;const subjects=[...new Set(units.map(u=>u.subject_name).filter(Boolean))];for(const subject of subjects){const group=document.createElement('section');group.className='subject-group';const h=document.createElement('h3');h.textContent=subject;group.append(h);for(const unit of units.filter(u=>u.subject_name===subject)){const b=document.createElement('button');b.className='content-item';b.textContent=unit.title_ar;b.addEventListener('click',async()=>{const lessons=await getApprovedLessons(unit.id);contentList.replaceChildren();const back=document.createElement('button');back.className='back-link';back.textContent='← العودة إلى الوحدات';back.addEventListener('click',()=>showContent('curriculum'));contentList.append(back);const title=document.createElement('h3');title.textContent=unit.title_ar;contentList.append(title);if(!lessons.length){const empty=document.createElement('p');empty.textContent='لا توجد دروس منشورة داخل هذه الوحدة بعد.';contentList.append(empty);}for(const lesson of lessons){addContentButton(lesson.title_ar,lesson.summary_ar||'درس معتمد',async()=>{const lessonStartedAt=new Date();clearContent();contentList.hidden=false;const back=document.createElement('button');back.className='back-link';back.textContent='← العودة إلى الدروس';back.onclick=()=>showContent('lessons');contentList.append(back);const h=document.createElement('h3');h.textContent=lesson.title_ar;contentList.append(h);if(lesson.summary_ar){const sh=document.createElement('h4');sh.textContent='ملخص الدرس';contentList.append(sh);const summary=document.createElement('p');summary.textContent=lesson.summary_ar;contentList.append(summary);}if(lesson.body_path){const bodyHeading=document.createElement('h4');bodyHeading.textContent='محتوى الدرس';contentList.append(bodyHeading);await displayPackageAsset(lesson.package_id,lesson.body_path,'قارئ الدروس');}else{const note=document.createElement('p');note.textContent='لم يُرفق نص تفصيلي لهذا الدرس في الحزمة؛ يظهر الملخص المعتمد فقط.';contentList.append(note);}const done=document.createElement('button');done.className='primary-action';done.textContent='إكمال الدرس وحفظ التقدم';done.addEventListener('click',async()=>{try{await saveLessonProgress(lesson.id,100);await recordLessonStudySession(lesson.id,lessonStartedAt,new Date());showMessage('تم تسجيل إكمال الدرس وحفظ التقدم محلياً.');done.disabled=true;done.textContent='تم إكمال الدرس';}catch(e){showMessage(e.message||'تعذر حفظ التقدم.');}});contentList.append(done);});}});group.append(b);}contentList.append(group);}return;}if(view==='notes'){
  clearContent();
  const notes=await getPublishedNotes({gradeId:p.grade_id,trackId:p.track_id});
  if(!notes.length){showMessage('لا توجد مذكرات منشورة ومعتمدة لهذا الصف حالياً.');return;}
  hideMessage();contentList.hidden=false;
  const heading=document.createElement('h3');heading.textContent='المذكرات';contentList.append(heading);
  for(const note of notes)addContentButton(note.title_ar,note.subject_name+' — '+(note.category||'المذكرات'),async()=>{
    clearContent();contentList.hidden=false;
    const back=document.createElement('button');back.className='back-link';back.textContent='← العودة إلى المذكرات';back.onclick=()=>showContent('notes');contentList.append(back);
    const title=document.createElement('h3');title.textContent=note.title_ar;contentList.append(title);
    if(note.summary_ar){const summary=document.createElement('p');summary.textContent=note.summary_ar;contentList.append(summary);}
    await displayPackageAsset(note.package_id,note.body_path,'قارئ المذكرات');
  });
  return;
}if(view==='exams'){clearContent();const [exams,active]=await Promise.all([getPublishedExams({gradeId:p.grade_id,trackId:p.track_id}),getActiveExamAttempts({gradeId:p.grade_id,trackId:p.track_id})]);if(!exams.length&&!active.length){showMessage('لا توجد امتحانات منشورة ومعتمدة لهذا الصف حالياً.');return;}hideMessage();contentList.hidden=false;if(active.length){const h=document.createElement('h3');h.textContent='محاولات قيد التنفيذ';contentList.append(h);for(const attempt of active){const exam=attempt.exam;addContentButton('متابعة: '+exam.title_ar,attempt.expires_at&&Date.parse(attempt.expires_at)<=Date.now()?'انتهى الوقت — سيتم تسليم المحاولة عند فتحها':'محاولة محفوظة على هذا الجهاز',()=>openExam(exam,p,attempt.id));}}if(exams.length){const h=document.createElement('h3');h.textContent='الامتحانات المتاحة';contentList.append(h);}for(const exam of exams)if(!active.some(attempt=>attempt.exam_id===exam.id))addContentButton(exam.title_ar,exam.subject_name+' — '+exam.question_count+' سؤال'+(exam.duration_minutes?' — '+exam.duration_minutes+' دقيقة':''),()=>openExam(exam,p));}}

async function openExam(exam,profile,resumeAttemptId=null){
  clearContent();hideMessage();contentList.hidden=false;
  const heading=document.createElement('h3');heading.textContent=exam.title_ar;contentList.append(heading);
  const info=document.createElement('p');info.textContent=exam.subject_name+' — '+exam.question_count+' سؤال';contentList.append(info);
  const start=document.createElement('button');start.className='primary-action';start.textContent='ابدأ الامتحان';contentList.append(start);
  const historyButton=document.createElement('button');historyButton.className='back-link';historyButton.textContent='سجل المحاولات';contentList.append(historyButton);
  historyButton.addEventListener('click',async()=>{contentList.replaceChildren();const back=document.createElement('button');back.className='back-link';back.textContent='← العودة';back.onclick=()=>openExam(exam,profile,resumeAttemptId);contentList.append(back);const rows=await getAttemptHistory(exam.id);if(!rows.length){const p=document.createElement('p');p.textContent='لا توجد محاولات مكتملة.';contentList.append(p);}for(const row of rows){const p=document.createElement('p');p.textContent=new Date(row.completed_at).toLocaleString('ar')+' — '+(row.total_marks>0?row.score+' / '+row.total_marks:'لم تُصحح آلياً');contentList.append(p);}});
  start.textContent=resumeAttemptId?'متابعة المحاولة':'ابدأ الامتحان';start.addEventListener('click',async()=>{try{const id=resumeAttemptId||await startExamAttempt(exam.id,{gradeId:profile.grade_id,trackId:profile.track_id});const [questions,attempt,saved]=await Promise.all([getAttemptQuestions(id),getExamAttempt(id),getAttemptAnswers(id)]);renderExamAttempt(exam,id,questions,attempt,saved);}catch(e){showMessage(e.message||'تعذر بدء الامتحان.');}});
}
function renderExamAttempt(exam,attemptId,questions,attempt,savedAnswers=[]){
  clearContent();contentList.hidden=false;let answers={};for(const row of savedAnswers){try{answers[row.question_id]=JSON.parse(row.answer_json);}catch{}}const title=document.createElement('h3');title.textContent=exam.title_ar;contentList.append(title);
  const counter=document.createElement('p');counter.textContent=Object.keys(answers).length+' من '+questions.length+' تمت الإجابة عنها';contentList.append(counter);const timer=document.createElement('p');timer.className='exam-timer';contentList.append(timer);
  for(let i=0;i<questions.length;i++){
    const q=questions[i],card=document.createElement('section');card.className='subject-group';
    const prompt=document.createElement('h4');prompt.textContent=(i+1)+'. '+q.prompt_ar;card.append(prompt);
    let options=[];try{options=q.options_json?JSON.parse(q.options_json):[];}catch{}
    if(q.question_type==='true_false'&&!options.length)options=[{value:true,label:'صح'},{value:false,label:'خطأ'}];
    if(Array.isArray(options)&&options.length){
      for(const opt of options){const value=opt&&typeof opt==='object'&&'value'in opt?opt.value:opt;const label=opt&&typeof opt==='object'?(opt.label??opt.text??String(value)):String(opt);const b=document.createElement('button');b.className='content-item';b.textContent=label;if(Object.prototype.hasOwnProperty.call(answers,q.id)&&JSON.stringify(answers[q.id])===JSON.stringify(value))b.classList.add('selected');b.addEventListener('click',async()=>{try{await saveAttemptAnswer(attemptId,q.id,value);answers[q.id]=value;counter.textContent=Object.keys(answers).length+' من '+questions.length+' تمت الإجابة عنها';for(const x of card.querySelectorAll('button'))x.classList.remove('selected');b.classList.add('selected');}catch(e){showMessage(e.message);}});card.append(b);}
    }else{const input=document.createElement('textarea');input.rows=3;input.placeholder='اكتب إجابتك هنا';input.value=answers[q.id]??'';input.addEventListener('change',async()=>{try{await saveAttemptAnswer(attemptId,q.id,input.value);answers[q.id]=input.value;counter.textContent=Object.keys(answers).length+' من '+questions.length+' تمت الإجابة عنها';}catch(e){showMessage(e.message);}});card.append(input);}
    contentList.append(card);
  }
  const submit=document.createElement('button');submit.className='primary-action';submit.textContent='تسليم الامتحان';contentList.append(submit);let submitting=false;
  async function finishAttempt(auto=false){if(submitting)return;if(!auto&&!confirm('هل تريد تسليم إجاباتك وإنهاء المحاولة؟'))return;submitting=true;stopExamTimer();submit.disabled=true;try{const result=await submitExamAttempt(attemptId);contentList.replaceChildren();const h=document.createElement('h3');h.textContent='نتيجة الامتحان';contentList.append(h);const p=document.createElement('p');p.textContent=result.total_marks>0?'درجتك: '+result.score+' من '+result.total_marks+' — تم تصحيح '+result.graded_questions+' سؤال آلياً.':'تم تسليم الامتحان. لا توجد مفاتيح إجابة موثقة تسمح بالتصحيح الآلي.';contentList.append(p);const back=document.createElement('button');back.className='back-link';back.textContent='العودة إلى الامتحانات';back.onclick=()=>showContent('exams');contentList.append(back);if(auto)showMessage('انتهى زمن الامتحان وتم تسليم إجاباتك المحفوظة.');}catch(e){submitting=false;submit.disabled=false;showMessage(e.message||'تعذر تسليم الامتحان.');}}
  submit.addEventListener('click',()=>finishAttempt(false));
  if(attempt?.expires_at){const deadline=Date.parse(attempt.expires_at);const tick=()=>{const remaining=Math.max(0,Math.ceil((deadline-Date.now())/1000));const mins=Math.floor(remaining/60),secs=remaining%60;timer.textContent='الوقت المتبقي: '+mins+':'+String(secs).padStart(2,'0');if(remaining===0){for(const control of contentList.querySelectorAll('button,textarea'))control.disabled=true;finishAttempt(true);}};tick();if(deadline>Date.now())examTimer=setInterval(tick,1000);}else{timer.textContent='لا يوجد حد زمني لهذا الامتحان.';}
}

document.querySelectorAll('[data-view]').forEach(btn=>btn.addEventListener('click',async()=>{const view=btn.dataset.view;if(view==='home'){clearContent();hideMessage();await renderProfile();return;}if(view==='profile'){clearContent();await openSetup();return;}await showContent(view);}));
if('serviceWorker'in navigator&&location.protocol!=='file:')navigator.serviceWorker.register('./sw.js').catch(()=>{});
renderProfile().catch(()=>showMessage('تعذر فتح قاعدة البيانات المحلية. يرجى إعادة تشغيل التطبيق.'));
