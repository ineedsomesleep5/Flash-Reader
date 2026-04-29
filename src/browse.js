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
  { id: '1342',  title: 'Pride and Prejudice',           author: 'Jane Austen' },
  { id: '1661',  title: 'The Adventures of Sherlock Holmes', author: 'Arthur Conan Doyle' },
  { id: '11',    title: "Alice's Adventures in Wonderland", author: 'Lewis Carroll' },
  { id: '84',    title: 'Frankenstein',                  author: 'Mary Shelley' },
  { id: '1952',  title: 'The Yellow Wallpaper',          author: 'Charlotte Perkins Gilman' },
  { id: '174',   title: 'The Picture of Dorian Gray',   author: 'Oscar Wilde' },
  { id: '98',    title: 'A Tale of Two Cities',          author: 'Charles Dickens' },
  { id: '2701',  title: 'Moby Dick',                    author: 'Herman Melville' },
];

export async function fetchGutenberg(id, title) {
  const candidates = [
    // Cache mirror is most reliable — always try first
    `https://www.gutenberg.org/cache/epub/${id}/pg${id}.txt`,
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
      // Reject 404 pages and other non-book content
      if (text.length < 2000) continue;
      return { title, text };
    } catch { /* try next */ }
  }
  throw new Error('Could not fetch book from Project Gutenberg');
}

function cleanGutenbergText(raw) {
  // Strip HTML tags if the proxy returned HTML instead of plain text
  let text = raw;
  if (/<[a-z][\s\S]*>/i.test(text)) {
    const div = document.createElement('div');
    div.innerHTML = text;
    div.querySelectorAll('script, style').forEach(el => el.remove());
    text = div.textContent ?? '';
  }

  // Strip Project Gutenberg header (everything before the START marker)
  const startMatch = text.match(/\*{3}\s*START OF (?:THIS |THE )?PROJECT GUTENBERG[^\n]*/i);
  if (startMatch) {
    text = text.slice(startMatch.index + startMatch[0].length);
  }

  // Strip Project Gutenberg footer (everything after the END marker)
  const endMatch = text.match(/\*{3}\s*END OF (?:THIS |THE )?PROJECT GUTENBERG[^\n]*/i);
  if (endMatch) {
    text = text.slice(0, endMatch.index);
  }

  // Collapse excessive blank lines and trim
  return text.replace(/\r\n/g, '\n').replace(/\n{4,}/g, '\n\n\n').trim();
}

async function fetchJSON(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}
