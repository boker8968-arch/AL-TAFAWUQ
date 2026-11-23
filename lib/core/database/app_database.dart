import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const databaseName = 'al_tafawuq.db';
  static const databaseVersion = 1;

  Database? _instance;

  Future<Database> get database async {
    _instance ??= await _open();
    return _instance!;
  }

  Future<Database> _open() async {
    final databaseDirectory = await getDatabasesPath();
    final databasePath = p.join(databaseDirectory, databaseName);

    return openDatabase(
      databasePath,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE grades (
          id INTEGER PRIMARY KEY,
          code TEXT NOT NULL UNIQUE,
          name_ar TEXT NOT NULL,
          sort_order INTEGER NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await txn.execute('''
        CREATE TABLE study_tracks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          grade_id INTEGER NOT NULL,
          code TEXT NOT NULL,
          name_ar TEXT NOT NULL,
          description_ar TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          UNIQUE (grade_id, code),
          FOREIGN KEY (grade_id) REFERENCES grades(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE subjects (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          grade_id INTEGER NOT NULL,
          track_id INTEGER,
          code TEXT NOT NULL,
          name_ar TEXT NOT NULL,
          description_ar TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (grade_id) REFERENCES grades(id) ON DELETE CASCADE,
          FOREIGN KEY (track_id) REFERENCES study_tracks(id) ON DELETE SET NULL,
          UNIQUE (grade_id, track_id, code)
        )
      ''');

      await txn.execute('''
        CREATE TABLE curriculum_units (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subject_id INTEGER NOT NULL,
          title_ar TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          source_label TEXT NOT NULL DEFAULT 'official',
          FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE lessons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          unit_id INTEGER NOT NULL,
          title_ar TEXT NOT NULL,
          summary_ar TEXT,
          body_path TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          content_version TEXT,
          FOREIGN KEY (unit_id) REFERENCES curriculum_units(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE exams (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subject_id INTEGER NOT NULL,
          title_ar TEXT NOT NULL,
          exam_type TEXT NOT NULL DEFAULT 'practice',
          duration_minutes INTEGER,
          source_label TEXT NOT NULL DEFAULT 'supplemental',
          FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE questions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subject_id INTEGER NOT NULL,
          lesson_id INTEGER,
          question_type TEXT NOT NULL,
          prompt_ar TEXT NOT NULL,
          options_json TEXT,
          answer_json TEXT,
          explanation_ar TEXT,
          difficulty INTEGER NOT NULL DEFAULT 1,
          source_label TEXT NOT NULL DEFAULT 'supplemental',
          FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
          FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE SET NULL
        )
      ''');

      await txn.execute('''
        CREATE TABLE exam_questions (
          exam_id INTEGER NOT NULL,
          question_id INTEGER NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          marks REAL NOT NULL DEFAULT 1,
          PRIMARY KEY (exam_id, question_id),
          FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE,
          FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE exam_attempts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          exam_id INTEGER NOT NULL,
          started_at TEXT NOT NULL,
          completed_at TEXT,
          score REAL,
          total_marks REAL,
          FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE attempt_answers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          attempt_id INTEGER NOT NULL,
          question_id INTEGER NOT NULL,
          answer_json TEXT,
          is_correct INTEGER,
          awarded_marks REAL,
          FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id) ON DELETE CASCADE,
          FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
          UNIQUE (attempt_id, question_id)
        )
      ''');

      await txn.execute('''
        CREATE TABLE bookmarks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_type TEXT NOT NULL,
          item_id INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          UNIQUE (item_type, item_id)
        )
      ''');

      await txn.execute('''
        CREATE TABLE study_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          lesson_id INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'not_started',
          progress_percent REAL NOT NULL DEFAULT 0,
          last_opened_at TEXT,
          completed_at TEXT,
          FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
          UNIQUE (lesson_id)
        )
      ''');

      await txn.execute('''
        CREATE TABLE student_profiles (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          display_name TEXT,
          grade_id INTEGER NOT NULL,
          track_id INTEGER,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (grade_id) REFERENCES grades(id),
          FOREIGN KEY (track_id) REFERENCES study_tracks(id)
        )
      ''');

      await txn.execute('''
        CREATE TABLE content_packages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          package_code TEXT NOT NULL UNIQUE,
          version TEXT NOT NULL,
          manifest_path TEXT NOT NULL,
          imported_at TEXT NOT NULL,
          checksum TEXT NOT NULL
        )
      ''');

      await txn.execute(
        'CREATE INDEX idx_tracks_grade ON study_tracks(grade_id, is_active)',
      );
      await txn.execute(
        'CREATE INDEX idx_subjects_grade ON subjects(grade_id, track_id)',
      );
      await txn.execute(
        'CREATE INDEX idx_units_subject ON curriculum_units(subject_id)',
      );
      await txn.execute(
        'CREATE INDEX idx_lessons_unit ON lessons(unit_id)',
      );
      await txn.execute(
        'CREATE INDEX idx_questions_subject ON questions(subject_id)',
      );

      final batch = txn.batch();
      batch.insert('grades', {
        'id': 1,
        'code': 'secondary_1',
        'name_ar': 'الصف الأول الثانوي',
        'sort_order': 1,
      });
      batch.insert('grades', {
        'id': 2,
        'code': 'secondary_2',
        'name_ar': 'الصف الثاني الثانوي',
        'sort_order': 2,
      });
      batch.insert('grades', {
        'id': 3,
        'code': 'secondary_3',
        'name_ar': 'الصف الثالث الثانوي',
        'sort_order': 3,
      });
      await batch.commit(noResult: true);
    });
  }

  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    // Add versioned migrations here before increasing databaseVersion.
  }

  Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
