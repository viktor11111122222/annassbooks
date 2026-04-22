const express        = require('express');
const router         = express.Router();
const db             = require('../db');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

// GET /api/wishlist/ids  — lightweight: just book IDs
router.get('/ids', (req, res) => {
  try {
    const rows = db.prepare('SELECT book_id FROM wishlists WHERE user_id = ?').all(req.user.userId);
    res.json(rows.map(r => r.book_id));
  } catch (e) {
    res.status(500).json({ message: 'Server error.' });
  }
});

// GET /api/wishlist  — full book info
router.get('/', (req, res) => {
  try {
    const rows = db.prepare(`
      SELECT b.id, b.title, b.author, b.cover_url, b.category,
             MIN(l.price)        AS min_price,
             COUNT(DISTINCT l.store) AS store_count,
             w.added_at
      FROM wishlists w
      JOIN books b    ON b.id = w.book_id
      LEFT JOIN listings l ON l.book_id = b.id AND l.in_stock = 1
      WHERE w.user_id = ?
      GROUP BY b.id
      ORDER BY w.added_at DESC
    `).all(req.user.userId);
    res.json(rows);
  } catch (e) {
    res.status(500).json({ message: 'Server error.' });
  }
});

// POST /api/wishlist/:bookId  — add
router.post('/:bookId', (req, res) => {
  try {
    const bookId = parseInt(req.params.bookId);
    if (!db.prepare('SELECT id FROM books WHERE id = ?').get(bookId))
      return res.status(404).json({ message: 'Book not found.' });
    db.prepare('INSERT OR IGNORE INTO wishlists (user_id, book_id) VALUES (?, ?)').run(req.user.userId, bookId);
    res.json({ message: 'Added to wishlist.' });
  } catch (e) {
    res.status(500).json({ message: 'Server error.' });
  }
});

// DELETE /api/wishlist/:bookId  — remove
router.delete('/:bookId', (req, res) => {
  try {
    db.prepare('DELETE FROM wishlists WHERE user_id = ? AND book_id = ?').run(req.user.userId, parseInt(req.params.bookId));
    res.json({ message: 'Removed from wishlist.' });
  } catch (e) {
    res.status(500).json({ message: 'Server error.' });
  }
});

module.exports = router;
