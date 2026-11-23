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
