import 'dart:convert';
import 'dart:io';

import 'package:al_tafawuq/features/content/data/content_package_importer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late Directory temporaryRoot;
  late Directory packagesDirectory;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createSchema(database);
    await _seedVerifiedCurriculum(database);
    temporaryRoot = await Directory.systemTemp.createTemp('al-tafawuq-import-test-');
    packagesDirectory = Directory(temporaryRoot.path + '/installed');
  });

  tearDown(() async {
    await database.close();
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  });

  test('imports verified package files and records atomically', () async {
    final packageDirectory = await _createPackage(temporaryRoot, content: 'درس تجريبي');
    final importer = ContentPackageImporter(database: database, packagesDirectory: packagesDirectory);

    final result = await importer.importDirectory(packageDirectory);

    expect(result.packageCode, 'biology-basics');
    expect(result.version, '1.0.0');
    expect(result.importedUnits, 1);
    expect(result.importedLessons, 1);
    expect(await database.query('content_packages'), hasLength(1));
    final units = await database.query('curriculum_units');
    final lessons = await database.query('lessons');
    expect(units, hasLength(1));
    expect(units.single['release_subject_id'], 1);
    expect(units.single['content_code'], 'unit-01');
    expect(lessons, hasLength(1));
    expect(lessons.single['content_code'], 'lesson-01');
    final bodyPath = lessons.single['body_path']! as String;
    expect(await File(bodyPath).readAsString(), 'درس تجريبي');
  });

  test('imports exam questions and links them to the package and lesson', () async {
    final packageDirectory = await _createPackage(
      temporaryRoot,
      content: 'درس تجريبي',
      exam: {
        'code': 'practice-01',
        'title': 'اختبار الوحدة الأولى',
        'duration_minutes': 15,
        'questions': [
          {
            'code': 'q-01',
            'type': 'multiple_choice',
            'prompt': 'اختر الإجابة الصحيحة',
            'lesson_code': 'lesson-01',
            'options': [
              {'value': 'a', 'label': 'أ'},
              {'value': 'b', 'label': 'ب'}
            ],
            'answer': 'b',
            'answer_key_verified': true,
            'marks': 2
          }
        ]
      },
    );
    final importer = ContentPackageImporter(database: database, packagesDirectory: packagesDirectory);
    await importer.importDirectory(packageDirectory);
    final exams = await database.query('exams');
    final questions = await database.query('questions');
    final links = await database.query('exam_questions');
    expect(exams, hasLength(1));
    expect(exams.single['package_id'], 1);
    expect(questions, hasLength(1));
    expect(questions.single['lesson_id'], 1);
    expect(questions.single['answer_key_verified'], 1);
    expect(links.single['marks'], 2);
  });

  test('rejects an asset with a mismatched SHA-256 without writing data', () async {
    final packageDirectory = await _createPackage(
      temporaryRoot,
      content: 'محتوى تغير',
      declaredHash: sha256.convert(utf8.encode('محتوى آخر')).toString(),
    );
    final importer = ContentPackageImporter(database: database, packagesDirectory: packagesDirectory);

    await expectLater(importer.importDirectory(packageDirectory), throwsA(isA<FormatException>()));
    expect(await database.query('content_packages'), isEmpty);
    expect(await database.query('curriculum_units'), isEmpty);
    expect(Directory(packagesDirectory.path + '/biology-basics/1.0.0').existsSync(), isFalse);
  });

  test('rejects packages without a verified curriculum mapping', () async {
    await database.update('curriculum_release_subjects', {'verification_status': 'pending'}, where: 'id = 1');
    final packageDirectory = await _createPackage(temporaryRoot, content: 'درس');
    final importer = ContentPackageImporter(database: database, packagesDirectory: packagesDirectory);

    await expectLater(importer.importDirectory(packageDirectory), throwsA(isA<StateError>()));
    expect(await database.query('content_packages'), isEmpty);
  });

  test('rejects an already installed package code without overwriting it', () async {
    final firstPackage = await _createPackage(temporaryRoot, content: 'النسخة الأولى');
    final importer = ContentPackageImporter(database: database, packagesDirectory: packagesDirectory);
    await importer.importDirectory(firstPackage);

    final secondRoot = Directory(temporaryRoot.path + '/second-source');
    await secondRoot.create();
    final secondPackage = await _createPackage(
      secondRoot,
      content: 'النسخة الثانية',
      packageCode: 'biology-basics',
      version: '2.0.0',
    );

    await expectLater(importer.importDirectory(secondPackage), throwsA(isA<StateError>()));
    expect(await database.query('content_packages'), hasLength(1));
    expect(
      await File(packagesDirectory.path + '/biology-basics/1.0.0/lessons/lesson-01.md').readAsString(),
      'النسخة الأولى',
    );
    expect(Directory(packagesDirectory.path + '/biology-basics/2.0.0').existsSync(), isFalse);
  });

  test('removes promoted files when the SQLite transaction fails', () async {
    await database.execute('''
      CREATE TRIGGER reject_lesson_insert
      BEFORE INSERT ON lessons
      BEGIN
        SELECT RAISE(ABORT, 'simulated lesson write failure');
      END
    ''');
    final packageDirectory = await _createPackage(temporaryRoot, content: 'درس');
    final importer = ContentPackageImporter(database: database, packagesDirectory: packagesDirectory);

    await expectLater(importer.importDirectory(packageDirectory), throwsA(isA<DatabaseException>()));
    expect(await database.query('content_packages'), isEmpty);
    expect(await database.query('curriculum_units'), isEmpty);
    expect(Directory(packagesDirectory.path + '/biology-basics/1.0.0').existsSync(), isFalse);
  });
}

