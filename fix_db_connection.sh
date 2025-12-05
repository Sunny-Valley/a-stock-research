#!/bin/bash

echo "🔌 开始修改 API 以适配直连模式 (Direct Connection)..."

# 重写 app/api/watchlist/route.js
# 使用 createClient() 替代 sql``，这样可以绕过连接池检查
cat <<EOF > app/api/watchlist/route.js
import { createClient } from '@vercel/postgres';
import { NextResponse } from 'next/server';

export async function GET() {
  let client;
  try {
    // 1. 创建客户端实例
    client = createClient();
    // 2. 建立连接
    await client.connect();

    // 3. 确保表存在
    await client.sql\`CREATE TABLE IF NOT EXISTS watchlist (
      code VARCHAR(10) PRIMARY KEY,
      name VARCHAR(50),
      added_at TIMESTAMP DEFAULT NOW()
    );\`;
    
    // 4. 查询数据
    const { rows } = await client.sql\`SELECT * FROM watchlist ORDER BY added_at DESC\`;
    
    return NextResponse.json({ data: rows });
  } catch (error) {
    console.error("DB Error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  } finally {
    // 5. 务必关闭连接 (直连模式必须手动关闭)
    if (client) await client.end();
  }
}

export async function POST(request) {
  let client;
  try {
    const { action, code, name } = await request.json();
    
    client = createClient();
    await client.connect();

    if (action === 'add') {
      await client.sql\`INSERT INTO watchlist (code, name) VALUES (\${code}, \${name}) 
                       ON CONFLICT (code) DO NOTHING\`;
    } else if (action === 'remove') {
      await client.sql\`DELETE FROM watchlist WHERE code = \${code}\`;
    }
    
    const { rows } = await client.sql\`SELECT * FROM watchlist ORDER BY added_at DESC\`;
    return NextResponse.json({ data: rows });
  } catch (error) {
    console.error("DB Write Error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  } finally {
    if (client) await client.end();
  }
}
EOF

echo "✅ 代码已修改为兼容模式！"
echo "正在提交更新..."

git add .
git commit -m "Fix: Switch to createClient for direct DB connection"
git push origin main