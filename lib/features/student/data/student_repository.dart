import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import 'student_models.dart';

class StudentRepository {
  StudentRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Grade>> getGrades() async {
    final db = await _database.database;
    final rows = await db.query(
      'grades',
      columns: ['id', 'code', 'name_ar', 'sort_order'],
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'sort_order ASC',
    );
    return rows.map(Grade.fromMap).toList(growable: false);
  }

  Future<List<StudyTrack>> getTracksForGrade(int gradeId) async {
    final db = await _database.database;
    final rows = await db.query(
      'study_tracks',
      columns: ['id', 'grade_id', 'code', 'name_ar'],
      where: 'grade_id = ? AND is_active = ?',
      whereArgs: [gradeId, 1],
      orderBy: 'name_ar COLLATE NOCASE ASC',
    );
    return rows.map(StudyTrack.fromMap).toList(growable: false);
  }

  Future<StudentProfile?> getStudentProfile() async {
    final db = await _database.database;
    final rows = await db.query(
      'student_profiles',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StudentProfile.fromMap(rows.first);
  }

  Future<void> saveStudentProfile(StudentProfile profile) async {
    final db = await _database.database;

    if (profile.trackId != null) {
      final tracks = await db.query(
        'study_tracks',
        columns: ['id'],
        where: 'id = ? AND grade_id = ? AND is_active = ?',
        whereArgs: [profile.trackId, profile.gradeId, 1],
        limit: 1,
      );
      if (tracks.isEmpty) {
        throw ArgumentError('The selected track does not belong to this grade.');
      }
    }

    await db.insert(
      'student_profiles',
      {
        'id': 1,
        'display_name': _normalizeName(profile.displayName),
        'grade_id': profile.gradeId,
        'track_id': profile.trackId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String? _normalizeName(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
