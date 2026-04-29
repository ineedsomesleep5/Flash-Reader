import JSZip from 'jszip';
import * as pdfjsLib from 'pdfjs-dist';
import pdfjsWorkerUrl from 'pdfjs-dist/build/pdf.worker.mjs?url';
import { loadDocuments, saveDocuments, loadSettings, saveSettings, loadStats, saveStats } from './store.js';
import { tokenize } from './tokenizer.js';
import { Reader } from './reader.js';
import {
  searchWikipedia, fetchWikiMostViewed, fetchWikiArticle,
  fetchGutenberg, CLASSICS,
} from './browse.js';

pdfjsLib.GlobalWorkerOptions.workerSrc = pdfjsWorkerUrl;

// ── State ──────────────────────────────────────────────────────────────────
let docs = loadDocuments();
let settings = loadSettings();
let stats = loadStats();
let currentDocId = null;
let sessionStart = null;
let sessionStartIndex = 0;
const reader = new Reader({ onWord: handleWord, onEnd: handleEnd });

// ── Helpers ────────────────────────────────────────────────────────────────
function uid() { return Math.random().toString(36).slice(2, 11); }

function createDoc(title, text) {
  return {
    id: uid(),
    title: (title?.trim()) || 'Untitled',
    tokens: tokenize(text),
    progress: 0,
    addedAt: Date.now(),
    lastRead: Date.now(),
  };
}

function getDoc(id = currentDocId) { return docs.find(d => d.id === id); }
function persist() { saveDocuments(docs); }

function etaLabel(wordsLeft, wpm) {
  const mins = Math.ceil(wordsLeft / wpm);
  if (mins < 1) return '< 1m left';
  if (mins < 60) return `~${mins}m left`;
  return `~${Math.floor(mins / 60)}h ${mins % 60}m left`;
}

