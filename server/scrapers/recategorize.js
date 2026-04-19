/**
 * Background job: fetch real categories from store pages for existing books.
 * Runs once at startup, processes only books with category_verified = 0.
 * Throttled to avoid hammering the stores.
 *
 * Also provides a fast keyword-based seed so chips appear immediately,
 * then HTTP verification corrects categories over time.
 */

const db = require('../db');
const { http, sleep, mapLagunaGenres, mapKcBreadcrumb } = require('./utils');
const cheerio = require('cheerio');

const DELAY = 250; // ms between requests

async function fetchLagunaCategory(storeUrl) {
  try {
    const { data } = await http.get(storeUrl, { timeout: 10000 });
    const $ = cheerio.load(data);
    let genreText = null;
    $('*').each((_, el) => {
      const t = $(el).text().trim();
      if (t.startsWith('Žanrovi:') && t.length > 9 && t.length < 200) {
        if (!genreText || t.length < genreText.length) genreText = t;
      }
    });
    return mapLagunaGenres(genreText) || null;
  } catch {
    return null;
  }
}

async function fetchKcCategory(storeUrl) {
  try {
    const { data } = await http.get(storeUrl, { timeout: 10000 });
    const $ = cheerio.load(data);
    let category = null;
    $('script[type="application/ld+json"]').each((_, el) => {
      try {
        const d = JSON.parse($(el).html());
        if (d['@type'] === 'BreadcrumbList') {
          category = mapKcBreadcrumb(d.itemListElement || []);
          return false;
        }
      } catch {}
    });
    return category;
  } catch {
    return null;
  }
}

async function recategorizeAll() {
  const updateStmt = db.prepare(
    `UPDATE books SET category = ?, category_verified = 1 WHERE id = ?`
  );

  const rows = db.prepare(`
    SELECT b.id, l.store, l.store_url
    FROM books b
    JOIN listings l ON l.book_id = b.id
    WHERE b.category_verified = 0
    ORDER BY b.id
  `).all();

  if (!rows.length) {
    console.log('[Recategorize] All books already verified.');
    return;
  }

  console.log(`[Recategorize] Starting background categorization of ${rows.length} books...`);
  let done = 0, updated = 0;

  for (const row of rows) {
    // Check if another listing already verified this book while we were running
    const book = db.prepare('SELECT category_verified FROM books WHERE id = ?').get(row.id);
    if (book?.category_verified) { done++; continue; }

    let category = null;
    if (row.store === 'laguna') {
      category = await fetchLagunaCategory(row.store_url);
    } else if (row.store === 'kreativni_centar') {
      category = await fetchKcCategory(row.store_url);
    }

    updateStmt.run(category || 'ostalo', row.id);
    if (category) updated++;

    done++;
    if (done % 100 === 0) {
      console.log(`[Recategorize] ${done}/${rows.length} processed, ${updated} updated`);
    }

    await sleep(DELAY);
  }

  console.log(`[Recategorize] Done — ${updated}/${rows.length} books categorized`);
}

// ── Fast keyword seed (synchronous, runs before HTTP migration) ───────────────

const SEED_RULES = [
  // Very high-confidence deca markers
  ['deca', [
    'bajka', 'bajke', 'slikovnic', 'za decu', 'za djecu', 'za najmlađe',
    'dečija', 'dečiji', 'dečije', 'djeteta', 'dečak i', 'devojčic',
    'beba ', 'mala enciklopedij', 'bojank', 'tinejdž',
  ]],
  // Kuvari — very distinctive
  ['kuvari', ['kuvar', 'recepti', 'kuhinja', 'gastronomij', 'kolači', 'torte', 'poslastic']],
  // Religija
  ['religija', ['biblij', 'pravoslav', 'jevanđelj', 'bogoslužb', 'liturgij', 'sveto pismo']],
  // Istorija — specific enough
  ['istorija', ['istorij', 'arheolog', 'drugi svetski rat', 'prvi svetski rat', 'hronik', 'imperij']],
  // Psihologija
  ['psihologija', ['psiholog', 'terapij', 'mentalno zdravlj', 'popularna psihologij']],
  // Biznis
  ['biznis', ['menadžment', 'marketing', 'preduzetništv', 'investicij']],
  // Filozofija
  ['filozofija', ['filozofij', 'egzistencij', 'stoicism', 'stoiciz']],
  // Nauka
  ['nauka', ['programiran', 'mašinsk učenj', 'veštačk inteligencij', 'kvantna fizik']],
  // Umetnost
  ['umetnost', ['istorija umetnost', 'likovna umetnost', 'arhitektur']],
];

function seedCategories() {
  const books = db.prepare('SELECT id, title, description FROM books WHERE category IS NULL OR category = \'ostalo\'').all();
  if (!books.length) return;

  const update = db.prepare('UPDATE books SET category = ? WHERE id = ?');
  const run = db.transaction(() => {
    let changed = 0;
    for (const b of books) {
      const text = ((b.title || '') + ' ' + (b.description || '')).toLowerCase();
      for (const [cat, keywords] of SEED_RULES) {
        if (keywords.some(kw => text.includes(kw))) {
          update.run(cat, b.id);
          changed++;
          break;
        }
      }
    }
    return changed;
  });
  const n = run();
  if (n > 0) console.log(`[Recategorize] Keyword seed applied to ${n} books`);
}

module.exports = { recategorizeAll, seedCategories };
