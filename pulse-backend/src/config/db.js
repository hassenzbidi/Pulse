const { Pool } = require('pg')

const pool = new Pool({
  host:     'localhost',
  port:     5432,
  database: 'pulse_db',
  user:     'postgres',
  password: 'hassen',
})

async function testConnection() {
  try {
    const client = await pool.connect()
    console.log('✅ PostgreSQL connecté avec succès')
    client.release()
  } catch (err) {
    console.error('❌ Erreur connexion PostgreSQL:', err.message)
    process.exit(1)
  }
}

module.exports = { pool, testConnection }