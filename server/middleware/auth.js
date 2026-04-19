const jwt = require('jsonwebtoken');
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

module.exports = (req, res, next) => {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Neautorizovan pristup.' });
  }
  try {
    req.user = jwt.verify(header.substring(7), JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ message: 'Token nije validan.' });
  }
};
