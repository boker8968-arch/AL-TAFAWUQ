import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../learning/data/student_learning_repository.dart';
import '../../student/data/student_repository.dart';
import 'lesson_reader_page.dart';

class LearningLibraryPage extends StatefulWidget {
  const LearningLibraryPage({super.key});

  @override
  State<LearningLibraryPage> createState() => _LearningLibraryPageState();
}

class _LearningLibraryPageState extends State<LearningLibraryPage> {
  late Future<List<Map<String, Object?>>> _unitsFuture;

  @override
  void initState() {
    super.initState();
    _unitsFuture = _loadUnits();
  }

  Future<List<Map<String, Object?>>> _loadUnits() async {
    final profile = await StudentRepository().getStudentProfile();
    if (profile == null) return [];
    final db = await AppDatabase.instance.database;
    return StudentLearningRepository(db).getApprovedUnits(
      gradeId: profile.gradeId,
      trackId: profile.trackId,
    );
  }

  Future<void> _refresh() async {
    setState(() => _unitsFuture = _loadUnits());
    await _unitsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المكتبة التعليمية')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _unitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _empty('تعذر تحميل المكتبة', 'حدث خطأ أثناء قراءة المحتوى المحلي.', Icons.error_outline);
          }
          final units = snapshot.data ?? const [];
          if (units.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(28),
                children: const [
                  SizedBox(height: 70),
                  Icon(Icons.menu_book_outlined, size: 54, color: AppColors.muted),
                  SizedBox(height: 18),
                  Text('لا يوجد محتوى منشور لهذا الصف حالياً', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  SizedBox(height: 8),
                  Text('تأكد من إعداد الصف الدراسي. ستظهر المواد بعد اعتماد حزم المحتوى والتحقق من إصدار المنهج.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.6)),
                ],
              ),
            );
          }

          final groups = <String, List<Map<String, Object?>>>{};
          for (final unit in units) {
            final key = unit['subject_id'].toString();
            groups.putIfAbsent(key, () => []).add(unit);
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppColors.emerald, AppColors.deepEmerald],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_stories_rounded, color: AppColors.gold, size: 28),
                      const SizedBox(height: 10),
                      const Text('مكتبتك الدراسية', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text('${groups.length} مادة متاحة • ${units.length} وحدة منشورة', style: const TextStyle(color: Color(0xFFE2F1E9), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (final entry in groups.entries) ...[
                  _SubjectSection(title: entry.value.first['subject_name'] as String? ?? 'مادة دراسية', units: entry.value),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _empty(String title, String message, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: AppColors.emerald),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 18),
        FilledButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
      ]),
    ),
  );
}

class _SubjectSection extends StatelessWidget {
  const _SubjectSection({required this.title, required this.units});
  final String title;
  final List<Map<String, Object?>> units;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.book_outlined, color: AppColors.emerald),
          const SizedBox(width: 9),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink))),
          Text('${units.length} وحدة', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
        const Divider(height: 20),
        for (final unit in units)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(radius: 18, backgroundColor: Color(0xFFE7F3EC), child: Icon(Icons.topic_outlined, color: AppColors.emerald, size: 19)),
            title: Text(unit['title_ar'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: const Text('افتح الوحدة لعرض الدروس', style: TextStyle(color: AppColors.muted, fontSize: 11)),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => UnitLessonsPage(unitId: unit['id'] as int, unitTitle: unit['title_ar'] as String),
            )),
          ),
      ]),
    ),
  );
}

class UnitLessonsPage extends StatefulWidget {
  const UnitLessonsPage({super.key, required this.unitId, required this.unitTitle});
  final int unitId;
  final String unitTitle;

  @override
  State<UnitLessonsPage> createState() => _UnitLessonsPageState();
}

class _UnitLessonsPageState extends State<UnitLessonsPage> {
  late Future<List<Map<String, Object?>>> _lessonsFuture;

  @override
  void initState() {
    super.initState();
    _lessonsFuture = _loadLessons();
  }

  Future<List<Map<String, Object?>>> _loadLessons() async {
    final db = await AppDatabase.instance.database;
    return StudentLearningRepository(db).getApprovedLessons(unitId: widget.unitId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.unitTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _lessonsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل الدروس.'));
        final lessons = snapshot.data ?? const [];
        if (lessons.isEmpty) return const Center(child: Text('لا توجد دروس منشورة في هذه الوحدة.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: lessons.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            return Card(child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE7F3EC), child: Icon(Icons.play_lesson_outlined, color: AppColors.emerald)),
              title: Text(lesson['title_ar'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: lesson['summary_ar'] == null ? null : Text(lesson['summary_ar'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LessonReaderPage(lesson: lesson))),
            ));
          },
        );
      },
    ),
  );
}
