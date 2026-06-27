import { Router } from 'express'
import { z } from 'zod'
import { db } from '../db'
import { requireAuth, AuthRequest } from '../middleware/auth'
import { pushLocationToFriends } from './friends'

export const locationRouter = Router()
locationRouter.use(requireAuth)

// POST /location — report current location + presence
locationRouter.post('/', async (req, res) => {
  const { userId } = req as AuthRequest
  const body = z.object({
    latitude:   z.number(),
    longitude:  z.number(),
    battery:    z.number().int().min(0).max(100).default(100),
    isCharging: z.boolean().default(false),
    movement:   z.enum(['stationary', 'walking', 'running', 'cycling', 'driving']).default('stationary'),
  }).parse(req.body)

  await db.query(
    `INSERT INTO locations (user_id, latitude, longitude, battery, is_charging, movement, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,NOW())
     ON CONFLICT (user_id) DO UPDATE SET
       latitude=EXCLUDED.latitude, longitude=EXCLUDED.longitude,
       battery=EXCLUDED.battery,   is_charging=EXCLUDED.is_charging,
       movement=EXCLUDED.movement,  updated_at=NOW()`,
    [userId, body.latitude, body.longitude, body.battery, body.isCharging, body.movement]
  )

  // Push update to all friends who are streaming
  const friendsResult = await db.query(
    'SELECT friend_id FROM friendships WHERE user_id = $1',
    [userId]
  )
  const friendIds = friendsResult.rows.map(r => r.friend_id as string)

  if (friendIds.length > 0) {
    pushLocationToFriends(friendIds, {
      type:      'location_update',
      userId,
      latitude:  body.latitude,
      longitude: body.longitude,
      battery:   body.battery,
      isCharging: body.isCharging,
      movement:  body.movement,
      updatedAt: new Date().toISOString(),
    })
  }

  res.json({ ok: true })
})
