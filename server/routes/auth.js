const express = require('express');
const router  = express.Router();
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const crypto  = require('crypto');
const https   = require('https');
const db      = require('../db');

const JWT_SECRET   = process.env.JWT_SECRET || 'dev-secret';
const SALT_ROUNDS  = 12;
const TOKEN_EXPIRY = '30d';

// ─── Apple Sign In helpers ────────────────────────────────────────────────────

let _appleKeys = null;
let _appleKeysFetched = 0;

function fetchAppleKeys() {
  const now = Date.now();
  if (_appleKeys && now - _appleKeysFetched < 3_600_000) return Promise.resolve(_appleKeys);
  return new Promise((resolve, reject) => {
    https.get('https://appleid.apple.com/auth/keys', res => {
      let raw = '';
      res.on('data', c => { raw += c; });
      res.on('end', () => {
        try {
          _appleKeys = JSON.parse(raw).keys;
          _appleKeysFetched = Date.now();
          resolve(_appleKeys);
        } catch (e) { reject(e); }
      });
    }).on('error', reject);
  });
}

async function verifyAppleToken(identityToken) {
  const keys = await fetchAppleKeys();
  const headerJson = Buffer.from(identityToken.split('.')[0], 'base64url').toString();
  const { kid } = JSON.parse(headerJson);
  const jwk = keys.find(k => k.kid === kid);
  if (!jwk) throw new Error('Apple public key not found');
  const pem = crypto.createPublicKey({ key: jwk, format: 'jwk' })
    .export({ type: 'spki', format: 'pem' });
  return jwt.verify(identityToken, pem, {
    algorithms: ['RS256'],
    issuer: 'https://appleid.apple.com',
    audience: 'vicko.anas-books',
  });
}

// ─── Registracija ────────────────────────────────────────────────────────────

router.post('/register', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password)
      return res.status(400).json({ message: 'Email i lozinka su obavezni.' });

    if (password.length < 6)
      return res.status(400).json({ message: 'Lozinka mora imati najmanje 6 karaktera.' });

    const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email.toLowerCase());
    if (existing)
      return res.status(409).json({ message: 'Ovaj email je već registrovan.' });

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    const result = db
      .prepare('INSERT INTO users (email, password_hash) VALUES (?, ?)')
      .run(email.toLowerCase(), passwordHash);

    const token = jwt.sign(
      { userId: result.lastInsertRowid, email: email.toLowerCase() },
      JWT_SECRET,
      { expiresIn: TOKEN_EXPIRY }
    );

    res.status(201).json({
      token,
      user: { id: result.lastInsertRowid, email: email.toLowerCase() }
    });
  } catch (err) {
    console.error('Register:', err);
    res.status(500).json({ message: 'Serverska greška. Pokušajte ponovo.' });
  }
});

// ─── Prijava ─────────────────────────────────────────────────────────────────

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password)
      return res.status(400).json({ message: 'Email i lozinka su obavezni.' });

    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email.toLowerCase());
    if (!user)
      return res.status(401).json({ message: 'Pogrešan email ili lozinka.' });

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid)
      return res.status(401).json({ message: 'Pogrešan email ili lozinka.' });

    const token = jwt.sign(
      { userId: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: TOKEN_EXPIRY }
    );

    res.json({ token, user: { id: user.id, email: user.email } });
  } catch (err) {
    console.error('Login:', err);
    res.status(500).json({ message: 'Serverska greška. Pokušajte ponovo.' });
  }
});

// ─── Zahtev za reset lozinke ─────────────────────────────────────────────────

router.post('/reset-password', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email)
      return res.status(400).json({ message: 'Email je obavezan.' });

    const user = db.prepare('SELECT id FROM users WHERE email = ?').get(email.toLowerCase());

    // Uvek vraćamo success da ne otkrijemo koji emailovi postoje
    if (!user)
      return res.json({ message: 'Ako nalog postoji, poslali smo email sa uputstvima.' });

    const token    = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString(); // 1h

    db.prepare('INSERT INTO password_resets (user_id, token, expires_at) VALUES (?, ?, ?)')
      .run(user.id, token, expiresAt);

    // TODO: Slanje emaila sa nodemailer kada se podesi SMTP
    // Za sada logujemo token u konzolu (development)
    console.log(`\n[Reset lozinke] ${email} → token: ${token}\n`);

    res.json({ message: 'Ako nalog postoji, poslali smo email sa uputstvima.' });
  } catch (err) {
    console.error('Reset password:', err);
    res.status(500).json({ message: 'Serverska greška. Pokušajte ponovo.' });
  }
});

