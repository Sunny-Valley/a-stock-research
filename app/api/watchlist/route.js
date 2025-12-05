import { sql } from '@vercel/postgres';
import { NextResponse } from 'next/server';

export async function GET() {
  try {
    // 打印环境变量检查日志
    console.log("Checking DB connection...");
    if (!process.env.POSTGRES_URL) {
      throw new Error("环境变量 POSTGRES_URL 未定义！请在 Vercel Settings 中配置。");
    }

    // 尝试建表
    await sql`CREATE TABLE IF NOT EXISTS watchlist (
      code VARCHAR(10) PRIMARY KEY,
      name VARCHAR(50),
      added_at TIMESTAMP DEFAULT NOW()
    );`;
    
    const { rows } = await sql`SELECT * FROM watchlist ORDER BY added_at DESC`;
    return NextResponse.json({ data: rows });
  } catch (error) {
    console.error("Database Error Details:", error);
    // 返回详细错误给前端，方便调试
    return NextResponse.json({ error: error.message, detail: String(error) }, { status: 500 });
  }
}

export async function POST(request) {
  try {
    const { action, code, name } = await request.json();
    if (action === 'add') {
      await sql`INSERT INTO watchlist (code, name) VALUES (${code}, ${name}) ON CONFLICT (code) DO NOTHING`;
    } else if (action === 'remove') {
      await sql`DELETE FROM watchlist WHERE code = ${code}`;
    }
    const { rows } = await sql`SELECT * FROM watchlist ORDER BY added_at DESC`;
    return NextResponse.json({ data: rows });
  } catch (error) {
    console.error("Database Write Error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
