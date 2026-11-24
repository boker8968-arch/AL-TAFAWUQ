import { importContentPackage } from './content-packages.js';
import { getContentPackages, getPackageReviewHistory, reviewContentPackage, getQuestionsForAnswerReview, getAnswerKeyReviewHistory, reviewAnswerKey, getAll } from './database.js';

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
  const pickerLabel = field('اختر مجلد الحزمة الذي يحتوي manifest.json والملفات التابعة له', picker);
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

  const listHeading = node('h4', 'الحزم المنتظرة للمراجعة');
  const list = node('div', '', 'admin-package-list');
  container.append(listHeading, list);
  const answerHeading=node('h4','مراجعة مفاتيح الإجابة');
  const answerHelp=node('p','لا يُفعّل التصحيح الآلي إلا بعد مطابقة الإجابة مع مرجع موثوق وكتابة بيانات المراجعة.','admin-muted');
  const answerList=node('div','','admin-package-list');
  container.append(node('hr'),answerHeading,answerHelp,answerList);

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

  await Promise.all([refreshPackages(),refreshAnswerKeys()]);
}
