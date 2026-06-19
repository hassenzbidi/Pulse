function initSocket(io) {
  io.on('connection', (socket) => {
    console.log('🔌 Socket connecté:', socket.id)

    socket.on('join_room', (userId) => {
      socket.join(userId)
      console.log(`User ${userId} a rejoint sa salle`)
    })

    socket.on('send_message', ({ toUserId, message }) => {
      io.to(toUserId).emit('receive_message', {
        from:      socket.id,
        message,
        timestamp: new Date().toISOString()
      })
    })

    socket.on('disconnect', () => {
      console.log('🔌 Socket déconnecté:', socket.id)
    })
  })
}

module.exports = { initSocket }