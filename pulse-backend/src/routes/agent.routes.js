const express      = require('express')
const router       = express.Router()
const { pool }     = require('../config/db')
const agentService = require('../services/agent.service')

// POST /api/agent/chat
router.post('/chat', async (req, res) => {
  const { user_id, message } = req.body

  if (!user_id || !message?.trim()) {
    return res.status(400).json({ error: 'user_id et message requis' })
  }

  try {
    const userResult = await pool.query(
      'SELECT * FROM users WHERE id = $1',
      [user_id]
    )
    if (!userResult.rows.length) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' })
    }

    const profileResult = await pool.query(
      'SELECT * FROM nutrition_profiles WHERE user_id = $1',
      [user_id]
    )

    const user    = userResult.rows[0]
    const profile = profileResult.rows[0] || null

    const reply = await agentService.chat(
      user_id, message, user, profile
    )

    res.json({ reply })
  } catch (err) {
    console.error('Erreur agent:', err.message)
    res.status(500).json({ error: err.message })
  }
})

// GET /api/agent/history/:user_id
router.get('/history/:user_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT role, content, created_at
       FROM conversations
       WHERE user_id = $1
       ORDER BY created_at ASC
       LIMIT 50`,
      [req.params.user_id]
    )
    res.json({ history: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// DELETE /api/agent/history/:user_id
router.delete('/history/:user_id', async (req, res) => {
  try {
    await agentService.clearHistory(req.params.user_id)
    res.json({ message: 'Historique effacé' })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router