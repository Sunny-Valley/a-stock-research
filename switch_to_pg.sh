#!/bin/bash

echo "🔄 开始切换到标准 PG 驱动..."

# 1. 安装 pg 库
echo "📦 安装 pg 依赖..."
npm install pg

# 2. 交互式输入密码 (防止手动修改文件出错)
echo ""
echo "========================================================"
echo "🔴 请粘贴您的数据库连接串 (postgres://...)"
echo "   (在 Vercel Dashboard -> Storage -> .env.local 中复制)"
echo "========================================================"
read -p "数据库连接串: " DB_URL

if [ -z "$DB_URL" ]; then
  echo "❌ 错误: 未输入连接串！请重新运行脚本。"
  exit 1
fi

# 3. 生成后端代码 (使用 pg 连接池)
echo "🔧 重写 app/api/watchlist/route.js..."
cat <<EOF > app/api/watchlist/route.js
import { Pool } from 'pg';
import { NextResponse } from 'next/server';

// 使用标准 pg 连接池，配置 SSL 以适配 Vercel/Neon
const pool = new Pool({
  connectionString: "$DB_URL",
  ssl: {
    rejectUnauthorized: false // 允许自签名证书 (云数据库必须)
  },
  max: 3, // 限制连接数防止超限
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

export async function GET() {
  let client;
  try {
    client = await pool.connect();
    
    // 建表
    await client.query(\`
      CREATE TABLE IF NOT EXISTS watchlist (
        code VARCHAR(10) PRIMARY KEY,
        name VARCHAR(50),
        added_at TIMESTAMP DEFAULT NOW()
      )
    \`);
    
    const res = await client.query('SELECT * FROM watchlist ORDER BY added_at DESC');
    return NextResponse.json({ data: res.rows });
  } catch (error) {
    console.error("DB Error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  } finally {
    if (client) client.release();
  }
}

export async function POST(request) {
  let client;
  try {
    const { action, code, name } = await request.json();
    client = await pool.connect();

    if (action === 'add') {
      await client.query(
        'INSERT INTO watchlist (code, name) VALUES (\$1, \$2) ON CONFLICT (code) DO NOTHING',
        [code, name]
      );
    } else if (action === 'remove') {
      await client.query('DELETE FROM watchlist WHERE code = \$1', [code]);
    }
    
    const res = await client.query('SELECT * FROM watchlist ORDER BY added_at DESC');
    return NextResponse.json({ data: res.rows });
  } catch (error) {
    console.error("DB Write Error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  } finally {
    if (client) client.release();
  }
}
EOF

# 4. 强制上传
echo "🚀 正在强制上传代码..."
rm -rf .git
git init
git branch -M main
echo -e "node_modules/\n.next/\n.devcontainer/\n.env*.local" > .gitignore
git add .
git commit -m "Fix: Switch to PG driver with hardcoded credentials"
git remote add origin https://github.com/Sunny-Valley/a-stock-research
git push -u origin main --force

echo "✅ 修复完成！请等待 Vercel 部署变绿 (约1-2分钟)。"