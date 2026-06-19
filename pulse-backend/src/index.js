
require('dotenv').config();
console.log("Vérification Clé API:", process.env.GROQ_API_KEY ? "Chargée ✅" : "Non trouvée ❌");
const express    = require('express')
const cors       = require('cors')
const helmet     = require('helmet')
const http       = require('http')
const { Server } = require('socket.io')
const rateLimit  = require('express-rate-limit')

const { testConnection } = require('./config/db')
const { initSocket }     = require('./config/socket')

const authRoutes    = require('./routes/auth.routes')
const profileRoutes = require('./routes/profile.routes')
const mealRoutes    = require('./routes/meal.routes')
const scoreRoutes   = require('./routes/score.routes')
const weightRoutes  = require('./routes/weight.routes')
const foodRoutes    = require('./routes/food.routes')
const agentRoutes   = require('./routes/agent.routes')
const doctorRoutes = require('./routes/doctor.routes')
const adminRoutes = require('./routes/admin.routes')
const notificationRoutes = require('./routes/notification.routes')
const chatRoutes         = require('./routes/chat.routes')


const app    = express()
const server = http.createServer(app)
const io     = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
})

app.use(helmet())
app.use(cors())
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true }))

app.use('/api/', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Trop de requêtes' }
}))

app.use('/api/auth',    authRoutes)
app.use('/api/profile', profileRoutes)
app.use('/api/meals',   mealRoutes)
app.use('/api/scores',  scoreRoutes)
app.use('/api/weight',  weightRoutes)
app.use('/api/foods',   foodRoutes)
app.use('/api/agent', agentRoutes)
app.use('/api/doctor', doctorRoutes)
app.use('/api/admin', adminRoutes)
app.use('/api/notifications', notificationRoutes)
app.use('/api/chat',          chatRoutes)

app.get('/health', (req, res) => {
  res.json({ status: 'ok', app: 'Pulse API', version: '1.0.0' })
})

app.use((req, res) => {
  res.status(404).json({ error: 'Route non trouvée' })
})

app.use((err, req, res, next) => {
  console.error('Erreur:', err.message)
  res.status(500).json({ error: err.message })
})

initSocket(io)

const PORT = 3000

async function start() {
  await testConnection()
  server.listen(PORT, () => {
    console.log(`\n🚀 Pulse API démarrée sur le port ${PORT}`)
    console.log(`🔗 Test : http://localhost:${PORT}/health\n`)
  })
}

start()