const SENT_END_RE = /[.!?][""']?$/;

function getSentenceContext(tokens, index) {
  let start = index;
  while (start > 0 && !SENT_END_RE.test(tokens[start - 1].raw)) start--;
  let end = index;
  while (end < tokens.length - 1 && !SENT_END_RE.test(tokens[end].raw)) end++;
  return tokens.slice(start, end + 1).map(t => t.raw).join(' ');
}

// ── Navigation ─────────────────────────────────────────────────────────────
function nav(screenId) {
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  document.getElementById(screenId).classList.add('active');
}

// ── Stats ──────────────────────────────────────────────────────────────────
function renderStats() {
  const words = stats.totalWordsRead;
  const mins = Math.round(stats.totalMinutes);
  document.getElementById('stat-words').textContent =
    words >= 1000 ? `${(words / 1000).toFixed(1)}k` : String(words);
  let timeStr = mins < 60 ? `${mins}m` : `${Math.floor(mins / 60)}h ${mins % 60}m`;
  document.getElementById('stat-time').textContent = timeStr;
  document.getElementById('stat-books').textContent = String(docs.length);
}

function accumulateSession(endIndex) {
  if (sessionStart === null) return;
  const wordsRead = Math.max(0, endIndex - sessionStartIndex);
  const minutesRead = (Date.now() - sessionStart) / 60000;
  stats.totalWordsRead += wordsRead;
  stats.totalMinutes += minutesRead;
  saveStats(stats);
  sessionStart = null;
  renderStats();
}

// ── Library ────────────────────────────────────────────────────────────────
function renderLibrary() {
  const list = document.getElementById('library-list');
  const sorted = [...docs].sort((a, b) => b.lastRead - a.lastRead);

  if (sorted.length === 0) {
    list.innerHTML = `<div class="empty-state">
      <p>Your library is empty.</p>
      <p style="margin-top:8px">Tap + to paste text or browse for something to read.</p>
    </div>`;
  } else {
    list.innerHTML = sorted.map(doc => {
      const pct = doc.tokens.length ? Math.floor((doc.progress / doc.tokens.length) * 100) : 0;
      const left = doc.tokens.length - doc.progress;
      return `<div class="card" data-doc-id="${doc.id}">
        <div class="card-title">${escHtml(doc.title)}</div>
        <div class="card-meta">${doc.tokens.length.toLocaleString()} words &middot; ${pct}% &middot; ${etaLabel(left, settings.wpm)}</div>
        <div class="progress-track"><div class="progress-fill" style="width:${pct}%"></div></div>
      </div>`;
    }).join('');
  }
  renderStats();
}

function openDoc(id) {
  currentDocId = id;
  const doc = getDoc();
  doc.lastRead = Date.now();
  persist();

  const total = doc.tokens.length;
  const pct = total ? Math.floor((doc.progress / total) * 100) : 0;
  const left = total - doc.progress;

  document.getElementById('detail-title').textContent = doc.title;
  document.getElementById('detail-pct').textContent = `${pct}%`;
  document.getElementById('detail-words').textContent = `${doc.progress.toLocaleString()} / ${total.toLocaleString()} words`;
  document.getElementById('detail-progress-bar').style.width = `${pct}%`;
  document.getElementById('detail-eta').textContent = etaLabel(left, settings.wpm);

  const preview = document.getElementById('detail-preview');
  preview.innerHTML = doc.tokens
    .map((t, i) => `<span class="${i === doc.progress ? 'active-word' : ''}" data-i="${i}">${escHtml(t.raw)} </span>`)
    .join('');
  preview.querySelector('.active-word')?.scrollIntoView({ block: 'center', behavior: 'smooth' });

  nav('screen-detail');
}

// ── Detail actions ─────────────────────────────────────────────────────────
function deleteDoc() {
  if (!confirm(`Delete "${getDoc().title}"?`)) return;
  docs = docs.filter(d => d.id !== currentDocId);
  persist();
  renderLibrary();
  nav('screen-library');
}

function resetProgress() {
  if (!confirm('Reset reading progress to the beginning?')) return;
  getDoc().progress = 0;
  persist();
  openDoc(currentDocId);
}

// ── Flash Reader ───────────────────────────────────────────────────────────
function startReading() {
  applySettings();
  initFlashUI(getDoc());
  nav('screen-flash');
}

function stopReading() {
  const idx = reader.pause();
  accumulateSession(idx);
  getDoc().progress = idx;
  persist();
  openDoc(currentDocId);
  renderLibrary();
}

function initFlashUI(doc) {
  const scrubber = document.getElementById('flash-scrubber');
  scrubber.max = Math.max(0, doc.tokens.length - 1);
  scrubber.value = doc.progress;
  const idx = doc.progress;
  const chunk = doc.tokens.slice(idx, idx + settings.chunkSize);
  updateFlashWord(chunk.length ? chunk : [doc.tokens[0]], idx, doc.tokens.length);
  updateHoldBtn(false);
}

// onWord callback — always receives array of tokens
function handleWord(chunks, index) {
  const doc = getDoc();
  doc.progress = index;
  updateFlashWord(chunks, index, doc.tokens.length);
}

function handleEnd() {
  const idx = reader.index;
  accumulateSession(idx);
  persist();
  updateHoldBtn(false);
  const doc = getDoc();
  if (doc.progress >= doc.tokens.length) doc.progress = doc.tokens.length - 1;
}

function updateFlashWord(chunks, startIndex, total) {
  if (!chunks?.length) return;
  const flashWord = document.getElementById('flash-word');

  if (chunks.length === 1) {
    const token = chunks[0];
    const pre  = token.stripped.slice(0, token.orp);
    const orp  = token.stripped.slice(token.orp, token.orp + 1);
    const post = token.stripped.slice(token.orp + 1);
    flashWord.style.left = '35%';
    flashWord.querySelector('.orp-pre').textContent  = pre;
    flashWord.querySelector('.orp-red').textContent  = orp;
    flashWord.querySelector('.orp-red').style.color  = '';
    flashWord.querySelector('.orp-post').textContent = post;
  } else {
    // Chunk mode: center all words, no ORP highlighting
    flashWord.style.left = '50%';
    flashWord.querySelector('.orp-pre').textContent  = '';
    flashWord.querySelector('.orp-red').textContent  = chunks.map(t => t.stripped).join('  ');
    flashWord.querySelector('.orp-red').style.color  = 'var(--text-primary)';
    flashWord.querySelector('.orp-post').textContent = '';
  }

  document.getElementById('flash-progress-text').textContent = `${startIndex + 1} / ${total}`;
  document.getElementById('flash-scrubber').value = startIndex;

  // Context bar
  if (settings.showContext) {
    const doc = getDoc();
    if (doc) {
      const bar = document.getElementById('context-bar');
      bar.textContent = getSentenceContext(doc.tokens, startIndex);
    }
  }
}

function updateHoldBtn(playing) {
  const btn = document.getElementById('hold-play-btn');
  btn.classList.toggle('playing', playing);
  btn.innerHTML = playing
    ? `<svg viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg> Reading…`
    : `<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg> Hold to Read`;
}

function startHold(e) {
  if (e.cancelable) e.preventDefault();
  const doc = getDoc();
  sessionStart = Date.now();
  sessionStartIndex = doc.progress;
  reader.play(doc.tokens, doc.progress, settings.wpm, settings.smartPauses, settings.chunkSize);
  updateHoldBtn(true);
}

function stopHold(e) {
  if (e.cancelable) e.preventDefault();
  const idx = reader.pause();
  accumulateSession(idx);
  getDoc().progress = idx;
  persist();
  updateHoldBtn(false);
}

function scrubProgress(val) {
  const doc = getDoc();
  const idx = parseInt(val, 10);
  doc.progress = idx;
  reader.seekTo(idx);
  persist();
}

// ── Settings ───────────────────────────────────────────────────────────────
function applySettings() {
  document.documentElement.style.setProperty('--font-scale', settings.fontSize);
  document.getElementById('setting-wpm').value = settings.wpm;
  document.getElementById('setting-wpm-val').textContent = settings.wpm;
  document.getElementById('setting-font').value = settings.fontSize;
  document.getElementById('setting-smart').checked = settings.smartPauses;
  document.getElementById('setting-chunk').value = settings.chunkSize;
  document.getElementById('setting-context').checked = settings.showContext;
  document.getElementById('flash-wpm-slider').value = settings.wpm;
  document.getElementById('flash-wpm-label').textContent = `${settings.wpm} WPM`;
  reader.setWpm(settings.wpm);

  const contextBar = document.getElementById('context-bar');
  contextBar.classList.toggle('visible', settings.showContext);
}

function onSettingsChange() {
  settings.wpm = parseInt(document.getElementById('setting-wpm').value, 10);
  settings.fontSize = parseFloat(document.getElementById('setting-font').value);
  settings.smartPauses = document.getElementById('setting-smart').checked;
  settings.chunkSize = parseInt(document.getElementById('setting-chunk').value, 10);
  settings.showContext = document.getElementById('setting-context').checked;
  saveSettings(settings);
  applySettings();
}

function onFlashWpmChange(val) {
  settings.wpm = parseInt(val, 10);
  saveSettings(settings);
  reader.setWpm(settings.wpm);
  document.getElementById('flash-wpm-label').textContent = `${settings.wpm} WPM`;
  document.getElementById('setting-wpm').value = settings.wpm;
  document.getElementById('setting-wpm-val').textContent = settings.wpm;
}

// ── Add Document ───────────────────────────────────────────────────────────
function addDocument() {
  const title = document.getElementById('add-title').value;
  const text  = document.getElementById('add-text').value.trim();
  if (!text) { alert('Please enter some text.'); return; }
  docs.push(createDoc(title, text));
  persist();
  renderLibrary();
  closeModal('modal-add');
  document.getElementById('add-title').value = '';
  document.getElementById('add-text').value = '';
}

async function handleFileUpload(e) {
  const file = e.target.files[0];
  if (!file) return;
  const title = file.name.replace(/\.[^/.]+$/, '');

  if (file.name.endsWith('.epub')) {
    try {
      const text = await parseEpub(file);
      document.getElementById('add-title').value = title;
      document.getElementById('add-text').value = text;
      switchAddTab('paste');
    } catch {
      alert('Could not read EPUB file. Try a different file.');
    }
    return;
  }

  if (file.name.endsWith('.pdf')) {
    try {
      const text = await parsePdf(file);
      document.getElementById('add-title').value = title;
      document.getElementById('add-text').value = text;
      switchAddTab('paste');
    } catch {
      alert('Could not read PDF file. Try a different file.');
    }
    return;
  }

  const fr = new FileReader();
  fr.onload = ev => {
    document.getElementById('add-title').value = title;
    document.getElementById('add-text').value = ev.target.result;
    switchAddTab('paste');
  };
  fr.readAsText(file);
}

async function parseEpub(file) {
  const zip = await JSZip.loadAsync(file);
  const opfFile = Object.keys(zip.files).find(n => n.endsWith('.opf'));
  let orderedFiles = [];

  if (opfFile) {
    const opfText = await zip.files[opfFile].async('text');
    const opf = new DOMParser().parseFromString(opfText, 'application/xml');
    const spineItems = [...opf.querySelectorAll('spine itemref')].map(el => el.getAttribute('idref'));
    const manifest = {};
    opf.querySelectorAll('manifest item').forEach(el => {
      manifest[el.getAttribute('id')] = el.getAttribute('href');
    });
    const basePath = opfFile.includes('/') ? opfFile.slice(0, opfFile.lastIndexOf('/') + 1) : '';
    orderedFiles = spineItems
      .map(id => basePath + manifest[id])
      .filter(href => href && zip.files[href]);
  }

  if (!orderedFiles.length) {
    orderedFiles = Object.keys(zip.files)
      .filter(n => /\.(html|xhtml|htm)$/i.test(n))
      .sort();
  }

  const parts = [];
  for (const filename of orderedFiles) {
    const html = await zip.files[filename].async('text');
    const doc = new DOMParser().parseFromString(html, 'text/html');
    doc.querySelectorAll('script, style, nav').forEach(el => el.remove());
    const text = doc.body?.textContent ?? '';
    const cleaned = text.replace(/\n{3,}/g, '\n\n').trim();
    if (cleaned.length > 50) parts.push(cleaned);
  }

  if (!parts.length) throw new Error('No readable content found in EPUB');
  return parts.join('\n\n');
}

async function parsePdf(file) {
  const arrayBuffer = await file.arrayBuffer();
  const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
  const parts = [];
  for (let i = 1; i <= pdf.numPages; i++) {
    const page = await pdf.getPage(i);
    const content = await page.getTextContent();
    const pageText = content.items
      .map(item => ('str' in item ? item.str : ''))
      .join(' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (pageText.length > 20) parts.push(pageText);
  }
  if (!parts.length) throw new Error('No readable content found in PDF');
  return parts.join('\n\n');
}

function switchAddTab(tab) {
  document.getElementById('add-paste-area').style.display = tab === 'paste' ? '' : 'none';
  document.getElementById('add-upload-area').style.display = tab === 'upload' ? '' : 'none';
  document.querySelectorAll('.add-tab').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.addTab === tab);
  });
}

