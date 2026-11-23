import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../student/data/student_repository.dart';
import '../data/student_learning_repository.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late Future<List<Map<String, Object?>>> _future;
  String? _notice;
  @override
  void initState() { super.initState(); _future = _load(); }

  Future<List<Map<String, Object?>>> _load() async {
    final profile = await StudentRepository().getStudentProfile();
    if (profile == null) { _notice = 'profile'; return []; }
    final db = await AppDatabase.instance.database;
    return db.rawQuery('''
      SELECT DISTINCT s.id, s.name_ar, s.code, s.sort_order
      FROM subjects s
      JOIN curriculum_release_subjects rs ON rs.subject_id=s.id
      JOIN curriculum_releases r ON r.id=rs.release_id
      JOIN curriculum_units u ON u.release_subject_id=rs.id
      JOIN content_packages cp ON cp.id=u.package_id
      WHERE s.grade_id=? AND s.is_active=1
        AND cp.review_status='approved'
        AND rs.verification_status='verified'
        AND r.verification_status='verified'
        AND (s.track_id IS NULL OR s.track_id=?)
        AND (r.track_id IS NULL OR r.track_id=?)
      ORDER BY s.sort_order, s.name_ar
    ''', [profile.gradeId, profile.trackId, profile.trackId]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المكتبة التعليمية')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المكتبة حالياً.'));
        if (_notice == 'profile') return const _EmptyLibrary(
          title: 'أكمل إعداد بيانات الطالب',
          message: 'اختر الصف الدراسي أولاً حتى نعرض المواد المناسبة لك.',
        );
        final subjects = snapshot.data ?? [];
        if (subjects.isEmpty) return const _EmptyLibrary(
          title: 'المكتبة قيد التجهيز',
          message: 'لا توجد حالياً مواد منشورة ومعتمدة لهذا الصف والمسار. ستظهر هنا بعد اعتماد المحتوى.',
        );
        return RefreshIndicator(
          onRefresh: () async { setState(() { _notice = null; _future = _load(); }); await _future; },
          child: ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => Card(child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE7F3EC), child: Icon(Icons.menu_book, color: AppColors.emerald)),
              title: Text(subjects[i]['name_ar'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('الوحدات والدروس المعتمدة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _UnitsPage(
                subjectId: subjects[i]['id'] as int, title: subjects[i]['name_ar'] as String))),
            )),
          ),
        );
      },
    ),
  );
}

class _UnitsPage extends StatefulWidget {
  const _UnitsPage({required this.subjectId, required this.title});
  final int subjectId;
  final String title;
  @override
  State<_UnitsPage> createState() => _UnitsPageState();
}
class _UnitsPageState extends State<_UnitsPage> {
  late Future<List<Map<String, Object?>>> _future;
  @override
  void initState() { super.initState(); _future = _load(); }
  Future<List<Map<String, Object?>>> _load() async {
    final profile = await StudentRepository().getStudentProfile();
    if (profile == null) return [];
    final db = await AppDatabase.instance.database;
    return StudentLearningRepository(db).getApprovedUnits(
      gradeId: profile.gradeId, trackId: profile.trackId, subjectId: widget.subjectId);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return const Center(child: Text('تعذر تحميل الوحدات.'));
        final units = snap.data ?? [];
        if (units.isEmpty) return const _EmptyLibrary(title: 'لا توجد وحدات منشورة', message: 'ستظهر الوحدات بعد اعتماد حزمة المحتوى والمنهج المرتبط بها.');
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: units.length,
          itemBuilder: (context, i) => Card(child: ExpansionTile(
            leading: const Icon(Icons.folder_open, color: AppColors.emerald),
            title: Text(units[i]['title_ar'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
            children: [ _LessonsList(unitId: units[i]['id'] as int) ],
          )));
      },
    ),
  );
}

