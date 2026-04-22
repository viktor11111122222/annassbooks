const Database = require('better-sqlite3');
const path = require('path');

const db = new Database(path.join(__dirname, 'anasbooks.db'));

// Performanse
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    email         TEXT    UNIQUE NOT NULL COLLATE NOCASE,
    password_hash TEXT    NOT NULL,
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS password_resets (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER  NOT NULL,
    token      TEXT     NOT NULL,
    expires_at DATETIME NOT NULL,
    used       INTEGER  DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );
`);

// Add apple_id column if it doesn't exist yet (safe to run on existing DBs)
try { db.exec(`ALTER TABLE users ADD COLUMN apple_id TEXT UNIQUE`); } catch {}
try { db.exec(`ALTER TABLE books ADD COLUMN category TEXT DEFAULT 'ostalo'`); } catch {}
try { db.exec(`ALTER TABLE books ADD COLUMN category_verified INTEGER DEFAULT 0`); } catch {}
try { db.exec(`CREATE INDEX IF NOT EXISTS idx_books_category ON books(category)`); } catch {}
try {
  db.exec(`
    CREATE TABLE IF NOT EXISTS wishlists (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      book_id  INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
      added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(user_id, book_id)
    );
    CREATE INDEX IF NOT EXISTS idx_wishlists_user ON wishlists(user_id);
  `);
} catch {}

// ── Books & listings ──────────────────────────────────────────────────────────

db.exec(`
  CREATE TABLE IF NOT EXISTS books (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    isbn           TEXT UNIQUE,
    normalized_key TEXT UNIQUE,          -- fallback dedup: title|author normalized
    title          TEXT NOT NULL,
    author         TEXT NOT NULL,
    description    TEXT,
    cover_url      TEXT,
    created_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS listings (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    book_id      INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    store        TEXT    NOT NULL,        -- 'kreativni_centar' | 'data_status' | 'laguna' …
    store_url    TEXT    NOT NULL,
    price        INTEGER NOT NULL,        -- RSD, no decimals
    in_stock     INTEGER DEFAULT 1,
    last_scraped DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(book_id, store)
  );

  CREATE INDEX IF NOT EXISTS idx_listings_book ON listings(book_id);
  CREATE INDEX IF NOT EXISTS idx_books_isbn    ON books(isbn);
  CREATE INDEX IF NOT EXISTS idx_books_key     ON books(normalized_key);
`);

module.exports = db;
