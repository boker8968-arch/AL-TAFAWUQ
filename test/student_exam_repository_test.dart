import 'package:al_tafawuq/features/exams/data/student_exam_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late StudentExamRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE subjects (id INTEGER PRIMARY KEY, grade_id INTEGER, track_id INTEGER, name_ar TEXT)');
    await db.execute('CREATE TABLE content_packages (id INTEGER PRIMARY KEY, review_status TEXT)');
    await db.execute('CREATE TABLE curriculum_releases (id INTEGER PRIMARY KEY, verification_status TEXT)');
    await db.execute('CREATE TABLE curriculum_release_subjects (id INTEGER PRIMARY KEY, release_id INTEGER, subject_id INTEGER, verification_status TEXT)');
    await db.execute('CREATE TABLE curriculum_units (id INTEGER PRIMARY KEY, package_id INTEGER, release_subject_id INTEGER)');
    await db.execute('CREATE TABLE exams (id INTEGER PRIMARY KEY, subject_id INTEGER, package_id INTEGER, title_ar TEXT, exam_type TEXT, duration_minutes INTEGER)');
    await db.execute('CREATE TABLE questions (id INTEGER PRIMARY KEY, package_id INTEGER, question_type TEXT, prompt_ar TEXT, options_json TEXT, answer_json TEXT, explanation_ar TEXT, answer_key_verified INTEGER)');
    await db.execute('CREATE TABLE exam_questions (exam_id INTEGER, question_id INTEGER, sort_order INTEGER, marks REAL)');
    await db.execute('CREATE TABLE exam_attempts (id INTEGER PRIMARY KEY AUTOINCREMENT, exam_id INTEGER, started_at TEXT, completed_at TEXT, score REAL, total_marks REAL)');
    await db.execute('CREATE TABLE attempt_answers (id INTEGER PRIMARY KEY AUTOINCREMENT, attempt_id INTEGER, question_id INTEGER, answer_json TEXT, is_correct INTEGER, awarded_marks REAL, UNIQUE(attempt_id, question_id))');
    await db.execute('CREATE TABLE study_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, subject_id INTEGER, session_type TEXT, started_at TEXT, ended_at TEXT, duration_seconds INTEGER, completed_items INTEGER)');
    await db.insert('subjects', {'id': 1, 'grade_id': 3, 'track_id': null, 'name_ar': 'مادة تجريبية'});
    await db.insert('content_packages', {'id': 1, 'review_status': 'approved'});
    await db.insert('curriculum_releases', {'id': 1, 'verification_status': 'verified'});
    await db.insert('curriculum_release_subjects', {'id': 1, 'release_id': 1, 'subject_id': 1, 'verification_status': 'verified'});
    await db.insert('curriculum_units', {'id': 1, 'package_id': 1, 'release_subject_id': 1});
    await db.insert('exams', {'id': 1, 'subject_id': 1, 'package_id': 1, 'title_ar': 'اختبار', 'exam_type': 'practice', 'duration_minutes': 10});
    await db.insert('questions', {
      'id': 1, 'package_id': 1, 'question_type': 'multiple_choice',
      'prompt_ar': 'اختر', 'options_json': '["a","b"]',
      'answer_json': '"b"', 'answer_key_verified': 1,
    });
    await db.insert('exam_questions', {'exam_id': 1, 'question_id': 1, 'sort_order': 0, 'marks': 2});
    repository = StudentExamRepository(db);
  });

  tearDown(() => db.close());

  test('hides unpublished exams and exposes no answer key during an attempt', () async {
    expect(await repository.getPublishedExams(gradeId: 3), hasLength(1));
    final attemptId = await repository.startAttempt(examId: 1, gradeId: 3);
    final questions = await repository.getAttemptQuestions(attemptId);
    expect(questions.single.containsKey('answer_json'), isFalse);
    await repository.saveAnswer(attemptId: attemptId, questionId: 1, answer: 'b');
    final result = await repository.submitAttempt(attemptId);
    expect(result['score'], 2.0);
    expect(result['graded_questions'], 1);
    expect((await db.query('attempt_answers')).single['is_correct'], 1);
  });

  test('does not allow an exam from another grade', () async {
    await expectLater(
      repository.startAttempt(examId: 1, gradeId: 2),
      throwsA(isA<StateError>()),
    );
  });

  test('does not list exams from pending packages', () async {
    await db.update('content_packages', {'review_status': 'pending_review'});
    expect(await repository.getPublishedExams(gradeId: 3), isEmpty);
    await expectLater(
      repository.startAttempt(examId: 1, gradeId: 3),
      throwsA(isA<StateError>()),
    );
  });
}
