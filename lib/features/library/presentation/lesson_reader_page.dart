import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../learning/data/student_learning_repository.dart';

class LessonReaderPage extends StatefulWidget {
  const LessonReaderPage({super.key, required this.lesson});
  final Map<String, Object?> lesson;

  @override
  State<LessonReaderPage> createState() => _LessonReaderPageState();
}

class _LessonReaderPageState extends State<LessonReaderPage> {
  late final DateTime _startedAt;
  late Future<String?> _bodyFuture;
  bool _saving = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _bodyFuture = _readLessonBody();
  }

  Future<String?> _readLessonBody() async {
    final storedPath = widget.lesson['body_path'] as String?;
    if (storedPath == null || storedPath.trim().isEmpty) return null;

    final databaseDirectory = await getDatabasesPath();
    final expectedRoot = p.normalize(p.join(databaseDirectory, 'al_tafawuq_content', 'packages'));
    final rootType = await FileSystemEntity.type(expectedRoot, followLinks: false);
    if (rootType != FileSystemEntityType.directory) {
      throw const FormatException('مجلد المحتوى المحلي غير صالح.');
    }
    final canonicalRoot = p.normalize(await Directory(expectedRoot).resolveSymbolicLinks());
    final candidate = p.normalize(p.absolute(storedPath));
    if (!p.isWithin(canonicalRoot, candidate)) {
      throw const FormatException('مسار ملف الدرس خارج مجلد المحتوى المسموح.');
    }
    final type = await FileSystemEntity.type(candidate, followLinks: false);
    if (type != FileSystemEntityType.file) {
      throw const FormatException('ملف الدرس غير موجود أو ليس ملفاً عادياً.');
    }
    final canonicalFile = p.normalize(await File(candidate).resolveSymbolicLinks());
    if (!p.isWithin(canonicalRoot, canonicalFile)) {
      throw const FormatException('ملف الدرس يشير إلى موقع خارج مجلد المحتوى.');
    }
    return utf8.decode(await File(canonicalFile).readAsBytes(), allowMalformed: false);
  }

  Future<void> _completeLesson() async {
    if (_saving || _completed) return;
    setState(() => _saving = true);
    try {
      final db = await AppDatabase.instance.database;
      final repository = StudentLearningRepository(db);
      final lessonId = widget.lesson['id'] as int;
      await repository.saveLessonProgress(lessonId: lessonId, progressPercent: 100);
      await repository.recordStudySession(
        lessonId: lessonId,
        sessionType: 'lesson',
        startedAt: _startedAt,
        endedAt: DateTime.now(),
        completedItems: 1,
      );
      if (!mounted) return;
      setState(() => _completed = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أُنجز الدرس وحُفظ تقدمك على الجهاز.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ التقدم. حاول مرة أخرى.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.lesson['title_ar'] as String? ?? 'الدرس';
    final summary = widget.lesson['summary_ar'] as String?;
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(child: FutureBuilder<String?>(
        future: _bodyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('تعذر فتح ملف الدرس. قد يكون الملف مفقوداً أو أن مساره غير آمن.'),
          ));
          final body = snapshot.data;
          return Column(children: [
            Expanded(child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xFFE7F3EC), borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    const Icon(Icons.menu_book_rounded, color: AppColors.emerald, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.deepEmerald))),
                  ]),
                ),
                if (summary != null && summary.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('ملخص الدرس', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.emerald)),
                  const SizedBox(height: 8),
                  Text(summary, style: const TextStyle(height: 1.7, fontSize: 15)),
                ],
                const SizedBox(height: 22),
                if (body != null && body.isNotEmpty) ...[
                  const Text('محتوى الدرس', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.emerald, fontSize: 16)),
                  const SizedBox(height: 10),
                  SelectableText(body, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 15, height: 1.9, color: AppColors.ink)),
                ] else if (summary == null || summary.isEmpty)
                  const Text('لم يُرفق نص أو ملخص لهذا الدرس بعد.', style: TextStyle(color: AppColors.muted)),
              ],
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _saving || _completed ? null : _completeLesson,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_completed ? Icons.check_circle : Icons.task_alt),
                label: Text(_completed ? 'تم إكمال الدرس' : 'إكمال الدرس وحفظ التقدم'),
              )),
            ),
          ]);
        },
      )),
    );
  }
}
