# Readrrr Clone — Codex Handoff

A working RSVP (Rapid Serial Visual Presentation) speed-reading web app. Pick up where this left off and ship the next iteration.

## What it is

A clone of the iOS Readrrr app: flashes one word at a time at a fixed focal point with the Optimal Recognition Point (ORP) letter highlighted in red. Imports text from paste, .txt/.md files, EPUB, PDF, Wikipedia, and Project Gutenberg. Persists library + settings + reading stats in localStorage.

## Tech stack

- **Vite 5** + vanilla JS ES modules (no framework)
- **JSZip** for EPUB parsing
- **pdfjs-dist** for PDF text extraction
- **Google Fonts**: Manrope (UI) + Playfair Display (flash word)
- **PWA**: manifest.json + service worker (production only)

## Run

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # outputs to dist/
```

## Status

### ✅ Done
- Library/Browse/Detail/Flash screens with tab navigation
- localStorage persistence (docs, settings, stats)
- Tokenizer with ORP calculation + smart-pause multipliers
- Reader state machine with play/pause/seekTo/setWpm/chunkSize
- Hold-to-read button (mouse + touch)
- Wikipedia search + most-viewed
- Project Gutenberg classics (uses cache/epub URL — most reliable)
- EPUB upload (spine-ordered via content.opf)
- PDF upload (pdfjs-dist worker via Vite ?url import)
- Settings: WPM, font size, smart pauses, chunk size (1/2/3), context bar
- Reading stats: words read, reading time, book count
- Sentence context bar in flash reader
- PWA manifest + service worker (prod-only registration)
- Custom design system (Manrope/Playfair, warm dark palette, accent red)

### 🐛 Watch out for
- **Service worker in dev** — only register in prod (`import.meta.env.PROD`). Otherwise CSS gets cached stale.
- **Chunk mode positioning** — single word anchors at `left: 35%` (ORP); multi-word switches to `left: 50%` (centered) to avoid clipping.
- **Gutenberg URLs** — try `cache/epub/{id}/pg{id}.txt` FIRST. Validate cleaned text > 2000 chars to reject 404 HTML pages.
- **EPUB parsing** — read spine order from .opf, not alphabetical filenames.
- **PDF worker** — must use `import workerUrl from 'pdfjs-dist/build/pdf.worker.mjs?url'` for Vite to bundle correctly.

### 🚧 Pitched but not built
- WPM history chart (last N sessions)
- Highlight/notes capture during reading
- Daily reading goal + streak
- Multi-language tokenizer (currently splits on whitespace only)
- Export library to JSON
- Resume audio cue / haptic feedback

## File tree

```
readrrr-clone/
├── index.html
├── manifest.json
├── package.json
├── public/
│   ├── sw.js
│   └── icon.svg
├── src/
│   ├── app.js          # main controller, all wiring
│   ├── browse.js       # Wikipedia + Gutenberg
│   ├── reader.js       # RSVP state machine
│   ├── store.js        # localStorage
│   ├── style.css       # full design system
│   └── tokenizer.js    # word splitting + ORP
├── .claude/commands/   # project-level skills
├── CLAUDE.md           # behavioral rules
└── PROMPT.md           # this file
```

## Design system

```css
--bg-dark:        #0d0d0d;   /* app background */
--bg-black:       #070707;   /* flash reader */
--bg-card:        #141414;
--text-primary:   #f0ece4;   /* warm white */
--text-secondary: #6b6560;
--accent:         #E24B4A;   /* ORP red */
--accent-glow:    rgba(226, 75, 74, 0.22);
--border:         #1e1c1a;

