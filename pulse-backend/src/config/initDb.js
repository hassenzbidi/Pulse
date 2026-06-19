require('dotenv').config()
const { pool } = require('./db')

async function initDb() {
  const client = await pool.connect()
  try {
    console.log('🔧 Initialisation de la base de données Pulse...')

    await client.query(`
      CREATE EXTENSION IF NOT EXISTS "pgcrypto";

      CREATE TABLE IF NOT EXISTS users (
        id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        firebase_uid  TEXT UNIQUE NOT NULL,
        email         TEXT UNIQUE NOT NULL,
        full_name     TEXT,
        avatar_url    TEXT,
        role          TEXT DEFAULT 'user',
        password_temp TEXT,
        created_at    TIMESTAMP DEFAULT NOW()
      );

      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS password_temp TEXT;

      CREATE TABLE IF NOT EXISTS nutrition_profiles (
        id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
        age             INTEGER,
        gender          TEXT,
        height_cm       DECIMAL(5,2),
        current_weight  DECIMAL(5,2),
        target_weight   DECIMAL(5,2),
        activity_level  TEXT DEFAULT 'moderate',
        goal            TEXT DEFAULT 'maintain',
        bmr             DECIMAL(7,2),
        daily_calories  DECIMAL(7,2),
        protein_g       DECIMAL(6,2),
        carbs_g         DECIMAL(6,2),
        fat_g           DECIMAL(6,2),
        updated_at      TIMESTAMP DEFAULT NOW(),
        UNIQUE(user_id)
      );

      CREATE TABLE IF NOT EXISTS weight_logs (
        id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
        weight_kg   DECIMAL(5,2) NOT NULL,
        note        TEXT,
        logged_at   TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS meals (
        id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
        meal_type    TEXT,
        photo_url    TEXT,
        total_cal    DECIMAL(7,2) DEFAULT 0,
        total_prot   DECIMAL(6,2) DEFAULT 0,
        total_carbs  DECIMAL(6,2) DEFAULT 0,
        total_fat    DECIMAL(6,2) DEFAULT 0,
        eaten_at     TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS meal_items (
        id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        meal_id      UUID REFERENCES meals(id) ON DELETE CASCADE,
        food_name    TEXT NOT NULL,
        source       TEXT,
        barcode      TEXT,
        quantity_g   DECIMAL(7,2),
        calories     DECIMAL(7,2),
        protein_g    DECIMAL(6,2),
        carbs_g      DECIMAL(6,2),
        fat_g        DECIMAL(6,2)
      );

      CREATE TABLE IF NOT EXISTS discipline_scores (
        id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id          UUID REFERENCES users(id) ON DELETE CASCADE,
        score_date       DATE NOT NULL,
        calories_score   DECIMAL(5,2) DEFAULT 0,
        macros_score     DECIMAL(5,2) DEFAULT 0,
        photo_score      DECIMAL(5,2) DEFAULT 0,
        weight_score     DECIMAL(5,2) DEFAULT 0,
        total_score      DECIMAL(5,2) DEFAULT 0,
        score_level      TEXT,
        streak_days      INTEGER DEFAULT 0,
        badges_earned    TEXT[] DEFAULT '{}',
        actual_calories  DECIMAL(7,2),
        target_calories  DECIMAL(7,2),
        meals_count      INTEGER DEFAULT 0,
        photos_count     INTEGER DEFAULT 0,
        created_at       TIMESTAMP DEFAULT NOW(),
        updated_at       TIMESTAMP DEFAULT NOW(),
        UNIQUE(user_id, score_date)
      );

      CREATE TABLE IF NOT EXISTS foods_tn (
        id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name_fr      TEXT NOT NULL,
        name_ar      TEXT,
        category     TEXT,
        calories     DECIMAL(7,2),
        protein_g    DECIMAL(6,2),
        carbs_g      DECIMAL(6,2),
        fat_g        DECIMAL(6,2),
        portion_g    DECIMAL(6,2) DEFAULT 300,
        region       TEXT DEFAULT 'national',
        created_at   TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS conversations (
        id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
        role         TEXT NOT NULL,
        content      TEXT NOT NULL,
        created_at   TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS doctor_access (
        id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        patient_id   UUID REFERENCES users(id) ON DELETE CASCADE,
        doctor_id    UUID REFERENCES users(id) ON DELETE CASCADE,
        status       TEXT DEFAULT 'pending',
        granted_at   TIMESTAMP,
        created_at   TIMESTAMP DEFAULT NOW(),
        UNIQUE(patient_id, doctor_id)
      );
    `)

    console.log('✅ Tables créées avec succès')

    await client.query(`
      ALTER TABLE discipline_scores
        ADD COLUMN IF NOT EXISTS protein_score DECIMAL(5,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS carbs_score   DECIMAL(5,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS fat_score     DECIMAL(5,2) DEFAULT 0;
    `)

    console.log('✅ Colonnes macros individuelles ajoutées')

    await client.query(`
      INSERT INTO foods_tn
        (name_fr, name_ar, category, calories, protein_g, carbs_g, fat_g, portion_g)
      VALUES
        ('Couscous agneau',  'كسكسي علوش',  'plat_principal', 180, 8,  22, 6,  350),
        ('Lablabi',          'لبلابي',         'plat_principal', 210, 12, 30, 5,  400),
        ('Brik à l''oeuf',   'بريك بالعظمة',   'snack',          280, 10, 25, 15, 120),
        ('Chorba frik',      'شوربة الفريك',   'soupe',           95,  5, 14, 2,  300),
        ('Salade mechouia',  'سلاطة مشوية',    'salade',          60,  2,  8, 3,  200),
        ('Tajine tunisien',  'طاجين',          'plat_principal', 220, 14, 10, 14, 250),
        ('Kafteji',          'كفتاجي',         'plat_principal', 190,  6, 18, 11, 300),
        ('Makroudh',         'مقروض',          'dessert',         380,  4, 55, 16, 100),
        ('Fricassée',        'فريكاسي',        'snack',           310,  9, 35, 15, 150),
        ('Mloukhiya',        'ملوخية',         'plat_principal', 160, 10,  8,  9, 300)
      ON CONFLICT DO NOTHING;
    `)

    console.log('✅ Aliments tunisiens ajoutés')
    console.log('🎉 Base de données Pulse prête !')

  } catch (err) {
    console.error('❌ Erreur:', err.message)
  } finally {
    client.release()
    pool.end()
  }
}

initDb()