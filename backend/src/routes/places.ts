import { Router } from 'express'
import { db } from '../db'
import { requireAuth, AuthRequest } from '../middleware/auth'

export const placesRouter = Router()
placesRouter.use(requireAuth)

// GET /places
placesRouter.get('/', async (req, res) => {
  const { userId } = req as AuthRequest
  const r = await db.query(
    `SELECT id, name, emoji, latitude, longitude, visit_count, last_visit
     FROM places WHERE user_id=$1 ORDER BY visit_count DESC LIMIT 20`,
    [userId]
  )
  res.json(r.rows.map(row => ({
    id:         row.id,
    name:       row.name,
    emoji:      row.emoji,
    coordinate: row.latitude ? { latitude: row.latitude, longitude: row.longitude } : null,
    visitCount: row.visit_count,
    lastVisit:  row.last_visit,
  })))
})
