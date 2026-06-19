require('dotenv').config();
const { GoogleGenerativeAI } = require('@google/generative-ai');

async function testGeminiKey() {
  const key = process.env.GEMINI_API_KEY;

  console.log('\n=== Test Validation Clé Gemini ===\n');

  // 1. Vérification présence
  if (!key) {
    console.error('❌ GEMINI_API_KEY non trouvée dans .env');
    process.exit(1);
  }
  console.log('✅ Clé présente dans .env');

  // 2. Vérification format (clé Google AI commence par "AIza")
  if (!key.startsWith('AIza') || key.length < 30) {
    console.error('❌ Format de clé invalide (doit commencer par "AIza" et faire 39+ caractères)');
    process.exit(1);
  }
  console.log(`✅ Format valide (longueur: ${key.length})`);

  // 3. Test appel réel à l'API
  console.log('\n⏳ Test connexion à l\'API Gemini...');
  const configs = [
    { apiVersion: 'v1beta', model: 'gemini-1.5-flash' },
    { apiVersion: 'v1beta', model: 'gemini-2.0-flash' },
    { apiVersion: 'v1',     model: 'gemini-1.5-flash' },
    { apiVersion: 'v1beta', model: 'gemini-pro' },
  ];

  for (const { apiVersion, model: modelName } of configs) {
    console.log(`   Essai ${modelName} (${apiVersion})...`);
    try {
      const genAI = new GoogleGenerativeAI(key, { apiVersion });
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent('Réponds juste "OK".');
      const text = result.response.text();
      console.log(`✅ API Gemini opérationnelle avec "${modelName}" - Réponse: "${text.trim()}"`);
      console.log('\n🎉 Clé Gemini valide et fonctionnelle !\n');
      return;
    } catch (err) {
      if (err.message.includes('404') || err.message.includes('not found') || err.message.includes('not supported')) {
        console.log(`   ⚠️  Non disponible, on essaie le suivant...`);
        continue;
      }
      // Erreur liée à la clé
      console.error('❌ Échec connexion API:', err.message);
      if (err.message.includes('API_KEY_INVALID') || err.message.includes('400')) {
        console.error('   → La clé est invalide ou révoquée');
      } else if (err.message.includes('PERMISSION_DENIED') || err.message.includes('403')) {
        console.error('   → La clé n\'a pas les permissions nécessaires');
      } else if (err.message.includes('quota') || err.message.includes('429')) {
        console.log(`✅ Clé authentifiée sur "${modelName}" — quota free tier épuisé.`);
        console.log('   → La clé est valide. Active la facturation sur https://ai.google.dev ou attends le reset quotidien.');
        console.log('\n⚠️  Agent temporairement indisponible (quota). Clé OK.\n');
        return;
      }
      process.exit(1);
    }
  }
  console.error('❌ Aucun modèle disponible. Vérifie les modèles accessibles avec ta clé.');
  process.exit(1);
}

testGeminiKey();
