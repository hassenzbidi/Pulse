const express  = require('express')
const router   = express.Router()
const { pool } = require('../config/db')

// POST /api/auth/register
router.post('/register', async (req, res) => {
  const {
    firebase_uid, email, full_name, role,
    speciality, hospital, license_number, bio,
    cv_base64, diploma_base64,
  } = req.body

  if (!firebase_uid || !email) {
    return res.status(400).json({ error: 'firebase_uid et email requis' })
  }

  const userRole = role === 'doctor' ? 'doctor' : 'user'

  try {
    // Ajouter les colonnes PDF si elles n'existent pas encore
    await pool.query(`
      ALTER TABLE doctor_profiles
        ADD COLUMN IF NOT EXISTS cv_pdf TEXT,
        ADD COLUMN IF NOT EXISTS diploma_pdf TEXT
    `)

    const result = await pool.query(
      `INSERT INTO users (firebase_uid, email, full_name, role)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (firebase_uid) DO UPDATE
         SET email = EXCLUDED.email
       RETURNING *`,
      [firebase_uid, email, full_name || null, userRole]
    )
    const user = result.rows[0]

    if (userRole === 'doctor') {
      await pool.query(
        `INSERT INTO doctor_profiles
           (user_id, speciality, hospital, license_number, bio,
            is_verified, cv_pdf, diploma_pdf)
         VALUES ($1, $2, $3, $4, $5, false, $6, $7)
         ON CONFLICT (user_id) DO UPDATE SET
           speciality     = EXCLUDED.speciality,
           hospital       = EXCLUDED.hospital,
           license_number = EXCLUDED.license_number,
           bio            = EXCLUDED.bio,
           cv_pdf         = EXCLUDED.cv_pdf,
           diploma_pdf    = EXCLUDED.diploma_pdf,
           is_verified    = false`,
        [user.id, speciality || null, hospital || null,
         license_number || null, bio || null,
         cv_base64 || null, diploma_base64 || null]
      )
    }

    res.status(201).json({ user })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/auth/me
router.get('/me', async (req, res) => {
  const { firebase_uid } = req.query

  if (!firebase_uid) {
    return res.status(400).json({ error: 'firebase_uid requis' })
  }

  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE firebase_uid = $1',
      [firebase_uid]
    )
    if (!result.rows.length) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' })
    }
    res.json({ user: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/auth/users — Liste tous les utilisateurs
router.get('/users', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email, full_name, role, created_at FROM users ORDER BY created_at DESC'
    )
    res.json({ users: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/auth/user/:id — Récupérer par UUID PostgreSQL
router.get('/user/:id', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE id = $1',
      [req.params.id]
    )
    if (!result.rows.length) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' })
    }
    res.json({ user: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router
