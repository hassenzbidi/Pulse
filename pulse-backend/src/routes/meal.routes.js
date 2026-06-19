const express  = require('express')
const router   = express.Router()
const axios    = require('axios')
const { pool } = require('../config/db')
const { analyzePhoto } = require('../services/photo.service')

// POST /api/meals
router.post('/', async (req, res) => {
  const { user_id, meal_type, photo_url, items } = req.body

  try {
    const totals = (items || []).reduce((acc, item) => ({
      cal:   acc.cal   + (item.calories  || 0),
      prot:  acc.prot  + (item.protein_g || 0),
      carbs: acc.carbs + (item.carbs_g   || 0),
      fat:   acc.fat   + (item.fat_g     || 0),
    }), { cal: 0, prot: 0, carbs: 0, fat: 0 })

    const meal = await pool.query(
      `INSERT INTO meals
         (user_id, meal_type, photo_url,
          total_cal, total_prot, total_carbs, total_fat)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [user_id, meal_type, photo_url || null,
       totals.cal, totals.prot, totals.carbs, totals.fat]
    )

    if (items && items.length > 0) {
      for (const item of items) {
        await pool.query(
          `INSERT INTO meal_items
             (meal_id, food_name, source, barcode,
              quantity_g, calories, protein_g, carbs_g, fat_g)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
          [meal.rows[0].id, item.food_name,
           item.source || 'manual', item.barcode || null,
           item.quantity_g || 100, item.calories,
           item.protein_g, item.carbs_g, item.fat_g]
        )
      }
    }

    res.status(201).json({ meal: meal.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/meals/today/:user_id
router.get('/today/:user_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT m.*, json_agg(mi.*) AS items
       FROM meals m
       LEFT JOIN meal_items mi ON mi.meal_id = m.id
       WHERE m.user_id = $1
         AND DATE(m.eaten_at) = CURRENT_DATE
       GROUP BY m.id
       ORDER BY m.eaten_at ASC`,
      [req.params.user_id]
    )
    res.json({ meals: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/meals/scan/:barcode
router.get('/scan/:barcode', async (req, res) => {
  try {
    const { data } = await axios.get(
      `https://world.openfoodfacts.org/api/v2/product/${req.params.barcode}.json`
    )
    if (data.status !== 1) {
      return res.status(404).json({ error: 'Produit non trouvé' })
    }
    const p = data.product
    const n = p.nutriments || {}
    res.json({
      source: 'openfoodfacts',
      food: {
        food_name: p.product_name || 'Produit inconnu',
        barcode:   req.params.barcode,
        calories:  n['energy-kcal_100g']  || 0,
        protein_g: n['proteins_100g']      || 0,
        carbs_g:   n['carbohydrates_100g'] || 0,
        fat_g:     n['fat_100g']           || 0,
      }
    })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})
// POST /api/meals/analyze-photo
router.post('/analyze-photo', async (req, res) => {
  const { image_base64, mime_type } = req.body

  if (!image_base64) {
    return res.status(400).json({ error: 'image_base64 requis' })
  }

  try {
    const result = await analyzePhoto(
      image_base64,
      mime_type || 'image/jpeg'
    )
    res.json({ food: result })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})
// GET /api/meals/bydate/:user_id?date=2026-05-10
router.get('/bydate/:user_id', async (req, res) => {
  const { date } = req.query
  const targetDate = date || new Date().toISOString().split('T')[0]

  try {
    const result = await pool.query(
      `SELECT m.*, json_agg(mi.*) AS items
       FROM meals m
       LEFT JOIN meal_items mi ON mi.meal_id = m.id
       WHERE m.user_id = $1
         AND DATE(m.eaten_at) = $2
       GROUP BY m.id
       ORDER BY m.eaten_at ASC`,
      [req.params.user_id, targetDate]
    )
    res.json({ meals: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/meals/search-food?q=poulet
router.get('/search-food', async (req, res) => {
  const { q } = req.query
  if (!q) return res.status(400).json({ error: 'q requis' })
  try {
    const { data } = await axios.get(
      `https://world.openfoodfacts.org/cgi/search.pl`,
      {
        params: {
          search_terms:   q,
          search_simple:  1,
          action:         'process',
          json:           1,
          page_size:      10,
          lc:             'fr',
        }
      }
    )
    const foods = (data.products || [])
      .filter(p => p.product_name &&
        p.nutriments?.['energy-kcal_100g'])
      .map(p => ({
        food_name:  p.product_name,
        barcode:    p.code,
        calories:   p.nutriments['energy-kcal_100g']  || 0,
        protein_g:  p.nutriments['proteins_100g']      || 0,
        carbs_g:    p.nutriments['carbohydrates_100g'] || 0,
        fat_g:      p.nutriments['fat_100g']           || 0,
        source:     'openfoodfacts',
      }))
    res.json({ foods })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router