import 'dart:convert';

/// Versioned, JSON-serializable description of one offline content package.
///
/// File paths are package-relative and must never escape the package root.
class ContentPackageManifest {
  const ContentPackageManifest({
    required this.schemaVersion,
    required this.packageCode,
    required this.version,
    required this.title,
    required this.gradeCode,
    required this.subjectCode,
    required this.academicYear,
    required this.editionCode,
    required this.sourceLabel,
    required this.units,
    required this.assets,
    required this.exams,
  });

  final int schemaVersion;
  final String packageCode;
  final String version;
  final String title;
  final String gradeCode;
  final String subjectCode;
  final String academicYear;
  final String editionCode;
  final String sourceLabel;
  final List<ContentPackageUnit> units;
  final List<ContentPackageAsset> assets;
  final List<ContentPackageExam> exams;

  factory ContentPackageManifest.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Package manifest must be a JSON object.');
    }
    return ContentPackageManifest.fromMap(decoded);
  }

  factory ContentPackageManifest.fromMap(Map<String, dynamic> map) {
    final schemaVersion = _requiredInt(map, 'schema_version');
    if (schemaVersion != 1) {
      throw FormatException('Unsupported content package schema: $schemaVersion');
    }

    final rawUnits = map['units'];
    final rawAssets = map['assets'];
    final rawExams = map['exams'] ?? const [];
    if (rawUnits is! List || rawAssets is! List || rawExams is! List) {
      throw const FormatException('Manifest units and assets must be arrays.');
    }

    final manifest = ContentPackageManifest(
      schemaVersion: schemaVersion,
      packageCode: _requiredString(map, 'package_code'),
      version: _requiredString(map, 'version'),
      title: _requiredString(map, 'title'),
      gradeCode: _requiredString(map, 'grade_code'),
      subjectCode: _requiredString(map, 'subject_code'),
      academicYear: _requiredString(map, 'academic_year'),
      editionCode: _requiredString(map, 'edition_code'),
      sourceLabel: _requiredString(map, 'source_label'),
      units: rawUnits.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Each unit must be a JSON object.');
        }
        return ContentPackageUnit.fromMap(item);
      }).toList(growable: false),
      exams: rawExams.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Each exam must be a JSON object.');
        }
        return ContentPackageExam.fromMap(item);
      }).toList(growable: false),
      assets: rawAssets.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Each asset must be a JSON object.');
        }
        return ContentPackageAsset.fromMap(item);
      }).toList(growable: false),
    );
    manifest.validate();
    return manifest;
  }

  void validate() {
    _requireNonEmpty(packageCode, 'package_code');
    _requireNonEmpty(version, 'version');
    _requireNonEmpty(title, 'title');
    _requireNonEmpty(gradeCode, 'grade_code');
    _requireNonEmpty(subjectCode, 'subject_code');
    _requireNonEmpty(academicYear, 'academic_year');
    _requireNonEmpty(editionCode, 'edition_code');
    if (!['official', 'supplemental'].contains(sourceLabel)) {
      throw FormatException('Invalid source_label: $sourceLabel');
    }
    if (units.isEmpty) {
      throw const FormatException('A package must contain at least one unit.');
    }

    final unitCodes = <String>{};
    final lessonCodes = <String>{};
    final referencedFiles = <String>{};
    final assetPaths = <String>{};
    final examCodes = <String>{};
    final questionCodes = <String>{};
    for (final unit in units) {
      if (!unitCodes.add(unit.code)) {
        throw FormatException('Duplicate unit code: ${unit.code}');
      }
      if (unit.lessons.isEmpty) {
        throw FormatException('Unit ${unit.code} must contain at least one lesson.');
      }
      for (final lesson in unit.lessons) {
        if (!lessonCodes.add(lesson.code)) {
          throw FormatException('Duplicate lesson code: ${lesson.code}');
        }
        if (lesson.bodyFile != null) {
          _validateRelativePath(lesson.bodyFile!, 'lesson body_file');
          referencedFiles.add(lesson.bodyFile!);
        }
      }
    }
    for (final exam in exams) {
      if (!examCodes.add(exam.code)) throw FormatException('Duplicate exam code: ${exam.code}');
      if (exam.questions.isEmpty) throw FormatException('Exam ${exam.code} must contain questions.');
      for (final question in exam.questions) {
        if (!questionCodes.add(question.code)) throw FormatException('Duplicate question code: ${question.code}');
        if (!{'multiple_choice', 'true_false', 'short_answer'}.contains(question.type)) {
          throw FormatException('Unsupported question type: ${question.type}');
        }
        if (question.type == 'multiple_choice' && (question.options == null || question.options!.length < 2)) {
          throw FormatException('Multiple-choice question ${question.code} requires at least two options.');
        }
        if (question.answerKeyVerified && question.answer == null) {
          throw FormatException('Verified answer key missing for question ${question.code}.');
        }
      }
    }
    for (final asset in assets) {
      _validateRelativePath(asset.path, 'asset path');
      if (!assetPaths.add(asset.path)) {
        throw FormatException('Duplicate package file path: ${asset.path}');
      }
    }
    for (final file in referencedFiles) {
      if (!assetPaths.contains(file)) {
        throw FormatException('Lesson body file is missing from assets: $file');
      }
    }
  }
}

class ContentPackageUnit {
  const ContentPackageUnit({
    required this.code,
    required this.title,
    required this.sortOrder,
    required this.lessons,
  });

