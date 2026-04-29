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
