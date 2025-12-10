import { Pool } from 'pg';
import { NextResponse } from 'next/server';

const INJECTED_DB_URL = 'postgres://c665bdb8d82cf3a3c3d3fe13754288561d9cd8e7240d3ca3f7339fd15439a7da:sk_K4bvSlbIuv2mH6m1iRbCX@db.prisma.io:5432/postgres?sslmode=require';
const DEFAULT_LIST = [
  {code: '600519', name: '贵州茅台'},
  {code: '300750', name: '宁德时代'},
  {code: '000001', 'name': '平安银行'}
];
export async function GET() {
  const DB_URL = INJECTED_DB_URL || process.env.POSTGRES_URL;
  if (DB_URL) {
    try {
      const pool = new Pool({ connectionString: DB_URL, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 3000 });
      const client = await pool.connect();
      await client.query(`CREATE TABLE IF NOT EXISTS watchlist (code VARCHAR(10) PRIMARY KEY, name VARCHAR(50), added_at TIMESTAMP DEFAULT NOW())`);
      const res = await client.query('SELECT * FROM watchlist ORDER BY added_at DESC');
      client.release();
      await pool.end();
      if (res.rows.length > 0) return NextResponse.json({ data: res.rows });
    } catch (e) { console.warn("Watchlist DB failed", e); }
  }
  return NextResponse.json({ data: DEFAULT_LIST });
}

export async function POST(request) {
  const DB_URL = INJECTED_DB_URL || process.env.POSTGRES_URL;
  if (!DB_URL) return NextResponse.json({ error: "No DB" }, { status: 200 });
  try {
    const { action, code, name } = await request.json();
    const pool = new Pool({ connectionString: DB_URL, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 3000 });
    const client = await pool.connect();
    if (action === 'add') await client.query('INSERT INTO watchlist (code, name) VALUES ($1, $2) ON CONFLICT (code) DO NOTHING', [code, name]);
    else if (action === 'remove') await client.query('DELETE FROM watchlist WHERE code = $1', [code]);
    const res = await client.query('SELECT * FROM watchlist ORDER BY added_at DESC');
    client.release();
    await pool.end();
    return NextResponse.json({ data: res.rows });
  } catch (e) { return NextResponse.json({ error: e.message }, { status: 200 }); }
}
