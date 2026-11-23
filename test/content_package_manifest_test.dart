import 'package:al_tafawuq/features/content/data/content_package_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> validManifest() => {
        'schema_version': 1,
        'package_code': 'sudan-certificate-biology',
        'version': '1.0.0',
        'title': 'الأحياء - الشهادة السودانية',
        'grade_code': 'secondary_3',
        'subject_code': 'biology',
        'academic_year': '2026-2027',
        'edition_code': 'edition-to-be-verified',
        'source_label': 'supplemental',
        'units': [
          {
            'code': 'unit-01',
            'title': 'الوحدة الأولى',
            'sort_order': 1,
            'lessons': [
              {
                'code': 'lesson-01',
                'title': 'الدرس الأول',
                'summary': 'ملخص تجريبي',
                'body_file': 'lessons/lesson-01.md',
                'sort_order': 1,
              }
            ],
          }
        ],
        'assets': [
          {
            'path': 'lessons/lesson-01.md',
            'sha256': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'bytes': 64,
            'media_type': 'text/markdown',
          },
          {
            'path': 'media/diagram.png',
            'sha256': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'bytes': 128,
            'media_type': 'image/png',
          }
        ],
      };

  group('ContentPackageManifest', () {
    test('parses a valid version 1 manifest', () {
      final manifest = ContentPackageManifest.fromMap(validManifest());
      expect(manifest.packageCode, 'sudan-certificate-biology');
      expect(manifest.units.single.lessons.single.bodyFile, 'lessons/lesson-01.md');
      expect(manifest.assets, hasLength(2));
      expect(manifest.assets.last.bytes, 128);
    });


    test('parses exams and typed questions without requiring them in older packages', () {
      final data = validManifest();
      data['exams'] = [
        {
          'code': 'practice-01',
          'title': 'اختبار تجريبي',
          'exam_type': 'practice',
          'duration_minutes': 20,
          'questions': [
            {
              'code': 'q-01',
              'type': 'multiple_choice',
              'prompt': 'اختر الإجابة الصحيحة',
              'options': [
                {'value': 'a', 'label': 'الخيار أ'},
                {'value': 'b', 'label': 'الخيار ب'}
              ],
              'answer': 'b',
              'answer_key_verified': true,
              'marks': 2
            }
          ]
        }
      ];
      final manifest = ContentPackageManifest.fromMap(data);
      expect(manifest.exams.single.questions.single.answer, 'b');
      expect(manifest.exams.single.questions.single.answerKeyVerified, isTrue);
      expect(manifest.exams.single.questions.single.marks, 2);
    });

    test('rejects multiple-choice questions without enough options', () {
      final data = validManifest();
      data['exams'] = [
        {
          'code': 'practice-01',
          'title': 'اختبار',
          'questions': [
            {
              'code': 'q-01',
              'type': 'multiple_choice',
              'prompt': 'سؤال',
              'options': ['خيار واحد']
            }
          ]
        }
      ];
      expect(() => ContentPackageManifest.fromMap(data), throwsFormatException);
    });

    test('rejects unsupported schema versions', () {
      final data = validManifest()..['schema_version'] = 9;
      expect(() => ContentPackageManifest.fromMap(data), throwsFormatException);
    });

    test('rejects path traversal in lesson files', () {
      final data = validManifest();
      final units = data['units'] as List;
      final lessons = (units.first as Map<String, dynamic>)['lessons'] as List;
      (lessons.first as Map<String, dynamic>)['body_file'] = '../../private.txt';
      expect(() => ContentPackageManifest.fromMap(data), throwsFormatException);
    });

    test('rejects invalid asset hashes', () {
      final data = validManifest();
      (data['assets'] as List).first['sha256'] = 'not-a-hash';
      expect(() => ContentPackageManifest.fromMap(data), throwsFormatException);
    });

    test('rejects duplicate unit codes', () {
      final data = validManifest();
      (data['units'] as List).add({
        'code': 'unit-01',
        'title': 'وحدة مكررة',
        'lessons': [
          {'code': 'lesson-02', 'title': 'درس'}
        ],
      });
      expect(() => ContentPackageManifest.fromMap(data), throwsFormatException);
    });
  });
}
