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

## Content packages

The package contract is versioned JSON v1. Each package contains `manifest.json`, one subject's ordered units/lessons, and a list of assets with SHA-256 and byte lengths.

The importer in `lib/features/content/data/content_package_importer.dart` resolves the exact grade, subject, academic year, and edition against a locally verified curriculum release and verified release-subject mapping. It validates asset file types, rejects symbolic links and paths escaping the package root, checks byte lengths and SHA-256, stages copies, promotes the directory, and writes package/unit/lesson rows in one SQLite transaction. If the database transaction fails after promotion, the newly promoted directory is removed.

Schema v3 associates imported units with their package and stable content codes. Existing package codes are rejected rather than overwritten: package replacement/removal is intentionally not implemented yet. Official-source packages are rejected by default because a manifest label is not proof of provenance; only a trusted editorial caller may opt in after reviewing source evidence.

The importer is a data-layer API only. Android folder selection, editorial review screens, package replacement, and device-level interruption/storage testing remain future work. It does not connect to Google Drive or any remote service.

## Content quality and provenance

Official Sudanese curriculum materials are the primary source. Grade/track structures and curriculum editions must be verified before content is encoded. Supplemental explanations must be clearly labeled as supplemental rather than official.

## Privacy and resilience

- No mandatory account for core study features.
- Keep student progress on-device by default.
- Provide explicit local backup and restore.
- Never put credentials or private keys in the repository.
- Avoid analytics or remote services that create recurring costs.

## Current implementation status

The initial Flutter shell, local database schemas v1–v3, curriculum repository, manifest parser, and verified local content importer are implemented in the repository. Flutter analysis, automated test execution, Android build verification, and device-level import testing have not yet been confirmed in an available Flutter environment.
