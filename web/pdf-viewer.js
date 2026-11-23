import * as pdfjsLib from './vendor/pdfjs/pdf.mjs';

pdfjsLib.GlobalWorkerOptions.workerSrc = new URL('./vendor/pdfjs/pdf.worker.mjs', import.meta.url).toString();

export async function renderPdfAsset(blob, container) {
  const data = new Uint8Array(await blob.arrayBuffer());
  const loadingTask = pdfjsLib.getDocument({
    data,
    cMapUrl: './vendor/pdfjs/cmaps/',
    cMapPacked: true,
    standardFontDataUrl: './vendor/pdfjs/standard_fonts/',
    wasmUrl: './vendor/pdfjs/wasm/',
    isEvalSupported: false
  });
  const pdf = await loadingTask.promise;
  let pageNumber = 1;
  let renderTask = null;
  let disposed = false;

  const toolbar = document.createElement('div');
  toolbar.className = 'pdf-toolbar';
  const previous = document.createElement('button');
  previous.type = 'button';
  previous.textContent = 'الصفحة السابقة';
  const status = document.createElement('span');
  status.setAttribute('aria-live', 'polite');
  const next = document.createElement('button');
  next.type = 'button';
  next.textContent = 'الصفحة التالية';
  const pageHost = document.createElement('div');
  pageHost.className = 'pdf-page-host';
  toolbar.append(previous, status, next);
  container.append(toolbar, pageHost);

  async function drawPage() {
    if (disposed) return;
    if (renderTask) {
      try { renderTask.cancel(); } catch {}
      renderTask = null;
    }
    pageHost.replaceChildren();
    const page = await pdf.getPage(pageNumber);
    if (disposed) return;
    const availableWidth = Math.max(280, (container.clientWidth || 360) - 20);
    const base = page.getViewport({ scale: 1 });
    const scale = Math.min(1.65, availableWidth / base.width);
    const viewport = page.getViewport({ scale });
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    const canvas = document.createElement('canvas');
    canvas.className = 'pdf-page';
    canvas.width = Math.floor(viewport.width * ratio);
    canvas.height = Math.floor(viewport.height * ratio);
    canvas.style.width = Math.floor(viewport.width) + 'px';
    canvas.style.height = Math.floor(viewport.height) + 'px';
    const context = canvas.getContext('2d', { alpha: false });
    pageHost.append(canvas);
    status.textContent = 'صفحة ' + pageNumber + ' من ' + pdf.numPages;
    previous.disabled = pageNumber <= 1;
    next.disabled = pageNumber >= pdf.numPages;
    renderTask = page.render({
      canvas,
      canvasContext: context,
      viewport,
      transform: ratio === 1 ? null : [ratio, 0, 0, ratio, 0, 0],
      background: '#ffffff'
    });
    await renderTask.promise;
    if (disposed) return;
    renderTask = null;
    page.cleanup();
  }

  previous.addEventListener('click', async () => {
    if (pageNumber <= 1) return;
    pageNumber--;
    try { await drawPage(); } catch (error) { status.textContent = 'تعذر عرض الصفحة.'; }
  });
  next.addEventListener('click', async () => {
    if (pageNumber >= pdf.numPages) return;
    pageNumber++;
    try { await drawPage(); } catch (error) { status.textContent = 'تعذر عرض الصفحة.'; }
  });

  try {
    await drawPage();
  } catch (error) {
    await loadingTask.destroy();
    throw error;
  }

  return async () => {
    disposed = true;
    if (renderTask) { try { renderTask.cancel(); } catch {} }
    await loadingTask.destroy();
  };
}