--font-base:  'Manrope', system-ui, sans-serif;
--font-serif: 'Playfair Display', Georgia, serif;  /* flash word only */
```

UI principles (frontend-design skill applied):
- Distinctive font pairing (NOT Inter/Roboto)
- Warm dark, not pure-black grey
- Single dominant accent (red); no purple gradients
- Tight letter-spacing (`-0.02em` to `-0.03em`) on headers
- Glow shadows only on accent elements (FAB, hold button playing)

## Core mechanics

**ORP calculation** (in `tokenizer.js`):
```js
orp = len <= 1 ? 0 : len <= 5 ? 1 : len <= 9 ? 2 : 3;
```

**Smart pause multipliers**:
- sentence end (`.!?`): 2.5×
- clause end (`,;:`): 1.5×
- long word (>12 chars): 1.4×
- medium word (>8 chars): 1.2×

**Delay formula** in `reader.js`:
```js
delay = (60000 / wpm) * (smartPauses ? maxMultiplierInChunk : 1);
```

**Chunk mode**: reader advances by `chunkSize` tokens per tick. `onWord` always receives an array. Multi-word display drops ORP, centers text, switches `flash-word.style.left` from `35%` → `50%`.

**Sentence context** (computed on the fly, not stored): scan back to last `[.!?]`, scan forward to next, join token raws with space.

---

Source code for every file follows in the next sections.

---

## `package.json`

```json
{
  "name": "readrrr-clone",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "devDependencies": {
    "vite": "^5.4.0"
  },
  "dependencies": {
    "jszip": "^3.10.1",
    "pdfjs-dist": "^4.4.168"
  }
}
```

## `manifest.json`

```json
{
  "name": "Readrrr",
  "short_name": "Readrrr",
  "description": "RSVP speed reading — one word at a time",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0d0d0d",
  "theme_color": "#0d0d0d",
  "icons": [
    { "src": "/icon.svg", "sizes": "any", "type": "image/svg+xml" }
  ]
}
```

## `public/icon.svg`

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 192 192">
  <rect width="192" height="192" rx="40" fill="#0d0d0d"/>
  <text x="96" y="138" font-family="Georgia, serif" font-size="130" font-weight="bold" fill="#E24B4A" text-anchor="middle">R</text>
</svg>
```

## `public/sw.js`

```js
const CACHE = 'readrrr-v1';

self.addEventListener('install', e => {
  self.skipWaiting();
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(['/', '/src/style.css', '/src/app.js']))
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  if (e.request.url.includes('wikipedia.org') ||
      e.request.url.includes('gutenberg.org') ||
      e.request.url.includes('allorigins')) {
    return;
  }
  e.respondWith(
    caches.match(e.request).then(r => r || fetch(e.request).then(res => {
      if (res.ok && e.request.method === 'GET') {
        const clone = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, clone));
      }
      return res;
    }))
  );
});
```

## `src/store.js`

```js
const DOCS_KEY     = 'readrrr_docs';
const SETTINGS_KEY = 'readrrr_settings';
const STATS_KEY    = 'readrrr_stats';

export const DEFAULT_SETTINGS = {
  wpm: 450,
  fontSize: 1.0,
  smartPauses: true,
  chunkSize: 1,
  showContext: false,
};

export const DEFAULT_STATS = {
  totalWordsRead: 0,
  totalMinutes: 0,
};

export function loadDocuments() {
  try { return JSON.parse(localStorage.getItem(DOCS_KEY)) ?? []; }
  catch { return []; }
}
export function saveDocuments(docs) {
  localStorage.setItem(DOCS_KEY, JSON.stringify(docs));
}
export function loadSettings() {
  try { return { ...DEFAULT_SETTINGS, ...JSON.parse(localStorage.getItem(SETTINGS_KEY)) }; }
  catch { return { ...DEFAULT_SETTINGS }; }
}
export function saveSettings(s) {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify(s));
}
export function loadStats() {
  try { return { ...DEFAULT_STATS, ...JSON.parse(localStorage.getItem(STATS_KEY)) }; }
  catch { return { ...DEFAULT_STATS }; }
}
export function saveStats(s) {
  localStorage.setItem(STATS_KEY, JSON.stringify(s));
}
```

## `src/tokenizer.js`

