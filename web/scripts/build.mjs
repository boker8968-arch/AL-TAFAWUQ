import { cp, mkdir, rm } from 'node:fs/promises';
await rm(new URL('../www', import.meta.url), { recursive: true, force: true });
await mkdir(new URL('../www', import.meta.url), { recursive: true });
for (const file of ['index.html','styles.css','app.js','manifest.webmanifest','sw.js']) await cp(new URL('../'+file, import.meta.url), new URL('../www/'+file, import.meta.url));
console.log('Offline web shell copied to www/.');