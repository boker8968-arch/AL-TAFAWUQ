# Architecture — منصة التفوق

## Architectural direction

The first release is a native Android application built with Flutter/Dart. The product is offline-first: core learning flows must not depend on a network connection, remote authentication, or a paid backend.

## Proposed layers

- **Presentation:** Flutter screens and reusable widgets, Arabic RTL.
- **Application:** use cases and state coordination.
- **Domain:** entities and repository contracts.
- **Data:** local SQLite database, local media/content files, import/export adapters.

Feature areas remain independent modules over a shared academic core: student profile, grade/track/curriculum, content library, lessons and summaries, exams/question bank, revision cards, study progress, study sessions, search, bookmarks, settings, and editorial content management. The same module contracts serve all three secondary grades; grade-specific differences are data/configuration, not separate app forks.

## Local persistence

Use SQLite for structured records such as student preferences, curriculum metadata, questions, attempts, answers, bookmarks, and progress. Store larger books, images, audio, and video as local files, with database records referring to their local paths.

## Content packages

The package contract is versioned JSON v1. Each package contains `manifest.json`, one subject's ordered units/lessons, and a list of assets with SHA-256 and byte lengths.

The importer in `lib/features/content/data/content_package_importer.dart` resolves the exact grade, subject, academic year, and edition against a locally verified curriculum release and verified release-subject mapping. It validates asset file types, rejects symbolic links and paths escaping the package root, checks byte lengths and SHA-256, stages copies, promotes the directory, and writes package/unit/lesson rows in one SQLite transaction. If the database transaction fails after promotion, the newly promoted directory is removed.

Schema v3 associates imported units with their package and stable content codes. Existing package codes are rejected rather than overwritten: package replacement/removal is intentionally not implemented yet. Official-source packages are rejected by default because a manifest label is not proof of provenance; only a trusted editorial caller may opt in after reviewing source evidence.

The importer is exposed through the Android content-management screen. Imported packages start in `pending_review`; the editorial review screen records decisions in an audit table. The reviewer label is not authentication, and the management route is not production-secured. Package replacement and device-level interruption/storage testing remain future work. The app does not connect directly to Google Drive or any remote service.

## Student library and lesson reader

The initial library UI in `lib/features/library/presentation/learning_library_page.dart` groups approved units by subject using `StudentLearningRepository`; it does not read imported content tables directly. Unit lesson lists use the same publication boundary. The reader in `lesson_reader_page.dart` reads UTF-8 lesson bodies from the app's private package directory only, rejects paths outside that root and non-regular files, and displays the lesson summary/body offline. Students can explicitly mark a lesson complete; progress and a local study session are saved in SQLite. Session records inherit the lesson's subject when one is not supplied so study-time summaries can aggregate correctly.

The current reader is text-first. PDF rendering, image/audio/video playback, exams, flashcards, and the progress dashboard remain planned work. Empty library state is expected until real curriculum releases, subject mappings, and reviewed content packages have been verified and approved; no curriculum or subject content is seeded.

## Content quality and provenance

Official Sudanese curriculum materials are the primary source. Grade/track structures and curriculum editions must be verified before content is encoded. Supplemental explanations must be clearly labeled as supplemental rather than official.

## Student publication boundary\n\n`StudentLearningRepository` is the student-facing read boundary. It only returns units and lessons whose content package is `approved` and whose curriculum release and release-subject mapping are both `verified`. Progress writes also verify that the lesson is currently published. New student-facing queries must preserve this rule; never query imported lesson tables directly from presentation widgets.\n\n## Shared academic product model\n\nThe university-platform concept is reused as a modular academic hub, adapted for Sudanese secondary education: a unified library, explanations/notes, question and exam bank, revision, learning analytics/progress, and editorial publishing workflow. There is no university/faculty/semester entity in this product; the academic hierarchy is grade → verified curriculum edition → optional track → subject → unit → lesson. The first content release remains Sudanese Certificate only, while the data model accommodates grades 1–3.\n\nThe AI study assistant (document analysis, summaries, question generation) is a planned separate service boundary, not a local feature falsely described as operational. It must remain optional, must not block offline learning, and must not introduce paid services without explicit approval.\n\n## Privacy and resilience

- No mandatory account for core study features.
- Keep student progress on-device by default.
- Provide explicit local backup and restore.
- Never put credentials or private keys in the repository.
- Avoid analytics or remote services that create recurring costs.

## Current implementation status

The Flutter shell, local database schemas v1–v5, curriculum repository, manifest parser, verified local content importer, editorial review workflow, student publication/progress repository, initial offline library, and text lesson reader are present in the repository. Flutter analysis, automated test execution, Android build verification, and device-level import testing have not yet been confirmed in an available Flutter environment. Flutter analysis, automated test execution, Android build verification, and device-level import testing have not yet been confirmed in an available Flutter environment.

## Offline exam workflow

Schema v6 scopes exams and questions to their originating content package and stable content codes. The manifest may optionally declare exams and typed questions; the importer inserts them atomically with the package's units and lessons. Legacy exam rows without package ownership remain hidden from students. `StudentExamRepository` is the student-facing exam boundary: it filters to approved packages and verified curriculum release mappings, creates local attempts, stores answers, and never returns answer keys to the active attempt UI. Automatic grading is limited to multiple-choice and true/false items whose answer key was explicitly marked verified; short answers are stored but are not auto-graded.