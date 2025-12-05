import { sql } from '@vercel/postgres';
import { NextResponse } from 'next/server';

// 获取自选股列表
export async function GET() {
  try {
    // 确保表存在
    await sql`CREATE TABLE IF NOT EXISTS watchlist (
      code VARCHAR(10) PRIMARY KEY,
      name VARCHAR(50),
      added_at TIMESTAMP DEFAULT NOW()
    );`;
    
    // 获取列表
    const { rows } = await sql`SELECT * FROM watchlist ORDER BY added_at DESC`;
    return NextResponse.json({ data: rows });
  } catch (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}

// 添加/删除自选股
export async function POST(request) {
  try {
    const { action, code, name } = await request.json();
    
    if (action === 'add') {
      await sql`INSERT INTO watchlist (code, name) VALUES (${code}, ${name}) 
                ON CONFLICT (code) DO NOTHING`;
    } else if (action === 'remove') {
      await sql`DELETE FROM watchlist WHERE code = ${code}`;
    }
    
    const { rows } = await sql`SELECT * FROM watchlist ORDER BY added_at DESC`;
    return NextResponse.json({ data: rows });
  } catch (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
