import 'package:al_tafawuq/features/student/data/student_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Student curriculum models', () {
    test('maps a grade row from SQLite', () {
      final grade = Grade.fromMap({
        'id': 3,
        'code': 'secondary_3',
        'name_ar': 'الصف الثالث الثانوي',
        'sort_order': 3,
      });

      expect(grade.id, 3);
      expect(grade.code, 'secondary_3');
      expect(grade.name, 'الصف الثالث الثانوي');
    });

    test('maps a study track row from SQLite', () {
      final track = StudyTrack.fromMap({
        'id': 8,
        'grade_id': 3,
        'code': 'track_example',
        'name_ar': 'مسار تجريبي',
      });

      expect(track.id, 8);
      expect(track.gradeId, 3);
      expect(track.name, 'مسار تجريبي');
    });

    test('maps a saved student profile with an optional track', () {
      final profile = StudentProfile.fromMap({
        'display_name': 'طالب',
        'grade_id': 2,
        'track_id': null,
      });

      expect(profile.displayName, 'طالب');
      expect(profile.gradeId, 2);
      expect(profile.trackId, isNull);
    });
  });
}
