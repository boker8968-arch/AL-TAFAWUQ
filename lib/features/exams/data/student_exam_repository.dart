import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Offline exam workflow. Student queries are always scoped to approved
/// packages and verified curriculum mappings.
class StudentExamRepository {
  StudentExamRepository(this._db);

  final Database _db;

  Future<List<Map<String, Object?>>> getPublishedExams({
    required int gradeId,
    int? trackId,
    int? subjectId,
  }) async {
    final clauses = <String>[
      "cp.review_status = 'approved'",
      's.grade_id = ?',
      '''EXISTS (
        SELECT 1 FROM curriculum_units u
        JOIN curriculum_release_subjects rs ON rs.id = u.release_subject_id
        JOIN curriculum_releases r ON r.id = rs.release_id
        WHERE u.package_id = cp.id AND rs.subject_id = s.id
          AND rs.verification_status = 'verified'
          AND r.verification_status = 'verified'
      )''',
    ];
    final args = <Object?>[gradeId];
    if (trackId == null) {
      clauses.add('s.track_id IS NULL');
    } else {
      clauses.add('(s.track_id IS NULL OR s.track_id = ?)');
      args.add(trackId);
    }
    if (subjectId != null) {
      clauses.add('s.id = ?');
      args.add(subjectId);
    }
    return _db.rawQuery('''
      SELECT e.id, e.title_ar, e.exam_type, e.duration_minutes,
        s.id AS subject_id, s.name_ar AS subject_name,
        COUNT(eq.question_id) AS question_count,
        COALESCE(SUM(eq.marks), 0) AS total_marks
      FROM exams e
      JOIN subjects s ON s.id = e.subject_id
      JOIN content_packages cp ON cp.id = e.package_id
      LEFT JOIN exam_questions eq ON eq.exam_id = e.id
      WHERE ${clauses.join(' AND ')}
      GROUP BY e.id
      HAVING COUNT(eq.question_id) > 0
      ORDER BY e.id DESC
    ''', args);
  }

