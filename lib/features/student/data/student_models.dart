class Grade {
  const Grade({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
  });

  final int id;
  final String code;
  final String name;
  final int sortOrder;

  factory Grade.fromMap(Map<String, Object?> map) {
    return Grade(
      id: map['id'] as int,
      code: map['code'] as String,
      name: map['name_ar'] as String,
      sortOrder: map['sort_order'] as int,
    );
  }
}

class StudyTrack {
  const StudyTrack({
    required this.id,
    required this.gradeId,
    required this.code,
    required this.name,
  });

  final int id;
  final int gradeId;
  final String code;
  final String name;

  factory StudyTrack.fromMap(Map<String, Object?> map) {
    return StudyTrack(
      id: map['id'] as int,
      gradeId: map['grade_id'] as int,
      code: map['code'] as String,
      name: map['name_ar'] as String,
    );
  }
}

class StudentProfile {
  const StudentProfile({
    this.displayName,
    required this.gradeId,
    this.trackId,
  });

  final String? displayName;
  final int gradeId;
  final int? trackId;

  factory StudentProfile.fromMap(Map<String, Object?> map) {
    return StudentProfile(
      displayName: map['display_name'] as String?,
      gradeId: map['grade_id'] as int,
      trackId: map['track_id'] as int?,
    );
  }
}
