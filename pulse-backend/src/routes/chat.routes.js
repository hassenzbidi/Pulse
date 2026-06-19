const express  = require('express')
const router   = express.Router()
const { pool } = require('../config/db')

// Création de la table messages + FK constraints au démarrage
;(async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        sender_id   UUID REFERENCES users(id) ON DELETE CASCADE,
        receiver_id UUID REFERENCES users(id) ON DELETE CASCADE,
        content     TEXT NOT NULL,
        is_read     BOOLEAN DEFAULT false,
        created_at  TIMESTAMP DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_messages_sender
        ON messages (sender_id, receiver_id, created_at);
    `)

    // Colonnes image (idempotent)
    await pool.query(`
      ALTER TABLE messages
        ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text';
      ALTER TABLE messages
        ADD COLUMN IF NOT EXISTS image_base64 TEXT;
    `)

    // Migration FK pour table existante sans contraintes
    await pool.query(`
      DO $$
      BEGIN
        BEGIN
          ALTER TABLE messages
            ADD CONSTRAINT messages_sender_fk
            FOREIGN KEY (sender_id)
            REFERENCES users(id) ON DELETE CASCADE;
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
        BEGIN
          ALTER TABLE messages
            ADD CONSTRAINT messages_receiver_fk
            FOREIGN KEY (receiver_id)
            REFERENCES users(id) ON DELETE CASCADE;
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
      END$$;
    `)

    console.log('✅ Table messages prête')
  } catch (err) {
    console.error('❌ Erreur table messages:', err.message)
  }
})()

// POST /api/chat/send — Envoyer un message texte ou image
router.post('/send', async (req, res) => {
  const {
    sender_id, receiver_id, content,
    message_type, image_base64,
  } = req.body
  const type = message_type || 'text'

  if (!sender_id || !receiver_id) {
    return res.status(400).json({
      error: 'sender_id et receiver_id sont requis'
    })
  }
  if (type === 'text' && !content?.trim()) {
    return res.status(400).json({
      error: 'content requis pour un message texte'
    })
  }
  if (type === 'image' && !image_base64) {
    return res.status(400).json({
      error: 'image_base64 requis pour un message image'
    })
  }

  try {
    const result = await pool.query(
      `INSERT INTO messages
         (sender_id, receiver_id, content,
          message_type, image_base64)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        sender_id,
        receiver_id,
        content?.trim() || '',
        type,
        image_base64 || null,
      ]
    )
    res.status(201).json({ message: result.rows[0] })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/chat/unread/:user_id — Nombre de messages non lus (badge)
// DOIT être déclaré avant /:user1_id/:user2_id pour éviter le conflit
router.get('/unread/:user_id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT COUNT(*) AS unread_count
       FROM messages
       WHERE receiver_id = $1
         AND is_read     = false`,
      [req.params.user_id]
    )
    res.json({
      unread_count: parseInt(result.rows[0].unread_count, 10)
    })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// GET /api/chat/:user1_id/:user2_id — Conversation entre deux utilisateurs
router.get('/:user1_id/:user2_id', async (req, res) => {
  const { user1_id, user2_id } = req.params
  try {
    const result = await pool.query(
      `SELECT id, sender_id, receiver_id, content,
              message_type, image_base64, is_read, created_at
       FROM messages
       WHERE (sender_id = $1 AND receiver_id = $2)
          OR (sender_id = $2 AND receiver_id = $1)
       ORDER BY created_at ASC`,
      [user1_id, user2_id]
    )
    res.json({ messages: result.rows })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// PATCH /api/chat/read/:sender_id/:receiver_id
// Marque comme lus tous les messages envoyés par sender_id à receiver_id
router.patch('/read/:sender_id/:receiver_id', async (req, res) => {
  const { sender_id, receiver_id } = req.params
  try {
    const result = await pool.query(
      `UPDATE messages
       SET is_read = true
       WHERE sender_id   = $1
         AND receiver_id = $2
         AND is_read     = false
       RETURNING id`,
      [sender_id, receiver_id]
    )
    res.json({
      message:       'Messages marqués comme lus',
      updated_count: result.rowCount,
    })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router