```js
const STRIP_RE = /^[.,!?;:"""'''()[\]{}\-–—]+|[.,!?;:"""'''()[\]{}\-–—]+$/g;
const SENTENCE_END_RE = /[.!?][""']?$/;
const CLAUSE_END_RE = /[,;:][""']?$/;

export function tokenize(text) {
  return text
    .split(/\s+/)
    .filter(w => w.length > 0)
    .map(raw => {
      const stripped = raw.replace(STRIP_RE, '') || raw;
      const len = stripped.length;

      let multiplier = 1;
      if (SENTENCE_END_RE.test(raw)) multiplier = 2.5;
      else if (CLAUSE_END_RE.test(raw)) multiplier = 1.5;
      else if (len > 12) multiplier = 1.4;
      else if (len > 8) multiplier = 1.2;

      const orp = len <= 1 ? 0 : len <= 5 ? 1 : len <= 9 ? 2 : 3;

      return { raw, stripped, multiplier, orp };
    });
}
```

## `src/reader.js`

```js
export class Reader {
  constructor({ onWord, onEnd } = {}) {
    this.onWord = onWord;
    this.onEnd = onEnd;
    this.isPlaying = false;
    this._timer = null;
    this._tokens = [];
    this._index = 0;
    this._wpm = 450;
    this._smartPauses = true;
    this._chunkSize = 1;
  }

  get index() { return this._index; }

  play(tokens, startIndex, wpm, smartPauses, chunkSize = 1) {
    if (this.isPlaying) return;
    this._tokens = tokens;
    this._index = Math.max(0, Math.min(startIndex, tokens.length - 1));
    this._wpm = wpm;
    this._smartPauses = smartPauses;
    this._chunkSize = Math.max(1, chunkSize);
    this.isPlaying = true;
    this._loop();
  }

  pause() {
    this.isPlaying = false;
    clearTimeout(this._timer);
    this._timer = null;
    return this._index;
  }

  seekTo(index) {
    this._index = Math.max(0, Math.min(index, this._tokens.length - 1));
    const chunk = this._tokens.slice(this._index, this._index + this._chunkSize);
    if (chunk.length) this.onWord?.(chunk, this._index);
  }

  setWpm(wpm) { this._wpm = wpm; }
  setChunkSize(n) { this._chunkSize = Math.max(1, n); }

  _loop() {
    if (!this.isPlaying) return;
    if (this._index >= this._tokens.length) {
      this.isPlaying = false;
      this.onEnd?.();
      return;
    }
    const chunk = this._tokens.slice(this._index, this._index + this._chunkSize);
    const mult = chunk.reduce((m, t) => Math.max(m, t.multiplier), 1);
    this.onWord?.(chunk, this._index);
    const delay = (60000 / this._wpm) * (this._smartPauses ? mult : 1);
    this._index += this._chunkSize;
    this._timer = setTimeout(() => this._loop(), delay);
  }
}
```

## `src/browse.js`

