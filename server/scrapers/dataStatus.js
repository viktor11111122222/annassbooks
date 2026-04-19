const cheerio = require('cheerio');
const { http, sleep, parsePrice, extractJsonLd } = require('./utils');

const BASE  = 'https://datastatus.rs';
const STORE = 'data_status';
const DELAY = 250;

async function getBookUrls() {
  const urls = new Set();
  // DataStatus blocks sitemap for bots — scrape category pages directly
  let page = 1;
  while (true) {
    try {
      const { data } = await http.get(`${BASE}/product-category/knjige/page/${page}/`);
      const matches = [...data.matchAll(/href="(https:\/\/datastatus\.rs\/knjige\/[^"]+)"/g)];
      const newUrls = [...new Set(matches.map(m => m[1]))];
      if (!newUrls.length) break;
      newUrls.forEach(u => urls.add(u));
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

    const title  = ld?.name        || $('h1.product_title').text().trim();
    const author = ld?.author?.[0]?.name || ld?.author?.name
                || $('span.author a').first().text().trim()
                || null;
    const cover  = ld?.image       || $('img.wp-post-image').attr('src')
                || $('img.wp-post-image').attr('data-src') || null;
    const desc   = ld?.description || $('meta[name="description"]').attr('content') || null;
    const isbn   = ld?.isbn        || $('[itemprop="isbn"]').text().trim() || null;

    // WooCommerce: prefer sale price (ins), otherwise regular
    let priceEl = $('span.price > ins span.woocommerce-Price-amount bdi');
    if (!priceEl.length) priceEl = $('span.price span.woocommerce-Price-amount bdi');
    const price = parsePrice(priceEl.first().text());

    if (!title || !price) return null;

    return {
      store: STORE,
      store_url: url,
      isbn: isbn || null,
      title,
      author: author || 'Nepoznat autor',
      description: desc,
      cover_url: cover || null,
      price,
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
