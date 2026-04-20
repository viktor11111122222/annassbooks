const axios = require('axios');

const http = axios.create({
  timeout: 15000,
  headers: {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'sr-RS,sr;q=0.9,en;q=0.8',
  },
});

/** Pause between requests so we don't hammer servers */
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

/** Normalize title+author into a stable dedup key */
function normalizeKey(title, author) {
  const norm = (s) =>
    (s || '')
      .toLowerCase()
      .replace(/[čćžšđ]/g, c => ({ č:'c',ć:'c',ž:'z',š:'s',đ:'d' })[c] || c)
      .replace(/[^a-z0-9]/g, '')
      .trim();
  return `${norm(title)}|${norm(author)}`;
}

/** Parse price string like "1.530,00 дин." or "1,090.00 RSD" → integer RSD */
function parsePrice(str) {
  if (!str) return null;
  // Remove currency symbols and whitespace
  let s = str.replace(/[^\d.,]/g, '');
  // Handle Serbian format: 1.530,00 → 1530
  if (s.includes(',') && s.includes('.')) {
    // Could be "1.530,00" (SR) or "1,530.00" (EN)
    const lastDot   = s.lastIndexOf('.');
    const lastComma = s.lastIndexOf(',');
    if (lastComma > lastDot) {
      // SR format: 1.530,00
      s = s.replace(/\./g, '').replace(',', '.');
    } else {
      // EN format: 1,530.00
      s = s.replace(/,/g, '');
    }
  } else if (s.includes(',')) {
    s = s.replace(',', '.');
  }
  const n = parseFloat(s);
  return isNaN(n) ? null : Math.round(n);
}

/** Extract JSON-LD product schema from HTML string */
function extractJsonLd(html) {
  const matches = [...html.matchAll(/<script[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/gi)];
  for (const m of matches) {
    try {
      const data = JSON.parse(m[1]);
      const items = Array.isArray(data) ? data : (data['@graph'] ? data['@graph'] : [data]);
      for (const item of items) {
        if (item['@type'] === 'Product' || item['@type'] === 'Book') return item;
      }
    } catch {}
  }
  return null;
}

// ── Category mapping from store-provided genres ───────────────────────────────

// Tags that indicate category on their own, NOT meta-labels to skip
const LAGUNA_META_TAGS = new Set([
  'domaći autori', 'nagrađene knjige', 'potpisane knjige',
  'ekranizovane knjige', 'za poklon', 'specijalna ponuda',
  'bestseler', 'novo', 'preporučujemo',
]);

const LAGUNA_GENRE_MAP = {
  'knjige za decu':        'deca',
  'za decu':               'deca',
  'deca':                  'deca',
  'edukativni za decu':    'deca',
  'tinejdž':               'deca',
  'tinejdzeri':            'deca',
  'young adult':           'deca',
  'drama':                 'romani',
  'ljubavni':              'romani',
  'ljubav':                'romani',
  'trileri':               'romani',
  'triler':                'romani',
  'krimić':                'romani',
  'krimi':                 'romani',
  'fantastika':            'romani',
  'naučna fantastika':     'romani',
  'humor':                 'romani',
  'komedija':              'romani',
  'satira':                'romani',
  'avanturistički':        'romani',
  'avantura':              'romani',
  'roman':                 'romani',
  'romani':                'romani',
  'klasici':               'romani',
  'klasična književnost':  'romani',
  'poezija':               'romani',
  'erotski':               'romani',
  'priče':                 'romani',
  'kratke priče':          'romani',
  'horror':                'romani',
  'horor':                 'romani',
  'istorijski':            'istorija',
  'istorija':              'istorija',
  'dokumentarni':          'istorija',
  'politika':              'istorija',
  'popularna psihologija': 'psihologija',
  'psihologija':           'psihologija',
  'self-help':             'psihologija',
  'lični razvoj':          'psihologija',
  'duh i telo':            'psihologija',
  'motivacija':            'psihologija',
  'biografija':            'biografije',
  'memoari':               'biografije',
  'autobiografija':        'biografije',
  'edukativni':            'nauka',
  'nauka':                 'nauka',
  'naučno-popularna':      'nauka',
  'priručnici':            'nauka',
  'tehnologija':           'nauka',
  'priroda':               'nauka',
  'medicina':              'nauka',
  'kulinarski':            'kuvari',
  'kuvanje':               'kuvari',
  'gastronomija':          'kuvari',
  'recepti':               'kuvari',
  'religija':              'religija',
  'duhovnost':             'religija',
  'spiritualnost':         'religija',
  'teologija':             'religija',
  'poslovne knjige':       'biznis',
  'biznis':                'biznis',
  'ekonomija':             'biznis',
  'menadžment':            'biznis',
  'marketing':             'biznis',
  'finansije':             'biznis',
  'filozofija':            'filozofija',
  'etika':                 'filozofija',
  'umetnost':              'umetnost',
  'muzika':                'umetnost',
  'film':                  'umetnost',
  'arhitektura':           'umetnost',
  'fotografija':           'umetnost',
  'dizajn':                'umetnost',
  'likovna umetnost':      'umetnost',
  'putopisi':              'ostalo',
  'publicistika':          'ostalo',
  'esej':                  'ostalo',
};

const KC_URL_MAP = {
  'za-decu':              'deca',
  'edukativni':           'nauka',
  'romani':               'romani',
  'istorija':             'istorija',
  'psihologija':          'psihologija',
  'biznis':               'biznis',
  'filozofija':           'filozofija',
  'religija':             'religija',
  'umetnost':             'umetnost',
  'kuvari':               'kuvari',
  'prirodne-nauke':       'nauka',
  'drustvene-nauke':      'nauka',
  'strucna-literatura':   'nauka',
  'biografije':           'biografije',
};

function mapLagunaGenres(genreText) {
  if (!genreText) return null;
  const genres = genreText
    .replace(/^[Žž]anrovi\s*:\s*/i, '')
    .split(',')
    .map(g => g.trim().toLowerCase())
    .filter(g => g.length > 0);

  if (!genres.length) return null;

  // Filter out meta-tags (not real genre indicators)
  const realGenres = genres.filter(g => !LAGUNA_META_TAGS.has(g));

  // "za decu" takes priority over everything
  if (realGenres.some(g => g.includes('za decu') || g.includes('deca') || g === 'dete' || g === 'tinejdž')) return 'deca';

  for (const genre of realGenres) {
    const mapped = LAGUNA_GENRE_MAP[genre];
    if (mapped) return mapped;
    // partial match — only if genre string is long enough to avoid false positives
    for (const [key, cat] of Object.entries(LAGUNA_GENRE_MAP)) {
      if (genre.length >= 5 && key.length >= 5 && (genre.includes(key) || key.includes(genre))) return cat;
    }
  }
  return realGenres.length ? 'ostalo' : null;
}

function mapKcBreadcrumb(breadcrumbItems) {
  // items: array of {name, item: {id}} from BreadcrumbList
  for (const item of breadcrumbItems.slice().reverse()) {
    const url = item?.item?.['@id'] || '';
    const segments = url.replace(/\/$/, '').split('/').filter(Boolean);
    for (const seg of segments.reverse()) {
      if (KC_URL_MAP[seg]) return KC_URL_MAP[seg];
      // "za-decu" check
      if (seg.includes('za-decu') || seg.includes('deca') || seg.includes('dete')) return 'deca';
    }
  }
  return null;
}

module.exports = { http, sleep, normalizeKey, parsePrice, extractJsonLd, mapLagunaGenres, mapKcBreadcrumb };
