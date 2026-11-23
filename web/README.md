# منصة التفوق — Web/Capacitor migration
This isolated branch starts the HTML/CSS/JavaScript Android migration. The existing Flutter application on main is preserved.
## Current scope
- RTL Arabic student shell and responsive mobile layout.
- Local student profile persistence with IndexedDB.
- PWA app-shell caching for offline launch.
- Capacitor Android project configuration.
## Not yet ported
The complete Flutter SQLite schema, content-package importer/review workflow, curriculum queries, lesson reader, exam engine, attempt scoring, bookmarks and study history still require migration and parity tests. No unverified subjects, lessons, notes or exams are seeded. The current UI is a migration scaffold, not a feature-complete student release.
## Build
From this directory: npm install, npm run build, npx cap add android, npx cap sync android. Android debug APK is built with Gradle from the generated android project.