  final String code;
  final String title;
  final int sortOrder;
  final List<ContentPackageLesson> lessons;

  factory ContentPackageUnit.fromMap(Map<String, dynamic> map) {
    final rawLessons = map['lessons'];
    if (rawLessons is! List) {
      throw const FormatException('Unit lessons must be an array.');
    }
    return ContentPackageUnit(
      code: _requiredString(map, 'code'),
      title: _requiredString(map, 'title'),
      sortOrder: _optionalInt(map, 'sort_order', 0),
      lessons: rawLessons.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Each lesson must be a JSON object.');
        }
        return ContentPackageLesson.fromMap(item);
      }).toList(growable: false),
    );
  }
}

class ContentPackageLesson {
  const ContentPackageLesson({
    required this.code,
    required this.title,
    required this.sortOrder,
    this.summary,
    this.bodyFile,
  });

  final String code;
  final String title;
  final int sortOrder;
  final String? summary;
  final String? bodyFile;

  factory ContentPackageLesson.fromMap(Map<String, dynamic> map) {
    return ContentPackageLesson(
      code: _requiredString(map, 'code'),
      title: _requiredString(map, 'title'),
      sortOrder: _optionalInt(map, 'sort_order', 0),
      summary: _optionalString(map, 'summary'),
      bodyFile: _optionalString(map, 'body_file'),
    );
  }
}

class ContentPackageExam {
  const ContentPackageExam({
    required this.code,
    required this.title,
    required this.examType,
    required this.questions,
    this.durationMinutes,
  });

  final String code;
  final String title;
  final String examType;
  final int? durationMinutes;
  final List<ContentPackageQuestion> questions;

  factory ContentPackageExam.fromMap(Map<String, dynamic> map) {
    final rawQuestions = map['questions'];
    if (rawQuestions is! List) {
      throw const FormatException('Exam questions must be an array.');
    }
    return ContentPackageExam(
      code: _requiredString(map, 'code'),
      title: _requiredString(map, 'title'),
      examType: _optionalString(map, 'exam_type') ?? 'practice',
      durationMinutes: map['duration_minutes'] == null
          ? null : _optionalInt(map, 'duration_minutes', 0),
      questions: rawQuestions.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Each question must be a JSON object.');
        }
        return ContentPackageQuestion.fromMap(item);
      }).toList(growable: false),
    );
  }
}

class ContentPackageQuestion {
  const ContentPackageQuestion({
    required this.code,
    required this.type,
    required this.prompt,
    required this.difficulty,
    required this.marks,
    this.lessonCode,
    this.options,
    this.answer,
    this.explanation,
    this.answerKeyVerified = false,
  });

  final String code;
  final String type;
  final String prompt;
  final int difficulty;
  final double marks;
  final String? lessonCode;
  final List<Object?>? options;
  final Object? answer;
  final String? explanation;
  final bool answerKeyVerified;

  factory ContentPackageQuestion.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    if (rawOptions != null && rawOptions is! List) {
      throw const FormatException('Question options must be an array.');
    }
    final rawVerified = map['answer_key_verified'] ?? false;
    if (rawVerified is! bool) {
      throw const FormatException('answer_key_verified must be boolean.');
    }
    final rawMarks = map['marks'] ?? 1;
    if (rawMarks is! num || rawMarks <= 0) {
      throw const FormatException('Question marks must be a positive number.');
    }
    return ContentPackageQuestion(
      code: _requiredString(map, 'code'),
      type: _requiredString(map, 'type'),
      prompt: _requiredString(map, 'prompt'),
      lessonCode: _optionalString(map, 'lesson_code'),
      options: rawOptions == null ? null : List<Object?>.from(rawOptions),
      answer: map['answer'],
      explanation: _optionalString(map, 'explanation'),
      difficulty: _optionalInt(map, 'difficulty', 1),
      marks: rawMarks.toDouble(),
      answerKeyVerified: rawVerified,
    );
  }
}

class ContentPackageAsset {
  const ContentPackageAsset({
    required this.path,
    required this.sha256,
    required this.bytes,
    required this.mediaType,
  });

  final String path;
  final String sha256;
  final int bytes;
  final String mediaType;

  factory ContentPackageAsset.fromMap(Map<String, dynamic> map) {
    final asset = ContentPackageAsset(
      path: _requiredString(map, 'path'),
      sha256: _requiredString(map, 'sha256').toLowerCase(),
      bytes: _requiredInt(map, 'bytes'),
      mediaType: _requiredString(map, 'media_type'),
    );
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(asset.sha256)) {
      throw FormatException('Invalid SHA-256 for asset: ${asset.path}');
    }
    if (asset.bytes < 0) {
      throw FormatException('Asset byte length cannot be negative: ${asset.path}');
    }
    return asset;
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or empty required string: $key');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string.');
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

int _optionalInt(Map<String, dynamic> map, String key, int fallback) {
  final value = map[key];
  if (value == null) return fallback;
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

void _requireNonEmpty(String value, String field) {
  if (value.trim().isEmpty) throw FormatException('$field must not be empty.');
}

void _validateRelativePath(String path, String field) {
  final normalized = path.replaceAll('\\\\', '/');
  final segments = normalized.split('/');
  if (normalized.isEmpty ||
      normalized.startsWith('/') ||
      RegExp(r'^[a-zA-Z]:').hasMatch(normalized) ||
      segments.any((segment) => segment.isEmpty || segment == '.' || segment == '..')) {
    throw FormatException('Unsafe $field: $path');
  }
}
