const cheerio = require('cheerio');
const { http, sleep, parsePrice, extractJsonLd, mapKcBreadcrumb } = require('./utils');

const BASE = 'https://kreativnicentar.rs';
const STORE = 'kreativni_centar';
const DELAY = 250; // ms between requests

async function getBookUrls() {
  const urls = new Set();
  try {
    // Main sitemap is an index — products are in proizvodi.php
    const { data } = await http.get(`${BASE}/sitemaps/proizvodi.php`);
    // Sitemap uses ns1: namespace prefix
    const matches = [...data.matchAll(/<(?:ns1:)?loc>(https:\/\/kreativnicentar\.rs\/p\/knjiga\/[^<]+)<\/(?:ns1:)?loc>/g)];
    matches.forEach(m => urls.add(m[1]));
  } catch (e) {
    console.error('[KreativniCentar] sitemap error:', e.message);
  }
  return [...urls];
}

async function scrapeBook(url) {
  try {
    const { data: html } = await http.get(url);
    const $  = cheerio.load(html);
    const ld = extractJsonLd(html);

    // JSON-LD is most reliable when available
    const title  = ld?.name        || $('h1').first().text().trim();
    const author = ld?.author?.[0]?.name || ld?.author?.name
                || $('a[href*="/a/"]').first().text().trim();
    const cover  = ld?.image       || $('img[src*="/data/v/"]').first().attr('src');
    const desc   = ld?.description || $('meta[name="description"]').attr('content') || null;
    const isbn   = ld?.isbn        || null;

    // Price: prefer discounted (last <strong> with "дин"), else first
    let priceStr = null;
    $('strong').each((_, el) => {
      const t = $(el).text();
      if (t.includes('дин') || t.includes('din') || t.toLowerCase().includes('rsd')) {
        priceStr = t;
      }
    });
    const price = parsePrice(priceStr);

    if (!title || !price) return null;

    // Extract category from BreadcrumbList JSON-LD
    let category = 'ostalo';
    $('script[type="application/ld+json"]').each((_, el) => {
      try {
        const d = JSON.parse($(el).html());
        if (d['@type'] === 'BreadcrumbList') {
          const mapped = mapKcBreadcrumb(d.itemListElement || []);
          if (mapped) { category = mapped; return false; }
        }
      } catch {}
    });

    return {
      store: STORE,
      store_url: url,
      isbn: isbn || null,
      title,
      author: author || 'Nepoznat autor',
      description: desc,
      cover_url: cover ? (cover.startsWith('http') ? cover : `${BASE}${cover}`) : null,
      price,
      category,
      category_verified: 1,
    };
  } catch (e) {
    console.error(`[KreativniCentar] error scraping ${url}:`, e.message);
    return null;
  }
}

async function run() {
  console.log('[KreativniCentar] Fetching book URLs...');
  const urls = await getBookUrls();
  console.log(`[KreativniCentar] Found ${urls.length} books`);

  const books = [];
  for (let i = 0; i < urls.length; i++) {
    const book = await scrapeBook(urls[i]);
    if (book) books.push(book);
    if (i % 20 === 0) console.log(`[KreativniCentar] ${i}/${urls.length}`);
    await sleep(DELAY);
  }

  console.log(`[KreativniCentar] Done — ${books.length} books scraped`);
  return books;
}

module.exports = { run };
