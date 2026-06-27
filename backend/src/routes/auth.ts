import { Router } from 'express'
import { z } from 'zod'
import { v4 as uuid } from 'uuid'
import { db } from '../db'
import { saveOtp, verifyOtp } from '../redis'
import { signToken } from '../middleware/auth'

export const authRouter = Router()

// Generate invite code
function makeInviteCode(): string {
  return 'J-' + Math.random().toString(36).slice(2, 8).toUpperCase()
}

// POST /auth/request-code
authRouter.post('/request-code', async (req, res) => {
  const { phone } = z.object({ phone: z.string().min(5) }).parse(req.body)

  const code = String(Math.floor(100000 + Math.random() * 900000))
  await saveOtp(phone, code)

  const isDev = process.env.NODE_ENV !== 'production'
  console.log(`📱 OTP for ${phone}: ${code}`)

  res.json({
    ok: true,
    // 开发模式下直接返回验证码，生产环境删掉 debug_code 字段并接入短信服务
    ...(isDev && { debug_code: code }),
  })
})

// POST /auth/verify
authRouter.post('/verify', async (req, res) => {
  const { phone, code } = z.object({
    phone: z.string().min(5),
    code:  z.string().min(4),
  }).parse(req.body)

  const isDev = process.env.NODE_ENV !== 'production'

  // 开发模式：4 位以上任意码都通过（与 iOS Demo 一致）
  const valid = isDev ? code.length >= 4 : await verifyOtp(phone, code)
  if (!valid) {
    res.status(400).json({ error: 'Invalid or expired code' })
    return
  }

  // Upsert user
  const result = await db.query<{ id: string; display_name: string; bio: string; invite_code: string; avatar: object }>(
    `INSERT INTO users (phone, display_name, invite_code, avatar)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (phone) DO UPDATE SET phone = EXCLUDED.phone
     RETURNING id, display_name, bio, invite_code, avatar`,
    [phone, phone.slice(-4) ? `用户${phone.slice(-4)}` : '新用户', makeInviteCode(), {}]
  )

  const user = result.rows[0]
  const token = signToken(user.id)

  res.json({
    token,
    user: {
      id:          user.id,
      displayName: user.display_name,
      bio:         user.bio,
      inviteCode:  user.invite_code,
      avatar:      user.avatar,
      phoneNumber: phone,
    },
  })
})