// ── Browse ─────────────────────────────────────────────────────────────────
async function searchWiki() {
  const query = document.getElementById('browse-search').value.trim();
  if (!query) return;
  withSpinner(async () => {
    const results = await searchWikipedia(query);
    renderBrowseResults(results);
  });
}

async function loadWikiDaily() {
  withSpinner(async () => {
    const results = await fetchWikiMostViewed();
    renderBrowseResults(results);
  });
}

function loadClassics() {
  const container = document.getElementById('browse-results');
  container.innerHTML = CLASSICS.map(c =>
    `<div class="card" data-gutenberg-id="${c.id}" data-gutenberg-title="${escAttr(c.title)}">
      <div class="card-title">${escHtml(c.title)}</div>
      <div class="browse-card-snippet">${escHtml(c.author)}</div>
    </div>`
  ).join('');
}

function renderBrowseResults(results) {
  const container = document.getElementById('browse-results');
  if (!results.length) {
    container.innerHTML = '<p class="empty-hint">No results found.</p>';
    return;
  }
  container.innerHTML = results.map(r =>
    `<div class="card" data-wiki-title="${escAttr(r.title)}">
      <div class="card-title">${escHtml(r.title)}</div>
      <div class="browse-card-snippet">${escHtml(r.snippet)}</div>
    </div>`
  ).join('');
}