class _LessonsList extends StatefulWidget {
  const _LessonsList({required this.unitId});
  final int unitId;
  @override
  State<_LessonsList> createState() => _LessonsListState();
}
class _LessonsListState extends State<_LessonsList> {
  late Future<List<Map<String, Object?>>> _future;
  @override
  void initState() { super.initState(); _future = _load(); }
  Future<List<Map<String, Object?>>> _load() async {
    final db = await AppDatabase.instance.database;
    return StudentLearningRepository(db).getApprovedLessons(unitId: widget.unitId);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
      if (snap.hasError) return const ListTile(title: Text('تعذر تحميل الدروس.'));
      final lessons = snap.data ?? [];
      if (lessons.isEmpty) return const ListTile(title: Text('لا توجد دروس منشورة بعد.'));
      return Column(children: lessons.map((lesson) => ListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: 56, end: 16),
        leading: const Icon(Icons.article_outlined, color: AppColors.emerald),
        title: Text(lesson['title_ar'] as String),
        subtitle: Text((lesson['summary_ar'] as String?) ?? 'درس تعليمي', maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _LessonPage(lesson: lesson))),
      )).toList());
    },
  );
}

class _LessonPage extends StatefulWidget {
  const _LessonPage({required this.lesson});
  final Map<String, Object?> lesson;
  @override
  State<_LessonPage> createState() => _LessonPageState();
}
class _LessonPageState extends State<_LessonPage> {
  late final DateTime _started = DateTime.now();
  late Future<String?> _body;
  bool _saving = false;
  @override
  void initState() { super.initState(); _body = _readBody(); }

  Future<String?> _readBody() async {
    final path = widget.lesson['body_path'] as String?;
    if (path == null || path.trim().isEmpty) return null;
    final dbDir = await getDatabasesPath();
    final rootDir = Directory(p.join(dbDir, 'al_tafawuq_content', 'packages'));
    if (!await rootDir.exists()) throw const FileSystemException('مجلد المحتوى غير موجود.');
    final root = await rootDir.resolveSymbolicLinks();
    final file = File(path);
    if (await FileSystemEntity.type(path, followLinks: false) != FileSystemEntityType.file) {
      throw const FileSystemException('ملف الدرس غير صالح.');
    }
    final resolved = await file.resolveSymbolicLinks();
    if (!p.normalize(resolved).startsWith(p.normalize(root) + p.separator)) {
      throw const FileSystemException('مسار الدرس خارج مجلد المحتوى.');
    }
    return File(resolved).readAsString();
  }

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final db = await AppDatabase.instance.database;
      final lessonId = widget.lesson['id'] as int;
      final unitId = widget.lesson['unit_id'] as int;
      final units = await db.query('curriculum_units', columns: ['subject_id'], where: 'id=?', whereArgs: [unitId], limit: 1);
      if (units.isEmpty) throw StateError('الوحدة غير موجودة.');
      final repo = StudentLearningRepository(db);
      await repo.saveLessonProgress(lessonId: lessonId, progressPercent: 100);
      await repo.recordStudySession(subjectId: units.single['subject_id'] as int,
        lessonId: lessonId, sessionType: 'lesson', startedAt: _started,
        endedAt: DateTime.now(), completedItems: 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إنجاز الدرس محلياً.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ التقدم: $e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.lesson['title_ar'] as String? ?? 'الدرس')),
    body: FutureBuilder<String?>(
      future: _body,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('تعذر فتح ملف الدرس بأمان. يرجى مراجعة حزمة المحتوى.')));
        final summary = widget.lesson['summary_ar'] as String?;
        return ListView(padding: const EdgeInsets.all(20), children: [
          if (summary != null && summary.trim().isNotEmpty) ...[
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
              color: const Color(0xFFE7F3EC), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ملخص الدرس', style: TextStyle(color: AppColors.deepEmerald, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8), Text(summary, style: const TextStyle(height: 1.7)),
              ]),
            ), const SizedBox(height: 20),
          ],
          if (snap.data == null || snap.data!.trim().isEmpty)
            const Text('لم يُرفق نص لهذا الدرس ضمن الحزمة.')
          else SelectableText(snap.data!, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 16, height: 1.9)),
          const SizedBox(height: 28),
          FilledButton.icon(onPressed: _saving ? null : _complete,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
            label: const Text('إكمال الدرس وحفظ التقدم')),
        ]);
      },
    ),
  );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.library_books_outlined, size: 50, color: AppColors.emerald),
      const SizedBox(height: 16), Text(title, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text(message, textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, height: 1.6)),
    ]),
  ));
}
