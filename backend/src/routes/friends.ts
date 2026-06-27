import { Router, Request, Response } from 'express'
import { z } from 'zod'
import { db } from '../db'
import { requireAuth, AuthRequest } from '../middleware/auth'
import { redis } from '../redis'

export const friendsRouter = Router()

// SSE client registry: userId → list of SSE response objects
const sseClients = new Map<string, Response[]>()

export function pushLocationToFriends(friendIds: string[], payload: object) {
  const data = `data: ${JSON.stringify(payload)}\n\n`
  for (const fid of friendIds) {
    const clients = sseClients.get(fid) ?? []
    for (const res of clients) {
      try { res.write(data) } catch { /* client disconnected */ }
    }
  }
}

friendsRouter.use(requireAuth)

// GET /friends — list friends with latest location
friendsRouter.get('/', async (req, res) => {
  const { userId } = req as AuthRequest
  const r = await db.query(
    `SELECT u.id, u.display_name, u.bio, u.invite_code, u.avatar,
            l.latitude, l.longitude, l.battery, l.is_charging, l.movement, l.updated_at
     FROM friendships f
     JOIN users     u ON u.id = f.friend_id
     LEFT JOIN locations l ON l.user_id = f.friend_id
     WHERE f.user_id = $1 AND u.is_ghost = false`,
    [userId]
  )
  res.json(r.rows.map(row => ({
    id:          row.id,
    displayName: row.display_name,
    bio:         row.bio,
    inviteCode:  row.invite_code,
    avatar:      row.avatar,
    coordinate:  row.latitude ? { latitude: row.latitude, longitude: row.longitude } : null,
    presence: {
      batteryLevel: row.battery ?? 100,
      isCharging:   row.is_charging ?? false,
      movement:     row.movement ?? 'stationary',
      lastSeen:     row.updated_at,
    },
  })))
})

// POST /friends/add — add by invite code
friendsRouter.post('/add', async (req, res) => {
  const { userId } = req as AuthRequest
  const { inviteCode } = z.object({ inviteCode: z.string().min(3) }).parse(req.body)

  const r = await db.query(
    'SELECT id FROM users WHERE UPPER(invite_code) = UPPER($1) AND id != $2',
    [inviteCode, userId]
  )
  if (!r.rows[0]) { res.status(404).json({ error: 'Invite code not found' }); return }
  const friendId = r.rows[0].id

  // Bidirectional friendship
  await db.query(
    `INSERT INTO friendships (user_id, friend_id) VALUES ($1,$2),($2,$1)
     ON CONFLICT DO NOTHING`,
    [userId, friendId]
  )

  // Return the new friend's profile
  const fr = await db.query(
    `SELECT u.id, u.display_name, u.bio, u.invite_code, u.avatar,
            l.latitude, l.longitude, l.battery, l.is_charging, l.movement
     FROM users u LEFT JOIN locations l ON l.user_id = u.id
     WHERE u.id = $1`,
    [friendId]
  )
  const f = fr.rows[0]
  res.json({
    id:          f.id,
    displayName: f.display_name,
    bio:         f.bio,
    inviteCode:  f.invite_code,
    avatar:      f.avatar,
    coordinate:  f.latitude ? { latitude: f.latitude, longitude: f.longitude } : null,
    presence: { batteryLevel: f.battery ?? 100, isCharging: f.is_charging ?? false, movement: f.movement ?? 'stationary' },
  })
})

// GET /friends/stream — SSE real-time location updates
friendsRouter.get('/stream', async (req: Request, res: Response) => {
  const { userId } = req as AuthRequest

  res.setHeader('Content-Type',  'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache')
  res.setHeader('Connection',    'keep-alive')
  res.setHeader('X-Accel-Buffering', 'no') // nginx: disable buffering
  res.flushHeaders()

  // Register client
  const existing = sseClients.get(userId) ?? []
  existing.push(res)
  sseClients.set(userId, existing)

  // Send current friend locations immediately
  const r = await db.query(
    `SELECT u.id, u.display_name, u.avatar,
            l.latitude, l.longitude, l.battery, l.is_charging, l.movement, l.updated_at
     FROM friendships f
     JOIN users u ON u.id = f.friend_id
     LEFT JOIN locations l ON l.user_id = f.friend_id
     WHERE f.user_id = $1 AND u.is_ghost = false`,
    [userId]
  )
  res.write(`data: ${JSON.stringify({ type: 'snapshot', friends: r.rows })}\n\n`)

  // Heartbeat every 30s
  const heartbeat = setInterval(() => {
    try { res.write(': ping\n\n') } catch { clearInterval(heartbeat) }
  }, 30_000)

  req.on('close', () => {
    clearInterval(heartbeat)
    const clients = sseClients.get(userId) ?? []
    sseClients.set(userId, clients.filter(c => c !== res))
  })
})
