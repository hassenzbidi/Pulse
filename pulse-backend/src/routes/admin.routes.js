const express  = require('express')
const router   = express.Router()
const { pool } = require('../config/db')
const crypto   = require('crypto')

function generatePassword() {
  const chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  return Array.from(crypto.randomBytes(8),
    b => chars[b % chars.length]).join('')
}

// Middleware auth admin
function adminAuth(req, res, next) {
  const { username, password } = req.headers
  if (
    username === process.env.ADMIN_USERNAME &&
    password === process.env.ADMIN_PASSWORD
  ) {
    return next()
  }
  res.status(401).json({ error: 'Accès refusé' })
}

// POST /api/admin/login
router.post('/login', (req, res) => {
  const { username, password } = req.body
  if (
    username === process.env.ADMIN_USERNAME &&
    password === process.env.ADMIN_PASSWORD
  ) {
    res.json({
      success: true,
      token:   Buffer.from(
        `${username}:${password}`).toString('base64'),
      message: 'Connexion admin réussie',
    })
  } else {
    res.status(401).json({ error: 'Identifiants incorrects' })
  }
})

// GET /api/admin/stats — Statistiques globales
router.get('/stats', adminAuth, async (req, res) => {
  try {
    const [users, doctors, patients, scores] =
      await Promise.all([
        pool.query(
          `SELECT COUNT(*) FROM users
           WHERE role = 'user'`),
        pool.query(
          `SELECT COUNT(*) FROM users
           WHERE role = 'doctor'`),
        pool.query(
          `SELECT COUNT(*) FROM doctor_access
           WHERE status = 'approved'`),
        pool.query(
          `SELECT AVG(total_score) as avg_score
           FROM discipline_scores
           WHERE score_date >= NOW() - INTERVAL '7 days'`),
      ])

    res.json({
      total_patients: parseInt(users.rows[0].count),
      total_doctors:  parseInt(doctors.rows[0].count),
      total_access:   parseInt(patients.rows[0].count),
      avg_score:      parseFloat(
        scores.rows[0].avg_score || 0).toFixed(1),
    })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/admin/patients — Liste tous les patients
router.get('/patients', adminAuth, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         u.id, u.full_name, u.email,
         u.created_at, u.role,
         np.current_weight, np.target_weight,
         np.daily_calories, np.goal,
         np.activity_level,
         (SELECT total_score FROM discipline_scores
          WHERE user_id = u.id
          ORDER BY score_date DESC LIMIT 1)
          AS last_score,
         (SELECT weight_kg FROM weight_logs
          WHERE user_id = u.id
          ORDER BY logged_at DESC LIMIT 1)
          AS last_weight,
         (SELECT COUNT(*) FROM meals
          WHERE user_id = u.id)
          AS total_meals
       FROM users u
       LEFT JOIN nutrition_profiles np
         ON np.user_id = u.id
       WHERE u.role = 'user'
       ORDER BY u.created_at DESC`
    )
    res.json({ patients: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/admin/pending-doctors — Médecins en attente de vérification
router.get('/pending-doctors', adminAuth, async (req, res) => {
  try {
    // Ajouter les colonnes PDF si elles n'existent pas encore
    await pool.query(`
      ALTER TABLE doctor_profiles
        ADD COLUMN IF NOT EXISTS cv_pdf TEXT,
        ADD COLUMN IF NOT EXISTS diploma_pdf TEXT
    `)
    const result = await pool.query(
      `SELECT
         u.id, u.full_name, u.email, u.created_at,
         dp.speciality, dp.hospital, dp.license_number,
         dp.bio, dp.is_verified,
         dp.cv_pdf, dp.diploma_pdf
       FROM users u
       JOIN doctor_profiles dp ON dp.user_id = u.id
       WHERE u.role = 'doctor'
         AND dp.is_verified = false
       ORDER BY u.created_at DESC`
    )
    res.json({ doctors: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/admin/doctors — Liste médecins et nutritionnistes
router.get('/doctors', adminAuth, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         u.id, u.full_name, u.email,
         u.created_at,
         dp.speciality, dp.hospital,
         dp.license_number, dp.bio,
         dp.is_verified,
         (SELECT COUNT(*) FROM doctor_access
          WHERE doctor_id = u.id
            AND status = 'approved')
          AS patient_count
       FROM users u
       LEFT JOIN doctor_profiles dp
         ON dp.user_id = u.id
       WHERE u.role = 'doctor'
       ORDER BY u.created_at DESC`
    )
    res.json({ doctors: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// PATCH /api/admin/doctor/:id/verify
// Approuver ou rejeter un médecin + notification
router.patch('/doctor/:id/verify', adminAuth,
  async (req, res) => {
  const { is_verified } = req.body
  try {
    await pool.query(
      `UPDATE doctor_profiles
       SET is_verified = $1
       WHERE user_id = $2`,
      [is_verified, req.params.id]
    )

    // Notification à l'utilisateur
    const title   = is_verified ? 'Compte approuvé ✅' : 'Demande rejetée'
    const message = is_verified
      ? 'Félicitations ! Votre compte spécialiste a été approuvé. Vous pouvez maintenant vous connecter et accéder à vos patients.'
      : 'Votre demande de compte spécialiste a été rejetée. Contactez l\'administration pour plus d\'informations.'
    try {
      await pool.query(
        `INSERT INTO notifications (user_id, type, title, message)
         VALUES ($1, 'verification', $2, $3)`,
        [req.params.id, title, message]
      )
    } catch (_) {
      // La table notifications peut avoir une structure différente
    }

    res.json({
      message: is_verified
        ? 'Médecin vérifié ✅'
        : 'Vérification retirée'
    })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// DELETE /api/admin/user/:id — Supprimer un utilisateur
router.delete('/user/:id', adminAuth, async (req, res) => {
  try {
    await pool.query(
      'DELETE FROM users WHERE id = $1',
      [req.params.id]
    )
    res.json({ message: 'Utilisateur supprimé' })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/admin/patient/:id — Détail d'un patient
router.get('/patient/:id', adminAuth, async (req, res) => {
  try {
    const [user, profile, scores, meals, weights] =
      await Promise.all([
        pool.query(
          'SELECT * FROM users WHERE id = $1',
          [req.params.id]),
        pool.query(
          `SELECT * FROM nutrition_profiles
           WHERE user_id = $1`,
          [req.params.id]),
        pool.query(
          `SELECT * FROM discipline_scores
           WHERE user_id = $1
           ORDER BY score_date DESC LIMIT 30`,
          [req.params.id]),
        pool.query(
          `SELECT * FROM meals
           WHERE user_id = $1
           ORDER BY eaten_at DESC LIMIT 20`,
          [req.params.id]),
        pool.query(
          `SELECT * FROM weight_logs
           WHERE user_id = $1
           ORDER BY logged_at DESC LIMIT 20`,
          [req.params.id]),
      ])
    res.json({
      user:    user.rows[0],
      profile: profile.rows[0],
      scores:  scores.rows,
      meals:   meals.rows,
      weights: weights.rows,
    })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})
// POST /api/admin/add-specialist
// Admin crée directement le compte spécialiste
router.post('/add-specialist', adminAuth, async (req, res) => {
  const {
    full_name, email, password,
    speciality, hospital, license_number, bio
  } = req.body

  if (!full_name || !email || !speciality) {
    return res.status(400).json({
      error: 'full_name, email et speciality requis'
    })
  }

  try {
    const password_temp = generatePassword()

    // Créer l'utilisateur avec rôle doctor
    const userResult = await pool.query(
      `INSERT INTO users
         (firebase_uid, email, full_name, role, password_temp)
       VALUES ($1, $2, $3, 'doctor', $4)
       ON CONFLICT (email) DO UPDATE
         SET full_name     = EXCLUDED.full_name,
             role          = 'doctor',
             password_temp = EXCLUDED.password_temp
       RETURNING *`,
      [email, email, full_name, password_temp]
    )
    const user = userResult.rows[0]

    // Créer le profil spécialiste vérifié
    await pool.query(
      `INSERT INTO doctor_profiles
         (user_id, speciality, hospital,
          license_number, bio, is_verified)
       VALUES ($1, $2, $3, $4, $5, true)
       ON CONFLICT (user_id) DO UPDATE SET
         speciality     = EXCLUDED.speciality,
         hospital       = EXCLUDED.hospital,
         license_number = EXCLUDED.license_number,
         bio            = EXCLUDED.bio,
         is_verified    = true`,
      [user.id, speciality, hospital || null,
       license_number || null, bio || null]
    )

    res.status(201).json({
      message:       'Spécialiste créé avec succès',
      user_id:       user.id,
      email:         user.email,
      verified:      true,
      password_temp: password_temp,
    })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router