// ─── Potvrda novom lozinkom ──────────────────────────────────────────────────

router.post('/reset-password/confirm', async (req, res) => {
  try {
    const { token, newPassword } = req.body;

    if (!token || !newPassword)
      return res.status(400).json({ message: 'Token i nova lozinka su obavezni.' });

    if (newPassword.length < 6)
      return res.status(400).json({ message: 'Lozinka mora imati najmanje 6 karaktera.' });

    const reset = db
      .prepare('SELECT * FROM password_resets WHERE token = ? AND used = 0')
      .get(token);

    if (!reset || new Date(reset.expires_at) < new Date())
      return res.status(400).json({ message: 'Link nije validan ili je istekao.' });

    const passwordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(passwordHash, reset.user_id);
    db.prepare('UPDATE password_resets SET used = 1 WHERE id = ?').run(reset.id);

    res.json({ message: 'Lozinka je uspešno promenjena.' });
  } catch (err) {
    console.error('Confirm reset:', err);
    res.status(500).json({ message: 'Serverska greška. Pokušajte ponovo.' });
  }
});

// ─── Apple Sign In ────────────────────────────────────────────────────────────

router.post('/apple', async (req, res) => {
  try {
    const { identityToken, email: clientEmail } = req.body;
    if (!identityToken) return res.status(400).json({ message: 'Identity token is required.' });

    const payload  = await verifyAppleToken(identityToken);
    const appleId  = payload.sub;
    const email    = (payload.email || clientEmail || '').toLowerCase() || null;

    // 1. Find by apple_id
    let user = db.prepare('SELECT * FROM users WHERE apple_id = ?').get(appleId);

    if (!user && email) {
      // 2. Link to existing email account
      user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
      if (user) {
        db.prepare('UPDATE users SET apple_id = ? WHERE id = ?').run(appleId, user.id);
      } else {
        // 3. Create new user
        const result = db
          .prepare('INSERT INTO users (email, password_hash, apple_id) VALUES (?, ?, ?)')
          .run(email, '', appleId);
        user = db.prepare('SELECT * FROM users WHERE id = ?').get(result.lastInsertRowid);
      }
    }

    if (!user) {
      return res.status(400).json({ message: 'Sign in failed. Please try again with Apple.' });
    }

    const token = jwt.sign(
      { userId: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: TOKEN_EXPIRY }
    );

    res.json({ token, user: { id: user.id, email: user.email } });
  } catch (err) {
    console.error('Apple sign-in:', err);
    res.status(401).json({ message: 'Apple sign-in failed. Please try again.' });
  }
});

// ─── Profil korisnika ─────────────────────────────────────────────────────────

const authMiddleware = require('../middleware/auth');

router.get('/me', authMiddleware, (req, res) => {
  try {
    const user = db.prepare('SELECT id, email, created_at, password_hash FROM users WHERE id = ?').get(req.user.userId);
    if (!user) return res.status(404).json({ message: 'Korisnik nije pronađen.' });
    res.json({
      id: user.id,
      email: user.email,
      created_at: user.created_at,
      has_password: !!(user.password_hash && user.password_hash.length > 0),
    });
  } catch (err) {
    console.error('GET /me:', err);
    res.status(500).json({ message: 'Serverska greška.' });
  }
});

// ─── Promena lozinke ──────────────────────────────────────────────────────────

router.post('/change-password', authMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword)
      return res.status(400).json({ message: 'Sva polja su obavezna.' });
    if (newPassword.length < 6)
      return res.status(400).json({ message: 'Nova lozinka mora imati najmanje 6 karaktera.' });

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.userId);
    if (!user) return res.status(404).json({ message: 'Korisnik nije pronađen.' });

    const valid = await bcrypt.compare(currentPassword, user.password_hash);
    if (!valid) return res.status(401).json({ message: 'Pogrešna trenutna lozinka.' });

    const hash = await bcrypt.hash(newPassword, SALT_ROUNDS);
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(hash, user.id);
    res.json({ message: 'Lozinka je uspešno promenjena.' });
  } catch (err) {
    console.error('POST /change-password:', err);
    res.status(500).json({ message: 'Serverska greška.' });
  }
});

module.exports = router;