async function importWiki(title) {
  withSpinner(async () => {
    const { title: t, text } = await fetchWikiArticle(title);
    docs.push(createDoc(t, text));
    persist();
    renderLibrary();
    nav('screen-library');
  });
}

async function importGutenberg(id, title) {
  withSpinner(async () => {
    const { text } = await fetchGutenberg(id, title);
    docs.push(createDoc(title, text));
    persist();
    renderLibrary();
    nav('screen-library');
  }, 'Fetching book…');
}

// ── Modals ─────────────────────────────────────────────────────────────────
function openModal(id) { document.getElementById(id).classList.add('active'); }
function closeModal(id) { document.getElementById(id).classList.remove('active'); }

// ── Spinner helper ─────────────────────────────────────────────────────────
async function withSpinner(fn) {
  const spinner = document.getElementById('search-spinner');
  spinner.style.display = 'block';
  try { await fn(); }
  catch (err) { alert(err.message || 'Something went wrong. Please try again.'); }
  finally { spinner.style.display = 'none'; }
}

// ── Escaping ───────────────────────────────────────────────────────────────
function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
function escAttr(str) { return escHtml(str).replace(/'/g, '&#39;'); }

// ── Event Wiring ───────────────────────────────────────────────────────────
function wire() {
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const tab = btn.dataset.tab;
      if (tab === 'library') nav('screen-library');
      if (tab === 'browse')  nav('screen-browse');
    });
  });

  document.getElementById('library-list').addEventListener('click', e => {
    const card = e.target.closest('[data-doc-id]');
    if (card) openDoc(card.dataset.docId);
  });
  document.getElementById('btn-settings').addEventListener('click', () => openModal('modal-settings'));
  document.getElementById('btn-add').addEventListener('click', () => {
    switchAddTab('paste');
    openModal('modal-add');
  });

  document.getElementById('btn-detail-back').addEventListener('click', () => nav('screen-library'));
  document.getElementById('btn-delete').addEventListener('click', deleteDoc);
  document.getElementById('btn-reset-progress').addEventListener('click', resetProgress);
  document.getElementById('btn-start-reading').addEventListener('click', startReading);
  document.getElementById('detail-preview').addEventListener('click', e => {
    const span = e.target.closest('[data-i]');
    if (!span) return;
    getDoc().progress = parseInt(span.dataset.i, 10);
    persist();
    openDoc(currentDocId);
  });

  document.getElementById('btn-flash-close').addEventListener('click', stopReading);
  document.getElementById('btn-flash-settings').addEventListener('click', () => openModal('modal-settings'));
  document.getElementById('flash-scrubber').addEventListener('input', e => scrubProgress(e.target.value));
  document.getElementById('flash-wpm-slider').addEventListener('input', e => onFlashWpmChange(e.target.value));

  const holdBtn = document.getElementById('hold-play-btn');
  holdBtn.addEventListener('mousedown',  startHold);
  holdBtn.addEventListener('mouseup',    stopHold);
  holdBtn.addEventListener('mouseleave', e => { if (reader.isPlaying) stopHold(e); });
  holdBtn.addEventListener('touchstart', startHold, { passive: false });
  holdBtn.addEventListener('touchend',   stopHold,  { passive: false });

  document.getElementById('setting-wpm').addEventListener('input', e => {
    document.getElementById('setting-wpm-val').textContent = e.target.value;
  });
  document.getElementById('setting-wpm').addEventListener('change', onSettingsChange);
  document.getElementById('setting-font').addEventListener('change', onSettingsChange);
  document.getElementById('setting-smart').addEventListener('change', onSettingsChange);
  document.getElementById('setting-chunk').addEventListener('change', onSettingsChange);
  document.getElementById('setting-context').addEventListener('change', onSettingsChange);

  document.getElementById('btn-confirm-add').addEventListener('click', addDocument);
  document.getElementById('file-upload').addEventListener('change', handleFileUpload);
  document.querySelectorAll('.add-tab').forEach(btn => {
    btn.addEventListener('click', () => switchAddTab(btn.dataset.addTab));
  });

  document.querySelectorAll('.modal-close').forEach(btn => {
    btn.addEventListener('click', () => closeModal(btn.dataset.modal));
  });
  document.querySelectorAll('.modal').forEach(modal => {
    modal.addEventListener('click', e => {
      if (e.target === modal) closeModal(modal.id);
    });
  });

  document.getElementById('browse-search').addEventListener('keydown', e => {
    if (e.key === 'Enter') searchWiki();
  });
  document.getElementById('chip-classics').addEventListener('click', loadClassics);
  document.getElementById('chip-wiki-daily').addEventListener('click', loadWikiDaily);

  document.getElementById('browse-results').addEventListener('click', e => {
    const card = e.target.closest('.card');
    if (!card) return;
    if (card.dataset.wikiTitle) importWiki(card.dataset.wikiTitle);
    if (card.dataset.gutenbergId) importGutenberg(card.dataset.gutenbergId, card.dataset.gutenbergTitle);
  });
}

