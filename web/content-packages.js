import { getAll, openDb } from './database.js';

const SAFE_SEGMENT = /^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/;
const SHA256 = /^[a-f0-9]{64}$/i;
const MAX_ASSET_BYTES = 50 * 1024 * 1024;
const MAX_PACKAGE_BYTES = 200 * 1024 * 1024;

function fail(message) { throw new Error(message); }
function requiredString(value, field) {
  if (typeof value !== 'string' || !value.trim()) fail('حقل مطلوب أو غير صالح: ' + field);
  return value.trim();
}
function safePath(value, field) {
  const path = requiredString(value, field).replaceAll('\\', '/');
  const parts = path.split('/');
  if (path.startsWith('/') || /^[a-z]:/i.test(path) || parts.some(p => !p || p === '.' || p === '..')) {
    fail('مسار غير آمن في الحزمة: ' + field);
  }
  return path;
}
export function validateManifest(m) {
  if (!m || typeof m !== 'object' || Array.isArray(m)) fail('ملف manifest.json غير صالح.');
  if (m.schema_version !== 1) fail('إصدار بنية الحزمة غير مدعوم.');
  for (const key of ['package_code','version','title','grade_code','subject_code','academic_year','edition_code','source_label']) requiredString(m[key], key);
  if (!SAFE_SEGMENT.test(m.package_code) || !SAFE_SEGMENT.test(m.version)) fail('رمز الحزمة أو الإصدار غير صالح للتخزين.');
  if (m.source_label !== 'supplemental') fail('يُسمح حالياً باستيراد الحزم التكميلية فقط.');
  if (!Array.isArray(m.units) || !m.units.length || !Array.isArray(m.assets)) fail('يجب أن تحتوي الحزمة على وحدات ومصفوفة ملفات.');
  if (m.exams != null && !Array.isArray(m.exams)) fail('مصفوفة الامتحانات غير صالحة.');
  if (m.notes != null && !Array.isArray(m.notes)) fail('مصفوفة المذكرات غير صالحة.');
  const units = new Set(), lessons = new Set(), exams = new Set(), questions = new Set(), noteCodes = new Set(), assets = new Map(), refs = [];
  for (const unit of m.units) {
    if (!unit || typeof unit !== 'object' || Array.isArray(unit)) fail('كل وحدة يجب أن تكون كائناً صالحاً.');
    requiredString(unit.code,'unit.code'); requiredString(unit.title,'unit.title');
    if (unit.sort_order != null && !Number.isInteger(unit.sort_order)) fail('ترتيب الوحدة غير صالح.');
    if (units.has(unit.code)) fail('رمز وحدة مكرر: ' + unit.code); units.add(unit.code);
    if (!Array.isArray(unit.lessons) || !unit.lessons.length) fail('كل وحدة يجب أن تحتوي درساً واحداً على الأقل.');
    for (const lesson of unit.lessons) {
      if (!lesson || typeof lesson !== 'object' || Array.isArray(lesson)) fail('كل درس يجب أن يكون كائناً صالحاً.');
      requiredString(lesson.code,'lesson.code'); requiredString(lesson.title,'lesson.title');
      if (lesson.sort_order != null && !Number.isInteger(lesson.sort_order)) fail('ترتيب الدرس غير صالح.');
      if (lesson.summary != null && typeof lesson.summary !== 'string') fail('ملخص الدرس يجب أن يكون نصاً.');
      if (lesson.body_file != null && typeof lesson.body_file !== 'string') fail('مسار ملف الدرس يجب أن يكون نصاً.');
      if (lessons.has(lesson.code)) fail('رمز درس مكرر: ' + lesson.code); lessons.add(lesson.code);
      if (lesson.body_file) refs.push(safePath(lesson.body_file,'body_file'));
    }
  }
  for (const note of (m.notes || [])) {
    if (!note || typeof note !== 'object' || Array.isArray(note)) fail('كل مذكرة يجب أن تكون كائناً صالحاً.');
    requiredString(note.code,'note.code'); requiredString(note.title,'note.title');
    if (note.summary != null && typeof note.summary !== 'string') fail('ملخص المذكرة يجب أن يكون نصاً.');
    if (noteCodes.has(note.code)) fail('رمز مذكرة مكرر: ' + note.code); noteCodes.add(note.code);
    refs.push(safePath(note.file,'note.file'));
  }
  for (const asset of m.assets) {
    if (!asset || typeof asset !== 'object' || Array.isArray(asset)) fail('كل ملف داخل assets يجب أن يكون كائناً صالحاً.');
    const path = safePath(asset.path,'asset.path');
    if (path === 'manifest.json' || assets.has(path)) fail('مسار ملف مكرر أو محجوز: ' + path);
    requiredString(asset.media_type,'asset.media_type');
    if (!/^[a-z0-9.+-]+\/[a-z0-9.+-]+$/i.test(asset.media_type)) fail('نوع الملف غير صالح: ' + path);
    if (!Number.isSafeInteger(asset.bytes) || asset.bytes < 0 || asset.bytes > MAX_ASSET_BYTES || !SHA256.test(asset.sha256 || '')) fail('بيانات حجم أو بصمة الملف غير صالحة أو تجاوز الملف الحد المسموح: ' + path);
    assets.set(path, asset);
  }
  for (const path of refs) if (!assets.has(path)) fail('الملف المشار إليه غير مدرج ضمن assets: ' + path);
  for (const exam of (m.exams || [])) {
    if (!exam || typeof exam !== 'object' || Array.isArray(exam)) fail('كل امتحان يجب أن يكون كائناً صالحاً.');
    requiredString(exam.code,'exam.code'); requiredString(exam.title,'exam.title');
    if (exam.exam_type != null && typeof exam.exam_type !== 'string') fail('نوع الامتحان غير صالح.');
    if (exam.duration_minutes != null && (!Number.isInteger(exam.duration_minutes) || exam.duration_minutes < 0)) fail('مدة الامتحان غير صالحة.');
    if (exams.has(exam.code)) fail('رمز امتحان مكرر: ' + exam.code); exams.add(exam.code);
    if (!Array.isArray(exam.questions) || !exam.questions.length) fail('كل امتحان يجب أن يحتوي أسئلة.');
    for (const q of exam.questions) {
      if (!q || typeof q !== 'object' || Array.isArray(q)) fail('كل سؤال يجب أن يكون كائناً صالحاً.');
      requiredString(q.code,'question.code'); requiredString(q.type,'question.type'); requiredString(q.prompt,'question.prompt');
      if (questions.has(q.code)) fail('رمز سؤال مكرر: ' + q.code); questions.add(q.code);
      if (!['multiple_choice','true_false','short_answer'].includes(q.type)) fail('نوع سؤال غير مدعوم: ' + q.type);
      if (q.options != null && !Array.isArray(q.options)) fail('خيارات السؤال يجب أن تكون مصفوفة.');
      if (q.answer_key_verified != null && typeof q.answer_key_verified !== 'boolean') fail('answer_key_verified يجب أن يكون قيمة منطقية.');
      if (q.difficulty != null && !Number.isInteger(q.difficulty)) fail('مستوى صعوبة السؤال غير صالح.');
      if (q.type === 'multiple_choice' && (!Array.isArray(q.options) || q.options.length < 2)) fail('سؤال الاختيار المتعدد يحتاج خيارين على الأقل.');
      if (q.lesson_code != null && typeof q.lesson_code !== 'string') fail('رمز درس السؤال يجب أن يكون نصاً.');
      if (q.explanation != null && typeof q.explanation !== 'string') fail('شرح السؤال يجب أن يكون نصاً.');
      if (q.lesson_code != null && !lessons.has(q.lesson_code)) fail('السؤال يشير إلى درس غير موجود: ' + q.lesson_code);
      if (q.marks != null && (typeof q.marks !== 'number' || q.marks <= 0)) fail('درجة السؤال غير صالحة.');
    }
  }
  return assets;
}
function fileMap(files) {
  const map = new Map();
  for (const file of files) {
    const rel = (file.webkitRelativePath || file.name).split('/').slice(1).join('/');
    if (rel) { const normalized=rel.replaceAll('\\','/'); if(map.has(normalized)) fail('مسار ملف مكرر داخل المجلد المختار: '+normalized); map.set(normalized,file); }
    if (file.name === 'manifest.json' && !map.has('manifest.json')) map.set('manifest.json', file);
  }
  return map;
}
async function digest(file) {
  const bytes = await file.arrayBuffer();
  const hash = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(hash)].map(x => x.toString(16).padStart(2,'0')).join('');
}
function req(request) {
  return new Promise((resolve,reject) => { request.onsuccess=()=>resolve(request.result); request.onerror=()=>reject(request.error); });
}

