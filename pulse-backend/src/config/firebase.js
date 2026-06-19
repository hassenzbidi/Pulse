const admin = require('firebase-admin')

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId:   process.env.FIREBASE_PROJECT_ID   || 'pulse-app',
      privateKey:  process.env.FIREBASE_PRIVATE_KEY  || '',
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL || '',
    }),
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET || '',
  })
}

const auth    = admin.auth()
const storage = admin.storage()

module.exports = { admin, auth, storage }