Future<void> _createSchema(Database db) async {
  await db.execute('CREATE TABLE grades (id INTEGER PRIMARY KEY, code TEXT NOT NULL)');
  await db.execute('CREATE TABLE subjects (id INTEGER PRIMARY KEY, grade_id INTEGER NOT NULL, track_id INTEGER, code TEXT NOT NULL, is_active INTEGER NOT NULL)');
  await db.execute('CREATE TABLE curriculum_releases (id INTEGER PRIMARY KEY, grade_id INTEGER NOT NULL, track_id INTEGER, academic_year TEXT NOT NULL, edition_code TEXT NOT NULL, verification_status TEXT NOT NULL)');
  await db.execute('CREATE TABLE curriculum_release_subjects (id INTEGER PRIMARY KEY, release_id INTEGER NOT NULL, subject_id INTEGER NOT NULL, verification_status TEXT NOT NULL)');
  await db.execute('''
    CREATE TABLE exams (
      id INTEGER PRIMARY KEY AUTOINCREMENT, subject_id INTEGER NOT NULL,
      title_ar TEXT NOT NULL, exam_type TEXT NOT NULL DEFAULT 'practice',
      duration_minutes INTEGER, source_label TEXT NOT NULL DEFAULT 'supplemental',
      package_id INTEGER, content_code TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE questions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, subject_id INTEGER NOT NULL,
      lesson_id INTEGER, question_type TEXT NOT NULL, prompt_ar TEXT NOT NULL,
      options_json TEXT, answer_json TEXT, explanation_ar TEXT,
      difficulty INTEGER NOT NULL DEFAULT 1, source_label TEXT NOT NULL DEFAULT 'supplemental',
      package_id INTEGER, content_code TEXT, answer_key_verified INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE exam_questions (
      exam_id INTEGER NOT NULL, question_id INTEGER NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0, marks REAL NOT NULL DEFAULT 1
    )
  ''');
  await db.execute('''
    CREATE TABLE content_packages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      package_code TEXT NOT NULL UNIQUE,
      version TEXT NOT NULL,
      manifest_path TEXT NOT NULL,
      imported_at TEXT NOT NULL,
      checksum TEXT NOT NULL,
      source_label TEXT NOT NULL DEFAULT 'supplemental',
      review_status TEXT NOT NULL DEFAULT 'pending_review',
      reviewed_at TEXT,
      reviewer_label TEXT,
      review_notes TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE curriculum_units (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_id INTEGER NOT NULL,
      release_subject_id INTEGER,
      package_id INTEGER,
      content_code TEXT,
      title_ar TEXT NOT NULL,
      sort_order INTEGER NOT NULL,
      source_label TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE lessons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      unit_id INTEGER NOT NULL,
      content_code TEXT,
      title_ar TEXT NOT NULL,
      summary_ar TEXT,
      body_path TEXT,
      sort_order INTEGER NOT NULL,
      content_version TEXT
    )
  ''');
}

Future<void> _seedVerifiedCurriculum(Database db) async {
  await db.insert('grades', {'id': 1, 'code': 'secondary_3'});
  await db.insert('subjects', {'id': 1, 'grade_id': 1, 'track_id': null, 'code': 'biology', 'is_active': 1});
  await db.insert('curriculum_releases', {
    'id': 1, 'grade_id': 1, 'track_id': null, 'academic_year': '2026-2027',
    'edition_code': 'verified-edition', 'verification_status': 'verified',
  });
  await db.insert('curriculum_release_subjects', {
    'id': 1, 'release_id': 1, 'subject_id': 1, 'verification_status': 'verified',
  });
}

Future<Directory> _createPackage(
  Directory parent, {
  required String content,
  String packageCode = 'biology-basics',
  String version = '1.0.0',
  String? declaredHash,
  Map<String, dynamic>? exam,
}) async {
  final directory = Directory(parent.path + '/' + packageCode + '-' + version);
  await directory.create(recursive: true);
  final asset = File(directory.path + '/lessons/lesson-01.md');
  await asset.parent.create(recursive: true);
  await asset.writeAsString(content, encoding: utf8);
  final bytes = utf8.encode(content);
  final manifest = {
    'schema_version': 1,
    'package_code': packageCode,
    'version': version,
    'title': 'حزمة أحياء تجريبية',
    'grade_code': 'secondary_3',
    'subject_code': 'biology',
    'academic_year': '2026-2027',
    'edition_code': 'verified-edition',
    'source_label': 'supplemental',
    'units': [
      {
        'code': 'unit-01',
        'title': 'الوحدة الأولى',
        'sort_order': 1,
        'lessons': [
          {
            'code': 'lesson-01',
            'title': 'الدرس الأول',
            'summary': 'ملخص',
            'body_file': 'lessons/lesson-01.md',
            'sort_order': 1,
          }
        ],
      }
    ],
    'exams': exam == null ? [] : [exam],
    'assets': [
      {
        'path': 'lessons/lesson-01.md',
        'sha256': declaredHash ?? sha256.convert(bytes).toString(),
        'bytes': bytes.length,
        'media_type': 'text/markdown',
      }
    ],
  };
  await File(directory.path + '/manifest.json').writeAsString(jsonEncode(manifest), encoding: utf8);
  return directory;
}
