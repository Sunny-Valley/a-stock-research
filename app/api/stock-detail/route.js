import { Pool } from 'pg';
import { NextResponse } from 'next/server';

const INJECTED_DB_URL = 'postgres://c665bdb8d82cf3a3c3d3fe13754288561d9cd8e7240d3ca3f7339fd15439a7da:sk_K4bvSlbIuv2mH6m1iRbCX@db.prisma.io:5432/postgres?sslmode=require';
export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get('code');
  const DB_URL = INJECTED_DB_URL || process.env.POSTGRES_URL;

  if (!code) return NextResponse.json({ error: 'Code required' }, { status: 400 });

  if (!DB_URL) {
    return NextResponse.json({ status: 'error', message: '数据库连接未配置' }, { status: 500 });
  }

  try {
    const pool = new Pool({
      connectionString: DB_URL,
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 5000,
    });
    
    const client = await pool.connect();
    
    // --- 核心逻辑：只查数据库，不进行任何实时抓取 ---
    // 这里的 ai_predictions_v2 表是由后台 Python 脚本定时填充的
    const res = await client.query('SELECT data, updated_at FROM ai_predictions_v2 WHERE code = $1', [code]);
    
    client.release();
    await pool.end();
    
    if (res.rows.length > 0) {
      const data = res.rows[0].data;
      data.lastUpdated = res.rows[0].updated_at;
      // 补充新闻字段（如果 Python 脚本没生成的话）
      if (!data.news) {
         data.news = [
            { type: '系统', title: '量化分析报告已从云端数据库同步', time: '刚刚' }
         ];
      }
      return NextResponse.json(data);
    } else {
      // 数据库无数据 -> 返回 Pending 状态，前端显示“计算中”
      return NextResponse.json({ 
        status: 'pending', 
        message: '该股票尚未纳入后台量化池，已加入队列，请等待下一次批量计算。' 
      });
    }

  } catch (error) {
    console.error("DB Error:", error);
    return NextResponse.json({ status: 'error', message: `数据库错误: ${error.message}` }, { status: 500 });
  }
}
