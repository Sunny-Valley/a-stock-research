import { createClient } from '@vercel/postgres';
import { NextResponse } from 'next/server';

export async function GET() {
  // ------------------------------------------------------------------
  // 请在下面双引号内粘贴您的 postgres://... 连接串
  // ------------------------------------------------------------------
  const MANUAL_DB_URL = ""; 
  
  const dbUrl = process.env.POSTGRES_URL || MANUAL_DB_URL;
  
  if (!dbUrl) {
    return NextResponse.json({ error: "missing_connection_string", detail: "请在代码中手动填入 MANUAL_DB_URL" }, { status: 500 });
  }

  const client = createClient({ connectionString: dbUrl });
  
  try {
    await client.connect();
    await client.sql`CREATE TABLE IF NOT EXISTS watchlist (code VARCHAR(10) PRIMARY KEY, name VARCHAR(50), added_at TIMESTAMP DEFAULT NOW());`;
    const { rows } = await client.sql`SELECT * FROM watchlist ORDER BY added_at DESC`;
    return NextResponse.json({ data: rows });
  } catch (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  } finally {
    await client.end();
  }
}

export async function POST(request) {
  const MANUAL_DB_URL = ""; // 这里也需要粘贴，或者复用上面的逻辑
  const dbUrl = process.env.POSTGRES_URL || MANUAL_DB_URL;
  
  if (!dbUrl) return NextResponse.json({ error: "missing_connection_string" }, { status: 500 });

  const client = createClient({ connectionString: dbUrl });
  try {
    const { action, code, name } = await request.json();
    await client.connect();
    if (action === 'add') await client.sql`INSERT INTO watchlist (code, name) VALUES (${code}, ${name}) ON CONFLICT (code) DO NOTHING`;
    else if (action === 'remove') await client.sql`DELETE FROM watchlist WHERE code = ${code}`;
    const { rows } = await client.sql`SELECT * FROM watchlist ORDER BY added_at DESC`;
    return NextResponse.json({ data: rows });
  } catch (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  } finally {
    await client.end();
  }
}
