import 'package:sqflite/sqflite.dart';

/// Student-facing read and progress API.
///
/// Every curriculum query is restricted to approved packages and verified
/// curriculum release mappings. This is the central publication boundary for
/// the offline student experience.
class StudentLearningRepository {
  StudentLearningRepository(this._database);

  final Database _database;

  Future<List<Map<String, Object?>>> getApprovedUnits({
    required int gradeId,
    int? trackId,
    int? subjectId,
  }) {
    final where = <String>[
      's.grade_id = ?',
      "cp.review_status = 'approved'",
      "r.verification_status = 'verified'",
      "rs.verification_status = 'verified'",
    ];
    final args = <Object?>[gradeId];
    if (trackId != null) {
      where.add('(s.track_id IS NULL OR s.track_id = ?)');
      args.add(trackId);
    } else {
      // Until a student selects a track, expose common subjects only.
      where.add('s.track_id IS NULL');
    }
    if (subjectId != null) {
      where.add('s.id = ?');
      args.add(subjectId);
    }
    return _database.rawQuery('''
      SELECT
        u.id,
        u.subject_id,
        u.title_ar,
        u.sort_order,
        u.content_code,
        s.code AS subject_code,
        s.name_ar AS subject_name,
        cp.package_code,
        cp.version AS package_version
      FROM curriculum_units u
      JOIN subjects s ON s.id = u.subject_id
      JOIN curriculum_release_subjects rs ON rs.id = u.release_subject_id
      JOIN curriculum_releases r ON r.id = rs.release_id
      JOIN content_packages cp ON cp.id = u.package_id
      WHERE ${where.join(' AND ')}
      ORDER BY s.sort_order, u.sort_order, u.id
    ''', args);
  }

  Future<List<Map<String, Object?>>> getApprovedLessons({
    required int unitId,
  }) {
    return _database.rawQuery('''
      SELECT
        l.id,
        l.unit_id,
        l.title_ar,
        l.summary_ar,
        l.body_path,
        l.sort_order,
        l.content_code,
        l.content_version
      FROM lessons l
      JOIN curriculum_units u ON u.id = l.unit_id
      JOIN content_packages cp ON cp.id = u.package_id
      JOIN curriculum_release_subjects rs ON rs.id = u.release_subject_id
      JOIN curriculum_releases r ON r.id = rs.release_id
      WHERE u.id = ?
        AND cp.review_status = 'approved'
        AND rs.verification_status = 'verified'
        AND r.verification_status = 'verified'
      ORDER BY l.sort_order, l.id
    ''', [unitId]);
  }

  Future<void> saveLessonProgress({
    required int lessonId,
    required double progressPercent,
  }) async {
    final bounded = progressPercent.clamp(0.0, 100.0).toDouble();
    final visible = await _database.rawQuery('''
      SELECT l.id
      FROM lessons l
      JOIN curriculum_units u ON u.id = l.unit_id
      JOIN content_packages cp ON cp.id = u.package_id
      JOIN curriculum_release_subjects rs ON rs.id = u.release_subject_id
      JOIN curriculum_releases r ON r.id = rs.release_id
      WHERE l.id = ?
        AND cp.review_status = 'approved'
        AND rs.verification_status = 'verified'
        AND r.verification_status = 'verified'
      LIMIT 1
    ''', [lessonId]);
    if (visible.isEmpty) {
      throw StateError('This lesson is not published for students.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final status = bounded >= 100
        ? 'completed'
        : bounded > 0
            ? 'in_progress'
            : 'not_started';
    await _database.insert(
      'study_progress',
      {
        'lesson_id': lessonId,
        'status': status,
        'progress_percent': bounded,
        'last_opened_at': now,
        'completed_at': bounded >= 100 ? now : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> recordStudySession({
    int? subjectId,
    int? lessonId,
    required String sessionType,
    required DateTime startedAt,
    required DateTime endedAt,
    int completedItems = 0,
  }) async {
    const allowed = {'lesson', 'exam', 'revision', 'flashcards'};
    if (!allowed.contains(sessionType)) {
      throw ArgumentError.value(sessionType, 'sessionType');
    }
    if (endedAt.isBefore(startedAt)) {
      throw ArgumentError('endedAt must not be earlier than startedAt.');
    }
    if (completedItems < 0) {
      throw ArgumentError.value(completedItems, 'completedItems');
    }
    if (lessonId != null) {
      final visible = await _database.rawQuery('''
        SELECT l.id
        FROM lessons l
        JOIN curriculum_units u ON u.id = l.unit_id
        JOIN content_packages cp ON cp.id = u.package_id
        JOIN curriculum_release_subjects rs ON rs.id = u.release_subject_id
        JOIN curriculum_releases r ON r.id = rs.release_id
        WHERE l.id = ?
          AND cp.review_status = 'approved'
          AND rs.verification_status = 'verified'
          AND r.verification_status = 'verified'
        LIMIT 1
      ''', [lessonId]);
      if (visible.isEmpty) {
        throw StateError('Study activity cannot reference an unpublished lesson.');
      }
    }
    await _database.insert('study_sessions', {
      'subject_id': subjectId,
      'lesson_id': lessonId,
      'session_type': sessionType,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'duration_seconds': endedAt.difference(startedAt).inSeconds,
      'completed_items': completedItems,
    });
  }

  Future<Map<String, Object?>> getProgressSummary({
    required int gradeId,
    int? trackId,
  }) async {
    final args = <Object?>[gradeId];
    var trackClause = ' AND s.track_id IS NULL';
    if (trackId != null) {
      trackClause = ' AND (s.track_id IS NULL OR s.track_id = ?)';
      args.add(trackId);
    }
    final rows = await _database.rawQuery('''
      SELECT
        COUNT(DISTINCT l.id) AS total_lessons,
        COUNT(DISTINCT CASE WHEN p.status = 'completed' THEN l.id END)
          AS completed_lessons,
        COALESCE(SUM(DISTINCT 0), 0) AS reserved_value
      FROM lessons l
      JOIN curriculum_units u ON u.id = l.unit_id
      JOIN subjects s ON s.id = u.subject_id
      JOIN content_packages cp ON cp.id = u.package_id
      JOIN curriculum_release_subjects rs ON rs.id = u.release_subject_id
      JOIN curriculum_releases r ON r.id = rs.release_id
      LEFT JOIN study_progress p ON p.lesson_id = l.id
      WHERE s.grade_id = ?
        AND cp.review_status = 'approved'
        AND rs.verification_status = 'verified'
        AND r.verification_status = 'verified'
        $trackClause
    ''', args);
    final result = Map<String, Object?>.from(rows.single);
    final sessions = await _database.rawQuery('''
      SELECT COALESCE(SUM(ss.duration_seconds), 0) AS study_seconds
      FROM study_sessions ss
      LEFT JOIN subjects s ON s.id = ss.subject_id
      WHERE s.grade_id = ? $trackClause
    ''', args);
    result['study_seconds'] = sessions.single['study_seconds'];
    result.remove('reserved_value');
    return result;
  }
}
