const { GoogleGenerativeAI } = require('@google/generative-ai');
const { pool } = require('../config/db');

// FORCE LA VERSION v1 ICI (C'est le changement critique)
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY, { apiVersion: 'v1beta' });

function buildSystemPrompt(user, profile) {
  const context = profile ? `
Prénom: ${user.full_name || 'utilisateur'}
Objectif: ${profile.goal === 'lose' ? 'perdre du poids' : profile.goal === 'gain' ? 'prendre de la masse' : 'maintenir le poids'}
Calories: ${profile.daily_calories} kcal
Macros: P:${profile.protein_g}g, G:${profile.carbs_g}g, L:${profile.fat_g}g
` : 'Profil non configuré.';

  return `Tu es NutriBot, coach nutritionnel Pulse expert en cuisine tunisienne. 
Infos: ${context}
Réponds en français, sois concis (3 lignes) et encourageant. Pas de conseils médicaux.`;
}

async function loadHistory(userId) {
  const result = await pool.query(
    `SELECT role, content FROM conversations WHERE user_id = $1 ORDER BY created_at ASC LIMIT 20`,
    [userId]
  );
  return result.rows.map(row => ({
    role: row.role === 'user' ? 'user' : 'model',
    parts: [{ text: row.content }],
  }));
}

async function saveMessage(userId, role, content) {
  await pool.query(
    `INSERT INTO conversations (user_id, role, content) VALUES ($1, $2, $3)`,
    [userId, role, content]
  );
}

async function chat(userId, userMessage, user, profile) {
  try {
    // Configuration simplifiée du modèle
    const model = genAI.getGenerativeModel({
      model: 'gemini-2.0-flash',
      systemInstruction: buildSystemPrompt(user, profile),
    });

    const history = await loadHistory(userId);

    const chatSession = model.startChat({ history });

    const result = await chatSession.sendMessage(userMessage);
    const aiMessage = result.response.text();

    await saveMessage(userId, 'user', userMessage);
    await saveMessage(userId, 'assistant', aiMessage);

    return aiMessage;
  } catch (error) {
    console.error("Erreur Gemini détaillée:", error);
    throw new Error(error.message);
  }
}

async function clearHistory(userId) {
  await pool.query('DELETE FROM conversations WHERE user_id = $1', [userId]);
}

module.exports = { chat, clearHistory };