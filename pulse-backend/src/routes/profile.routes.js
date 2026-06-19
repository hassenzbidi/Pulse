const express  = require('express')
const router   = express.Router()
const { pool } = require('../config/db')

function calculateBMR(weight, height, age, gender) {
  if (gender === 'male') {
    return 10 * weight + 6.25 * height - 5 * age + 5
  }
  return 10 * weight + 6.25 * height - 5 * age - 161
}

const ACTIVITY_FACTORS = {
  sedentary:   1.2,
  light:       1.375,
  moderate:    1.55,
  active:      1.725,
  very_active: 1.9,
}

// POST /api/profile
router.post('/', async (req, res) => {
  const {
    user_id, age, gender, height_cm,
    current_weight, target_weight,
    activity_level, goal
  } = req.body

  try {
    const bmr          = calculateBMR(current_weight, height_cm, age, gender)
    const tdee         = bmr * (ACTIVITY_FACTORS[activity_level] || 1.55)
    const daily_cal    = goal === 'lose' ? tdee - 500
                       : goal === 'gain' ? tdee + 500
                       : tdee
    const protein_g    = Math.round((daily_cal * 0.25) / 4)
    const fat_g        = Math.round((daily_cal * 0.25) / 9)
    const carbs_g      = Math.round((daily_cal - protein_g * 4 - fat_g * 9) / 4)

    const result = await pool.query(
      `INSERT INTO nutrition_profiles
         (user_id, age, gender, height_cm, current_weight, target_weight,
          activity_level, goal, bmr, daily_calories, protein_g, carbs_g, fat_g)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
       ON CONFLICT (user_id) DO UPDATE SET
         age = EXCLUDED.age,
         gender = EXCLUDED.gender,
         height_cm = EXCLUDED.height_cm,
         current_weight = EXCLUDED.current_weight,
         target_weight = EXCLUDED.target_weight,
         activity_level = EXCLUDED.activity_level,
         goal = EXCLUDED.goal,
         bmr = EXCLUDED.bmr,
         daily_calories = EXCLUDED.daily_calories,
         protein_g = EXCLUDED.protein_g,
         carbs_g = EXCLUDED.carbs_g,
         fat_g = EXCLUDED.fat_g,
         updated_at = NOW()
       RETURNING *`,
      [user_id, age, gender, height_cm, current_weight,
       target_weight, activity_level, goal,
       Math.round(bmr), Math.round(daily_cal),
       protein_g, carbs_g, fat_g]
    )
    res.json({ profile: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/profile/:user_id
router.get('/:user_id', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM nutrition_profiles WHERE user_id = $1',
      [req.params.user_id]
    )
    if (!result.rows.length) {
      return res.status(404).json({ error: 'Profil non trouvé' })
    }
    res.json({ profile: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router