import {renderPdfAsset} from './pdf-viewer.js';
import {groupCurriculumUnits,filterCurriculumEntries,getCurriculumUnitStats} from './curriculum-view.js';
import {filterStudyNotes,groupStudyNotes,countStudyNoteCategories} from './notes-view.js';
import {filterPublishedExams,groupExamsBySubject,getExamFilterOptions} from './exams-view.js';
import {filterPublishedBankQuestions,groupBankQuestionsBySubject,getQuestionBankFilterOptions,canShowVerifiedAnswer} from './question-bank-view.js';
import {CONTENT_ADMIN_ENABLED} from './app-config.js';
import {renderContentAdmin} from './content-admin.js';
import {getStudentProfile,saveStudentProfile,hasLocalCredential,createLocalCredential,verifyLocalCredential,getTracksForGrade,getApprovedUnits,getApprovedLessons,getPublishedExams,getPublishedQuestionBank,getAll,saveLessonProgress,startExamAttempt,getExamAttempt,getAttemptAnswers,getActiveExamAttempts,getAttemptQuestions,saveAttemptAnswer,submitExamAttempt,getAttemptHistory,getPublishedNotes,getStudentDashboard,recordLessonStudySession,getPackageAsset} from './database.js';
const dialog=document.querySelector('#setup'),form=document.querySelector('#profile-form'),trackField=document.querySelector('#track-field'),trackSelect=form.elements.track;
const grades=[{id:1,name:'الصف الأول الثانوي'},{id:2,name:'الصف الثاني الثانوي'},{id:3,name:'الصف الثالث الثانوي'}];
const authScreen=document.querySelector('#auth-screen'),authRegister=document.querySelector('#auth-register'),authLogin=document.querySelector('#auth-login'),authTitle=document.querySelector('#auth-title'),authDescription=document.querySelector('#auth-description'),authMessage=document.querySelector('#auth-message');
function setAuthMessage(message){authMessage.textContent=message;authMessage.hidden=false;}
function lockApp(mode='login'){document.body.classList.add('auth-locked');authScreen.hidden=false;authMessage.hidden=true;authRegister.hidden=mode!=='register';authLogin.hidden=mode!=='login';authTitle.textContent=mode==='register'?'مرحباً بك في منصة التفوق':'مرحباً بعودتك';authDescription.textContent=mode==='register'?'أنشئ ملفك الدراسي واحفظ دخولك على هذا الجهاز.':'سجّل الدخول لمتابعة رحلتك التعليمية.';}
function unlockApp(){document.body.classList.remove('auth-locked');authScreen.hidden=true;authRegister.reset();authLogin.reset();renderProfile().catch(()=>showMessage('تعذر تحميل بيانات الطالب.'));}
async function initializeLocalAuth(){const credential=await hasLocalCredential();if(credential){lockApp('login');return;}const profile=await getStudentProfile();if(profile){authRegister.elements.name.value=profile.display_name||'';authRegister.elements.grade.value=String(profile.grade_id||'');}lockApp('register');}
authRegister.addEventListener('submit',async event=>{event.preventDefault();authMessage.hidden=true;const data=new FormData(authRegister),password=String(data.get('password')||'');if(password!==String(data.get('confirm')||'')){setAuthMessage('كلمتا المرور غير متطابقتين.');return;}try{const existing=await getStudentProfile();await saveStudentProfile({name:data.get('name'),gradeId:data.get('grade'),trackId:existing?.grade_id===Number(data.get('grade'))?existing.track_id:null});await createLocalCredential(password);unlockApp();showMessage('تم إنشاء الحساب المحلي بنجاح.');}catch(error){setAuthMessage(error.message||'تعذر إنشاء الحساب.');}});
authLogin.addEventListener('submit',async event=>{event.preventDefault();authMessage.hidden=true;const password=String(new FormData(authLogin).get('password')||'');try{if(await verifyLocalCredential(password)){unlockApp();}else setAuthMessage('كلمة المرور غير صحيحة.');}catch(error){setAuthMessage(error.message||'تعذر تسجيل الدخول.');}});