export async function importContentPackage(fileList) {
  const files = [...fileList];
  const byPath = fileMap(files);
  const manifestFile = byPath.get('manifest.json') || files.find(f => f.name === 'manifest.json');
  if (!manifestFile) fail('لم يتم العثور على manifest.json داخل المجلد المختار.');
  let manifest;
  try { manifest = JSON.parse(await manifestFile.text()); } catch { fail('تعذر قراءة manifest.json؛ تأكد من صحة JSON.'); }
  const assets = validateManifest(manifest);
  const verifiedFiles = [];
  for (const [path, spec] of assets) {
    const file = byPath.get(path);
    if (!file) fail('ملف مفقود من الحزمة: ' + path);
    if (file.size !== spec.bytes) fail('حجم الملف لا يطابق manifest: ' + path);
    packageBytes+=file.size;if(packageBytes>MAX_PACKAGE_BYTES)fail('حجم الحزمة يتجاوز 200 ميجابايت؛ يرجى تقسيمها إلى حزم أصغر.');
    if ((await digest(file)) !== spec.sha256.toLowerCase()) fail('فشل التحقق من SHA-256 للملف: ' + path);
    verifiedFiles.push({path,file,media_type:spec.media_type});
  }

  const [grades,subjects,releases,mappings,packages] = await Promise.all(['grades','subjects','curriculum_releases','curriculum_release_subjects','content_packages'].map(getAll));
  const grade = grades.find(x => x.code === manifest.grade_code && x.is_active === 1);
  const subject = grade && subjects.find(x => x.code === manifest.subject_code && x.grade_id === grade.id && x.is_active === 1);
  if (!grade || !subject) fail('الصف أو المادة غير موجودين في قاعدة المناهج المعتمدة.');
  const matches = mappings.filter(map => {
    const release = releases.find(r => r.id === map.release_id);
    return map.subject_id === subject.id && map.verification_status === 'verified' &&
      release && release.grade_id === grade.id && release.academic_year === manifest.academic_year &&
      release.edition_code === manifest.edition_code && release.verification_status === 'verified' &&
      (release.track_id == null || subject.track_id == null || release.track_id === subject.track_id);
  });
  if (matches.length !== 1) fail(matches.length ? 'الحزمة تطابق أكثر من ربط منهجي؛ يجب حل التعارض أولاً.' : 'لا يوجد إصدار منهج وربط مادة موثّقان يطابقان هذه الحزمة.');
  if (packages.some(p => p.package_code === manifest.package_code)) fail('هذه الحزمة مثبتة مسبقاً. تحديث الحزم غير متاح بعد.');
  const mapping = matches[0];
  const manifestChecksum = await digest(manifestFile);
  const db = await openDb();
  const names = ['content_packages','curriculum_units','lessons','exams','questions','exam_questions','package_assets','study_notes'];
  const tx = db.transaction(names,'readwrite');
  const packageStore = tx.objectStore('content_packages');
  const packageRequest = packageStore.add({
    package_code:manifest.package_code,version:manifest.version,title:manifest.title,
    imported_at:new Date().toISOString(),source_label:'supplemental',review_status:'pending_review',
    checksum:manifestChecksum,grade_code:manifest.grade_code,subject_code:manifest.subject_code
  });
  const done = new Promise((resolve,reject)=>{tx.oncomplete=()=>resolve(true);tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error||new Error('أُلغيت عملية الاستيراد.'));});
  packageRequest.onsuccess = () => {
    const packageId = packageRequest.result;
    const lessonIds = new Map();
    let remainingLessons = manifest.units.reduce((n,unit) => n + unit.lessons.length, 0);
    const addExams = () => {
      for (const exam of (manifest.exams || [])) {
        const examReq = tx.objectStore('exams').add({
          subject_id:subject.id,package_id:packageId,content_code:exam.code,title_ar:exam.title,
          exam_type:exam.exam_type || 'practice',duration_minutes:exam.duration_minutes || null,source_label:'supplemental'
        });
        examReq.onsuccess = () => {
          exam.questions.forEach((q,index) => {
            const questionReq = tx.objectStore('questions').add({
              subject_id:subject.id,lesson_id:q.lesson_code ? lessonIds.get(q.lesson_code) : null,
              package_id:packageId,content_code:q.code,question_type:q.type,prompt_ar:q.prompt,
              options_json:q.options==null?null:JSON.stringify(q.options),
              answer_json:q.answer==null?null:JSON.stringify(q.answer),explanation_ar:q.explanation||null,
              difficulty:q.difficulty||1,source_label:'supplemental',answer_key_verified:0
            });
            questionReq.onsuccess = () => tx.objectStore('exam_questions').add({
              exam_id:examReq.result,question_id:questionReq.result,sort_order:index,marks:q.marks||1
            });
          });
        };
      }
    };
    for (const unit of manifest.units) {
      const unitReq = tx.objectStore('curriculum_units').add({
        subject_id:subject.id,release_subject_id:mapping.id,package_id:packageId,
        content_code:unit.code,title_ar:unit.title,sort_order:unit.sort_order || 0,source_label:'supplemental'
      });
      unitReq.onsuccess = () => {
        for (const lesson of unit.lessons) {
          const lessonReq = tx.objectStore('lessons').add({
            unit_id:unitReq.result,content_code:lesson.code,title_ar:lesson.title,
            summary_ar:lesson.summary || null,body_path:lesson.body_file || null,
            sort_order:lesson.sort_order || 0,content_version:manifest.version
          });
          lessonReq.onsuccess = () => {
            lessonIds.set(lesson.code,lessonReq.result);
            remainingLessons--;
            if (remainingLessons === 0) addExams();
          };
        }
      };
    }
    for (const note of (manifest.notes || [])) tx.objectStore('study_notes').add({
      subject_id:subject.id,package_id:packageId,content_code:note.code,title_ar:note.title,
      summary_ar:note.summary||null,body_path:safePath(note.file,'note.file'),category:'المذكرات'
    });
    for (const item of verifiedFiles) tx.objectStore('package_assets').add({
      package_id:packageId,path:item.path,blob:item.file,media_type:item.media_type
    });
  };
  await done;
  return {packageId:packageRequest.result,packageCode:manifest.package_code,version:manifest.version,units:manifest.units.length,lessons:manifest.units.reduce((n,u)=>n+u.lessons.length,0),status:'pending_review'};
}

export async function readPackageText(packageId, relativePath) {
  const db = await openDb();
  const tx = db.transaction('package_assets','readonly');
  const row = await req(tx.objectStore('package_assets').get([Number(packageId),relativePath]));
  if (!row || !(row.blob instanceof Blob)) fail('ملف المحتوى غير موجود داخل الحزمة المحلية.');
  return row.blob.text();
}
