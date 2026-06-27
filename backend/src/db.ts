import { Pool } from 'pg'

export const db = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
})

export async function runMigration() {
  const fs = await import('fs')
  const path = await import('path')
  const sql = fs.readFileSync(path.join(__dirname, '../migrations/001_init.sql'), 'utf8')
  await db.query(sql)
  console.log('✅ Migration applied')
}
