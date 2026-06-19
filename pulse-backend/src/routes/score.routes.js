const express  = require('express')
const router   = express.Router()
const { pool } = require('../config/db')

function calculateScore(consumed, target, maxPoints) {
  if (target <= 0) return maxPoints
  const ratio = consumed / target
  if (ratio >= 0.80 && ratio <= 1.20) {
    return maxPoints
  } else if (ratio < 0.80) {
    return Math.round(maxPoints * (ratio / 0.80))
  } else {
    const excess = ratio - 1.20
    return Math.max(0, Math.round(maxPoints * (1 - excess * 2)))
  }
}

// POST /api/scores/calculate
router.post('/calculate', async (req, res) => {
  const { user_id } = req.body
  const today = new Date().toISOString().split('T')[0]

  try {
    const profile = await pool.query(
      'SELECT * FROM nutrition_profiles WHERE user_id = $1',
      [user_id]
    )
    if (!profile.rows.length) {
      return res.status(400).json({ error: 'Profil requis' })
    }
    const p = profile.rows[0]

    const meals = await pool.query(
      `SELECT * FROM meals
       WHERE user_id = $1 AND DATE(eaten_at) = $2`,
      [user_id, today]
    )

    const totalCal   = meals.rows.reduce((s, m) => s + +m.total_cal,   0)
    const totalProt  = meals.rows.reduce((s, m) => s + +m.total_prot,  0)
    const totalCarbs = meals.rows.reduce((s, m) => s + +m.total_carbs, 0)
    const totalFat   = meals.rows.reduce((s, m) => s + +m.total_fat,   0)

    const caloriesScore = calculateScore(totalCal,   +p.daily_calories, 50)
    const proteinScore  = calculateScore(totalProt,  +p.protein_g,      17)
    const carbsScore    = calculateScore(totalCarbs, +p.carbs_g,        17)
    const fatScore      = calculateScore(totalFat,   +p.fat_g,          16)
    const macrosScore   = proteinScore + carbsScore + fatScore
    const totalScore    = caloriesScore + macrosScore
    const scoreLevel    = totalScore >= 90 ? 'excellent'
                        : totalScore >= 70 ? 'bon'
                        : 'ameliorer'

    const result = await pool.query(
      `INSERT INTO discipline_scores
         (user_id, score_date, calories_score, protein_score, carbs_score, fat_score,
          macros_score, photo_score, weight_score, total_score, score_level,
          actual_calories, target_calories, meals_count, photos_count)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
       ON CONFLICT (user_id, score_date) DO UPDATE SET
         calories_score  = EXCLUDED.calories_score,
         protein_score   = EXCLUDED.protein_score,
         carbs_score     = EXCLUDED.carbs_score,
         fat_score       = EXCLUDED.fat_score,
         macros_score    = EXCLUDED.macros_score,
         photo_score     = EXCLUDED.photo_score,
         weight_score    = EXCLUDED.weight_score,
         total_score     = EXCLUDED.total_score,
         score_level     = EXCLUDED.score_level,
         updated_at      = NOW()
       RETURNING *`,
      [user_id, today, caloriesScore, proteinScore, carbsScore, fatScore,
       macrosScore, 0, 0, totalScore, scoreLevel,
       totalCal, p.daily_calories,
       meals.rows.length, 0]
    )
    res.json({ score: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/scores/history/:user_id
router.get('/history/:user_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM discipline_scores
       WHERE user_id = $1
       ORDER BY score_date DESC
       LIMIT 30`,
      [req.params.user_id]
    )
    res.json({ scores: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router