function showMessage(message){const el=document.querySelector('#notice');el.textContent=message;el.hidden=false;}
function hideMessage(){const el=document.querySelector('#notice');el.hidden=true;el.textContent='';}
async function loadTracks(gradeId,selected=null){const tracks=await getTracksForGrade(gradeId);trackSelect.replaceChildren(new Option('المسار المشترك / لم أحدد مساراً',''));for(const t of tracks)trackSelect.add(new Option(t.name_ar,t.id));trackSelect.value=selected==null?'':String(selected);trackField.hidden=tracks.length===0;}
async function openSetup(){hideMessage();const p=await getStudentProfile();form.elements.name.value=p?.display_name||'';form.elements.grade.value=String(p?.grade_id||'');if(p?.grade_id)await loadTracks(p.grade_id,p.track_id);else{trackSelect.replaceChildren(new Option('اختر الصف أولاً',''));trackField.hidden=true;}dialog.showModal();}
document.querySelector('#setup-open').addEventListener('click',openSetup);
document.querySelector('#logout').addEventListener('click',()=>{dialog.close();lockApp('login');});
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
function setActiveNavigation(view){const target=['lessons','notes'].includes(view)?'curriculum':view;document.querySelectorAll('.bottom [data-view]').forEach(button=>{const active=button.dataset.view===target;button.classList.toggle('active',active);if(active)button.setAttribute('aria-current','page');else button.removeAttribute('aria-current');});}
function addContentButton(label,detail,onClick,container=contentList){const b=document.createElement('button');b.className='content-item';const strong=document.createElement('strong');strong.textContent=label;b.append(strong);if(detail){const small=document.createElement('small');small.textContent=detail;b.append(small);}if(onClick)b.addEventListener('click',onClick);container.append(b);}
async function showContent(view){if(view!=='content-admin')setActiveNavigation(view);if(view==='content-admin'){if(!CONTENT_ADMIN_ENABLED){showMessage('أدوات إدارة المحتوى غير مفعلة في هذا الإصدار.');return;}clearContent();hideMessage();contentList.hidden=false;await renderContentAdmin(contentList);return;}const p=await getStudentProfile();if(!p){showMessage('يرجى إعداد بيانات الطالب واختيار الصف أولاً.');await openSetup();return;}if(view==='curriculum'){
  clearContent();
  const units=await getApprovedUnits({gradeId:p.grade_id,trackId:p.track_id});
  if(!units.length){showMessage('لا يوجد محتوى منشور ومعتمد لهذا الصف حتى الآن. ستظهر المواد بعد استيراد حزمة موثقة واعتمادها.');return;}
  hideMessage();contentList.hidden=false;
  const [progressRows,lessonGroups]=await Promise.all([
    getAll('study_progress'),
    Promise.all(units.map(async unit=>({unit,lessons:await getApprovedLessons(unit.id)})))
  ]);
  const progressByLesson=new Map(progressRows.map(row=>[row.lesson_id,row]));
  const subjectMap=groupCurriculumUnits(lessonGroups);
  const searchWrap=document.createElement('label');
  searchWrap.className='curriculum-search';
  searchWrap.textContent='ابحث عن مادة أو وحدة';
  const search=document.createElement('input');
  search.type='search';search.placeholder='اكتب اسم المادة أو الوحدة...';search.setAttribute('aria-label','البحث في المواد والوحدات');
  searchWrap.append(search);contentList.append(searchWrap);
  const summary=document.createElement('p');summary.className='curriculum-summary';contentList.append(summary);
  const results=document.createElement('div');results.className='curriculum-results';contentList.append(results);
  function renderCurriculum(query=''){
    results.replaceChildren();
    const needle=query.trim().toLocaleLowerCase('ar');
    let visibleSubjects=0,visibleUnits=0,totalLessons=0,completedLessons=0;
    for(const [subject,entries] of subjectMap){
      const matched=filterCurriculumEntries(entries,subject,needle);
      if(!matched.length)continue;
      visibleSubjects++;
      const group=document.createElement('section');group.className='subject-group curriculum-subject';
      const heading=document.createElement('h3');heading.textContent=subject;group.append(heading);
      const subjectStats=matched.reduce((stats,item)=>{const unitStats=getCurriculumUnitStats(item.lessons,progressByLesson);stats.total+=unitStats.total;stats.completed+=unitStats.completed;return stats;},{total:0,completed:0});
      const meta=document.createElement('p');meta.className='curriculum-meta';
      meta.textContent=matched.length+' وحدة · '+subjectStats.total+' درس · '+subjectStats.completed+' مكتمل';
      group.append(meta);
      for(const {unit,lessons} of matched){
        visibleUnits++;totalLessons+=lessons.length;
        const unitStats=getCurriculumUnitStats(lessons,progressByLesson),done=unitStats.completed;
        completedLessons+=done;
        const card=document.createElement('button');card.type='button';card.className='content-item curriculum-unit';
        const title=document.createElement('strong');title.textContent=unit.title_ar;card.append(title);
        const detail=document.createElement('small');detail.textContent=lessons.length+' درس · '+done+' مكتمل';card.append(detail);
        const track=document.createElement('span');track.className='curriculum-progress-track';track.setAttribute('role','progressbar');track.setAttribute('aria-label','نسبة إنجاز '+unit.title_ar);track.setAttribute('aria-valuemin','0');track.setAttribute('aria-valuemax','100');
        const fill=document.createElement('span');const percent=unitStats.percent;fill.style.width=percent+'%';track.setAttribute('aria-valuenow',String(percent));track.append(fill);card.append(track);
        card.addEventListener('click',async()=>{
          const currentLessons=lessons;
          contentList.replaceChildren();
          const back=document.createElement('button');back.className='back-link';back.textContent='← العودة إلى المواد والوحدات';back.addEventListener('click',()=>showContent('curriculum'));contentList.append(back);
          const title=document.createElement('h3');title.textContent=unit.title_ar;contentList.append(title);
          const subjectLabel=document.createElement('p');subjectLabel.className='curriculum-meta';subjectLabel.textContent=subject+' · '+currentLessons.length+' درس';contentList.append(subjectLabel);
          if(!currentLessons.length){const empty=document.createElement('p');empty.textContent='لا توجد دروس منشورة داخل هذه الوحدة بعد.';contentList.append(empty);}
          for(const lesson of currentLessons){
            const row=progressByLesson.get(lesson.id);
            const detail=row?.status==='completed'?'مكتمل':lesson.summary_ar||'درس معتمد';
            addContentButton(lesson.title_ar,detail,async()=>{
              const lessonStartedAt=new Date();clearContent();contentList.hidden=false;
              const back=document.createElement('button');back.className='back-link';back.textContent='← العودة إلى الدروس';back.onclick=()=>showContent('curriculum');contentList.append(back);
              const h=document.createElement('h3');h.textContent=lesson.title_ar;contentList.append(h);
              if(lesson.summary_ar){const sh=document.createElement('h4');sh.textContent='ملخص الدرس';contentList.append(sh);const summary=document.createElement('p');summary.textContent=lesson.summary_ar;contentList.append(summary);}
              if(lesson.body_path){const bodyHeading=document.createElement('h4');bodyHeading.textContent='محتوى الدرس';contentList.append(bodyHeading);await displayPackageAsset(lesson.package_id,lesson.body_path,'قارئ الدروس');}
              else{const note=document.createElement('p');note.textContent='لم يُرفق نص تفصيلي لهذا الدرس في الحزمة؛ يظهر الملخص المعتمد فقط.';contentList.append(note);}
              const done=document.createElement('button');done.className='primary-action';done.textContent='إكمال الدرس وحفظ التقدم';done.addEventListener('click',async()=>{try{await saveLessonProgress(lesson.id,100);await recordLessonStudySession(lesson.id,lessonStartedAt,new Date());showMessage('تم تسجيل إكمال الدرس وحفظ التقدم محلياً.');done.disabled=true;done.textContent='تم إكمال الدرس';}catch(e){showMessage(e.message||'تعذر حفظ التقدم.');}});contentList.append(done);
            });
          }
        });
        group.append(card);
      }
      results.append(group);
    }
    summary.textContent='المواد: '+visibleSubjects+' · الوحدات: '+visibleUnits+' · الدروس: '+totalLessons+' · المكتمل: '+completedLessons;
    if(!visibleUnits){const empty=document.createElement('p');empty.className='curriculum-empty';empty.textContent='لا توجد نتائج مطابقة لبحثك.';results.append(empty);}
  }
  search.addEventListener('input',()=>renderCurriculum(search.value));
  renderCurriculum();
  return;
}
if(view==='lessons'){
  clearContent();
  const units=await getApprovedUnits({gradeId:p.grade_id,trackId:p.track_id});
  const lessonGroups=await Promise.all(units.map(async unit=>({unit,lessons:await getApprovedLessons(unit.id)})));
  const available=lessonGroups.flatMap(({unit,lessons})=>lessons.map(lesson=>({unit,lesson})));
  if(!available.length){showMessage('لا توجد شروحات منشورة ومعتمدة لهذا الصف حتى الآن. ستظهر الشروحات بعد اعتماد محتوى موثق.');return;}
  hideMessage();contentList.hidden=false;
  const progressRows=await getAll('study_progress');
  const progressByLesson=new Map(progressRows.map(row=>[row.lesson_id,row]));
  const searchWrap=document.createElement('label');searchWrap.className='curriculum-search';searchWrap.textContent='ابحث في الشروحات';
  const search=document.createElement('input');search.type='search';search.placeholder='اسم المادة أو الوحدة أو الدرس...';search.setAttribute('aria-label','البحث في الشروحات');searchWrap.append(search);contentList.append(searchWrap);
  const summary=document.createElement('p');summary.className='curriculum-summary';contentList.append(summary);
  const results=document.createElement('div');results.className='curriculum-results';contentList.append(results);
  function renderLessons(query=''){
    results.replaceChildren();
    const needle=String(query||'').trim().toLocaleLowerCase('ar');
    let count=0,completed=0;
    for(const {unit,lessons} of lessonGroups){
      const matches=lessons.filter(lesson=>!needle||[unit.subject_name,unit.title_ar,lesson.title_ar,lesson.summary_ar].some(value=>String(value||'').toLocaleLowerCase('ar').includes(needle)));
      if(!matches.length)continue;
      const section=document.createElement('section');section.className='subject-group curriculum-subject';
      const heading=document.createElement('h3');heading.textContent=unit.subject_name||'المادة';section.append(heading);
      const unitHeading=document.createElement('p');unitHeading.className='curriculum-meta';unitHeading.textContent=unit.title_ar;section.append(unitHeading);
      for(const lesson of matches){
        count++;
        const done=progressByLesson.get(lesson.id)?.status==='completed';if(done)completed++;
        const detail=done?'مكتمل':lesson.summary_ar||'شرح معتمد';
        addContentButton(lesson.title_ar,detail,async()=>{
          const startedAt=new Date();clearContent();hideMessage();contentList.hidden=false;
          const back=document.createElement('button');back.className='back-link';back.textContent='← العودة إلى الشروحات';back.onclick=()=>showContent('lessons');contentList.append(back);
          const subjectTitle=document.createElement('p');subjectTitle.className='curriculum-meta';subjectTitle.textContent=(unit.subject_name||'المادة')+' · '+unit.title_ar;contentList.append(subjectTitle);
          const title=document.createElement('h3');title.textContent=lesson.title_ar;contentList.append(title);
          if(lesson.summary_ar){const summaryHeading=document.createElement('h4');summaryHeading.textContent='ملخص الشرح';contentList.append(summaryHeading);const summaryText=document.createElement('p');summaryText.textContent=lesson.summary_ar;contentList.append(summaryText);}
          if(lesson.body_path){const bodyHeading=document.createElement('h4');bodyHeading.textContent='الشرح الكامل';contentList.append(bodyHeading);await displayPackageAsset(lesson.package_id,lesson.body_path,'قسم الشروحات');}
          else{const note=document.createElement('p');note.textContent='لا يتوفر ملف شرح تفصيلي لهذا الدرس حالياً؛ المعروض هو الملخص المعتمد فقط.';contentList.append(note);}
          const complete=document.createElement('button');complete.className='primary-action';complete.textContent=done?'تم إكمال هذا الدرس':'إكمال الشرح وحفظ التقدم';complete.disabled=done;
          complete.addEventListener('click',async()=>{try{await saveLessonProgress(lesson.id,100);await recordLessonStudySession(lesson.id,startedAt,new Date());complete.disabled=true;complete.textContent='تم إكمال هذا الدرس';showMessage('تم حفظ تقدمك في هذا الدرس على الجهاز.');}catch(error){showMessage(error.message||'تعذر حفظ التقدم.');}});
          contentList.append(complete);
        });
      }
      results.append(section);
    }
    summary.textContent='الدروس المعروضة: '+count+' · المكتملة: '+completed;
    if(!count){const empty=document.createElement('p');empty.className='curriculum-empty';empty.textContent='لا توجد شروحات مطابقة لبحثك.';results.append(empty);}
  }
  search.addEventListener('input',()=>renderLessons(search.value));renderLessons();return;
}
if(view==='notes'){
  clearContent();
  const notes=await getPublishedNotes({gradeId:p.grade_id,trackId:p.track_id});
  if(!notes.length){showMessage('لا توجد مذكرات منشورة ومعتمدة لهذا الصف حالياً.');return;}
  hideMessage();contentList.hidden=false;
  const heading=document.createElement('h3');heading.textContent='المذكرات والملخصات';contentList.append(heading);
  const searchWrap=document.createElement('label');searchWrap.className='curriculum-search';searchWrap.textContent='ابحث في المحتوى الدراسي';
  const search=document.createElement('input');search.type='search';search.placeholder='اسم الملف أو المادة أو موضوعه...';search.setAttribute('aria-label','البحث في المذكرات والملخصات');searchWrap.append(search);contentList.append(searchWrap);
  const counts=countStudyNoteCategories(notes),filters=document.createElement('div');filters.className='notes-filters';
  const summary=document.createElement('p');summary.className='curriculum-summary';contentList.append(filters,summary);
  const results=document.createElement('div');results.className='notes-results';contentList.append(results);
  let activeCategory='all';
  const choices=[['all','الكل ('+counts.all+')'],['المذكرات','المذكرات ('+counts.notes+')'],['الملخصات','الملخصات ('+counts.summaries+')']];
  for(const [value,label] of choices){const button=document.createElement('button');button.type='button';button.className='notes-filter'+(value===activeCategory?' active':'');button.textContent=label;button.setAttribute('aria-pressed',String(value===activeCategory));button.addEventListener('click',()=>{activeCategory=value;for(const item of filters.children){const selected=item.dataset.category===value;item.classList.toggle('active',selected);item.setAttribute('aria-pressed',String(selected));}renderNotes();});button.dataset.category=value;filters.append(button);}
  function renderNotes(){
    results.replaceChildren();
    const filtered=filterStudyNotes(notes,search.value,activeCategory),groups=groupStudyNotes(filtered);
    let count=0;
    for(const [subject,items] of groups){
      const section=document.createElement('section');section.className='subject-group curriculum-subject notes-subject';
      const subjectHeading=document.createElement('h3');subjectHeading.textContent=subject;section.append(subjectHeading);
      const meta=document.createElement('p');meta.className='curriculum-meta';meta.textContent=items.length+' ملف معتمد';section.append(meta);
      for(const note of items){
        count++;
        const detail=(note.category||'المذكرات')+' · '+(note.summary_ar||'ملف معتمد');
        addContentButton(note.title_ar,detail,async()=>{
          clearContent();hideMessage();contentList.hidden=false;
          const back=document.createElement('button');back.className='back-link';back.textContent='← العودة إلى المذكرات والملخصات';back.onclick=()=>showContent('notes');contentList.append(back);
          const title=document.createElement('h3');title.textContent=note.title_ar;contentList.append(title);
          const subjectLine=document.createElement('p');subjectLine.className='curriculum-meta';subjectLine.textContent=subject+' · '+(note.category||'المذكرات');contentList.append(subjectLine);
          if(note.summary_ar){const summaryHeading=document.createElement('h4');summaryHeading.textContent='نبذة عن الملف';contentList.append(summaryHeading);const summaryText=document.createElement('p');summaryText.textContent=note.summary_ar;contentList.append(summaryText);}
          await displayPackageAsset(note.package_id,note.body_path,'قارئ المحتوى الدراسي');
        },section);
      }
      results.append(section);
    }
    summary.textContent='الملفات المعتمدة: '+count+' · المواد: '+groups.size;
    if(!count){const empty=document.createElement('p');empty.className='curriculum-empty';empty.textContent='لا توجد ملفات مطابقة لهذا التصنيف أو البحث.';results.append(empty);}
  }
  search.addEventListener('input',renderNotes);renderNotes();return;
}
if(view==='exams'){
  clearContent();
  const [exams,active]=await Promise.all([getPublishedExams({gradeId:p.grade_id,trackId:p.track_id}),getActiveExamAttempts({gradeId:p.grade_id,trackId:p.track_id})]);
  if(!exams.length&&!active.length){showMessage('لا توجد امتحانات منشورة ومعتمدة لهذا الصف حالياً.');return;}
  hideMessage();contentList.hidden=false;
  if(active.length){
    const h=document.createElement('h3');h.textContent='محاولات قيد التنفيذ';contentList.append(h);
    for(const attempt of active){const exam=attempt.exam;addContentButton('متابعة: '+exam.title_ar,attempt.expires_at&&Date.parse(attempt.expires_at)<=Date.now()?'انتهى الوقت — سيتم تسليم المحاولة عند فتحها':'محاولة محفوظة على هذا الجهاز',()=>openExam(exam,p,attempt.id));}
  }
  if(exams.length){
    const h=document.createElement('h3');h.textContent='الامتحانات السابقة والتدريبية';contentList.append(h);
    const searchWrap=document.createElement('label');searchWrap.className='curriculum-search';searchWrap.textContent='ابحث باسم الامتحان أو المادة أو السنة';
    const search=document.createElement('input');search.type='search';search.placeholder='مثلاً: الرياضيات أو 2024';search.setAttribute('aria-label','البحث في الامتحانات');searchWrap.append(search);contentList.append(searchWrap);
    const filterOptions=getExamFilterOptions(exams),filterBar=document.createElement('div');filterBar.className='exam-filters';
    const makeFilter=(label,items)=>{const select=document.createElement('select');select.setAttribute('aria-label',label);const all=document.createElement('option');all.value='';all.textContent=label;select.append(all);for(const item of items){const option=document.createElement('option');option.value=item.value;option.textContent=item.label;select.append(option);}return select;};
    const yearFilter=makeFilter('كل السنوات',filterOptions.years.map(year=>({value:year,label:year})));
    const typeLabels={previous:'امتحانات سابقة',practice:'امتحانات تدريبية',mock:'امتحانات تجريبية'};
    const typeFilter=makeFilter('كل أنواع الامتحانات',filterOptions.types.map(type=>({value:type,label:typeLabels[type]||type})));
    filterBar.append(yearFilter,typeFilter);contentList.append(filterBar);
    const summary=document.createElement('p');summary.className='curriculum-summary';contentList.append(summary);
    const results=document.createElement('div');results.className='exam-results';contentList.append(results);
    function renderExams(query=''){
      results.replaceChildren();
      const filtered=filterPublishedExams(exams,query,{year:yearFilter.value,type:typeFilter.value}),groups=groupExamsBySubject(filtered);
      let count=0;
      for(const [subject,items] of groups){
        const section=document.createElement('section');section.className='curriculum-subject exam-subject';
        const title=document.createElement('h3');title.textContent=subject;section.append(title);
        const meta=document.createElement('p');meta.className='curriculum-meta';meta.textContent=items.length+' امتحان متاح';section.append(meta);
        for(const exam of items)if(!active.some(attempt=>attempt.exam_id===exam.id)){
          count++;
          const year=exam.academic_year||exam.year||'السنة غير محددة';
          addContentButton(exam.title_ar,year+' — '+exam.question_count+' سؤال'+(exam.duration_minutes?' — '+exam.duration_minutes+' دقيقة':''),()=>openExam(exam,p),section);
        }
        results.append(section);
      }
      summary.textContent='الامتحانات المطابقة: '+count+' · المواد: '+groups.size;
      if(!filtered.length){const empty=document.createElement('p');empty.className='curriculum-empty';empty.textContent='لا توجد امتحانات مطابقة لبحثك.';results.append(empty);}
    }
    search.addEventListener('input',()=>renderExams(search.value));yearFilter.addEventListener('change',()=>renderExams(search.value));typeFilter.addEventListener('change',()=>renderExams(search.value));renderExams();
  }
}

if(view==='question-bank'){
  clearContent();
  const questions=await getPublishedQuestionBank({gradeId:p.grade_id,trackId:p.track_id});
  if(!questions.length){showMessage('لا توجد أسئلة منشورة ومعتمدة في بنك الأسئلة لهذا الصف حتى الآن. ستظهر الأسئلة بعد اعتماد حزم موثقة وربطها بالمنهج.');return;}
  hideMessage();contentList.hidden=false;
  const heading=document.createElement('h3');heading.textContent='بنك الأسئلة والتدريب';contentList.append(heading);
  const intro=document.createElement('p');intro.className='curriculum-meta';intro.textContent='تدرّب على الأسئلة المنشورة من الحزم المعتمدة. لا يظهر مفتاح الإجابة إلا بعد توثيقه ومراجعته.';contentList.append(intro);
  const searchWrap=document.createElement('label');searchWrap.className='curriculum-search';searchWrap.textContent='ابحث في بنك الأسئلة';
  const search=document.createElement('input');search.type='search';search.placeholder='نص السؤال أو المادة أو الدرس...';search.setAttribute('aria-label','البحث في بنك الأسئلة');searchWrap.append(search);contentList.append(searchWrap);
  const options=getQuestionBankFilterOptions(questions),filters=document.createElement('div');filters.className='exam-filters';
  const makeFilter=(label,values)=>{const select=document.createElement('select');select.setAttribute('aria-label',label);const all=document.createElement('option');all.value='';all.textContent=label;select.append(all);for(const value of values){const option=document.createElement('option');option.value=value;option.textContent=value;select.append(option);}return select;};
  const subjectFilter=makeFilter('كل المواد',options.subjects),typeNames={multiple_choice:'اختيار من متعدد',true_false:'صح أو خطأ',short_answer:'إجابة قصيرة'};
  const typeFilter=makeFilter('كل أنواع الأسئلة',options.types.map(type=>typeNames[type]||type));
  for(const option of typeFilter.options)if(option.value){const pair=options.types.find(type=>(typeNames[type]||type)===option.value);option.value=pair||option.value;}
  const difficultyFilter=makeFilter('كل مستويات الصعوبة',options.difficulties);
  filters.append(subjectFilter,typeFilter,difficultyFilter);contentList.append(filters);
  const summary=document.createElement('p');summary.className='curriculum-summary';contentList.append(summary);
  const results=document.createElement('div');results.className='question-bank-results';contentList.append(results);
  function renderBank(){
    results.replaceChildren();
    const filtered=filterPublishedBankQuestions(questions,search.value,{subject:subjectFilter.value,type:typeFilter.value,difficulty:difficultyFilter.value});
    const groups=groupBankQuestionsBySubject(filtered);let count=0;
    for(const [subject,items] of groups){
      const section=document.createElement('section');section.className='subject-group curriculum-subject';
      const title=document.createElement('h3');title.textContent=subject;section.append(title);
      for(const question of items){
        count++;
        const card=document.createElement('article');card.className='question-bank-card';
        const prompt=document.createElement('h4');prompt.textContent=question.prompt_ar;card.append(prompt);
        const meta=document.createElement('p');meta.className='curriculum-meta';meta.textContent=(typeNames[question.question_type]||'سؤال')+(question.lesson_title?' · '+question.lesson_title:'')+(question.academic_year?' · '+question.academic_year:'');card.append(meta);
        let choices=[];try{choices=question.options_json?JSON.parse(question.options_json):[];}catch{}
        if(question.question_type==='true_false'&&!choices.length)choices=[{value:true,label:'صح'},{value:false,label:'خطأ'}];
        if(Array.isArray(choices)&&choices.length){const list=document.createElement('ul');list.className='question-options';for(const choice of choices){const item=document.createElement('li');item.textContent=choice&&typeof choice==='object'?(choice.label??choice.text??String(choice.value)):String(choice);list.append(item);}card.append(list);}
        if(canShowVerifiedAnswer(question)&&question.verified_answer_json!=null){
          const reveal=document.createElement('button');reveal.type='button';reveal.className='back-link';reveal.textContent='إظهار الإجابة الموثقة';
          const answer=document.createElement('p');answer.hidden=true;answer.className='verified-answer';
          let answerValue=question.verified_answer_json;try{answerValue=JSON.parse(answerValue);}catch{}
          if(typeof answerValue==='boolean')answerValue=answerValue?'صح':'خطأ';
          else if(typeof answerValue==='object'&&answerValue!==null)answerValue=answerValue.label??answerValue.text??JSON.stringify(answerValue);
          answer.textContent='الإجابة الموثقة: '+String(answerValue);
          reveal.addEventListener('click',()=>{answer.hidden=!answer.hidden;reveal.textContent=answer.hidden?'إظهار الإجابة الموثقة':'إخفاء الإجابة';});
          card.append(reveal,answer);
        }else{
          const warning=document.createElement('p');warning.className='curriculum-meta';warning.textContent='مفتاح الإجابة غير موثّق بعد؛ لن يتم عرض إجابة أو تصحيح هذا السؤال.';card.append(warning);
        }
        const source=document.createElement('small');source.textContent='المصدر: '+question.source_exam_title;card.append(source);
        section.append(card);
      }
      results.append(section);
    }
    summary.textContent='الأسئلة المتاحة: '+count+' · المواد: '+groups.size;
    if(!count){const empty=document.createElement('p');empty.className='curriculum-empty';empty.textContent='لا توجد أسئلة مطابقة لخيارات البحث.';results.append(empty);}
  }
  search.addEventListener('input',renderBank);subjectFilter.addEventListener('change',renderBank);typeFilter.addEventListener('change',renderBank);difficultyFilter.addEventListener('change',renderBank);renderBank();return;
}

}
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
  clearContent();contentList.hidden=false;let answers={};const pendingSaves=new Set();for(const row of savedAnswers){try{answers[row.question_id]=JSON.parse(row.answer_json);}catch{}}const title=document.createElement('h3');title.textContent=exam.title_ar;contentList.append(title);
  const counter=document.createElement('p');counter.textContent=Object.keys(answers).length+' من '+questions.length+' تمت الإجابة عنها';contentList.append(counter);const timer=document.createElement('p');timer.className='exam-timer';contentList.append(timer);
  function persistAnswer(questionId,value){const task=saveAttemptAnswer(attemptId,questionId,value).then(()=>{answers[questionId]=value;counter.textContent=Object.keys(answers).length+' من '+questions.length+' تمت الإجابة عنها';},error=>{showMessage(error.message||'تعذر حفظ الإجابة.');throw error;});pendingSaves.add(task);task.then(()=>pendingSaves.delete(task),()=>pendingSaves.delete(task));return task;}
  for(let i=0;i<questions.length;i++){
    const q=questions[i],card=document.createElement('section');card.className='subject-group';
    const prompt=document.createElement('h4');prompt.textContent=(i+1)+'. '+q.prompt_ar;card.append(prompt);
    let options=[];try{options=q.options_json?JSON.parse(q.options_json):[];}catch{}
    if(q.question_type==='true_false'&&!options.length)options=[{value:true,label:'صح'},{value:false,label:'خطأ'}];
    if(Array.isArray(options)&&options.length){
      for(const opt of options){const value=opt&&typeof opt==='object'&&'value'in opt?opt.value:opt;const label=opt&&typeof opt==='object'?(opt.label??opt.text??String(value)):String(opt);const b=document.createElement('button');b.className='content-item';b.textContent=label;if(Object.prototype.hasOwnProperty.call(answers,q.id)&&JSON.stringify(answers[q.id])===JSON.stringify(value))b.classList.add('selected');b.addEventListener('click',async()=>{try{await persistAnswer(q.id,value);for(const x of card.querySelectorAll('button'))x.classList.remove('selected');b.classList.add('selected');}catch{}});card.append(b);}
    }else{const input=document.createElement('textarea');input.rows=3;input.dataset.questionId=String(q.id);input.placeholder='اكتب إجابتك هنا';input.value=answers[q.id]??'';input.addEventListener('change',()=>{persistAnswer(q.id,input.value).catch(()=>{});});card.append(input);}
    contentList.append(card);
  }
  const submit=document.createElement('button');submit.className='primary-action';submit.textContent='تسليم الامتحان';contentList.append(submit);let submitting=false;
  async function finishAttempt(auto=false){if(submitting)return;if(!auto&&!confirm('هل تريد تسليم إجاباتك وإنهاء المحاولة؟'))return;submitting=true;stopExamTimer();submit.disabled=true;try{await Promise.all([...pendingSaves]);for(const field of contentList.querySelectorAll('textarea[data-question-id]')){const questionId=Number(field.dataset.questionId);if(answers[questionId]!==field.value)await persistAnswer(questionId,field.value);}await Promise.all([...pendingSaves]);const result=await submitExamAttempt(attemptId);contentList.replaceChildren();const h=document.createElement('h3');h.textContent='نتيجة الامتحان';contentList.append(h);const p=document.createElement('p');p.textContent=result.total_marks>0?'درجتك: '+result.score+' من '+result.total_marks+' — تم تصحيح '+result.graded_questions+' سؤال آلياً.':'تم تسليم الامتحان. لا توجد مفاتيح إجابة موثقة تسمح بالتصحيح الآلي.';contentList.append(p);const back=document.createElement('button');back.className='back-link';back.textContent='العودة إلى الامتحانات';back.onclick=()=>showContent('exams');contentList.append(back);if(auto)showMessage('انتهى زمن الامتحان وتم تسليم إجاباتك المحفوظة.');}catch(e){submitting=false;submit.disabled=false;showMessage(e.message||'تعذر تسليم الامتحان.');}}
  submit.addEventListener('click',()=>finishAttempt(false));
  if(attempt?.expires_at){const deadline=Date.parse(attempt.expires_at);const tick=()=>{const remaining=Math.max(0,Math.ceil((deadline-Date.now())/1000));const mins=Math.floor(remaining/60),secs=remaining%60;timer.textContent='الوقت المتبقي: '+mins+':'+String(secs).padStart(2,'0');if(remaining===0){for(const control of contentList.querySelectorAll('button,textarea'))control.disabled=true;finishAttempt(true);}};tick();if(deadline>Date.now())examTimer=setInterval(tick,1000);}else{timer.textContent='لا يوجد حد زمني لهذا الامتحان.';}
}

const contentAdminButton=document.querySelector('#content-admin-open');if(CONTENT_ADMIN_ENABLED&&contentAdminButton){contentAdminButton.hidden=false;contentAdminButton.addEventListener('click',()=>showContent('content-admin'));}
document.querySelectorAll('[data-view]').forEach(btn=>btn.addEventListener('click',async()=>{const view=btn.dataset.view;if(view==='home'){setActiveNavigation('home');clearContent();hideMessage();await renderProfile();return;}if(view==='profile'){setActiveNavigation('profile');clearContent();await openSetup();return;}await showContent(view);}));
if('serviceWorker'in navigator&&location.protocol!=='file:')navigator.serviceWorker.register('./sw.js').catch(()=>{});
initializeLocalAuth().catch(error=>{lockApp('register');setAuthMessage(error.message||'تعذر فتح قاعدة البيانات المحلية.');});
