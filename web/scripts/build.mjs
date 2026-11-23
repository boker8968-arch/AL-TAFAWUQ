import { cp, mkdir, rm } from 'node:fs/promises';
await rm(new URL('../www', import.meta.url), { recursive: true, force: true });
await mkdir(new URL('../www', import.meta.url), { recursive: true });
for (const file of ['index.html','styles.css','app.js','database.js','content-packages.js','manifest.webmanifest','sw.js']) await cp(new URL('../'+file, import.meta.url), new URL('../www/'+file, import.meta.url));
console.log('Offline web shell copied to www/.');
const pdfVendor = new URL('../www/vendor/pdfjs/', import.meta.url);
await mkdir(pdfVendor, { recursive: true });
for (const file of ['pdf.mjs','pdf.worker.mjs']) {
  await cp(new URL('../node_modules/pdfjs-dist/build/'+file, import.meta.url), new URL(file, pdfVendor));
}
for (const folder of ['cmaps','standard_fonts','wasm']) {
  await cp(new URL('../node_modules/pdfjs-dist/'+folder, import.meta.url), new URL(folder, pdfVendor), { recursive: true });
}