  Future<int> startAttempt({
    required int examId,
    required int gradeId,
    int? trackId,
  }) async {
    final visible = await _db.rawQuery('''
      SELECT e.id FROM exams e
      JOIN content_packages cp ON cp.id = e.package_id
      JOIN subjects s ON s.id = e.subject_id
      JOIN curriculum_units u ON u.package_id = cp.id
      JOIN curriculum_release_subjects rs ON rs.id = u.release_subject_id
      JOIN curriculum_releases r ON r.id = rs.release_id
      WHERE e.id = ? AND cp.review_status = 'approved'
        AND s.grade_id = ?
        AND ((? IS NULL AND s.track_id IS NULL) OR
          (? IS NOT NULL AND (s.track_id IS NULL OR s.track_id = ?)))
        AND rs.subject_id = s.id
        AND rs.verification_status = 'verified'
        AND r.verification_status = 'verified'
      LIMIT 1
    ''', [examId, gradeId, trackId, trackId, trackId]);
    if (visible.isEmpty) throw StateError('This exam is not published.');
    return _db.insert('exam_attempts', {
      'exam_id': examId,
      'started_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getAttemptQuestions(int attemptId) async {
    final attempt = await _db.rawQuery('''
      SELECT a.id FROM exam_attempts a
      JOIN exams e ON e.id = a.exam_id
      JOIN content_packages cp ON cp.id = e.package_id
      WHERE a.id = ? AND a.completed_at IS NULL
        AND cp.review_status = 'approved'
    ''', [attemptId]);
    if (attempt.isEmpty) throw StateError('Attempt is unavailable or completed.');
    return _db.rawQuery('''
      SELECT q.id, q.question_type, q.prompt_ar, q.options_json,
        q.explanation_ar, eq.sort_order, eq.marks
      FROM exam_attempts a
      JOIN exam_questions eq ON eq.exam_id = a.exam_id
      JOIN questions q ON q.id = eq.question_id
      JOIN content_packages cp ON cp.id = q.package_id
      JOIN exams e ON e.id = a.exam_id
      WHERE a.id = ? AND cp.review_status = 'approved'
        AND q.package_id = e.package_id
      ORDER BY eq.sort_order, q.id
    ''', [attemptId]);
  }

  Future<void> saveAnswer({
    required int attemptId,
    required int questionId,
    required Object answer,
  }) async {
    final allowed = await _db.rawQuery('''
      SELECT q.id FROM exam_attempts a
      JOIN exam_questions eq ON eq.exam_id = a.exam_id
      JOIN questions q ON q.id = eq.question_id
      JOIN exams e ON e.id = a.exam_id
      JOIN content_packages cp ON cp.id = e.package_id
      WHERE a.id = ? AND q.id = ? AND a.completed_at IS NULL
        AND cp.review_status = 'approved'
        AND q.package_id = e.package_id
    ''', [attemptId, questionId]);
    if (allowed.isEmpty) throw StateError('Question is not part of this active exam.');
    await _db.insert('attempt_answers', {
      'attempt_id': attemptId,
      'question_id': questionId,
      'answer_json': jsonEncode(answer),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>> submitAttempt(int attemptId) async {
    return _db.transaction((txn) async {
      final attempts = await txn.rawQuery('''
        SELECT a.id, a.exam_id, a.started_at, a.completed_at,
          e.subject_id, cp.review_status
        FROM exam_attempts a
        JOIN exams e ON e.id = a.exam_id
        JOIN content_packages cp ON cp.id = e.package_id
        WHERE a.id = ? AND cp.review_status = 'approved'
      ''', [attemptId]);
      if (attempts.isEmpty || attempts.first['completed_at'] != null) {
        throw StateError('Attempt is unavailable or already submitted.');
      }
      final questions = await txn.rawQuery('''
        SELECT q.id, q.answer_json, q.answer_key_verified,
          q.question_type, eq.marks
        FROM exam_questions eq
        JOIN questions q ON q.id = eq.question_id
        WHERE eq.exam_id = ?
        ORDER BY eq.sort_order, q.id
      ''', [attempts.first['exam_id']]);
      var score = 0.0;
      var total = 0.0;
      var graded = 0;
      for (final q in questions) {
        final marks = (q['marks'] as num).toDouble();
        final canGrade = q['answer_key_verified'] == 1 &&
            q['answer_json'] != null &&
            const {'multiple_choice', 'true_false'}.contains(q['question_type']);
        if (!canGrade) continue;
        total += marks;
        graded++;
        final answerRows = await txn.query('attempt_answers',
          columns: ['answer_json'],
          where: 'attempt_id = ? AND question_id = ?',
          whereArgs: [attemptId, q['id']], limit: 1);
        if (answerRows.isEmpty) continue;
        final submitted = jsonDecode(answerRows.first['answer_json'] as String);
        final expected = jsonDecode(q['answer_json'] as String);
        final correct = jsonEncode(submitted) == jsonEncode(expected);
        final awarded = correct ? marks : 0.0;
        score += awarded;
        await txn.update('attempt_answers', {
          'is_correct': correct ? 1 : 0,
          'awarded_marks': awarded,
        }, where: 'attempt_id = ? AND question_id = ?',
          whereArgs: [attemptId, q['id']]);
      }
      final now = DateTime.now().toUtc();
      await txn.update('exam_attempts', {
        'completed_at': now.toIso8601String(),
        'score': score,
        'total_marks': total,
      }, where: 'id = ?', whereArgs: [attemptId]);
      await txn.insert('study_sessions', {
        'subject_id': attempts.first['subject_id'],
        'session_type': 'exam',
        'started_at': attempts.first['started_at'],
        'ended_at': now.toIso8601String(),
        'duration_seconds': now.difference(DateTime.parse(
          attempts.first['started_at'] as String)).inSeconds,
        'completed_items': questions.length,
      });
      return {
        'attempt_id': attemptId,
        'score': score,
        'total_marks': total,
        'graded_questions': graded,
        'total_questions': questions.length,
      };
    });
  }

  Future<List<Map<String, Object?>>> getAttemptHistory(int examId) {
    return _db.rawQuery('''
      SELECT a.id, a.exam_id, a.started_at, a.completed_at, a.score, a.total_marks
      FROM exam_attempts a
      JOIN exams e ON e.id = a.exam_id
      JOIN content_packages cp ON cp.id = e.package_id
      WHERE a.exam_id = ? AND a.completed_at IS NOT NULL
        AND cp.review_status = 'approved'
      ORDER BY a.completed_at DESC
    ''', [examId]);
  }
}
