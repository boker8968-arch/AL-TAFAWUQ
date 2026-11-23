import 'package:al_tafawuq/features/curriculum/data/curriculum_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Curriculum release models', () {
    test('maps release metadata without requiring an official subject list', () {
      final release = CurriculumRelease.fromMap({
        'id': 4,
        'grade_id': 3,
        'track_id': null,
        'academic_year': '2026-2027',
        'edition_code': 'sudan-secondary-2025-guide',
        'edition_label': 'دليل امتحانات الشهادة السودانية 2025',
        'issuing_authority': 'المركز القومي للمناهج والبحث التربوي',
        'source_title': 'دليل امتحانات الشهادة الثانوية 2025م',
        'source_url': 'https://example.invalid/reference.pdf',
        'published_at': '2025-08-01',
        'verification_status': 'pending',
      });

      expect(release.gradeId, 3);
      expect(release.trackId, isNull);
      expect(release.academicYear, '2026-2027');
      expect(release.verificationStatus, 'pending');
    });

    test('maps a release subject and its verification state', () {
      final entry = CurriculumReleaseSubject.fromMap({
        'id': 9,
        'release_id': 4,
        'subject_id': 12,
        'requirement_type': 'unclassified',
        'selection_group': null,
        'sort_order': 0,
        'verification_status': 'pending',
        'source_reference': null,
      });

      expect(entry.subjectId, 12);
      expect(entry.requirementType, 'unclassified');
      expect(entry.verificationStatus, 'pending');
    });
  });
}
