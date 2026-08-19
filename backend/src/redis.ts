import { createClient } from 'redis'

export const redis = createClient({ url: process.env.REDIS_URL })

redis.on('error', (err: Error) => console.error('Redis error:', err))

export async function connectRedis() {
  await redis.connect()
  console.log('✅ Redis connected')
}

// OTP helpers
const OTP_TTL = 600 // 10 minutes

export async function saveOtp(phone: string, code: string) {
  await redis.setEx(`otp:${phone}`, OTP_TTL, code)
}

export async function verifyOtp(phone: string, code: string): Promise<boolean> {
  const stored = await redis.get(`otp:${phone}`)
  if (!stored) return false
  const match = stored === code
  if (match) await redis.del(`otp:${phone}`)
  return match
}

// SSE pub/sub: when a user's location updates, notify their friends
export async function publishLocation(userId: string, payload: object) {
  await redis.publish(`location:${userId}`, JSON.stringify(payload))
}
