import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const databaseName = 'al_tafawuq.db';
  static const databaseVersion = 6;

  Database? _instance;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_instance != null) return _instance!;
    _opening ??= _open();
    _instance = await _opening!;
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

  // sqflite runs onCreate inside its own transaction, so use db directly here.
  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE grades (
        id INTEGER PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        name_ar TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
      CREATE TABLE curriculum_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        title_ar TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        source_label TEXT NOT NULL DEFAULT 'official',
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_type TEXT NOT NULL,
        item_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (item_type, item_id)
      )
    ''');

    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
      CREATE TABLE content_packages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_code TEXT NOT NULL UNIQUE,
        version TEXT NOT NULL,
        manifest_path TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        checksum TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_tracks_grade ON study_tracks(grade_id, is_active)',
    );
    await db.execute(
      'CREATE INDEX idx_subjects_grade ON subjects(grade_id, track_id)',
    );
    await db.execute(
      'CREATE INDEX idx_units_subject ON curriculum_units(subject_id)',
    );
    await db.execute(
      'CREATE INDEX idx_lessons_unit ON lessons(unit_id)',
    );
    await db.execute(
      'CREATE INDEX idx_questions_subject ON questions(subject_id)',
    );

    final batch = db.batch();
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
    await _migrateToV2(db);
    await _migrateToV3(db);
    await _migrateToV4(db);
    await _migrateToV5(db);
    await _migrateToV6(db);
  }

  Future<void> _migrateToV2(Database db) async {
    await db.execute('''
      CREATE TABLE curriculum_releases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_id INTEGER NOT NULL,
        track_id INTEGER,
        academic_year TEXT NOT NULL,
        edition_code TEXT NOT NULL,
        edition_label TEXT NOT NULL,
        issuing_authority TEXT,
        source_title TEXT,
        source_url TEXT,
        published_at TEXT,
        verification_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (verification_status IN ('pending', 'verified', 'rejected')),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (grade_id) REFERENCES grades(id) ON DELETE CASCADE,
        FOREIGN KEY (track_id) REFERENCES study_tracks(id) ON DELETE SET NULL,
        UNIQUE (grade_id, academic_year, edition_code)
      )
    ''');

    await db.execute('''
      CREATE TABLE curriculum_release_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        release_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        requirement_type TEXT NOT NULL DEFAULT 'unclassified'
          CHECK (requirement_type IN ('mandatory', 'elective', 'unclassified')),
        selection_group TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        verification_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (verification_status IN ('pending', 'verified', 'rejected')),
        source_reference TEXT,
        notes TEXT,
        FOREIGN KEY (release_id) REFERENCES curriculum_releases(id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        UNIQUE (release_id, subject_id)
      )
    ''');

    await db.execute('''
      ALTER TABLE curriculum_units
      ADD COLUMN release_subject_id INTEGER
      REFERENCES curriculum_release_subjects(id) ON DELETE SET NULL
    ''');

    await db.execute(
      'CREATE INDEX idx_curriculum_releases_grade_year '
      'ON curriculum_releases(grade_id, academic_year, verification_status)',
    );
    await db.execute(
      'CREATE INDEX idx_release_subjects_release '
      'ON curriculum_release_subjects(release_id, sort_order)',
    );
    await db.execute(
      'CREATE INDEX idx_release_subjects_subject '
      'ON curriculum_release_subjects(subject_id)',
    );
    await db.execute(
      'CREATE INDEX idx_units_release_subject '
      'ON curriculum_units(release_subject_id)',
    );

    // Enforce that a release only contains subjects belonging to its grade
    // and, when specified, compatible with its study track.
    await db.execute('''
      CREATE TRIGGER validate_release_subject_insert
      BEFORE INSERT ON curriculum_release_subjects
      BEGIN
        SELECT CASE WHEN NOT EXISTS (
          SELECT 1
          FROM curriculum_releases r
          JOIN subjects s ON s.id = NEW.subject_id
          WHERE r.id = NEW.release_id
            AND r.grade_id = s.grade_id
            AND (r.track_id IS NULL OR s.track_id IS NULL OR r.track_id = s.track_id)
        ) THEN RAISE(ABORT, 'Subject does not match curriculum release grade or track') END;
      END
    ''');
    await db.execute('''
      CREATE TRIGGER validate_release_subject_update
      BEFORE UPDATE OF release_id, subject_id ON curriculum_release_subjects
      BEGIN
        SELECT CASE WHEN NOT EXISTS (
          SELECT 1
          FROM curriculum_releases r
          JOIN subjects s ON s.id = NEW.subject_id
          WHERE r.id = NEW.release_id
            AND r.grade_id = s.grade_id
            AND (r.track_id IS NULL OR s.track_id IS NULL OR r.track_id = s.track_id)
        ) THEN RAISE(ABORT, 'Subject does not match curriculum release grade or track') END;
      END
    ''');
  }

  Future<void> _migrateToV3(Database db) async {
    // Package ownership and stable content codes make imports traceable and
    // prevent duplicate units/lessons while preserving all legacy rows.
    await db.execute('''
      ALTER TABLE curriculum_units
      ADD COLUMN package_id INTEGER
      REFERENCES content_packages(id) ON DELETE CASCADE
    ''');
    await db.execute('''
      ALTER TABLE curriculum_units ADD COLUMN content_code TEXT
    ''');
    await db.execute('''
      ALTER TABLE lessons ADD COLUMN content_code TEXT
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_units_package_code
      ON curriculum_units(package_id, content_code)
      WHERE package_id IS NOT NULL AND content_code IS NOT NULL
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_lessons_unit_code
      ON lessons(unit_id, content_code)
      WHERE content_code IS NOT NULL
    ''');
    await db.execute(
      'CREATE INDEX idx_units_package ON curriculum_units(package_id)',
    );
  }


  Future<void> _migrateToV4(Database db) async {
    // Imported packages remain private to the editorial workflow until a
    // review decision is recorded. Existing package rows are staged as pending.
    await db.execute('''
      ALTER TABLE content_packages
      ADD COLUMN source_label TEXT NOT NULL DEFAULT 'supplemental'
    ''');
    await db.execute('''
      ALTER TABLE content_packages
      ADD COLUMN review_status TEXT NOT NULL DEFAULT 'pending_review'
        CHECK (review_status IN ('pending_review', 'approved', 'rejected'))
    ''');
    await db.execute('ALTER TABLE content_packages ADD COLUMN reviewed_at TEXT');
    await db.execute('ALTER TABLE content_packages ADD COLUMN reviewer_label TEXT');
    await db.execute('ALTER TABLE content_packages ADD COLUMN review_notes TEXT');

    await db.execute('''
      CREATE TABLE content_package_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_id INTEGER NOT NULL,
        decision TEXT NOT NULL
          CHECK (decision IN ('approved', 'rejected')),
        reviewer_label TEXT NOT NULL,
        notes TEXT,
        reviewed_at TEXT NOT NULL,
        FOREIGN KEY (package_id) REFERENCES content_packages(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_content_packages_review_status '
      'ON content_packages(review_status, imported_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_content_package_reviews_package '
      'ON content_package_reviews(package_id, reviewed_at DESC)',
    );
  }


  Future<void> _migrateToV5(Database db) async {
    // Offline study activity is device-local and does not require an account.
    await db.execute('''
      CREATE TABLE study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER,
        lesson_id INTEGER,
        session_type TEXT NOT NULL
          CHECK (session_type IN ('lesson', 'exam', 'revision', 'flashcards')),
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_seconds INTEGER NOT NULL DEFAULT 0
          CHECK (duration_seconds >= 0),
        completed_items INTEGER NOT NULL DEFAULT 0
          CHECK (completed_items >= 0),
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE SET NULL,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_study_sessions_started '
      'ON study_sessions(started_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_study_sessions_subject '
      'ON study_sessions(subject_id, started_at DESC)',
    );
  }

  Future<void> _migrateToV6(Database db) async {
    // Legacy exam rows remain unlinked and are not student-visible.
    await db.execute('ALTER TABLE exams ADD COLUMN package_id INTEGER REFERENCES content_packages(id) ON DELETE CASCADE');
    await db.execute('ALTER TABLE exams ADD COLUMN content_code TEXT');
    await db.execute('ALTER TABLE questions ADD COLUMN package_id INTEGER REFERENCES content_packages(id) ON DELETE CASCADE');
    await db.execute('ALTER TABLE questions ADD COLUMN content_code TEXT');
    await db.execute("ALTER TABLE questions ADD COLUMN answer_key_verified INTEGER NOT NULL DEFAULT 0 CHECK (answer_key_verified IN (0, 1))");
    await db.execute('CREATE UNIQUE INDEX idx_exams_package_code ON exams(package_id, content_code) WHERE package_id IS NOT NULL AND content_code IS NOT NULL');
    await db.execute('CREATE UNIQUE INDEX idx_questions_package_code ON questions(package_id, content_code) WHERE package_id IS NOT NULL AND content_code IS NOT NULL');
    await db.execute('CREATE INDEX idx_exams_package ON exams(package_id)');
    await db.execute('CREATE INDEX idx_questions_package ON questions(package_id)');
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _migrateToV2(db);
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }
    if (oldVersion < 6) {
      await _migrateToV6(db);
    }
  }

  Future<void> close() async {
    await _instance?.close();
    _instance = null;
    _opening = null;
  }
}
