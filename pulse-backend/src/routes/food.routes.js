const express  = require('express')
const router   = express.Router()
const { pool } = require('../config/db')

// GET /api/foods
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM foods_tn ORDER BY name_fr ASC'
    )
    res.json({ foods: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/foods/search?q=couscous
router.get('/search', async (req, res) => {
  const { q } = req.query
  if (!q) {
    return res.status(400).json({ error: 'Paramètre q requis' })
  }
  try {
    const result = await pool.query(
      `SELECT * FROM foods_tn
       WHERE name_fr ILIKE $1
          OR name_ar ILIKE $1
       LIMIT 10`,
      [`%${q}%`]
    )
    res.json({ foods: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router