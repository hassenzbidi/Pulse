const express  = require('express')
const router   = express.Router()
const { pool } = require('../config/db')

// ── ROUTES STATIQUES (pas de paramètre dynamique) ──────────────────
// Doivent être déclarées AVANT les routes /:param pour éviter les conflits

// GET /api/doctor/list — Liste tous les médecins vérifiés
router.get('/list', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.full_name, u.email,
              dp.speciality, dp.hospital, dp.bio
       FROM users u
       JOIN doctor_profiles dp ON dp.user_id = u.id
       WHERE u.role = 'doctor'
         AND dp.is_verified = true
       ORDER BY u.full_name ASC`
    )
    res.json({ doctors: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// POST /api/doctor/profile — Créer / mettre à jour profil médecin
router.post('/profile', async (req, res) => {
  const { user_id, speciality, license_number,
          hospital, bio } = req.body
  try {
    await pool.query(
      `UPDATE users SET role = 'doctor' WHERE id = $1`,
      [user_id]
    )
    const result = await pool.query(
      `INSERT INTO doctor_profiles
         (user_id, speciality, license_number, hospital, bio)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (user_id) DO UPDATE SET
         speciality     = EXCLUDED.speciality,
         license_number = EXCLUDED.license_number,
         hospital       = EXCLUDED.hospital,
         bio            = EXCLUDED.bio
       RETURNING *`,
      [user_id, speciality, license_number, hospital, bio]
    )
    res.json({ profile: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// POST /api/doctor/request — Patient demande accès + notification médecin
router.post('/request', async (req, res) => {
  const { patient_id, doctor_id } = req.body
  try {
    await pool.query(
      `INSERT INTO doctor_access (patient_id, doctor_id)
       VALUES ($1, $2)
       ON CONFLICT (patient_id, doctor_id) DO NOTHING`,
      [patient_id, doctor_id]
    )

    const patientRes = await pool.query(
      'SELECT full_name FROM users WHERE id = $1',
      [patient_id]
    )
    const patientName = patientRes.rows[0]?.full_name ?? 'Un patient'

    await pool.query(
      `INSERT INTO notifications
         (user_id, title, message, type, data)
       VALUES ($1, $2, $3, 'access_request', $4)`,
      [
        doctor_id,
        'Nouvelle demande de suivi',
        `${patientName} souhaite que vous accédiez à son suivi nutritionnel.`,
        JSON.stringify({ patient_id, type: 'access_request' }),
      ]
    )

    res.json({ message: 'Demande envoyée avec notification' })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// POST /api/doctor/comment — Médecin ajoute un commentaire
router.post('/comment', async (req, res) => {
  const { doctor_id, patient_id, content } = req.body
  if (!doctor_id || !patient_id || !content?.trim()) {
    return res.status(400).json({ error: 'Champs requis manquants' })
  }
  try {
    const result = await pool.query(
      `INSERT INTO doctor_comments (doctor_id, patient_id, content)
       VALUES ($1, $2, $3) RETURNING *`,
      [doctor_id, patient_id, content.trim()]
    )
    res.status(201).json({ comment: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// ── ROUTES DYNAMIQUES (:param) ─────────────────────────────────────

// GET /api/doctor/profile/:user_id
router.get('/profile/:user_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT dp.*, u.full_name, u.email
       FROM doctor_profiles dp
       JOIN users u ON u.id = dp.user_id
       WHERE dp.user_id = $1`,
      [req.params.user_id]
    )
    if (!result.rows.length) {
      return res.status(404).json({ error: 'Profil médecin non trouvé' })
    }
    res.json({ profile: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/doctor/patients/:doctor_id — Liste patients approuvés
router.get('/patients/:doctor_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         u.id, u.full_name, u.email, u.avatar_url,
         da.status, da.granted_at,
         np.current_weight, np.target_weight,
         np.daily_calories, np.goal,
         (SELECT total_score FROM discipline_scores
          WHERE user_id = u.id
          ORDER BY score_date DESC LIMIT 1) as last_score,
         (SELECT weight_kg FROM weight_logs
          WHERE user_id = u.id
          ORDER BY logged_at DESC LIMIT 1) as last_weight
       FROM doctor_access da
       JOIN users u ON u.id = da.patient_id
       LEFT JOIN nutrition_profiles np ON np.user_id = u.id
       WHERE da.doctor_id = $1
         AND da.status = 'approved'
       ORDER BY u.full_name ASC`,
      [req.params.doctor_id]
    )
    res.json({ patients: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/doctor/pending/:doctor_id — Demandes en attente
router.get('/pending/:doctor_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.full_name, u.email, da.created_at
       FROM doctor_access da
       JOIN users u ON u.id = da.patient_id
       WHERE da.doctor_id = $1 AND da.status = 'pending'
       ORDER BY da.created_at DESC`,
      [req.params.doctor_id]
    )
    res.json({ requests: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/doctor/access-status/:patient_id
router.get('/access-status/:patient_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT da.doctor_id, da.status,
              da.granted_at, da.created_at
       FROM doctor_access da
       WHERE da.patient_id = $1`,
      [req.params.patient_id]
    )
    res.json({ accesses: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/doctor/comments/:patient_id
router.get('/comments/:patient_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT dc.*, u.full_name as doctor_name
       FROM doctor_comments dc
       JOIN users u ON u.id = dc.doctor_id
       WHERE dc.patient_id = $1
       ORDER BY dc.created_at DESC`,
      [req.params.patient_id]
    )
    res.json({ comments: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/doctor/my-doctors/:patient_id — Spécialistes approuvés
router.get('/my-doctors/:patient_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT da.doctor_id, u.full_name,
              dp.speciality, da.status, da.granted_at
       FROM doctor_access da
       JOIN users u ON u.id = da.doctor_id
       LEFT JOIN doctor_profiles dp
         ON dp.user_id = da.doctor_id
       WHERE da.patient_id = $1
         AND da.status = 'approved'
       ORDER BY da.granted_at ASC`,
      [req.params.patient_id]
    )
    res.json({ doctors: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/doctor/patient/:patient_id/dashboard
router.get('/patient/:patient_id/dashboard', async (req, res) => {
  const { doctor_id, date } = req.query
  try {
    const access = await pool.query(
      `SELECT id FROM doctor_access
       WHERE doctor_id = $1
         AND patient_id = $2
         AND status = 'approved'`,
      [doctor_id, req.params.patient_id]
    )
    if (!access.rows.length) {
      return res.status(403).json({ error: 'Accès refusé' })
    }

    const pid = req.params.patient_id

    const mealsQuery = date
      ? pool.query(
          `SELECT * FROM meals
           WHERE user_id = $1 AND DATE(eaten_at) = $2
           ORDER BY eaten_at DESC`,
          [pid, date])
      : pool.query(
          `SELECT * FROM meals
           WHERE user_id = $1
             AND eaten_at >= NOW() - INTERVAL '7 days'
           ORDER BY eaten_at DESC`,
          [pid])

    const [user, profile, scores, weights, meals] =
      await Promise.all([
        pool.query('SELECT * FROM users WHERE id = $1', [pid]),
        pool.query(
          'SELECT * FROM nutrition_profiles WHERE user_id = $1',
          [pid]),
        pool.query(
          `SELECT * FROM discipline_scores
           WHERE user_id = $1
           ORDER BY score_date DESC LIMIT 30`, [pid]),
        pool.query(
          `SELECT * FROM weight_logs
           WHERE user_id = $1
           ORDER BY logged_at DESC LIMIT 20`, [pid]),
        mealsQuery,
      ])

    res.json({
      user:    user.rows[0],
      profile: profile.rows[0],
      scores:  scores.rows,
      weights: weights.rows,
      meals:   meals.rows,
    })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// PATCH /api/doctor/access/:patient_id — Approuver / refuser / révoquer
router.patch('/access/:patient_id', async (req, res) => {
  const { doctor_id, status } = req.body
  try {
    await pool.query(
      `UPDATE doctor_access
       SET status = $1, granted_at = NOW()
       WHERE doctor_id = $2 AND patient_id = $3`,
      [status, doctor_id, req.params.patient_id]
    )

    const doctorRes = await pool.query(
      `SELECT u.full_name, dp.speciality
       FROM users u
       LEFT JOIN doctor_profiles dp ON dp.user_id = u.id
       WHERE u.id = $1`,
      [doctor_id]
    )
    const doctorName       = doctorRes.rows[0]?.full_name ?? 'Le spécialiste'
    const doctorSpeciality = doctorRes.rows[0]?.speciality ?? null

    if (status !== 'revoked') {
      await pool.query(
        `INSERT INTO notifications
           (user_id, title, message, type, data)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          req.params.patient_id,
          status === 'approved' ? 'Demande acceptée !' : 'Demande refusée',
          status === 'approved'
            ? `Dr. ${doctorName} a accepté de suivre votre progression.`
            : `Dr. ${doctorName} n'a pas pu accepter votre demande.`,
          status === 'approved' ? 'access_approved' : 'access_rejected',
          JSON.stringify({
            doctor_id,
            status,
            doctor_name:       doctorName,
            doctor_speciality: doctorSpeciality,
          }),
        ]
      )
    }

    res.json({ message: `Accès ${status}` })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router
