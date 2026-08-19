import { Router } from 'express'
import { z } from 'zod'
import { db } from '../db'
import { requireAuth, AuthRequest } from '../middleware/auth'

export const conversationsRouter = Router()
conversationsRouter.use(requireAuth)

// GET /conversations
conversationsRouter.get('/', async (req, res) => {
  const { userId } = req as unknown as AuthRequest
  const r = await db.query(
    `SELECT c.id, c.last_message, c.last_message_at,
            u.id as other_id, u.display_name, u.avatar
     FROM conversations c
     JOIN users u ON u.id = CASE WHEN c.participant_a = $1 THEN c.participant_b ELSE c.participant_a END
     WHERE c.participant_a = $1 OR c.participant_b = $1
     ORDER BY c.last_message_at DESC NULLS LAST`,
    [userId]
  )
  res.json(r.rows.map(row => ({
    id:            row.id,
    lastMessage:   row.last_message,
    lastMessageAt: row.last_message_at,
    participant: { id: row.other_id, displayName: row.display_name, avatar: row.avatar },
  })))
})

// GET /conversations/:id/messages
conversationsRouter.get('/:id/messages', async (req, res) => {
  const { userId } = req as unknown as AuthRequest
  const { id } = req.params
  // Verify participant
  const check = await db.query(
    'SELECT id FROM conversations WHERE id=$1 AND (participant_a=$2 OR participant_b=$2)',
    [id, userId]
  )
  if (!check.rows[0]) { res.status(403).json({ error: 'Forbidden' }); return }

  const r = await db.query(
    `SELECT m.id, m.sender_id, m.content, m.created_at,
            u.display_name as sender_name
     FROM messages m JOIN users u ON u.id = m.sender_id
     WHERE m.conversation_id = $1
     ORDER BY m.created_at ASC LIMIT 100`,
    [id]
  )
  res.json(r.rows.map(row => ({
    id:         row.id,
    senderId:   row.sender_id,
    senderName: row.sender_name,
    content:    row.content,
    createdAt:  row.created_at,
    isMine:     row.sender_id === userId,
  })))
})

// POST /conversations/:id/messages
conversationsRouter.post('/:id/messages', async (req, res) => {
  const { userId } = req as unknown as AuthRequest
  const { id } = req.params
  const { content } = z.object({ content: z.string().min(1).max(2000) }).parse(req.body)

  const check = await db.query(
    'SELECT id FROM conversations WHERE id=$1 AND (participant_a=$2 OR participant_b=$2)',
    [id, userId]
  )
  if (!check.rows[0]) { res.status(403).json({ error: 'Forbidden' }); return }

  const r = await db.query(
    `INSERT INTO messages (conversation_id, sender_id, content)
     VALUES ($1,$2,$3) RETURNING id, created_at`,
    [id, userId, content]
  )
  await db.query(
    'UPDATE conversations SET last_message=$1, last_message_at=NOW() WHERE id=$2',
    [content, id]
  )
  res.json({ id: r.rows[0].id, createdAt: r.rows[0].created_at })
})

// POST /conversations — create or get DM with a friend
conversationsRouter.post('/', async (req, res) => {
  const { userId } = req as unknown as AuthRequest
  const { friendId } = z.object({ friendId: z.string().uuid() }).parse(req.body)

  if (friendId === userId) { res.status(400).json({ error: 'Cannot message yourself' }); return }
  const friendship = await db.query(
    'SELECT 1 FROM friendships WHERE user_id = $1 AND friend_id = $2',
    [userId, friendId]
  )
  if (!friendship.rows[0]) { res.status(403).json({ error: 'Friendship required' }); return }

  const [a, b] = [userId, friendId].sort()
  const r = await db.query(
    `INSERT INTO conversations (participant_a, participant_b)
     VALUES ($1,$2) ON CONFLICT (participant_a, participant_b)
     DO UPDATE SET participant_a=EXCLUDED.participant_a
     RETURNING id`,
    [a, b]
  )
  res.json({ id: r.rows[0].id })
})

// PATCH /conversations/:id/read — verify access and acknowledge read state
conversationsRouter.patch('/:id/read', async (req, res) => {
  const { userId } = req as unknown as AuthRequest
  const { id } = req.params
  const check = await db.query(
    'SELECT id FROM conversations WHERE id=$1 AND (participant_a=$2 OR participant_b=$2)',
    [id, userId]
  )
  if (!check.rows[0]) { res.status(403).json({ error: 'Forbidden' }); return }
  // The current PostgreSQL schema has no unread/read columns; keep the endpoint
  // compatible while the message-read model is introduced in a later migration.
  res.json({ ok: true })
})
