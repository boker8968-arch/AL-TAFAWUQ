import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'content_package_manifest.dart';

/// Imports one subject package only when its exact curriculum release and
/// release-subject mapping have both been verified locally.
class ContentPackageImporter {
  ContentPackageImporter({
    required Database database,
    required Directory packagesDirectory,
    this.allowOfficialSource = false,
  })  : _database = database,
        _packagesDirectory = packagesDirectory;

  final Database _database;
  final Directory _packagesDirectory;

  /// Must only be enabled by a trusted editorial workflow after provenance review.
  final bool allowOfficialSource;

  Future<ContentPackageImportResult> importDirectory(
    Directory packageDirectory,
  ) async {
    final sourceRoot = await packageDirectory.resolveSymbolicLinks();
    final manifestFile = File(p.join(sourceRoot, 'manifest.json'));
    if (await FileSystemEntity.type(manifestFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException(
        'Package manifest.json is missing or is not a regular file.',
      );
    }
    final resolvedManifest = await manifestFile.resolveSymbolicLinks();
    if (!p.normalize(resolvedManifest).startsWith(
      p.normalize(sourceRoot) + p.separator,
    )) {
      throw const FormatException('Manifest resolves outside the package directory.');
    }

    final manifestBytes = await manifestFile.readAsBytes();
    final manifest = ContentPackageManifest.fromJson(utf8.decode(manifestBytes));
    _validateStorageSegment(manifest.packageCode, 'package_code');
    _validateStorageSegment(manifest.version, 'version');
    if (manifest.sourceLabel == 'official' && !allowOfficialSource) {
      throw StateError(
        'Official-source packages require an explicitly trusted editorial import workflow.',
      );
    }

    final matches = await _database.rawQuery('''
      SELECT r.id AS release_id, rs.id AS release_subject_id, s.id AS subject_id
      FROM curriculum_releases r
      JOIN grades g ON g.id = r.grade_id
      JOIN curriculum_release_subjects rs ON rs.release_id = r.id
      JOIN subjects s ON s.id = rs.subject_id
      WHERE g.code = ? AND s.code = ? AND r.academic_year = ?
        AND r.edition_code = ? AND r.verification_status = 'verified'
        AND rs.verification_status = 'verified' AND s.is_active = 1
        AND (r.track_id IS NULL OR s.track_id IS NULL OR r.track_id = s.track_id)
      LIMIT 2
    ''', [
      manifest.gradeCode,
      manifest.subjectCode,
      manifest.academicYear,
      manifest.editionCode,
    ]);
    if (matches.isEmpty) {
      throw StateError(
        'No verified curriculum release and subject mapping match this package.',
      );
    }
    if (matches.length != 1) {
      throw StateError(
        'The package matches more than one verified curriculum mapping; resolve the ambiguity first.',
      );
    }

    final installed = await _database.query(
      'content_packages',
      columns: ['id', 'version'],
      where: 'package_code = ?',
      whereArgs: [manifest.packageCode],
      limit: 1,
    );
    if (installed.isNotEmpty) {
      throw StateError(
        'Package ${manifest.packageCode} is already installed '
        '(version ${installed.first['version']}). Replacement is not supported yet.',
      );
    }

    await _packagesDirectory.create(recursive: true);
    final packagesPath = await _packagesDirectory.resolveSymbolicLinks();
    final packageParent = Directory(p.join(packagesPath, manifest.packageCode));
    final parentType = await FileSystemEntity.type(
      packageParent.path,
      followLinks: false,
    );
    if (parentType == FileSystemEntityType.link ||
        (parentType != FileSystemEntityType.notFound &&
            parentType != FileSystemEntityType.directory)) {
      throw FileSystemException('Unsafe package storage directory.', packageParent.path);
    }
    await packageParent.create(recursive: true);
    final finalDirectory = Directory(p.join(packageParent.path, manifest.version));
    if (await finalDirectory.exists()) {
      throw StateError('The target package version directory already exists.');
    }

    final stagingDirectory = Directory(
      p.join(packageParent.path, '.staging-${DateTime.now().microsecondsSinceEpoch}'),
    );
    await stagingDirectory.create();
    var promoted = false;

    try {
      for (final asset in manifest.assets) {
        if (asset.path == 'manifest.json') {
          throw const FormatException('manifest.json is reserved and cannot be declared as an asset.');
        }
        final sourceFile = await _resolveSafeAsset(sourceRoot, asset.path);
        final actualLength = await sourceFile.length();
        if (actualLength != asset.bytes) {
          throw FormatException(
            'Asset size mismatch for ${asset.path}: expected ${asset.bytes}, got $actualLength.',
          );
        }
        final actualDigest = await sha256.bind(sourceFile.openRead()).first;
        if (actualDigest.toString() != asset.sha256) {
          throw FormatException('SHA-256 mismatch for ${asset.path}.');
        }

        final destination = File(p.join(stagingDirectory.path, asset.path));
        await destination.parent.create(recursive: true);
        await sourceFile.copy(destination.path);
      }

      await File(p.join(stagingDirectory.path, 'manifest.json'))
          .writeAsBytes(manifestBytes, flush: true);
      await stagingDirectory.rename(finalDirectory.path);
      promoted = true;

      final now = DateTime.now().toUtc().toIso8601String();
      final manifestPath = p.join(finalDirectory.path, 'manifest.json');
      final manifestChecksum = sha256.convert(manifestBytes).toString();
      final packageId = await _database.transaction<int>((txn) async {
        final id = await txn.insert('content_packages', {
          'package_code': manifest.packageCode,
          'version': manifest.version,
          'manifest_path': manifestPath,
          'imported_at': now,
          'checksum': manifestChecksum,
          'source_label': manifest.sourceLabel,
          'review_status': 'pending_review',
        });

        final lessonIdsByCode = <String, int>{};
        for (final unit in manifest.units) {
          final unitId = await txn.insert('curriculum_units', {
            'subject_id': matches.single['subject_id'],
            'release_subject_id': matches.single['release_subject_id'],
            'package_id': id,
            'content_code': unit.code,
            'title_ar': unit.title,
            'sort_order': unit.sortOrder,
            'source_label': manifest.sourceLabel,
          });
          for (final lesson in unit.lessons) {
            final lessonId = await txn.insert('lessons', {
              'unit_id': unitId,
              'content_code': lesson.code,
              'title_ar': lesson.title,
              'summary_ar': lesson.summary,
              'body_path': lesson.bodyFile == null
                  ? null
                  : p.join(finalDirectory.path, lesson.bodyFile!),
              'sort_order': lesson.sortOrder,
              'content_version': manifest.version,
            });
            lessonIdsByCode[lesson.code] = lessonId;
          }
        }
        for (final exam in manifest.exams) {
          final examId = await txn.insert('exams', {
            'subject_id': matches.single['subject_id'],
            'package_id': id,
            'content_code': exam.code,
            'title_ar': exam.title,
            'exam_type': exam.examType,
            'duration_minutes': exam.durationMinutes,
            'source_label': manifest.sourceLabel,
          });
          for (var index = 0; index < exam.questions.length; index++) {
            final question = exam.questions[index];
            final lessonId = question.lessonCode == null
                ? null : lessonIdsByCode[question.lessonCode];
            if (question.lessonCode != null && lessonId == null) {
              throw FormatException('Unknown lesson_code ${question.lessonCode} in question ${question.code}.');
            }
            final questionId = await txn.insert('questions', {
              'subject_id': matches.single['subject_id'],
              'lesson_id': lessonId,
              'package_id': id,
              'content_code': question.code,
              'question_type': question.type,
              'prompt_ar': question.prompt,
              'options_json': question.options == null ? null : jsonEncode(question.options),
              'answer_json': question.answer == null ? null : jsonEncode(question.answer),
              'explanation_ar': question.explanation,
              'difficulty': question.difficulty,
              'source_label': manifest.sourceLabel,
              'answer_key_verified': question.answerKeyVerified ? 1 : 0,
            });
            await txn.insert('exam_questions', {
              'exam_id': examId,
              'question_id': questionId,
              'sort_order': index,
              'marks': question.marks,
            });
          }
        }
        return id;
      });

      return ContentPackageImportResult(
        packageId: packageId,
        packageCode: manifest.packageCode,
        version: manifest.version,
        importedUnits: manifest.units.length,
        importedLessons: manifest.units.fold<int>(
          0,
          (total, unit) => total + unit.lessons.length,
        ),
      );
    } catch (_) {
      if (promoted && await finalDirectory.exists()) {
        await finalDirectory.delete(recursive: true);
      }
      rethrow;
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<File> _resolveSafeAsset(String sourceRoot, String relativePath) async {
    final segments = relativePath.split('/');
    var current = sourceRoot;
    for (var index = 0; index < segments.length; index++) {
      current = p.join(current, segments[index]);
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.notFound ||
          type == FileSystemEntityType.link) {
        throw FileSystemException('Asset is missing or contains a symbolic link.', current);
      }
      if (index < segments.length - 1 && type != FileSystemEntityType.directory) {
        throw FileSystemException('Asset parent is not a directory.', current);
      }
      if (index == segments.length - 1 && type != FileSystemEntityType.file) {
        throw FileSystemException('Asset is not a regular file.', current);
      }
    }

    final resolved = await File(current).resolveSymbolicLinks();
    final prefix = p.normalize(sourceRoot) + p.separator;
    if (!p.normalize(resolved).startsWith(prefix)) {
      throw FileSystemException('Asset resolves outside the package directory.', current);
    }
    return File(resolved);
  }

  static void _validateStorageSegment(String value, String field) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(value)) {
      throw FormatException('Unsafe $field for local storage: $value');
    }
  }
}

class ContentPackageImportResult {
  const ContentPackageImportResult({
    required this.packageId,
    required this.packageCode,
    required this.version,
    required this.importedUnits,
    required this.importedLessons,
  });

  final int packageId;
  final String packageCode;
  final String version;
  final int importedUnits;
  final int importedLessons;
}
