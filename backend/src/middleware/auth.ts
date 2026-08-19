import { Request, Response, NextFunction } from 'express'
import jwt from 'jsonwebtoken'

export interface AuthRequest extends Request {
  userId: string
}

function jwtSecret(): string {
  const secret = process.env.JWT_SECRET
  if (!secret || secret.length < 32) {
    throw new Error('JWT_SECRET must be configured with at least 32 characters')
  }
  return secret
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing token' })
    return
  }
  try {
    const token = header.slice(7)
    const payload = jwt.verify(token, jwtSecret()) as { sub?: string }
    if (!payload.sub) {
      res.status(401).json({ error: 'Invalid token' })
      return
    }
    ;(req as AuthRequest).userId = payload.sub
    next()
  } catch {
    res.status(401).json({ error: 'Invalid token' })
  }
}

export function signToken(userId: string): string {
  return jwt.sign({ sub: userId }, jwtSecret(), { expiresIn: '30d' })
}
