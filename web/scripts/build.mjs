import { cp, mkdir, rm, readdir, writeFile } from 'node:fs/promises';
await rm(new URL('../www', import.meta.url), { recursive: true, force: true });
await mkdir(new URL('../www', import.meta.url), { recursive: true });
for (const file of ['index.html','styles.css','app.js','database.js','content-packages.js','content-admin.js','app-config.js','pdf-viewer.js','manifest.webmanifest','icon.svg','sw.js']) await cp(new URL('../'+file, import.meta.url), new URL('../www/'+file, import.meta.url));
const contentAdminEnabled = process.env.CONTENT_ADMIN_ENABLED === 'true';
await writeFile(new URL('../www/app-config.js', import.meta.url), 'export const CONTENT_ADMIN_ENABLED = '+contentAdminEnabled+';');
console.log('Offline web shell copied to www/. Content admin enabled: '+contentAdminEnabled);
const pdfVendor = new URL('../www/vendor/pdfjs/', import.meta.url);
await mkdir(pdfVendor, { recursive: true });
await cp(new URL('../node_modules/pdfjs-dist/LICENSE', import.meta.url), new URL('LICENSE', pdfVendor));
for (const file of ['pdf.mjs','pdf.worker.mjs']) {
  await cp(new URL('../node_modules/pdfjs-dist/build/'+file, import.meta.url), new URL(file, pdfVendor));
}
for (const folder of ['cmaps','standard_fonts','wasm']) {
  await cp(new URL('../node_modules/pdfjs-dist/'+folder, import.meta.url), new URL(folder, pdfVendor), { recursive: true });
}

async function listFiles(directory, prefix) {
  const entries = await readdir(directory, { withFileTypes: true });
  const found = [];
  for (const entry of entries) {
    const relative = prefix + entry.name;
    if (entry.isDirectory()) found.push(...await listFiles(new URL(entry.name+'/', directory), relative+'/'));
    else if (entry.isFile()) found.push('./vendor/pdfjs/'+relative);
  }
  return found;
}
const pdfAssetUrls = [];
for (const folder of ['cmaps','standard_fonts','wasm']) {
  pdfAssetUrls.push(...await listFiles(new URL(folder+'/', pdfVendor), folder+'/'));
}
await writeFile(new URL('../www/pdf-assets.json', import.meta.url), JSON.stringify(pdfAssetUrls));
