import { importContentPackage } from './content-packages.js';
import { getContentPackages, getPackageReviewHistory, reviewContentPackage, getQuestionsForAnswerReview, getAnswerKeyReviewHistory, reviewAnswerKey, getCurriculumCatalog, createCurriculumSubject, createCurriculumRelease, createCurriculumReleaseSubject, reviewCurriculumRecord, getCurriculumReviewHistory, getAll } from './database.js';

function node(tag, text = '', className = '') {
  const el = document.createElement(tag);
  if (text) el.textContent = text;
  if (className) el.className = className;
  return el;
}
function button(text, className, action) {
  const el = node('button', text, className);
  el.type = 'button';
  el.addEventListener('click', action);
  return el;
}
function field(labelText, input) {
  const wrap = node('label', '', 'admin-field');
  wrap.append(node('span', labelText), input);
  return wrap;
}
export async function renderContentAdmin(container) {
  container.replaceChildren();
  const title = node('h3', 'إدارة المحتوى التعليمي');
  const warning = node('p', 'وضع تطوير داخلي فقط: هذه الشاشة لا توفر مصادقة أو تحققاً من هوية المراجع، ولا يجوز توزيعها في إصدار الطلاب العام.', 'admin-warning');
  container.append(title, warning);

  const picker = document.createElement('input');
  picker.type = 'file';
  picker.multiple = true;
  picker.setAttribute('webkitdirectory', '');
  picker.setAttribute('directory', '');
  picker.accept = '.json,.txt,.md,.html,.pdf,.jpg,.jpeg,.png,.webp,.mp3,.mp4';
  const pickerLabel = field('اختر مجلد الحزمة. إذا لم يدعم جهازك اختيار المجلد، اختر manifest.json وكل الملفات معاً بأسماء ملفات غير مكررة.', picker);
  const selected = node('p', 'لم يتم اختيار مجلد بعد.', 'admin-muted');
  picker.addEventListener('change', () => {
    selected.textContent = picker.files?.length
      ? 'تم اختيار ' + picker.files.length + ' ملفاً. سيجري التحقق من الأحجام وبصمات SHA-256 قبل الاستيراد.'
      : 'لم يتم اختيار مجلد بعد.';
  });
  const importStatus = node('p', '', 'admin-status');
  const importButton = button('التحقق من الحزمة واستيرادها', 'primary-action', async () => {
    if (!picker.files?.length) { importStatus.textContent = 'اختر مجلد الحزمة أولاً.'; return; }
    importButton.disabled = true;
    importStatus.textContent = 'جارٍ التحقق من manifest والملفات وبصمات SHA-256...';
    try {
      const result = await importContentPackage(picker.files);
      importStatus.textContent = 'تم الاستيراد بنجاح: ' + result.packageCode + ' — ' + result.lessons + ' درس. الحالة: قيد المراجعة.';
      picker.value = '';
      selected.textContent = 'لم يتم اختيار مجلد بعد.';
      await refreshPackages();
      await refreshAnswerKeys();
    } catch (error) {
      importStatus.textContent = error.message || 'تعذر استيراد الحزمة.';
    } finally {
      importButton.disabled = false;
    }
  });
  container.append(pickerLabel, selected, importButton, importStatus, node('hr'));

  const reviewer = document.createElement('input');
  reviewer.type = 'text';
  reviewer.maxLength = 80;
  reviewer.placeholder = 'اسم المراجع الوصفي';
  const notes = document.createElement('textarea');
  notes.rows = 2;
  notes.maxLength = 1000;
  notes.placeholder = 'ملاحظات المراجعة أو سبب الرفض (إلزامي عند الرفض)';
  const reviewFields = node('section', '', 'admin-review-fields');
  reviewFields.append(field('اسم المراجع', reviewer), field('ملاحظات المراجعة', notes));
  container.append(reviewFields);

  const catalogHeading=node('h4','إعداد سجل المنهج والمواد');
  const catalogHelp=node('p','أضف بيانات المواد وإصدار المنهج من مصادر موثوقة. تبدأ السجلات غير منشورة، ولا تظهر للطلاب حتى توثيق الإصدار وربط المادة كلٌّ على حدة.','admin-muted');
  const catalogForms=node('section','','admin-catalog-forms');
  const subjectForm=document.createElement('form');subjectForm.className='admin-catalog-form';
  const subjectGrade=document.createElement('select');for(const [id,label] of [[1,'الأول الثانوي'],[2,'الثاني الثانوي'],[3,'الثالث الثانوي']])subjectGrade.add(new Option(label,String(id)));
  const subjectCode=document.createElement('input');subjectCode.required=true;subjectCode.maxLength=80;subjectCode.placeholder='رمز داخلي للمادة بالإنجليزية';
  const subjectName=document.createElement('input');subjectName.required=true;subjectName.maxLength=120;subjectName.placeholder='اسم المادة بالعربية';
  const subjectSave=document.createElement('button');subjectSave.type='submit';subjectSave.className='primary-action';subjectSave.textContent='إضافة مادة غير منشورة';
  subjectForm.append(node('h5','إضافة مادة'),field('الصف',subjectGrade),field('رمز المادة',subjectCode),field('اسم المادة',subjectName),subjectSave);

  const releaseForm=document.createElement('form');releaseForm.className='admin-catalog-form';
  const releaseGrade=document.createElement('select');for(const [id,label] of [[1,'الأول الثانوي'],[2,'الثاني الثانوي'],[3,'الثالث الثانوي']])releaseGrade.add(new Option(label,String(id)));
  const academicYear=document.createElement('input');academicYear.required=true;academicYear.maxLength=30;academicYear.placeholder='السنة الدراسية كما وردت في المصدر';
  const editionCode=document.createElement('input');editionCode.required=true;editionCode.maxLength=80;editionCode.placeholder='رمز الطبعة بالإنجليزية';
  const editionLabel=document.createElement('input');editionLabel.required=true;editionLabel.maxLength=120;editionLabel.placeholder='اسم الطبعة';
  const authority=document.createElement('input');authority.required=true;authority.maxLength=160;authority.placeholder='الجهة المصدرة';
  const sourceTitle=document.createElement('input');sourceTitle.required=true;sourceTitle.maxLength=200;sourceTitle.placeholder='اسم الوثيقة أو المصدر';
  const sourceUrl=document.createElement('input');sourceUrl.type='url';sourceUrl.maxLength=500;sourceUrl.placeholder='رابط المصدر (اختياري)';
  const releaseSave=document.createElement('button');releaseSave.type='submit';releaseSave.className='primary-action';releaseSave.textContent='إضافة إصدار غير موثق';
  releaseForm.append(node('h5','إضافة إصدار منهج'),field('الصف',releaseGrade),field('السنة الدراسية',academicYear),field('رمز الطبعة',editionCode),field('اسم الطبعة',editionLabel),field('الجهة المصدرة',authority),field('اسم المصدر',sourceTitle),field('رابط المصدر',sourceUrl),releaseSave);

  const mappingForm=document.createElement('form');mappingForm.className='admin-catalog-form';
  const releaseSelect=document.createElement('select'),subjectSelect=document.createElement('select');
  const requirement=document.createElement('select');requirement.add(new Option('غير مصنف','unclassified'));requirement.add(new Option('إلزامي','mandatory'));requirement.add(new Option('اختياري','elective'));
  const mappingOrder=document.createElement('input');mappingOrder.type='number';mappingOrder.min='0';mappingOrder.step='1';mappingOrder.value='0';
  const mappingSource=document.createElement('input');mappingSource.required=true;mappingSource.maxLength=240;mappingSource.placeholder='مرجع وجود المادة في الإصدار';
  const mappingSave=document.createElement('button');mappingSave.type='submit';mappingSave.className='primary-action';mappingSave.textContent='ربط المادة بإصدار المنهج';
  mappingForm.append(node('h5','ربط مادة بإصدار'),field('إصدار المنهج',releaseSelect),field('المادة',subjectSelect),field('نوع المادة',requirement),field('الترتيب',mappingOrder),field('مرجع الربط',mappingSource),mappingSave);
  catalogForms.append(subjectForm,releaseForm,mappingForm);
  const catalogReviewHeading=node('h5','مراجعة سجلات المنهج');
  const catalogReviewList=node('div','','admin-package-list');
  container.append(catalogHeading,catalogHelp,catalogForms,catalogReviewHeading,catalogReviewList,node('hr'));

  subjectForm.addEventListener('submit',async event=>{event.preventDefault();try{await createCurriculumSubject({gradeId:subjectGrade.value,code:subjectCode.value,nameAr:subjectName.value});subjectCode.value='';subjectName.value='';importStatus.textContent='أُضيفت المادة بحالة غير منشورة.';await refreshCatalog();}catch(error){importStatus.textContent=error.message||'تعذرت إضافة المادة.';}});
  releaseForm.addEventListener('submit',async event=>{event.preventDefault();try{await createCurriculumRelease({gradeId:releaseGrade.value,academicYear:academicYear.value,editionCode:editionCode.value,editionLabel:editionLabel.value,issuingAuthority:authority.value,sourceTitle:sourceTitle.value,sourceUrl:sourceUrl.value});importStatus.textContent='أُضيف إصدار المنهج بحالة قيد التوثيق.';await refreshCatalog();}catch(error){importStatus.textContent=error.message||'تعذرت إضافة إصدار المنهج.';}});
  mappingForm.addEventListener('submit',async event=>{event.preventDefault();try{await createCurriculumReleaseSubject({releaseId:releaseSelect.value,subjectId:subjectSelect.value,requirementType:requirement.value,sortOrder:mappingOrder.value,sourceReference:mappingSource.value});mappingSource.value='';importStatus.textContent='أُضيف ربط المادة بحالة قيد التوثيق.';await refreshCatalog();}catch(error){importStatus.textContent=error.message||'تعذر ربط المادة بإصدار المنهج.';}});

  const listHeading = node('h4', 'الحزم المنتظرة للمراجعة');
  const list = node('div', '', 'admin-package-list');
  container.append(listHeading, list);
  const answerHeading=node('h4','مراجعة مفاتيح الإجابة');
  const answerHelp=node('p','لا يُفعّل التصحيح الآلي إلا بعد مطابقة الإجابة مع مرجع موثوق وكتابة بيانات المراجعة.','admin-muted');
  const answerList=node('div','','admin-package-list');
  container.append(node('hr'),answerHeading,answerHelp,answerList);

  async function refreshCatalog(){
    const catalog=await getCurriculumCatalog();
    releaseSelect.replaceChildren(new Option('اختر إصداراً',''));
    for(const item of catalog.releases)releaseSelect.add(new Option(item.academic_year+' — '+item.edition_label+' ('+item.verification_status+')',String(item.id)));
    subjectSelect.replaceChildren(new Option('اختر مادة',''));
    for(const item of catalog.subjects)subjectSelect.add(new Option(item.name_ar+' — الصف '+item.grade_id,String(item.id)));
    catalogReviewList.replaceChildren();
    const pendingReleases=catalog.releases.filter(x=>x.verification_status==='pending');
    const pendingMappings=catalog.mappings.filter(x=>x.verification_status==='pending');
    if(!pendingReleases.length&&!pendingMappings.length){catalogReviewList.append(node('p','لا توجد سجلات منهج تنتظر التوثيق.','admin-muted'));}
    for(const item of pendingReleases){
      const card=node('article','','admin-package');
      card.append(node('h5','إصدار: '+item.edition_label+' — '+item.academic_year));
      card.append(node('p','الصف: '+item.grade_id+' | الرمز: '+item.edition_code+' | الجهة: '+item.issuing_authority+' | المصدر: '+item.source_title));
      const history=await getCurriculumReviewHistory('release',item.id);if(history.length)card.append(node('p','سجل المراجعة: '+history.length,'admin-muted'));
      const source=document.createElement('input');source.required=true;source.maxLength=240;source.placeholder='مرجع التحقق من الإصدار';
      const actions=node('div','','admin-actions');
      actions.append(button('توثيق الإصدار','admin-approve',async()=>{if(!reviewer.value.trim()||!source.value.trim()){importStatus.textContent='اسم المراجع ومرجع المصدر مطلوبان.';return;}if(!confirm('هل تحققت من بيانات هذا الإصدار ومصدره؟'))return;try{await reviewCurriculumRecord({entityType:'release',entityId:item.id,decision:'verified',reviewerLabel:reviewer.value,sourceReference:source.value,notes:notes.value});importStatus.textContent='تم توثيق إصدار المنهج.';await refreshCatalog();}catch(error){importStatus.textContent=error.message||'تعذر توثيق الإصدار.';}}));
      actions.append(button('رفض الإصدار','admin-reject',async()=>{if(!reviewer.value.trim()||!source.value.trim()||!notes.value.trim()){importStatus.textContent='اسم المراجع والمرجع وسبب الرفض مطلوبة.';return;}try{await reviewCurriculumRecord({entityType:'release',entityId:item.id,decision:'rejected',reviewerLabel:reviewer.value,sourceReference:source.value,notes:notes.value});importStatus.textContent='تم رفض إصدار المنهج.';await refreshCatalog();}catch(error){importStatus.textContent=error.message||'تعذر رفض الإصدار.';}}));
      card.append(field('مرجع التحقق',source),actions);catalogReviewList.append(card);
    }
    for(const item of pendingMappings){
      const subject=catalog.subjects.find(x=>x.id===item.subject_id),release=catalog.releases.find(x=>x.id===item.release_id);
      const card=node('article','','admin-package');
      card.append(node('h5','ربط مادة: '+(subject?.name_ar||item.subject_id)));
      card.append(node('p','الإصدار: '+(release?.edition_label||item.release_id)+' — '+(release?.academic_year||'')));
      const history=await getCurriculumReviewHistory('mapping',item.id);if(history.length)card.append(node('p','سجل المراجعة: '+history.length,'admin-muted'));
      const source=document.createElement('input');source.required=true;source.maxLength=240;source.placeholder='مرجع ظهور المادة في المنهج';
      const actions=node('div','','admin-actions');
      actions.append(button('توثيق الربط','admin-approve',async()=>{if(!reviewer.value.trim()||!source.value.trim()){importStatus.textContent='اسم المراجع ومرجع المصدر مطلوبان.';return;}if(!confirm('هل تحققت من وجود المادة ضمن هذا الإصدار؟'))return;try{await reviewCurriculumRecord({entityType:'mapping',entityId:item.id,decision:'verified',reviewerLabel:reviewer.value,sourceReference:source.value,notes:notes.value});importStatus.textContent='تم توثيق ربط المادة.';await refreshCatalog();}catch(error){importStatus.textContent=error.message||'تعذر توثيق الربط.';}}));
      actions.append(button('رفض الربط','admin-reject',async()=>{if(!reviewer.value.trim()||!source.value.trim()||!notes.value.trim()){importStatus.textContent='اسم المراجع والمرجع وسبب الرفض مطلوبة.';return;}try{await reviewCurriculumRecord({entityType:'mapping',entityId:item.id,decision:'rejected',reviewerLabel:reviewer.value,sourceReference:source.value,notes:notes.value});importStatus.textContent='تم رفض ربط المادة.';await refreshCatalog();}catch(error){importStatus.textContent=error.message||'تعذر رفض الربط.';}}));
      card.append(field('مرجع التحقق',source),actions);catalogReviewList.append(card);
    }
  }

  async function refreshPackages() {
    list.replaceChildren();
    const packages = await getContentPackages({reviewStatus:'pending_review'});
    if (!packages.length) { list.append(node('p', 'لا توجد حزم تنتظر المراجعة حالياً.', 'admin-muted')); return; }
    const [units,lessons,exams,questions,studyNotes] = await Promise.all(['curriculum_units','lessons','exams','questions','study_notes'].map(getAll));
    for (const pkg of packages) {
      const card = node('article', '', 'admin-package');
      card.append(node('h4', pkg.title || pkg.package_code));
      card.append(node('p', pkg.package_code + ' — الإصدار ' + pkg.version));
      card.append(node('p', 'الصف: ' + (pkg.grade_code || 'غير محدد') + ' | المادة: ' + (pkg.subject_code || 'غير محددة')));
      card.append(node('p', 'الوحدات: ' + units.filter(x=>x.package_id===pkg.id).length +
        ' | الدروس: ' + lessons.filter(x=>units.some(u=>u.id===x.unit_id&&u.package_id===pkg.id)).length +
        ' | المذكرات: ' + studyNotes.filter(x=>x.package_id===pkg.id).length +
        ' | الامتحانات: ' + exams.filter(x=>x.package_id===pkg.id).length +
        ' | الأسئلة: ' + questions.filter(x=>x.package_id===pkg.id).length));
      card.append(node('p', 'تاريخ الاستيراد: ' + (pkg.imported_at || 'غير متاح')));
      const history = await getPackageReviewHistory(pkg.id);
      if (history.length) card.append(node('p', 'سجل القرارات السابقة: ' + history.length));
      const actions = node('div', '', 'admin-actions');
      actions.append(button('اعتماد الحزمة', 'admin-approve', async () => {
        if (!reviewer.value.trim()) { importStatus.textContent = 'اكتب اسم المراجع أولاً.'; return; }
        if (!confirm('هل راجعت محتوى الحزمة ومصدره وتريد اعتماده للطلاب؟')) return;
        try {
          await reviewContentPackage({packageId:pkg.id,decision:'approved',reviewerLabel:reviewer.value,notes:notes.value});
          importStatus.textContent = 'تم اعتماد الحزمة ' + pkg.package_code + '.';
          notes.value = '';
          await refreshPackages();
          await refreshAnswerKeys();
        } catch (error) { importStatus.textContent = error.message || 'تعذر اعتماد الحزمة.'; }
      }));
      actions.append(button('رفض الحزمة', 'admin-reject', async () => {
        if (!reviewer.value.trim()) { importStatus.textContent = 'اكتب اسم المراجع أولاً.'; return; }
        if (!notes.value.trim()) { importStatus.textContent = 'سبب الرفض إلزامي.'; return; }
        if (!confirm('هل تريد رفض هذه الحزمة؟')) return;
        try {
          await reviewContentPackage({packageId:pkg.id,decision:'rejected',reviewerLabel:reviewer.value,notes:notes.value});
          importStatus.textContent = 'تم رفض الحزمة ' + pkg.package_code + '.';
          notes.value = '';
          await refreshPackages();
        } catch (error) { importStatus.textContent = error.message || 'تعذر رفض الحزمة.'; }
      }));
      card.append(actions);
      list.append(card);
    }
  }
  async function refreshAnswerKeys() {
    answerList.replaceChildren();
    const questions=await getQuestionsForAnswerReview();
    if(!questions.length){answerList.append(node('p','لا توجد مفاتيح إجابة تنتظر المراجعة.','admin-muted'));return;}
    for(const q of questions){
      const card=node('article','','admin-package');
      card.append(node('h4',q.package_title+' — '+q.subject_name));
      card.append(node('p',q.prompt_ar||'سؤال دون نص'));
      let options=[];
      try{options=q.options_json?JSON.parse(q.options_json):[];}catch{}
      if(Array.isArray(options))for(const option of options){
        const label=typeof option==='object'&&option!==null?(option.label??option.value??'') : String(option??'');
        card.append(node('p','خيار: '+String(label)));
      }
      let answer='غير متاح';
      try{answer=JSON.stringify(JSON.parse(q.answer_json));}catch{}
      card.append(node('p','مفتاح الإجابة المسجل: '+answer));
      card.append(node('p',q.answer_key_verified===1?'الحالة: مفتاح موثق':'الحالة: غير موثق — لا تصحيح آلي'));
      const source=document.createElement('input');source.type='text';source.maxLength=240;source.placeholder='مرجع الإجابة (الكتاب والصفحة أو نموذج إجابة معتمد)';
      const comment=document.createElement('textarea');comment.rows=2;comment.maxLength=1000;comment.placeholder='ملاحظات المراجعة أو سبب الرفض';
      card.append(field('مرجع الإجابة',source),field('ملاحظات',comment));
      const actions=node('div','','admin-actions');
      actions.append(button('توثيق مفتاح الإجابة','admin-approve',async()=>{
        if(!reviewer.value.trim()){importStatus.textContent='اكتب اسم المراجع أولاً.';return;}
        if(!source.value.trim()){importStatus.textContent='مرجع الإجابة إلزامي.';return;}
        if(!confirm('هل طابقت الإجابة مع المرجع المذكور وتريد تفعيل التصحيح الآلي؟'))return;
        try{await reviewAnswerKey({questionId:q.id,decision:'verified',reviewerLabel:reviewer.value,sourceReference:source.value,notes:comment.value});importStatus.textContent='تم توثيق مفتاح الإجابة وتفعيل التصحيح الآلي لهذا السؤال.';await refreshAnswerKeys();}
        catch(error){importStatus.textContent=error.message||'تعذر توثيق مفتاح الإجابة.';}
      }));
      actions.append(button('رفض المفتاح','admin-reject',async()=>{
        if(!reviewer.value.trim()){importStatus.textContent='اكتب اسم المراجع أولاً.';return;}
        if(!comment.value.trim()){importStatus.textContent='سبب الرفض إلزامي.';return;}
        if(!confirm('هل تريد رفض مفتاح الإجابة؟'))return;
        try{await reviewAnswerKey({questionId:q.id,decision:'rejected',reviewerLabel:reviewer.value,sourceReference:source.value,notes:comment.value});importStatus.textContent='تم رفض مفتاح الإجابة وإبقاء التصحيح الآلي معطلاً.';await refreshAnswerKeys();}
        catch(error){importStatus.textContent=error.message||'تعذر رفض مفتاح الإجابة.';}
      }));
      card.append(actions);
      const history=await getAnswerKeyReviewHistory(q.id);
      if(history.length)card.append(node('p','سجل مراجعات المفتاح: '+history.length,'admin-muted'));
      answerList.append(card);
    }
  }

  await Promise.all([refreshCatalog(),refreshPackages(),refreshAnswerKeys()]);
}
