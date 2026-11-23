import 'package:al_tafawuq/features/learning/data/student_learning_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late StudentLearningRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createSchema(database);
    await _seed(database);
    repository = StudentLearningRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('student queries hide imported lessons until package approval', () async {
    expect(await repository.getApprovedUnits(gradeId: 3), isEmpty);
    expect(await repository.getApprovedLessons(unitId: 1), isEmpty);

    await database.update(
      'content_packages',
      {'review_status': 'approved'},
      where: 'id = ?',
      whereArgs: [1],
    );

    expect(await repository.getApprovedUnits(gradeId: 3), hasLength(1));
    expect(await repository.getApprovedLessons(unitId: 1), hasLength(1));
  });

  test('progress cannot be written for unpublished lessons', () async {
    await expectLater(
      repository.saveLessonProgress(lessonId: 1, progressPercent: 35),
      throwsA(isA<StateError>()),
    );
    expect(await database.query('study_progress'), isEmpty);
  });

  test('approved lessons accept local progress and report completion', () async {
    await database.update(
      'content_packages',
      {'review_status': 'approved'},
      where: 'id = ?',
      whereArgs: [1],
    );

    await repository.saveLessonProgress(lessonId: 1, progressPercent: 100);
    final summary = await repository.getProgressSummary(gradeId: 3);

    expect(summary['total_lessons'], 1);
    expect(summary['completed_lessons'], 1);
  });
}

Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE subjects (
      id INTEGER PRIMARY KEY,
      grade_id INTEGER NOT NULL,
      track_id INTEGER,
      code TEXT NOT NULL,
      name_ar TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE curriculum_releases (
      id INTEGER PRIMARY KEY,
      grade_id INTEGER NOT NULL,
      verification_status TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE curriculum_release_subjects (
      id INTEGER PRIMARY KEY,
      release_id INTEGER NOT NULL,
      verification_status TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE content_packages (
      id INTEGER PRIMARY KEY,
      package_code TEXT NOT NULL,
      version TEXT NOT NULL,
      review_status TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE curriculum_units (
      id INTEGER PRIMARY KEY,
      subject_id INTEGER NOT NULL,
      release_subject_id INTEGER NOT NULL,
      package_id INTEGER NOT NULL,
      content_code TEXT,
      title_ar TEXT NOT NULL,
      sort_order INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE lessons (
      id INTEGER PRIMARY KEY,
      unit_id INTEGER NOT NULL,
      title_ar TEXT NOT NULL,
      summary_ar TEXT,
      body_path TEXT,
      sort_order INTEGER NOT NULL,
      content_code TEXT,
      content_version TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE study_progress (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lesson_id INTEGER NOT NULL UNIQUE,
      status TEXT NOT NULL,
      progress_percent REAL NOT NULL,
      last_opened_at TEXT,
      completed_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE study_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_id INTEGER,
      lesson_id INTEGER,
      session_type TEXT NOT NULL,
      started_at TEXT NOT NULL,
      ended_at TEXT,
      duration_seconds INTEGER NOT NULL,
      completed_items INTEGER NOT NULL
    )
  ''');
}

Future<void> _seed(Database db) async {
  await db.insert('subjects', {
    'id': 1, 'grade_id': 3, 'track_id': null, 'code': 'subject-a',
    'name_ar': 'مادة تجريبية', 'sort_order': 1,
  });
  await db.insert('curriculum_releases', {
    'id': 1, 'grade_id': 3, 'verification_status': 'verified',
  });
  await db.insert('curriculum_release_subjects', {
    'id': 1, 'release_id': 1, 'verification_status': 'verified',
  });
  await db.insert('content_packages', {
    'id': 1, 'package_code': 'package-a', 'version': '1.0.0',
    'review_status': 'pending_review',
  });
  await db.insert('curriculum_units', {
    'id': 1, 'subject_id': 1, 'release_subject_id': 1,
    'package_id': 1, 'content_code': 'unit-a', 'title_ar': 'الوحدة الأولى',
    'sort_order': 1,
  });
  await db.insert('lessons', {
    'id': 1, 'unit_id': 1, 'title_ar': 'الدرس الأول',
    'summary_ar': null, 'body_path': null, 'sort_order': 1,
    'content_code': 'lesson-a', 'content_version': '1.0.0',
  });
}
