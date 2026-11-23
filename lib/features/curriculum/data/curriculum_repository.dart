import 'package:sqflite/sqflite.dart';

import 'curriculum_models.dart';

/// Local data access for curriculum releases and their subject mappings.
///
/// A curriculum item is visible to students only when both the release and
/// its subject mapping have been verified. No curriculum is seeded here.
class CurriculumRepository {
  CurriculumRepository(this._database);

  final Database _database;

  static const pending = 'pending';
  static const verified = 'verified';
  static const rejected = 'rejected';

  static const mandatory = 'mandatory';
  static const elective = 'elective';
  static const unclassified = 'unclassified';

  Future<int> createRelease({
    required int gradeId,
    int? trackId,
    required String academicYear,
    required String editionCode,
    required String editionLabel,
    String? issuingAuthority,
    String? sourceTitle,
    String? sourceUrl,
    String? publishedAt,
    String? notes,
    String verificationStatus = pending,
  }) async {
    _validateVerificationStatus(verificationStatus);
    _requireText(academicYear, 'academicYear');
    _requireText(editionCode, 'editionCode');
    _requireText(editionLabel, 'editionLabel');

    final now = DateTime.now().toUtc().toIso8601String();
    return _database.insert('curriculum_releases', {
      'grade_id': gradeId,
      'track_id': trackId,
      'academic_year': academicYear.trim(),
      'edition_code': editionCode.trim(),
      'edition_label': editionLabel.trim(),
      'issuing_authority': _cleanOptional(issuingAuthority),
      'source_title': _cleanOptional(sourceTitle),
      'source_url': _cleanOptional(sourceUrl),
      'published_at': publishedAt,
      'verification_status': verificationStatus,
      'notes': _cleanOptional(notes),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<CurriculumRelease?> getRelease(int releaseId) async {
    final rows = await _database.query(
      'curriculum_releases',
      where: 'id = ?',
      whereArgs: [releaseId],
      limit: 1,
    );
    return rows.isEmpty ? null : CurriculumRelease.fromMap(rows.first);
  }

  /// Returns all releases for editorial/admin workflows.
  Future<List<CurriculumRelease>> getReleases({
    int? gradeId,
    int? trackId,
    bool includeGradeWide = true,
    String? verificationStatus,
  }) async {
    if (verificationStatus != null) {
      _validateVerificationStatus(verificationStatus);
    }

    final clauses = <String>[];
    final args = <Object?>[];
    if (gradeId != null) {
      clauses.add('grade_id = ?');
      args.add(gradeId);
    }
    if (trackId != null) {
      clauses.add(includeGradeWide ? '(track_id = ? OR track_id IS NULL)' : 'track_id = ?');
      args.add(trackId);
    }
    if (verificationStatus != null) {
      clauses.add('verification_status = ?');
      args.add(verificationStatus);
    }

    final rows = await _database.query(
      'curriculum_releases',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'academic_year DESC, id DESC',
    );
    return rows.map(CurriculumRelease.fromMap).toList(growable: false);
  }

  /// Student-facing list: only verified releases are returned.
  Future<List<CurriculumRelease>> getPublishedReleases({
    required int gradeId,
    int? trackId,
  }) {
    return getReleases(
      gradeId: gradeId,
      trackId: trackId,
      verificationStatus: verified,
    );
  }

  Future<int> updateReleaseVerification({
    required int releaseId,
    required String verificationStatus,
    String? notes,
  }) async {
    _validateVerificationStatus(verificationStatus);
    return _database.update(
      'curriculum_releases',
      {
        'verification_status': verificationStatus,
        if (notes != null) 'notes': _cleanOptional(notes),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [releaseId],
    );
  }

  Future<int> addSubjectToRelease({
    required int releaseId,
    required int subjectId,
    String requirementType = unclassified,
    String? selectionGroup,
    int sortOrder = 0,
    String verificationStatus = pending,
    String? sourceReference,
    String? notes,
  }) async {
    _validateRequirementType(requirementType);
    _validateVerificationStatus(verificationStatus);

    // SQLite trigger independently enforces grade/track compatibility.
    return _database.insert('curriculum_release_subjects', {
      'release_id': releaseId,
      'subject_id': subjectId,
      'requirement_type': requirementType,
      'selection_group': _cleanOptional(selectionGroup),
      'sort_order': sortOrder,
      'verification_status': verificationStatus,
      'source_reference': _cleanOptional(sourceReference),
      'notes': _cleanOptional(notes),
    });
  }

  Future<List<CurriculumReleaseSubject>> getReleaseSubjects(
    int releaseId, {
    bool verifiedOnly = false,
  }) async {
    final rows = await _database.query(
      'curriculum_release_subjects',
      where: verifiedOnly
          ? 'release_id = ? AND verification_status = ?'
          : 'release_id = ?',
      whereArgs: verifiedOnly ? [releaseId, verified] : [releaseId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(CurriculumReleaseSubject.fromMap).toList(growable: false);
  }

  /// Student-facing subjects; both the release and mapping must be verified.
  /// Inactive subjects are excluded. A track-specific release can coexist
  /// with a grade-wide release when the caller's track is supplied.
  Future<List<Map<String, Object?>>> getPublishedSubjects({
    required int gradeId,
    int? trackId,
    String? academicYear,
  }) async {
    final clauses = <String>[
      'r.grade_id = ?',
      'r.verification_status = ?',
      'rs.verification_status = ?',
      's.is_active = 1',
    ];
    final args = <Object?>[gradeId, verified, verified];

    if (trackId != null) {
      clauses.add('(r.track_id = ? OR r.track_id IS NULL)');
      args.add(trackId);
      clauses.add('(s.track_id = ? OR s.track_id IS NULL)');
      args.add(trackId);
    } else {
      clauses.add('r.track_id IS NULL');
      clauses.add('s.track_id IS NULL');
    }

    if (academicYear != null) {
      clauses.add('r.academic_year = ?');
      args.add(academicYear);
    }

    return _database.rawQuery('''
      SELECT
        rs.id AS release_subject_id,
        rs.release_id,
        rs.subject_id,
        rs.requirement_type,
        rs.selection_group,
        rs.sort_order,
        rs.source_reference,
        s.code AS subject_code,
        s.name_ar AS subject_name_ar,
        s.grade_id,
        s.track_id,
        r.academic_year,
        r.edition_code,
        r.edition_label
      FROM curriculum_release_subjects rs
      JOIN curriculum_releases r ON r.id = rs.release_id
      JOIN subjects s ON s.id = rs.subject_id
      WHERE ${clauses.join(' AND ')}
      ORDER BY rs.sort_order ASC, s.sort_order ASC, s.name_ar ASC
    ''', args);
  }

  Future<int> updateReleaseSubjectVerification({
    required int releaseSubjectId,
    required String verificationStatus,
    String? sourceReference,
    String? notes,
  }) async {
    _validateVerificationStatus(verificationStatus);
    return _database.update(
      'curriculum_release_subjects',
      {
        'verification_status': verificationStatus,
        if (sourceReference != null)
          'source_reference': _cleanOptional(sourceReference),
        if (notes != null) 'notes': _cleanOptional(notes),
      },
      where: 'id = ?',
      whereArgs: [releaseSubjectId],
    );
  }

  Future<int> linkUnitToReleaseSubject({
    required int unitId,
    required int releaseSubjectId,
  }) async {
    final rows = await _database.rawQuery('''
      SELECT 1
      FROM curriculum_units u
      JOIN subjects s ON s.id = u.subject_id
      JOIN curriculum_release_subjects rs ON rs.id = ?
      JOIN curriculum_releases r ON r.id = rs.release_id
      WHERE u.id = ?
        AND s.id = rs.subject_id
        AND s.grade_id = r.grade_id
        AND (r.track_id IS NULL OR s.track_id IS NULL OR r.track_id = s.track_id)
      LIMIT 1
    ''', [releaseSubjectId, unitId]);

    if (rows.isEmpty) {
      throw ArgumentError(
        'The unit and curriculum release subject do not belong to the same subject and compatible grade/track.',
      );
    }

    return _database.update(
      'curriculum_units',
      {'release_subject_id': releaseSubjectId},
      where: 'id = ?',
      whereArgs: [unitId],
    );
  }

  static void _validateVerificationStatus(String value) {
    if (![pending, verified, rejected].contains(value)) {
      throw ArgumentError.value(value, 'verificationStatus');
    }
  }

  static void _validateRequirementType(String value) {
    if (![mandatory, elective, unclassified].contains(value)) {
      throw ArgumentError.value(value, 'requirementType');
    }
  }

  static void _requireText(String value, String field) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, field, 'Must not be empty.');
    }
  }

  static String? _cleanOptional(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
