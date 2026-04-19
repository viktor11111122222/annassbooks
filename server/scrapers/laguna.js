const cheerio = require('cheerio');
const { http, sleep, parsePrice, extractJsonLd, mapLagunaGenres } = require('./utils');

const BASE  = 'https://laguna.rs';
const STORE = 'laguna';
const DELAY = 200;

// Laguna titles: "Laguna - Title - Author - Tagline"
function extractLagunaTitle(raw) {
  const parts = raw.replace(/^Laguna\s*-\s*/i, '').split(' - ').map(s => s.trim()).filter(Boolean);
  return parts[0] || raw;
}

function extractLagunaAuthor(raw) {
  const parts = raw.replace(/^Laguna\s*-\s*/i, '').split(' - ').map(s => s.trim()).filter(Boolean);
  if (parts.length >= 3) return parts[parts.length - 2];
  if (parts.length === 2) return parts[1];
  return null;
}

async function getBookUrls() {
  const urls = new Set();
  let page = 1;
  while (true) {
    try {
      const { data } = await http.get(`${BASE}/sitemap/products/${page}/`);
      const matches = [...data.matchAll(/<loc>(https:\/\/laguna\.rs\/proizvodi\/knjige\/[^<]+)<\/loc>/g)];
      if (!matches.length) break;
      matches.forEach(m => urls.add(m[1]));
      page++;
      await sleep(400);
    } catch {
      break;
    }
  }
  return [...urls];
}

async function scrapeBook(url) {
  try {
    const { data: html } = await http.get(url);
    const $  = cheerio.load(html);
    const ld = extractJsonLd(html);

    const titleRaw = ld?.name || $('h1').first().text().trim();
    const title    = extractLagunaTitle(titleRaw);
    const author   = ld?.author?.[0]?.name || ld?.author?.name
                  || extractLagunaAuthor(titleRaw) || null;
    const cover  = ld?.image       || $('picture img').first().attr('src')
                || $('img[src*="laguna"]').first().attr('src') || null;
    const desc   = ld?.description || $('meta[property="og:description"]').attr('content') || null;
    const isbn   = ld?.isbn        || null;

    // Price: find element with "RSD", skip member price
    let price = null;
    if (ld?.offers?.price) {
      price = Math.round(parseFloat(ld.offers.price));
    } else {
      $('*').each((_, el) => {
        const t = $(el).text();
        if (t.includes('RSD') && !t.includes('Članska') && !t.includes('clanska')) {
          const p = parsePrice(t);
          if (p && p > 100) { price = p; return false; }
        }
      });
    }

    if (!title || !price) return null;

    // Extract genre from "Žanrovi: X, Y" text on the page
    let genreText = null;
    $('*').each((_, el) => {
      const t = $(el).text().trim();
      if (t.startsWith('Žanrovi:') && t.length > 9 && t.length < 200) {
        if (!genreText || t.length < genreText.length) genreText = t;
      }
    });
    const category = mapLagunaGenres(genreText) || 'ostalo';

    return {
      store: STORE,
      store_url: url,
      isbn: isbn || null,
      title,
      author: author || 'Nepoznat autor',
      description: desc,
      cover_url: cover || null,
      price,
      category,
      category_verified: 1,
    };
  } catch (e) {
    console.error(`[Laguna] error scraping ${url}:`, e.message);
    return null;
  }
}

async function run() {
  console.log('[Laguna] Fetching book URLs...');
  const urls = await getBookUrls();
  console.log(`[Laguna] Found ${urls.length} books`);

  const books = [];
  for (let i = 0; i < urls.length; i++) {
    const book = await scrapeBook(urls[i]);
    if (book) books.push(book);
    if (i % 20 === 0) console.log(`[Laguna] ${i}/${urls.length}`);
    await sleep(DELAY);
  }

  console.log(`[Laguna] Done — ${books.length} books scraped`);
  return books;
}

module.exports = { run };
