import { createClient } from '@vercel/postgres';
import { NextResponse } from 'next/server';

export async function GET() {
  let client;
  try {
    // 检查环境变量是否存在
    if (!process.env.POSTGRES_URL) {
      throw new Error("POSTGRES_URL 环境变量未找到");
    }

    // 1. 创建客户端实例 (显式传递连接字符串，解决 missing_connection_string 错误)
    client = createClient({
      connectionString: process.env.POSTGRES_URL,
    });
    
    // 2. 建立连接
    await client.connect();

    // 3. 确保表存在
    await client.sql`CREATE TABLE IF NOT EXISTS watchlist (
      code VARCHAR(10) PRIMARY KEY,
      name VARCHAR(50),
      added_at TIMESTAMP DEFAULT NOW()
    );`;
    
    // 4. 查询数据
    const { rows } = await client.sql`SELECT * FROM watchlist ORDER BY added_at DESC`;
    
    return NextResponse.json({ data: rows });
  } catch (error) {
    console.error("DB Error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  } finally {
    // 5. 务必关闭连接
    if (client) await client.end();
  }
}

export async function POST(request) {
  let client;
  try {
    const { action, code, name } = await request.json();
    
    if (!process.env.POSTGRES_URL) {
      throw new Error("POSTGRES_URL 环境变量未找到");
    }

    client = createClient({
      connectionString: process.env.POSTGRES_URL,
    });
    
    await client.connect();

    if (action === 'add') {
      await client.sql`INSERT INTO watchlist (code, name) VALUES (${code}, ${name}) 
                       ON CONFLICT (code) DO NOTHING`;
    } else if (action === 'remove') {
      await client.sql`DELETE FROM watchlist WHERE code = ${code}`;
    }
    
    const { rows } = await client.sql`SELECT * FROM watchlist ORDER BY added_at DESC`;
    return NextResponse.json({ data: rows });
  } catch (error) {
    console.error("DB Write Error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  } finally {
    if (client) await client.end();
  }
}
