const cheerio = require('cheerio');
const { http, sleep, parsePrice, extractJsonLd } = require('./utils');

const BASE  = 'https://datastatus.rs';
const STORE = 'data_status';
const DELAY = 300;

async function getBookUrls() {
  const seen = new Set();
  let page = 1;

  while (true) {
    try {
      const url = page === 1 ? `${BASE}/knjige/` : `${BASE}/knjige/page/${page}/`;
      const { data } = await http.get(url);
      const matches = [...data.matchAll(/href="(https:\/\/datastatus\.rs\/knjige\/[^"#?]+)"/g)];
      const newUrls = matches
        .map(m => m[1].replace(/\/$/, '') + '/')
        .filter(u => !/\/page\/|\/feed\/|\/category\/|\/tag\//.test(u))
        .filter(u => !seen.has(u));

      if (!newUrls.length) break;
      newUrls.forEach(u => seen.add(u));
      page++;
      await sleep(400);
    } catch {
      break;
    }
  }

  return [...seen];
}

function extractAuthor(ld, $) {
  // Data Status stores author in additionalProperty
  const props = ld?.additionalProperty || [];
  const authorProp = props.find(p => p.name === 'pa_book-author');
  if (authorProp?.value) return authorProp.value;

  // Fallback: standard schema author field
  return ld?.author?.[0]?.name || ld?.author?.name
      || $('span[itemprop="author"]').text().trim()
      || null;
}

async function scrapeBook(url) {
  try {
    const { data: html } = await http.get(url);
    const $  = cheerio.load(html);
    const ld = extractJsonLd(html);

    // Title: strip "| Data STATUS" suffix
    const rawTitle = ld?.name || $('h1.product_title').text().trim();
    const title = rawTitle?.replace(/\s*\|\s*Data STATUS\s*$/i, '').trim();

    const author = extractAuthor(ld, $) || 'Nepoznat autor';
    const isbn   = ld?.sku || $('[itemprop="isbn"]').text().trim() || null;
    const cover  = ld?.image?.[0]?.url || ld?.image || $('img.wp-post-image').attr('src') || null;
    const desc   = ld?.description || $('meta[name="description"]').attr('content') || null;

    // Price from JSON-LD offers
    const priceRaw = ld?.offers?.price;
    const price = priceRaw ? Math.round(parseFloat(priceRaw)) : parsePrice($('span.woocommerce-Price-amount bdi').first().text());

    const inStock = ld?.offers?.availability?.includes('InStock') ?? true;

    if (!title || !price) return null;

    return {
      store: STORE,
      store_url: url,
      isbn,
      title,
      author,
      description: desc,
      cover_url: cover,
      price,
      in_stock: inStock ? 1 : 0,
    };
  } catch (e) {
    console.error(`[DataStatus] error scraping ${url}:`, e.message);
    return null;
  }
}

async function run() {
  console.log('[DataStatus] Fetching book URLs...');
  const urls = await getBookUrls();
  console.log(`[DataStatus] Found ${urls.length} books`);

  const books = [];
  for (let i = 0; i < urls.length; i++) {
    const book = await scrapeBook(urls[i]);
    if (book) books.push(book);
    if (i % 20 === 0) console.log(`[DataStatus] ${i}/${urls.length}`);
    await sleep(DELAY);
  }

  console.log(`[DataStatus] Done — ${books.length} books scraped`);
  return books;
}

module.exports = { run };
