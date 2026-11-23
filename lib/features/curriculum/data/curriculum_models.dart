class CurriculumRelease {
  const CurriculumRelease({
    required this.id,
    required this.gradeId,
    this.trackId,
    required this.academicYear,
    required this.editionCode,
    required this.editionLabel,
    this.issuingAuthority,
    this.sourceTitle,
    this.sourceUrl,
    this.publishedAt,
    required this.verificationStatus,
  });

  final int id;
  final int gradeId;
  final int? trackId;
  final String academicYear;
  final String editionCode;
  final String editionLabel;
  final String? issuingAuthority;
  final String? sourceTitle;
  final String? sourceUrl;
  final String? publishedAt;
  final String verificationStatus;

  factory CurriculumRelease.fromMap(Map<String, Object?> map) {
    return CurriculumRelease(
      id: map['id'] as int,
      gradeId: map['grade_id'] as int,
      trackId: map['track_id'] as int?,
      academicYear: map['academic_year'] as String,
      editionCode: map['edition_code'] as String,
      editionLabel: map['edition_label'] as String,
      issuingAuthority: map['issuing_authority'] as String?,
      sourceTitle: map['source_title'] as String?,
      sourceUrl: map['source_url'] as String?,
      publishedAt: map['published_at'] as String?,
      verificationStatus: map['verification_status'] as String,
    );
  }
}

class CurriculumReleaseSubject {
  const CurriculumReleaseSubject({
    required this.id,
    required this.releaseId,
    required this.subjectId,
    required this.requirementType,
    this.selectionGroup,
    required this.sortOrder,
    required this.verificationStatus,
    this.sourceReference,
  });

  final int id;
  final int releaseId;
  final int subjectId;
  final String requirementType;
  final String? selectionGroup;
  final int sortOrder;
  final String verificationStatus;
  final String? sourceReference;

  factory CurriculumReleaseSubject.fromMap(Map<String, Object?> map) {
    return CurriculumReleaseSubject(
      id: map['id'] as int,
      releaseId: map['release_id'] as int,
      subjectId: map['subject_id'] as int,
      requirementType: map['requirement_type'] as String,
      selectionGroup: map['selection_group'] as String?,
      sortOrder: map['sort_order'] as int,
      verificationStatus: map['verification_status'] as String,
      sourceReference: map['source_reference'] as String?,
    );
  }
}
