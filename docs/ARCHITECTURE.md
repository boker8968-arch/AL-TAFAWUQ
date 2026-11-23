# Architecture — منصة التفوق

## Architectural direction

The first release is a native Android application built with Flutter/Dart. The product is offline-first: core learning flows must not depend on a network connection, remote authentication, or a paid backend.

## Proposed layers

- **Presentation:** Flutter screens and reusable widgets, Arabic RTL.
- **Application:** use cases and state coordination.
- **Domain:** entities and repository contracts.
- **Data:** local SQLite database, local media/content files, import/export adapters.

Feature areas should remain separated: student setup, curriculum, lessons, summaries, exams, question bank, progress, timetable, search, favorites, settings, and content packages.

## Local persistence

Use SQLite for structured records such as student preferences, curriculum metadata, questions, attempts, answers, bookmarks, and progress. Store larger books, images, audio, and video as local files, with database records referring to their local paths.

A database abstraction such as Drift may be evaluated during implementation. The final dependency choice must remain compatible with the zero-dollar constraint and offline operation.

## Content packages

Content updates should be optional. A package-import workflow should validate a manifest, package version, curriculum identifiers, file hashes, and compatibility before importing. The app must remain usable with previously installed content if an update is unavailable or interrupted.

## Content quality and provenance

Official Sudanese curriculum materials are the primary source. Grade/track structures and curriculum editions must be verified before content is encoded. Supplemental explanations must be clearly labeled as supplemental rather than official.

## Privacy and resilience

- No mandatory account for core study features.
- Keep student progress on-device by default.
- Provide explicit local backup and restore.
- Never put credentials or private keys in the repository.
- Avoid analytics or remote services that create recurring costs.

## Current implementation status

The initial Flutter shell and theme are scaffolding only. Database, navigation flows, content import, tests, and Android build verification are not yet implemented.

## Content package manifest v1

The first package contract is implemented in `lib/features/content/data/content_package_manifest.dart`.

A package is a directory containing `manifest.json` and the files declared by its `assets` array. The manifest identifies exactly one grade, subject, academic year, and curriculum edition. It does not create or approve curriculum records; import must resolve these identifiers against an already verified local curriculum release.

Required top-level fields:

- `schema_version`: currently `1`.
- `package_code`, `version`, `title`.
- `grade_code`, `subject_code`, `academic_year`, `edition_code`.
- `source_label`: `official` or `supplemental`.
- `units`: ordered units containing ordered lessons.
- `assets`: package-relative file path, SHA-256, byte length, and media type for every included file.

Every lesson `body_file` must also be declared in `assets`. Paths are validated against absolute paths, drive-prefixed paths, empty segments, and directory traversal. The parser rejects unsupported schema versions, duplicate unit/lesson codes, duplicate asset paths, missing fields, and malformed hashes.

The manifest parser validates structure and metadata only. It does not yet copy files, calculate hashes from disk, import database rows, or publish content. Those operations belong to the subsequent importer implementation and must run only after resolving a verified curriculum release and subject. Import must be transactional, checksum-verified, idempotent by package code/version, and must preserve the previously installed package if an update fails.
