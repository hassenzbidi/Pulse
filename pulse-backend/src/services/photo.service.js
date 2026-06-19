const Groq   = require('groq-sdk')
const { pool } = require('../config/db')

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY
})

async function analyzeWithGroq(imageBase64, mimeType) {
  const response = await groq.chat.completions.create({
    model: 'meta-llama/llama-4-scout-17b-16e-instruct',
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'image_url',
            image_url: {
              url: `data:${mimeType};base64,${imageBase64}`,
            },
          },
          {
            type: 'text',
            text: `Tu es un expert en nutrition spécialisé
dans la cuisine tunisienne et méditerranéenne.
Analyse cette photo de repas et retourne UNIQUEMENT
un JSON valide, sans texte supplémentaire,
sans backticks, sans commentaires.

Format attendu:
{
  "food_name": "nom du plat en français",
  "food_name_ar": "nom en arabe si plat tunisien sinon null",
  "calories": estimation calories pour 1 portion normale,
  "protein_g": grammes de protéines,
  "carbs_g": grammes de glucides,
  "fat_g": grammes de lipides,
  "portion_g": poids estimé de la portion en grammes,
  "confidence": "high" ou "medium" ou "low",
  "is_tunisian": true ou false,
  "notes": "remarque courte sur le plat"
}`,
          },
        ],
      },
    ],
    max_tokens: 500,
  })

  const content = response.choices[0].message.content
  const clean   = content.replace(/```json|```/g, '').trim()

  try {
    return JSON.parse(clean)
  } catch {
    return {
      food_name:    'Plat non identifié',
      food_name_ar: null,
      calories:     0,
      protein_g:    0,
      carbs_g:      0,
      fat_g:        0,
      portion_g:    300,
      confidence:   'low',
      is_tunisian:  false,
      notes:        'Analyse impossible',
    }
  }
}

async function searchInFoodsTN(foodName) {
  if (!foodName) return null
  const words  = foodName.toLowerCase().split(' ')
  const result = await pool.query(
    `SELECT * FROM foods_tn
     WHERE name_fr ILIKE $1
        OR name_ar ILIKE $1
     ORDER BY
       CASE WHEN name_fr ILIKE $2 THEN 0 ELSE 1 END
     LIMIT 1`,
    [`%${words[0]}%`, `%${foodName}%`]
  )
  return result.rows.length ? result.rows[0] : null
}

async function analyzePhoto(imageBase64, mimeType) {
  console.log('🔍 Analyse photo avec Groq Vision...')

  const groqResult = await analyzeWithGroq(
    imageBase64, mimeType)

  console.log('Groq result:', groqResult.food_name,
    '— confiance:', groqResult.confidence)

  if (groqResult.is_tunisian ||
      groqResult.confidence !== 'high') {
    console.log('🇹🇳 Recherche dans base tunisienne...')
    const local = await searchInFoodsTN(groqResult.food_name)

    if (local) {
      console.log('✅ Trouvé dans foods_tn:', local.name_fr)
      return {
        food_name:    local.name_fr,
        food_name_ar: local.name_ar,
        calories:     parseFloat(local.calories),
        protein_g:    parseFloat(local.protein_g),
        carbs_g:      parseFloat(local.carbs_g),
        fat_g:        parseFloat(local.fat_g),
        portion_g:    parseFloat(local.portion_g),
        confidence:   'high',
        source:       'foods_tn',
        notes:        groqResult.notes,
        is_tunisian:  true,
      }
    }
  }

  return { ...groqResult, source: 'groq' }
}

module.exports = { analyzePhoto }