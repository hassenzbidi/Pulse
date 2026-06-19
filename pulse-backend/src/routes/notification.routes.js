const express  = require('express')
const router   = express.Router()
const { pool } = require('../config/db')

// GET /api/notifications/:user_id
router.get('/:user_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM notifications
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 20`,
      [req.params.user_id]
    )
    const unread = result.rows.filter(
      n => !n.is_read).length

    res.json({
      notifications: result.rows,
      unread_count:  unread,
    })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// PATCH /api/notifications/:id/read
router.patch('/:id/read', async (req, res) => {
  try {
    await pool.query(
      `UPDATE notifications SET is_read = true
       WHERE id = $1`,
      [req.params.id]
    )
    res.json({ message: 'Lu' })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// PATCH /api/notifications/read-all/:user_id
router.patch('/read-all/:user_id', async (req, res) => {
  try {
    await pool.query(
      `UPDATE notifications SET is_read = true
       WHERE user_id = $1`,
      [req.params.user_id]
    )
    res.json({ message: 'Toutes lues' })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router