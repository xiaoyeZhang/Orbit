import 'dotenv/config'
import express from 'express'
import cors from 'cors'
import { db, runMigration } from './db'
import { connectRedis } from './redis'
import { authRouter }          from './routes/auth'
import { usersRouter }         from './routes/users'
import { friendsRouter }       from './routes/friends'
import { locationRouter }      from './routes/location'
import { conversationsRouter } from './routes/conversations'
import { placesRouter }        from './routes/places'

const app = express()

app.use(cors())
app.use(express.json())

// Health check
app.get('/health', (_req, res) => res.json({ ok: true, ts: new Date().toISOString() }))

// Routes
app.use('/auth',          authRouter)
app.use('/users',         usersRouter)
app.use('/friends',       friendsRouter)
app.use('/location',      locationRouter)
app.use('/conversations', conversationsRouter)
app.use('/places',        placesRouter)

// Global error handler
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  if (err.name === 'ZodError') {
    res.status(400).json({ error: 'Validation error', details: err.message })
    return
  }
  console.error(err)
  res.status(500).json({ error: 'Internal server error' })
})

async function main() {
  await connectRedis()
  await runMigration()

  const port = Number(process.env.PORT ?? 3000)
  app.listen(port, '0.0.0.0', () => {
    console.log(`🚀 Orbit backend running on :${port}`)
    console.log(`   NODE_ENV=${process.env.NODE_ENV}`)
  })
}

main().catch(err => {
  console.error('Fatal:', err)
  process.exit(1)
})