// ── Seed data (first run only) ─────────────────────────────────────────────
function seedIfEmpty() {
  if (docs.length > 0) return;
  docs.push(createDoc(
    'Welcome to Readrrr',
    `Speed reading is not about skipping words — it's about eliminating subvocalization. Most people read at 200–300 WPM, limited by silently mouthing each word. RSVP (Rapid Serial Visual Presentation) breaks that habit by flashing one word at a time at a fixed focal point. The red letter marks the Optimal Recognition Point — the spot your eye should fixate on. Your brain fills in the rest. Start at 300 WPM and work up gradually. Within a week most readers comfortably reach 500–600 WPM with good retention. The key is consistency: read something every day. Use the Browse tab to import Wikipedia articles or classic novels from Project Gutenberg. Tap the + button to paste any text from the web. Hold the button below to begin.`
  ));
  persist();
}

// ── PWA ────────────────────────────────────────────────────────────────────
function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) return;
  // Only activate SW in production — dev server + SW = stale CSS
  if (import.meta.env.PROD) {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  } else {
    navigator.serviceWorker.getRegistrations().then(regs =>
      regs.forEach(r => r.unregister())
    );
  }
}

// ── Init ───────────────────────────────────────────────────────────────────
function init() {
  seedIfEmpty();
  applySettings();
  wire();
  renderLibrary();
  registerServiceWorker();
}

init();
