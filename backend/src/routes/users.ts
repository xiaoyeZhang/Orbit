import { Router } from 'express'
import { z } from 'zod'
import { db } from '../db'
import { requireAuth, AuthRequest } from '../middleware/auth'

export const usersRouter = Router()
usersRouter.use(requireAuth)

// GET /users/me
usersRouter.get('/me', async (req, res) => {
  const { userId } = req as unknown as AuthRequest
  const r = await db.query(
    'SELECT id, display_name, bio, invite_code, avatar, is_ghost FROM users WHERE id = $1',
    [userId]
  )
  if (!r.rows[0]) { res.status(404).json({ error: 'Not found' }); return }
  const u = r.rows[0]
  res.json({
    id: u.id, displayName: u.display_name, bio: u.bio,
    inviteCode: u.invite_code, avatar: u.avatar, isGhost: u.is_ghost,
  })
})

// PATCH /users/me
usersRouter.patch('/me', async (req, res) => {
  const { userId } = req as unknown as AuthRequest
  const body = z.object({
    displayName: z.string().optional(),
    bio:         z.string().optional(),
    avatar:      z.object({}).passthrough().optional(),
  }).parse(req.body)

  const sets: string[] = []
  const vals: unknown[] = []
  let idx = 1
  if (body.displayName !== undefined) { sets.push(`display_name = $${idx++}`); vals.push(body.displayName) }
  if (body.bio         !== undefined) { sets.push(`bio = $${idx++}`);          vals.push(body.bio) }
  if (body.avatar      !== undefined) { sets.push(`avatar = $${idx++}`);       vals.push(JSON.stringify(body.avatar)) }
  if (!sets.length) { res.json({ ok: true }); return }

  vals.push(userId)
  await db.query(`UPDATE users SET ${sets.join(', ')} WHERE id = $${idx}`, vals)
  res.json({ ok: true })
})

// PATCH /users/me/ghost-mode
usersRouter.patch('/me/ghost-mode', async (req, res) => {
  const { userId } = req as unknown as AuthRequest
  const { enabled } = z.object({ enabled: z.boolean() }).parse(req.body)
  await db.query('UPDATE users SET is_ghost = $1 WHERE id = $2', [enabled, userId])
  res.json({ ok: true })
})
