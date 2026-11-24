# مواصفات حزمة محتوى منصة التفوق — manifest v1

هذه المواصفات للحزم التكميلية التي تُستورد محلياً. لا تُنشئ الحزمة منهجاً معتمداً تلقائياً؛ كل حزمة تبدأ بحالة `pending_review` ولا تظهر للطالب قبل قرار مراجعة واعتماد وربط منهجي موثّق.

## بنية المجلد

```text
my-package/
├── manifest.json
├── lessons/
│   └── lesson-01.txt
├── notes/
│   └── summary-01.pdf
└── exams/
    └── exam-01-source.txt
```

يجب إدراج كل ملف يُشار إليه في `body_file` أو `notes[].file` داخل مصفوفة `assets` مع حجمه الفعلي وبصمة SHA-256 ونوع MIME.

## قالب manifest.json

القالب التالي توضيحي فقط؛ استبدل الرموز والقيم ببيانات حقيقية متوافقة مع صف ومادة وإصدار منهج موجودة وموثقة في قاعدة التطبيق. لا تستخدم رموزاً افتراضية عند إعداد حزمة للاستيراد.

```json
{
  "schema_version": 1,
  "package_code": "replace-with-unique-code",
  "version": "1.0.0",
  "title": "عنوان الحزمة",
  "grade_code": "EXISTING_GRADE_CODE",
  "subject_code": "EXISTING_SUBJECT_CODE",
  "academic_year": "EXACT_VERIFIED_YEAR",
  "edition_code": "EXACT_VERIFIED_EDITION",
  "source_label": "supplemental",
  "units": [
    {
      "code": "unit-01",
      "title": "عنوان الوحدة",
      "sort_order": 1,
      "lessons": [
        {
          "code": "lesson-01",
          "title": "عنوان الدرس",
          "summary": "ملخص اختياري",
          "body_file": "lessons/lesson-01.txt",
          "sort_order": 1
        }
      ]
    }
  ],
  "notes": [
    {
      "code": "note-01",
      "title": "عنوان المذكرة",
      "summary": "وصف اختياري",
      "file": "notes/summary-01.pdf"
    }
  ],
  "exams": [
    {
      "code": "exam-01",
      "title": "عنوان الامتحان",
      "exam_type": "practice",
      "duration_minutes": 45,
      "questions": [
        {
          "code": "question-01",
          "type": "multiple_choice",
          "prompt": "نص السؤال",
          "lesson_code": "lesson-01",
          "options": [
            {"value": "A", "label": "الخيار الأول"},
            {"value": "B", "label": "الخيار الثاني"}
          ],
          "answer": "A",
          "explanation": "شرح اختياري",
          "difficulty": 1,
          "marks": 1,
          "answer_key_verified": false
        }
      ]
    }
  ],
  "assets": [
    {
      "path": "lessons/lesson-01.txt",
      "bytes": 0,
      "sha256": "REPLACE_WITH_64_HEX_CHARACTERS",
      "media_type": "text/plain"
    },
    {
      "path": "notes/summary-01.pdf",
      "bytes": 0,
      "sha256": "REPLACE_WITH_64_HEX_CHARACTERS",
      "media_type": "application/pdf"
    }
  ]
}
```

## القواعد التي يطبقها المستورد

- `schema_version` يجب أن يساوي 1.
- `package_code` و`version` رموز تخزين فريدة تتكون من أحرف إنجليزية وأرقام ونقطة وشرطة وشرطة سفلية، وتبدأ بحرف أو رقم.
- `source_label` يجب أن يكون `supplemental`. الحزم الموسومة `official` مرفوضة حتى تتوفر آلية مستقلة للتحقق من مصدرها.
- يجب أن يطابق `grade_code` و`subject_code` صفاً ومادة نشطين، وأن يطابق العام الدراسي ورمز الطبعة إصدار منهج وربط مادة موثّقين. لا يُستورد المحتوى عند غياب المطابقة أو وجود أكثر من مطابقة.
- كل وحدة يجب أن تحتوي درساً واحداً على الأقل. رموز الوحدات والدروس والامتحانات والأسئلة والمذكرات لا تتكرر داخل الحزمة.
- أنواع الأسئلة المدعومة: `multiple_choice` و`true_false` و`short_answer`. سؤال الاختيار المتعدد يحتاج خيارين على الأقل. `marks` رقم موجب، ومدة الامتحان عدد صحيح غير سالب.
- `lesson_code` في السؤال يجب أن يشير إلى درس موجود في الحزمة نفسها.
- مسارات الملفات نسبية وآمنة؛ تُرفض المسارات المطلقة ومسارات الرجوع مثل `..` والملفات المفقودة والمسارات المكررة وملف `manifest.json` ضمن assets.
- الحد الحالي للملف الواحد 50 MiB، وإجمالي الأصول 200 MiB، وملف manifest بحد أقصى 2 MiB.
- يُطابق المستورد الحجم الفعلي لكل ملف وبصمة SHA-256 قبل تخزين أي محتوى.
- المذكرات اختيارية في امتداد الويب، وتُصنف دائماً تحت الفئة `المذكرات`.
- لا يستطيع manifest اعتماد مفتاح الإجابة لنفسه؛ يحفظ المستورد `answer_key_verified=0` لكل سؤال بصرف النظر عن القيمة الواردة. بعد اعتماد الحزمة، يمكن لمراجع المحتوى توثيق مفتاح سؤال موضوعي فقط مع مرجع إجابة محدد؛ يسجل النظام القرار في سجل مستقل ولا يكشف المفتاح لواجهة الطالب.
- الحزمة المستوردة تسجل `pending_review`، ولا تظهر للطالب قبل اعتمادها.

## إنشاء بصمة SHA-256

Linux / macOS:
```bash
sha256sum lessons/lesson-01.txt
```

Windows PowerShell:
```powershell
(Get-FileHash .\\lessons\\lesson-01.txt -Algorithm SHA256).Hash.ToLower()
```

انسخ الحجم الفعلي بالبايت في `bytes`، والبصمة المكونة من 64 رمزاً في `sha256`. كرر ذلك لكل ملف في `assets`.

## ملاحظات توافق

- الحقول الأساسية تتبع manifest v1 في تطبيق Flutter الأصلي.
- `notes` امتداد اختياري أضيف لمسار Web / Capacitor؛ الإصدارات القديمة من مستورد Flutter قد تتجاهل هذا الحقل ولا تستورد سجلات المذكرات.
- نجاح التحقق التقني لا يعني صحة المحتوى الأكاديمي أو صحة مفتاح الإجابة. المراجعة التحريرية المنفصلة تظل إلزامية.
- واجهة إدارة الحزم والصلاحيات الموثوقة ليست مكتملة بعد؛ لا تعرض وظائف الاعتماد للمستخدم النهائي قبل تنفيذ المصادقة والتفويض.
