require('dotenv').config();
const express    = require('express');
const cors       = require('cors');
const cron       = require('node-cron');
const authRoutes     = require('./routes/auth');
const booksRoutes    = require('./routes/books');
const wishlistRoutes = require('./routes/wishlist');
const { runAll }  = require('./scrapers/index');
const { recategorizeAll, seedCategories } = require('./scrapers/recategorize');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.use('/api/auth',     authRoutes);
app.use('/api/books',    booksRoutes);
app.use('/api/wishlist', wishlistRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', app: 'AnasBooks API' });
});

app.listen(PORT, () => {
  console.log(`AnasBooks server → http://localhost:${PORT}`);

  // Fast keyword seed (sync, instant) then slow HTTP verification (async)
  seedCategories();
  recategorizeAll().catch(e => console.error('Recategorize failed:', e.message));

  // Run scraper immediately on first start, then every 6 hours
  runAll().catch(e => console.error('Initial scrape failed:', e.message));
  cron.schedule('0 */6 * * *', () => {
    runAll().catch(e => console.error('Scheduled scrape failed:', e.message));
  });
});
