import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../student/data/student_repository.dart';
import '../data/student_exam_repository.dart';

class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key});

  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  late final Future<List<Map<String, Object?>>> _exams = _loadExams();

  Future<List<Map<String, Object?>>> _loadExams() async {
    final profile = await StudentRepository().getStudentProfile();
    if (profile == null) return [];
    final db = await AppDatabase.instance.database;
    return StudentExamRepository(db).getPublishedExams(
      gradeId: profile.gradeId,
      trackId: profile.trackId,
    );
  }

  Future<void> _start(Map<String, Object?> exam) async {
    final db = await AppDatabase.instance.database;
    final repository = StudentExamRepository(db);
    final attemptId = await repository.startAttempt(exam['id'] as int);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ExamAttemptPage(
        repository: repository,
        attemptId: attemptId,
        title: exam['title_ar'] as String,
      ),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الامتحانات وبنك الأسئلة')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _exams,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل الامتحانات حالياً.'));
          }
          final exams = snapshot.data ?? const [];
          if (exams.isEmpty) {
            return const _EmptyExamsState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: exams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final exam = exams[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE7F3EC),
                    child: Icon(Icons.quiz_outlined, color: AppColors.emerald),
                  ),
                  title: Text(exam['title_ar'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${exam['subject_name']} • ${exam['question_count']} سؤال'
                    '${exam['duration_minutes'] == null ? '' : ' • ${exam['duration_minutes']} دقيقة'}',
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => _start(exam),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyExamsState extends StatelessWidget {
  const _EmptyExamsState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.assignment_outlined, size: 52, color: AppColors.emerald),
          const SizedBox(height: 14),
          const Text('لا توجد امتحانات منشورة حالياً',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('ستظهر الامتحانات وبنوك الأسئلة هنا بعد استيراد المحتوى ومراجعته واعتماده.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.5)),
        ],
      ),
    ),
  );
}

class ExamAttemptPage extends StatefulWidget {
  const ExamAttemptPage({
    super.key,
    required this.repository,
    required this.attemptId,
    required this.title,
  });

  final StudentExamRepository repository;
  final int attemptId;
  final String title;

  @override
  State<ExamAttemptPage> createState() => _ExamAttemptPageState();
}

class _ExamAttemptPageState extends State<ExamAttemptPage> {
  late final Future<List<Map<String, Object?>>> _questions =
      widget.repository.getAttemptQuestions(widget.attemptId);
  final Map<int, Object> _answers = {};
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await widget.repository.submitAttempt(widget.attemptId);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => ExamResultPage(result: result),
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تسليم الامتحان. حاول مرة أخرى.')),
        );
      }
    }
  }

  Future<void> _choose(int questionId, Object value) async {
    await widget.repository.saveAnswer(
      attemptId: widget.attemptId,
      questionId: questionId,
      answer: value,
    );
    if (mounted) setState(() => _answers[questionId] = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _questions,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) return const Center(child: Text('تعذر فتح الامتحان.'));
            return const Center(child: CircularProgressIndicator());
          }
          final questions = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${_answers.length} من ${questions.length} تمت الإجابة عنها',
                style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              for (var i = 0; i < questions.length; i++)
                _QuestionCard(
                  number: i + 1,
                  question: questions[i],
                  selected: _answers[questions[i]['id'] as int],
                  onChoose: (value) => _choose(questions[i]['id'] as int, value),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'جارٍ التسليم...' : 'تسليم الامتحان'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.selected,
    required this.onChoose,
  });

  final int number;
  final Map<String, Object?> question;
  final Object? selected;
  final ValueChanged<Object> onChoose;

  @override
  Widget build(BuildContext context) {
    final raw = question['options_json'] as String?;
    final decoded = raw == null ? null : jsonDecode(raw);
    final options = decoded is List
        ? decoded
        : question['question_type'] == 'true_false'
            ? const [
                {'value': true, 'label': 'صح'},
                {'value': false, 'label': 'خطأ'},
              ]
            : const [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('السؤال $number', style: const TextStyle(
              color: AppColors.emerald, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(question['prompt_ar'] as String,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (question['question_type'] == 'short_answer')
              TextFormField(
                initialValue: selected?.toString(),
                decoration: const InputDecoration(
                  hintText: 'اكتب إجابتك هنا',
                  border: OutlineInputBorder(),
                ),
                onChanged: onChoose,
              )
            else
              for (final option in options)
                RadioListTile<Object>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: option is Map ? option['value'] as Object : option as Object,
                  groupValue: selected,
                  onChanged: (value) {
                    if (value != null) onChoose(value);
                  },
                  title: Text(option is Map
                    ? option['label'].toString()
                    : option.toString()),
                ),
          ],
        ),
      ),
    );
  }
}

class ExamResultPage extends StatelessWidget {
  const ExamResultPage({super.key, required this.result});

  final Map<String, Object?> result;

  @override
  Widget build(BuildContext context) {
    final score = (result['score'] as num).toDouble();
    final total = (result['total_marks'] as num).toDouble();
    final graded = result['graded_questions'] as int;
    final count = result['total_questions'] as int;
    return Scaffold(
      appBar: AppBar(title: const Text('نتيجة الامتحان')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.gold),
              const SizedBox(height: 16),
              const Text('تم تسليم الامتحان بنجاح',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('$score / $total',
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
                  color: AppColors.emerald)),
              const SizedBox(height: 8),
              Text('تم تصحيح $graded من $count سؤال آلياً. الأسئلة التي لا تملك مفتاح إجابة معتمداً لم تدخل في الدرجة.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('العودة إلى الامتحانات'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