```js
const WIKI_API = 'https://en.wikipedia.org/w/api.php';
const ORIGINS = '&origin=*&format=json';

function stripHtml(html) {
  const div = document.createElement('div');
  div.innerHTML = html;
  return div.textContent ?? '';
}

export async function searchWikipedia(query) {
  const url = `${WIKI_API}?action=query&list=search&srsearch=${encodeURIComponent(query)}${ORIGINS}`;
  const data = await fetchJSON(url);
  return data.query.search.map(item => ({
    title: item.title,
    snippet: stripHtml(item.snippet),
    type: 'wiki',
  }));
}

export async function fetchWikiMostViewed() {
  const url = `${WIKI_API}?action=query&list=mostviewed${ORIGINS}`;
  const data = await fetchJSON(url);
  return data.query.mostviewed
    .filter(v => !v.title.startsWith('Special:') && !v.title.startsWith('Wikipedia:'))
    .slice(0, 12)
    .map(v => ({ title: v.title, snippet: 'Trending on Wikipedia today', type: 'wiki' }));
}

export async function fetchWikiArticle(title) {
  const url = `${WIKI_API}?action=query&prop=extracts&explaintext&exsectionformat=plain&titles=${encodeURIComponent(title)}${ORIGINS}`;
  const data = await fetchJSON(url);
  const pages = data.query.pages;
  const page = pages[Object.keys(pages)[0]];
  if (!page.extract) throw new Error('No content found');
  return { title: page.title, text: page.extract };
}

export const CLASSICS = [
  { id: '1342', title: 'Pride and Prejudice',               author: 'Jane Austen' },
  { id: '1661', title: 'The Adventures of Sherlock Holmes', author: 'Arthur Conan Doyle' },
  { id: '11',   title: "Alice's Adventures in Wonderland",  author: 'Lewis Carroll' },
  { id: '84',   title: 'Frankenstein',                      author: 'Mary Shelley' },
  { id: '1952', title: 'The Yellow Wallpaper',              author: 'Charlotte Perkins Gilman' },
  { id: '174',  title: 'The Picture of Dorian Gray',        author: 'Oscar Wilde' },
  { id: '98',   title: 'A Tale of Two Cities',              author: 'Charles Dickens' },
  { id: '2701', title: 'Moby Dick',                         author: 'Herman Melville' },
];

export async function fetchGutenberg(id, title) {
  const candidates = [
    `https://www.gutenberg.org/cache/epub/${id}/pg${id}.txt`,  // most reliable
    `https://www.gutenberg.org/files/${id}/${id}-0.txt`,
    `https://www.gutenberg.org/files/${id}/${id}.txt`,
  ];
  const proxy = 'https://api.allorigins.win/get?url=';
  for (const fileUrl of candidates) {
    try {
      const res = await fetch(proxy + encodeURIComponent(fileUrl));
      if (!res.ok) continue;
      const data = await res.json();
      const raw = data.contents ?? '';
      if (raw.length < 500) continue;
      const text = cleanGutenbergText(raw);
      if (text.length < 2000) continue; // reject 404 HTML pages
      return { title, text };
    } catch { /* try next */ }
  }
  throw new Error('Could not fetch book from Project Gutenberg');
}

function cleanGutenbergText(raw) {
  let text = raw;
  if (/<[a-z][\s\S]*>/i.test(text)) {
    const div = document.createElement('div');
    div.innerHTML = text;
    div.querySelectorAll('script, style').forEach(el => el.remove());
    text = div.textContent ?? '';
  }
  const startMatch = text.match(/\*{3}\s*START OF (?:THIS |THE )?PROJECT GUTENBERG[^\n]*/i);
  if (startMatch) text = text.slice(startMatch.index + startMatch[0].length);
  const endMatch = text.match(/\*{3}\s*END OF (?:THIS |THE )?PROJECT GUTENBERG[^\n]*/i);
  if (endMatch) text = text.slice(0, endMatch.index);
  return text.replace(/\r\n/g, '\n').replace(/\n{4,}/g, '\n\n\n').trim();
}

