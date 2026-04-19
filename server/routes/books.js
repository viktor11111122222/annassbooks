const express = require('express');
const router  = express.Router();
const db      = require('../db');

const STORE_LABELS = {
  kreativni_centar: 'Kreativni Centar',
  data_status:      'Data Status',
  laguna:           'Laguna',
};

// GET /api/books/featured?limit=12
// Returns a random selection from top-500 books by price (proxy for popularity)
router.get('/featured', (req, res) => {
  try {
    const limit = Math.min(20, parseInt(req.query.limit) || 12);
    const rows = db.prepare(`
      SELECT id, title, author, cover_url, category, min_price, store_count FROM (
        SELECT b.id, b.title, b.author, b.cover_url, b.category,
               MIN(l.price) AS min_price,
               COUNT(DISTINCT l.store) AS store_count
        FROM books b
        JOIN listings l ON l.book_id = b.id AND l.in_stock = 1
        WHERE b.cover_url IS NOT NULL AND b.cover_url != ''
        GROUP BY b.id
        ORDER BY min_price DESC
        LIMIT 500
      ) ORDER BY RANDOM() LIMIT ?
    `).all(limit);
    res.json(rows);
  } catch (e) {
    console.error('GET /books/featured:', e);
    res.status(500).json({ message: 'Server error.' });
  }
});

// GET /api/categories
router.get('/categories', (req, res) => {
  try {
    const rows = db.prepare(`
      SELECT COALESCE(b.category, 'ostalo') AS category, COUNT(DISTINCT b.id) AS count
      FROM books b
      JOIN listings l ON l.book_id = b.id AND l.in_stock = 1
      GROUP BY category
      HAVING category IS NOT NULL
      ORDER BY count DESC
    `).all();
    res.json(rows);
  } catch (e) {
    console.error('GET /categories:', e);
    res.status(500).json({ message: 'Server error.' });
  }
});

// GET /api/books?page=1&limit=30&q=searchterm&category=romani
router.get('/', (req, res) => {
  try {
    const page     = Math.max(1, parseInt(req.query.page)  || 1);
    const limit    = Math.min(50, parseInt(req.query.limit) || 30);
    const q        = (req.query.q || '').trim();
    const category = (req.query.category || '').trim();
    const author   = (req.query.author || '').trim();
    const offset   = (page - 1) * limit;

    const conditions = ['l.in_stock = 1'];
    const params     = [];

    if (q) {
      conditions.push('(b.title LIKE ? OR b.author LIKE ?)');
      params.push(`%${q}%`, `%${q}%`);
    }
    if (category) {
      conditions.push('COALESCE(b.category, \'ostalo\') = ?');
      params.push(category);
    }
    if (author) {
      conditions.push('b.author = ?');
      params.push(author);
    }

    const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

    const rows = db.prepare(`
      SELECT b.id, b.title, b.author, b.cover_url, b.category,
             MIN(l.price) AS min_price,
             COUNT(DISTINCT l.store) AS store_count
      FROM books b
      JOIN listings l ON l.book_id = b.id
      ${where}
      GROUP BY b.id
      ORDER BY b.title
      LIMIT ? OFFSET ?
    `).all(...params, limit, offset);

    const total = db.prepare(`
      SELECT COUNT(DISTINCT b.id) AS n
      FROM books b
      JOIN listings l ON l.book_id = b.id
      ${where}
    `).get(...params).n;

    res.json({ books: rows, total, page, limit });
  } catch (e) {
    console.error('GET /books:', e);
    res.status(500).json({ message: 'Server error.' });
  }
});

// GET /api/books/:id  — full detail with all store listings sorted by price
router.get('/:id', (req, res) => {
  try {
    const book = db.prepare('SELECT * FROM books WHERE id = ?').get(req.params.id);
    if (!book) return res.status(404).json({ message: 'Book not found.' });

    const listings = db.prepare(`
      SELECT store, store_url, price, in_stock
      FROM listings
      WHERE book_id = ?
      ORDER BY price ASC
    `).all(book.id).map(l => ({
      ...l,
      store_label: STORE_LABELS[l.store] || l.store,
    }));

    res.json({ ...book, listings });
  } catch (e) {
    console.error('GET /books/:id:', e);
    res.status(500).json({ message: 'Server error.' });
  }
});

module.exports = router;
