const { pool } = require('../config/db')

async function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Token manquant' })
    }

    const token = authHeader.split('Bearer ')[1]

    // Pour le moment on vérifie juste que le token existe
    // On ajoutera Firebase plus tard
    if (!token) {
      return res.status(401).json({ error: 'Token invalide' })
    }

    // Chercher l'utilisateur par son firebase_uid
    const result = await pool.query(
      'SELECT * FROM users WHERE firebase_uid = $1',
      [token]
    )

    if (!result.rows.length) {
      return res.status(401).json({ error: 'Utilisateur non trouvé' })
    }

    req.user = result.rows[0]
    next()
  } catch (err) {
    return res.status(401).json({ error: err.message })
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Accès refusé' })
    }
    next()
  }
}

module.exports = { authenticate, requireRole }