async function fetchJSON(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}
```

## `index.html`

Long inline SVG paths in icon buttons are Material Icons (gear, close, plus, back, search, edit, play, pause, etc.). Keep them verbatim.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="theme-color" content="#0d0d0d">
  <title>Readrrr</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="/src/style.css">
  <link rel="manifest" href="/manifest.json">
</head>
<body>

<div id="app">

  <!-- LIBRARY -->
  <div id="screen-library" class="screen active">
    <div class="header">
      <h1 class="header-title">Library</h1>
      <button class="icon-btn" id="btn-settings" aria-label="Settings">
        <svg viewBox="0 0 24 24"><!-- gear icon path --></svg>
      </button>
    </div>
    <div class="stats-bar">
      <div class="stat-item"><span class="stat-num" id="stat-words">0</span><span class="stat-lbl">words read</span></div>
      <div class="stat-item"><span class="stat-num" id="stat-time">0m</span><span class="stat-lbl">reading time</span></div>
      <div class="stat-item"><span class="stat-num" id="stat-books">0</span><span class="stat-lbl">books</span></div>
    </div>
    <div class="content" id="library-list"></div>
    <button class="fab" id="btn-add" aria-label="Add document">
      <svg viewBox="0 0 24 24"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/></svg>
    </button>
    <nav class="tab-bar">
      <button class="tab-btn active" data-tab="library">Library</button>
      <button class="tab-btn" data-tab="browse">Browse</button>
    </nav>
  </div>

  <!-- BROWSE -->
  <div id="screen-browse" class="screen">
    <div class="header"><h1 class="header-title">Browse</h1></div>
    <div class="content">
      <div class="search-bar">
        <svg class="icon-sm" viewBox="0 0 24 24"><!-- search icon --></svg>
        <input type="text" id="browse-search" placeholder="Search Wikipedia…" autocomplete="off">
        <div class="loading-spinner" id="search-spinner"></div>
      </div>
      <div class="chip-row">
        <button class="chip" id="chip-classics">E-Books</button>
        <button class="chip" id="chip-wiki-daily">Wiki Featured</button>
      </div>
      <div id="browse-results">
        <p class="empty-hint">Search for topics or browse classics to find something to read.</p>
      </div>
    </div>
    <nav class="tab-bar">
      <button class="tab-btn" data-tab="library">Library</button>
      <button class="tab-btn active" data-tab="browse">Browse</button>
    </nav>
  </div>

  <!-- DETAIL -->
  <div id="screen-detail" class="screen">
    <div class="header">
      <button class="icon-btn" id="btn-detail-back" aria-label="Back">
        <svg viewBox="0 0 24 24"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/></svg>
      </button>
      <button class="danger-btn" id="btn-delete">Delete</button>
    </div>
    <div class="content">
      <h1 id="detail-title" class="detail-title">Title</h1>
      <div class="card stat-card">
        <div class="stat-row">
          <span id="detail-pct" class="stat-big">0%</span>
          <span id="detail-words" class="stat-sub">0 / 0 words</span>
        </div>
        <div class="progress-track"><div id="detail-progress-bar" class="progress-fill" style="width:0%"></div></div>
        <div class="stat-row" style="margin-top:8px;">
          <span id="detail-eta" class="stat-sub"></span>
          <button class="reset-btn" id="btn-reset-progress">Reset</button>
        </div>
      </div>
      <p class="section-label">Preview — tap a word to jump</p>
      <div id="detail-preview" class="preview-text"></div>
      <button class="pill-button" id="btn-start-reading">Start Reading</button>
      <div class="notes-panel">
        <div class="notes-header">
          <span class="notes-title">Notes &amp; Highlights</span>
          <svg class="icon-sm" viewBox="0 0 24 24"><!-- edit icon --></svg>
        </div>
        <p class="notes-empty">Highlight text while reading to save it here.</p>
      </div>
    </div>
  </div>

  <!-- FLASH READER -->
  <div id="screen-flash" class="screen screen-black">
    <div class="header">
      <button class="icon-btn" id="btn-flash-close" aria-label="Close">
        <svg viewBox="0 0 24 24"><!-- close X icon --></svg>
      </button>
      <div class="flash-progress-wrap">
        <span id="flash-progress-text" class="flash-progress-text">0 / 0</span>
        <input type="range" id="flash-scrubber" class="flash-scrubber" min="0" max="100" value="0">
      </div>
      <button class="icon-btn" id="btn-flash-settings" aria-label="Settings">
        <svg viewBox="0 0 24 24"><!-- gear icon --></svg>
      </button>
    </div>

    <div class="flash-container" id="flash-container">
      <div class="guide-rails">
        <div class="tick top"></div>
        <div class="tick bottom"></div>
      </div>
      <div id="flash-word" class="flash-word">
        <span class="orp-pre"></span><span class="orp-red"></span><span class="orp-post"></span>
      </div>
    </div>

    <div id="context-bar" class="context-bar"></div>

    <div class="flash-controls">
      <button class="hold-play-btn" id="hold-play-btn">
        <svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
        Hold to Read
      </button>
    </div>

    <div class="reader-bottom">
      <span id="flash-wpm-label" class="wpm-label">450 WPM</span>
      <input type="range" id="flash-wpm-slider" class="wpm-slider" min="100" max="1000" step="10" value="450">
    </div>
  </div>

  <!-- MODAL: SETTINGS -->
  <div id="modal-settings" class="modal" role="dialog" aria-modal="true">
    <div class="modal-content">
      <div class="modal-header">
        <h2>Settings</h2>
        <button class="icon-btn modal-close" data-modal="modal-settings">
          <svg viewBox="0 0 24 24"><!-- close X --></svg>
        </button>
      </div>
      <div class="settings-row col">
        <span>Speed: <b id="setting-wpm-val">450</b> WPM</span>
        <input type="range" id="setting-wpm" min="100" max="1000" step="10" value="450">
      </div>
      <div class="settings-row">
        <span>Font Size</span>
        <select id="setting-font">
          <option value="0.8">Small</option>
          <option value="1.0" selected>Medium</option>
          <option value="1.3">Large</option>
        </select>
      </div>
      <div class="settings-row">
        <span>Smart Pauses</span>
        <input type="checkbox" id="setting-smart" checked>
      </div>
      <div class="settings-row">
        <span>Chunk Size</span>
        <select id="setting-chunk">
          <option value="1" selected>1 word</option>
          <option value="2">2 words</option>
          <option value="3">3 words</option>
        </select>
      </div>
      <div class="settings-row">
        <span>Context Bar</span>
        <input type="checkbox" id="setting-context">
      </div>
    </div>
  </div>

  <!-- MODAL: ADD DOCUMENT -->
  <div id="modal-add" class="modal" role="dialog" aria-modal="true">
    <div class="modal-content">
      <div class="modal-header">
        <h2>Add Document</h2>
        <button class="icon-btn modal-close" data-modal="modal-add">
          <svg viewBox="0 0 24 24"><!-- close X --></svg>
        </button>
      </div>
      <div class="add-tabs">
        <button class="add-tab active" data-add-tab="paste">Paste</button>
        <button class="add-tab" data-add-tab="upload">Upload</button>
      </div>
      <div id="add-paste-area">
        <div class="form-group">
          <label for="add-title">Title</label>
          <input type="text" id="add-title" placeholder="Optional">
        </div>
        <div class="form-group">
          <label for="add-text">Content</label>
          <textarea id="add-text" placeholder="Paste your text here…"></textarea>
        </div>
      </div>
      <div id="add-upload-area" style="display:none">
        <div class="form-group">
          <label for="file-upload">Upload .txt, .md, .epub, or .pdf</label>
          <input type="file" id="file-upload" accept=".txt,.md,.epub,.pdf">
        </div>
      </div>
      <button class="pill-button" id="btn-confirm-add">Add to Library</button>
    </div>
  </div>

</div>

<script type="module" src="/src/app.js"></script>
</body>
</html>
```

## `src/app.js`

```js
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
    flashWord.style.left = '50%';
    flashWord.querySelector('.orp-pre').textContent  = '';
    flashWord.querySelector('.orp-red').textContent  = chunks.map(t => t.stripped).join('  ');
    flashWord.querySelector('.orp-red').style.color  = 'var(--text-primary)';
    flashWord.querySelector('.orp-post').textContent = '';
  }

  document.getElementById('flash-progress-text').textContent = `${startIndex + 1} / ${total}`;
  document.getElementById('flash-scrubber').value = startIndex;

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
    } catch { alert('Could not read EPUB file. Try a different file.'); }
    return;
  }

  if (file.name.endsWith('.pdf')) {
    try {
      const text = await parsePdf(file);
      document.getElementById('add-title').value = title;
      document.getElementById('add-text').value = text;
      switchAddTab('paste');
    } catch { alert('Could not read PDF file. Try a different file.'); }
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
      .join(' ').replace(/\s+/g, ' ').trim();
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
  });
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
```
