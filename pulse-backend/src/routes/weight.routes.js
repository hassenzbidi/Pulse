const express  = require('express')
const router   = express.Router()
const { pool } = require('../config/db')

// POST /api/weight
router.post('/', async (req, res) => {
  const { user_id, weight_kg, note } = req.body
  if (!user_id || !weight_kg) {
    return res.status(400).json({
      error: 'user_id et weight_kg requis'
    })
  }
  try {
    const result = await pool.query(
      `INSERT INTO weight_logs (user_id, weight_kg, note)
       VALUES ($1, $2, $3) RETURNING *`,
      [user_id, weight_kg, note || null]
    )
    res.status(201).json({ log: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/weight/history/:user_id
router.get('/history/:user_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM weight_logs
       WHERE user_id = $1
       ORDER BY logged_at DESC
       LIMIT 30`,
      [req.params.user_id]
    )
    res.json({ logs: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// POST /api/weight/water
router.post('/water', async (req, res) => {
  const { user_id, amount_ml, date } = req.body
  const logDate = date || new Date().toISOString().split('T')[0]
  try {
    const result = await pool.query(
      `INSERT INTO water_logs_daily (user_id, log_date, amount_ml)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, log_date) DO UPDATE
         SET amount_ml = $3, updated_at = NOW()
       RETURNING *`,
      [user_id, logDate, amount_ml]
    )
    res.json({ water: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/weight/water/:user_id
router.get('/water/:user_id', async (req, res) => {
  const { date } = req.query
  const logDate  = date || new Date().toISOString().split('T')[0]
  try {
    const result = await pool.query(
      `SELECT * FROM water_logs_daily
       WHERE user_id = $1 AND log_date = $2`,
      [req.params.user_id, logDate]
    )
    res.json({
      amount_ml: result.rows[0]?.amount_ml ?? 0,
      date:      logDate,
    })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router