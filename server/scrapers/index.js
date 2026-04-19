const db              = require('../db');
const { normalizeKey } = require('./utils');
const kreativniCentar = require('./kreativniCentar');
const dataStatus      = require('./dataStatus');
const laguna          = require('./laguna');

const scrapers = [
  { name: 'Kreativni Centar', run: kreativniCentar.run },
  { name: 'Data Status',      run: dataStatus.run      },
  { name: 'Laguna',           run: laguna.run           },
];

// ── Deduplication + upsert ────────────────────────────────────────────────────

function upsertBook(entry) {
  const key = normalizeKey(entry.title, entry.author);

  // 1. Try ISBN match
  if (entry.isbn) {
    const existing = db.prepare('SELECT id FROM books WHERE isbn = ?').get(entry.isbn);
    if (existing) return existing.id;
  }

  // 2. Try normalized key match
  const byKey = db.prepare('SELECT id, category_verified FROM books WHERE normalized_key = ?').get(key);
  if (byKey) {
    const fields = ['cover_url = COALESCE(cover_url, ?)', 'description = COALESCE(description, ?)', 'isbn = COALESCE(isbn, ?)', 'updated_at = CURRENT_TIMESTAMP'];
    const params = [entry.cover_url, entry.description, entry.isbn];
    // Overwrite category only if this scrape has a verified category
    if (entry.category_verified) {
      fields.push('category = ?', 'category_verified = 1');
      params.push(entry.category || 'ostalo');
    }
    db.prepare(`UPDATE books SET ${fields.join(', ')} WHERE id = ?`).run(...params, byKey.id);
    return byKey.id;
  }

  // 3. Create new book
  const result = db.prepare(`
    INSERT INTO books (isbn, normalized_key, title, author, description, cover_url, category, category_verified)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(entry.isbn, key, entry.title, entry.author, entry.description, entry.cover_url,
         entry.category || 'ostalo', entry.category_verified ? 1 : 0);

  return result.lastInsertRowid;
}

function upsertListing(bookId, entry) {
  db.prepare(`
    INSERT INTO listings (book_id, store, store_url, price, in_stock, last_scraped)
    VALUES (?, ?, ?, ?, 1, CURRENT_TIMESTAMP)
    ON CONFLICT(book_id, store) DO UPDATE SET
      price        = excluded.price,
      store_url    = excluded.store_url,
      in_stock     = 1,
      last_scraped = CURRENT_TIMESTAMP
  `).run(bookId, entry.store, entry.store_url, entry.price);
}

// ── Main runner ───────────────────────────────────────────────────────────────

async function runAll() {
  console.log('\n═══ Scrape started', new Date().toISOString(), '═══');
  let totalNew = 0, totalUpdated = 0;

  for (const scraper of scrapers) {
    try {
      const books = await scraper.run();

      const saveAll = db.transaction((books) => {
        for (const b of books) {
          if (!b) continue;
          const bookId = upsertBook(b);
          upsertListing(bookId, b);
        }
      });
      saveAll(books);

      console.log(`[${scraper.name}] Saved ${books.length} listings`);
      totalUpdated += books.length;
    } catch (e) {
      console.error(`[${scraper.name}] FAILED:`, e.message);
    }
  }

  // Mark listings not updated in this run as out of stock
  db.prepare(`
    UPDATE listings SET in_stock = 0
    WHERE last_scraped < datetime('now', '-1 day')
  `).run();

  console.log(`═══ Scrape done — ${totalUpdated} listings processed ═══\n`);
}

module.exports = { runAll };
