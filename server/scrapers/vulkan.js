const cheerio = require('cheerio');
const { http, sleep, parsePrice } = require('./utils');

const BASE  = 'https://www.knjizare-vulkan.rs';
const STORE = 'vulkan';
const LISTING_DELAY = 200;
const DETAIL_DELAY  = 250;

// Main categories — /domace-knjige covers all domestic publishers (Laguna, KC, etc.)
// /english-books covers foreign titles available in Serbia
const CATEGORIES = [
  '/domace-knjige',
  '/english-books',
];

async function getProductsFromPage(url) {
  try {
    const { data: html } = await http.get(url);
    const $ = cheerio.load(html);
    const products = [];
    const seen = new Set();

    // Products are in .products-new-list-wrapper > div with data-product* attrs
    $('.products-new-list-wrapper > div[data-productid][data-productname]').each((_, el) => {
      const d = el.attribs;
      const id = d['data-productid'];
      if (!id || !d['data-productname'] || seen.has(id)) return;
      seen.add(id);

      const link = $(el).find('a[href*="/"]').first().attr('href');
      if (!link) return;

      products.push({
        id,
        name: d['data-productname'].trim(),
        price: d['data-productprice'],
        url: link.startsWith('http') ? link : BASE + link,
      });
    });

    return products;
  } catch {
    return [];
  }
}

async function getTotalPages(categoryUrl) {
  try {
    const { data: html } = await http.get(`${BASE}${categoryUrl}/`);
    const $ = cheerio.load(html);

    // Pagination links use /category/page-N format
    let maxPage = 1;
    $('a[href]').each((_, el) => {
      const href = $(el).attr('href') || '';
      const m = href.match(/\/page-(\d+)/);
      if (m) maxPage = Math.max(maxPage, parseInt(m[1]));
    });
    return maxPage;
  } catch {
    return 1;
  }
}

async function scrapeDetail(url) {
  try {
    const { data: html } = await http.get(url);
    const $ = cheerio.load(html);

    // Author: structure is <span>Autor:</span><span>Name</span> inside a <div>
    let author = null;
    $('span, td').each((_, el) => {
      if (author) return false;
      const text = $(el).text().trim();
      if (/^Autor\s*:$/i.test(text)) {
        const val = $(el).next().text().trim();
        if (val && val.length > 1 && val.length < 200) author = val;
      }
    });

    // ISBN: inside .code div with "Isbn:" prefix
    let isbn = null;
    $('[class*="code"]').each((_, el) => {
      const text = $(el).text().trim();
      if (/isbn/i.test(text)) {
        const m = text.match(/(\d{13})/);
        if (m) isbn = m[1];
      }
    });
    // Also check 13-digit numbers in product description area
    if (!isbn) {
      const m = html.match(/(?:ISBN|isbn)[:\s]+(\d{13})/);
      if (m) isbn = m[1];
    }

    // Cover image
    const cover = $('img[src*="slike_proizvoda"]').first().attr('src') ||
                  $('[class*="product-image"] img, [class*="gallery"] img').first().attr('src');
    const coverUrl = cover
      ? (cover.startsWith('http') ? cover : BASE + cover).replace('/thumbs_w/', '/thumbs_350/').replace(/_w_0_0px/, '_350_350px')
      : null;

    // Description
    const desc = $('[class*="product-desc"] p, [itemprop="description"]').first().text().trim() || null;

    return { author: author || null, isbn, cover_url: coverUrl, description: desc };
  } catch {
    return { author: null, isbn: null, cover_url: null, description: null };
  }
}

async function scrapeCategory(categoryPath) {
  console.log(`[Vulkan] Category: ${categoryPath}`);
  const totalPages = await getTotalPages(categoryPath);
  console.log(`[Vulkan] ${categoryPath}: ${totalPages} pages`);

  const allProducts = [];
  const seenIds = new Set();

  for (let page = 1; page <= totalPages; page++) {
    const url = page === 1
      ? `${BASE}${categoryPath}/`
      : `${BASE}${categoryPath}/page-${page}`;
    const products = await getProductsFromPage(url);

    let added = 0;
    for (const p of products) {
      if (!seenIds.has(p.id)) {
        seenIds.add(p.id);
        allProducts.push(p);
        added++;
      }
    }

    if (page % 50 === 0) console.log(`[Vulkan] ${categoryPath} page ${page}/${totalPages} (+${added})`);
    if (!products.length) break;
    await sleep(LISTING_DELAY);
  }

  console.log(`[Vulkan] ${categoryPath}: ${allProducts.length} products collected`);
  return allProducts;
}

// onBook(book) is called immediately after each detail fetch so callers can
// persist books incrementally instead of waiting for the full ~2hr scrape.
async function run(onBook) {
  console.log('[Vulkan] Starting scrape...');
  const allProducts = [];
  const seenIds = new Set();

  for (const cat of CATEGORIES) {
    const products = await scrapeCategory(cat);
    for (const p of products) {
      if (!seenIds.has(p.id)) {
        seenIds.add(p.id);
        allProducts.push(p);
      }
    }
  }

  console.log(`[Vulkan] Total unique products: ${allProducts.length}`);
  console.log('[Vulkan] Fetching product details (author, ISBN)...');

  const books = [];
  for (let i = 0; i < allProducts.length; i++) {
    const p = allProducts[i];
    const price = parsePrice(p.price);
    if (!price) continue;

    const detail = await scrapeDetail(p.url);

    const book = {
      store: STORE,
      store_url: p.url,
      isbn: detail.isbn,
      title: p.name,
      author: detail.author || 'Nepoznat autor',
      description: detail.description,
      cover_url: detail.cover_url,
      price,
    };

    if (onBook) {
      onBook(book);
    } else {
      books.push(book);
    }

    if (i % 100 === 0) console.log(`[Vulkan] Details ${i}/${allProducts.length}`);
    await sleep(DETAIL_DELAY);
  }

  console.log(`[Vulkan] Done — ${allProducts.length} books`);
  return books;
}

module.exports = { run };
