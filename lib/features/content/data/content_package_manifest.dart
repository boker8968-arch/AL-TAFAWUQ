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
    if (rawUnits is! List || rawAssets is! List) {
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
