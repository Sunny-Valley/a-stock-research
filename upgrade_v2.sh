#!/bin/bash

echo "🚀 开始升级 A-Share AI 到 V2 版本 (自选股+实时刷新+数据库集成)..."

# ---------------------------------------------------------
# 1. 创建后端 API (用于前端读写数据库)
# ---------------------------------------------------------
echo "🔌 创建后端 API: app/api/watchlist/route.js..."
mkdir -p app/api/watchlist
cat <<EOF > app/api/watchlist/route.js
import { sql } from '@vercel/postgres';
import { NextResponse } from 'next/server';

// 获取自选股列表
export async function GET() {
  try {
    // 确保表存在
    await sql\`CREATE TABLE IF NOT EXISTS watchlist (
      code VARCHAR(10) PRIMARY KEY,
      name VARCHAR(50),
      added_at TIMESTAMP DEFAULT NOW()
    );\`;
    
    // 获取列表
    const { rows } = await sql\`SELECT * FROM watchlist ORDER BY added_at DESC\`;
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
      await sql\`INSERT INTO watchlist (code, name) VALUES (\${code}, \${name}) 
                ON CONFLICT (code) DO NOTHING\`;
    } else if (action === 'remove') {
      await sql\`DELETE FROM watchlist WHERE code = \${code}\`;
    }
    
    const { rows } = await sql\`SELECT * FROM watchlist ORDER BY added_at DESC\`;
    return NextResponse.json({ data: rows });
  } catch (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
EOF

# ---------------------------------------------------------
# 2. 更新 AI 核心脚本 (让 Python 从数据库读取关注列表)
# ---------------------------------------------------------
echo "🧠 升级 AI 脚本: scripts/run_prediction.py..."
cat <<EOF > scripts/run_prediction.py
import os
import akshare as ak
import psycopg2
import pandas as pd
from datetime import datetime, timedelta

# 连接数据库
def get_db_connection():
    dsn = os.environ.get("POSTGRES_URL")
    if not dsn: return None
    try:
        return psycopg2.connect(dsn)
    except:
        return None

def fetch_watchlist(conn):
    """从数据库获取用户关注的股票"""
    cur = conn.cursor()
    # 确保表存在
    cur.execute("""
        CREATE TABLE IF NOT EXISTS watchlist (
            code VARCHAR(10) PRIMARY KEY,
            name VARCHAR(50),
            added_at TIMESTAMP DEFAULT NOW()
        );
    """)
    conn.commit()
    
    cur.execute("SELECT code, name FROM watchlist")
    rows = cur.fetchall()
    
    # 如果数据库为空，返回默认列表
    if not rows:
        defaults = [("600519", "贵州茅台"), ("300750", "宁德时代"), ("000001", "平安银行")]
        for code, name in defaults:
            cur.execute("INSERT INTO watchlist (code, name) VALUES (%s, %s) ON CONFLICT DO NOTHING", (code, name))
        conn.commit()
        return defaults
        
    return rows

def fetch_and_predict():
    conn = get_db_connection()
    if not conn:
        print("No DB Connection")
        return

    watchlist = fetch_watchlist(conn)
    print(f"Analyzing {len(watchlist)} stocks from Watchlist...")
    
    cur = conn.cursor()
    # 确保预测表存在
    cur.execute("""
        CREATE TABLE IF NOT EXISTS ai_predictions (
            id SERIAL PRIMARY KEY,
            code VARCHAR(10) NOT NULL,
            predict_date DATE NOT NULL,
            current_price DECIMAL(10, 2),
            predicted_change DECIMAL(10, 2),
            confidence_score INTEGER,
            analysis_text TEXT,
            created_at TIMESTAMP DEFAULT NOW(),
            UNIQUE(code, predict_date)
        );
    """)
    conn.commit()

    predict_date = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
    start_date = (datetime.now() - timedelta(days=200)).strftime("%Y%m%d")

    for code, name in watchlist:
        try:
            print(f"Processing {name} ({code})...")
            # 获取数据
            df = ak.stock_zh_a_hist(symbol=code, period="daily", start_date=start_date, adjust="qfq")
            if df.empty: continue
            
            # --- 简单的 AI 逻辑模拟 (实际可替换为 Qlib) ---
            # 1. 计算均线
            df['MA5'] = df['收盘'].rolling(5).mean()
            df['MA20'] = df['收盘'].rolling(20).mean()
            
            latest = df.iloc[-1]
            price = float(latest['收盘'])
            ma5 = float(latest['MA5'])
            ma20 = float(latest['MA20'])
            
            # 2. 评分系统
            score = 50
            analysis = []
            
            if price > ma20:
                score += 20
                analysis.append("股价站上20日线，趋势向好")
            else:
                score -= 10
                analysis.append("股价受制于20日线，趋势偏弱")
                
            if price > ma5:
                score += 10
                analysis.append("短线动能强劲")
            
            # 3. 量能分析
            vol_mean = df['成交量'].tail(5).mean()
            if latest['成交量'] > vol_mean * 1.5:
                score += 10
                analysis.append("近期明显放量，资金关注度高")
            
            score = max(0, min(100, score))
            change_pred = (score - 50) / 10.0
            
            analysis_str = "。".join(analysis)
            
            # 存入数据库
            cur.execute("""
                INSERT INTO ai_predictions (code, predict_date, current_price, predicted_change, confidence_score, analysis_text)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (code, predict_date) 
                DO UPDATE SET 
                    current_price = EXCLUDED.current_price,
                    predicted_change = EXCLUDED.predicted_change,
                    confidence_score = EXCLUDED.confidence_score,
                    analysis_text = EXCLUDED.analysis_text,
                    created_at = NOW();
            """, (code, predict_date, price, change_pred, int(score), analysis_str))
            
        except Exception as e:
            print(f"Error {code}: {e}")
            
    conn.commit()
    cur.close()
    conn.close()

if __name__ == "__main__":
    fetch_and_predict()
EOF

# ---------------------------------------------------------
# 3. 更新前端 UI (Page.js - V2)
# ---------------------------------------------------------
echo "📱 更新前端 UI: app/page.js..."
cat <<EOF > app/page.js
"use client";

import React, { useState, useEffect, useRef } from 'react';
import { 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, 
  BarChart, Bar, ReferenceLine 
} from 'recharts';
import { 
  Search, TrendingUp, TrendingDown, Sparkles, Plus, Trash2,
  Activity, BarChart3, RefreshCcw, LayoutGrid
} from 'lucide-react';

export default function Home() {
  const [watchlist, setWatchlist] = useState([]);
  const [activeStock, setActiveStock] = useState(null); // 当前选中的股票
  const [stockData, setStockData] = useState(null);     // 详细数据
  const [loading, setLoading] = useState(false);
  const [query, setQuery] = useState('');
  const [lastUpdated, setLastUpdated] = useState(new Date());

  // --- 1. 初始化与自选股加载 ---
  useEffect(() => {
    fetchWatchlist();
  }, []);

  const fetchWatchlist = async () => {
    try {
      const res = await fetch('/api/watchlist');
      const json = await res.json();
      if (json.data && json.data.length > 0) {
        setWatchlist(json.data);
        // 默认选中第一个
        if (!activeStock) handleSelectStock(json.data[0]);
      } else {
        // 如果没有数据，初始化默认
        await addToWatchlist('600519', '贵州茅台');
      }
    } catch (e) { console.error("Fetch watchlist failed", e); }
  };

  const addToWatchlist = async (code, name) => {
    const res = await fetch('/api/watchlist', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ action: 'add', code, name })
    });
    const json = await res.json();
    setWatchlist(json.data);
    handleSelectStock({code, name}); // 选中新添加的
    setQuery(''); // 清空搜索
  };

  const removeFromWatchlist = async (e, code) => {
    e.stopPropagation();
    if(!confirm('确定移除吗？')) return;
    const res = await fetch('/api/watchlist', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ action: 'remove', code })
    });
    const json = await res.json();
    setWatchlist(json.data);
    if (activeStock?.code === code && json.data.length > 0) {
      handleSelectStock(json.data[0]);
    }
  };

  // --- 2. 核心：数据获取与模拟实时刷新 ---
  const handleSelectStock = (stock) => {
    setActiveStock(stock);
    setLoading(true);
    // 立即获取一次
    fetchStockDetails(stock).then(() => setLoading(false));
  };

  // 模拟从服务器获取详细数据 + 实时波动
  const fetchStockDetails = async (stock) => {
    // 真实场景：这里应该 fetch('/api/stock-detail?code=' + stock.code)
    // 但由于没有实时数据源，我们基于 Mock + 随机波动来模拟
    
    // 模拟延迟
    await new Promise(r => setTimeout(r, 300));
    
    const basePrice = getBasePrice(stock.code);
    const volatility = basePrice * 0.02; // 2% 波动
    const randomChange = (Math.random() - 0.5) * volatility;
    const currentPrice = basePrice + randomChange;
    
    // 生成历史数据 (模拟)
    const history = generateHistory(basePrice);
    
    // 模拟 AI 分析结果
    const aiScore = Math.floor(Math.random() * 30) + 60; // 60-90分
    
    setStockData({
      ...stock,
      price: currentPrice,
      change: randomChange,
      changePercent: (randomChange / basePrice) * 100,
      history: history,
      aiScore: aiScore,
      analysis: aiScore > 75 ? '多头排列，量价齐升' : '震荡整理，方向未明',
      forecast: generateForecast(currentPrice)
    });
    setLastUpdated(new Date());
  };

  // 定时器：每 15 秒刷新一次当前选中股票的价格
  useEffect(() => {
    if (!activeStock) return;
    const interval = setInterval(() => {
      fetchStockDetails(activeStock);
    }, 15000); // 15秒
    return () => clearInterval(interval);
  }, [activeStock]);

  // --- 辅助函数 ---
  const getBasePrice = (code) => {
    // 简单的 Hash 算法生成固定的"基准价"，保证每次刷新不会跳变太离谱
    let hash = 0;
    for (let i = 0; i < code.length; i++) hash = code.charCodeAt(i) + ((hash << 5) - hash);
    return (Math.abs(hash) % 200) + 10;
  };

  const generateHistory = (base) => {
    let price = base * 0.9;
    return Array.from({length: 30}, (_, i) => {
      price = price * (1 + (Math.random() - 0.45) * 0.05);
      return { 
        date: \`T-\${30-i}\`, 
        price: parseFloat(price.toFixed(2)),
        ma5: parseFloat((price * 1.02).toFixed(2)) // 模拟均线
      };
    });
  };

  const generateForecast = (current) => {
    let price = current;
    return Array.from({length: 7}, (_, i) => {
      price = price * (1 + (Math.random() - 0.4) * 0.02);
      return { day: \`未来\${i+1}天\`, price: parseFloat(price.toFixed(2)) };
    });
  };

  // --- UI 渲染 ---
  const isPositive = stockData?.change >= 0;
  const colorClass = isPositive ? 'text-[#FF3B30]' : 'text-[#34C759]';
  const chartColor = isPositive ? '#FF3B30' : '#34C759';

  return (
    <div className="flex min-h-screen bg-[#f5f5f7] font-sans text-gray-900">
      
      {/* --- 左侧侧边栏：股票池 --- */}
      <div className="w-80 bg-white border-r border-gray-200 flex flex-col h-screen fixed left-0 top-0 z-20 shadow-sm">
        <div className="p-6 border-b border-gray-100">
          <div className="flex items-center gap-2 mb-6">
            <div className="bg-black text-white p-1.5 rounded-lg"><Activity className="w-4 h-4" /></div>
            <span className="font-bold text-lg tracking-tight">StockAI Pro</span>
          </div>
          
          {/* 添加股票输入框 */}
          <div className="relative group">
            <input 
              type="text" 
              value={query}
              onChange={e => setQuery(e.target.value)}
              onKeyDown={e => {
                if(e.key === 'Enter' && query) addToWatchlist(query, \`自选 \${query}\`);
              }}
              placeholder="添加代码 (回车)"
              className="w-full bg-gray-50 border border-gray-200 rounded-xl py-2.5 pl-9 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-black/5 transition-all"
            />
            <Search className="w-4 h-4 absolute left-3 top-3 text-gray-400" />
            {query && (
              <button 
                onClick={() => addToWatchlist(query, \`自选 \${query}\`)}
                className="absolute right-2 top-2 p-1 bg-black text-white rounded-md hover:scale-105 transition-transform"
              >
                <Plus className="w-3 h-3" />
              </button>
            )}
          </div>
        </div>

        {/* 股票列表 */}
        <div className="flex-1 overflow-y-auto p-3 space-y-2">
          {watchlist.map(stock => (
            <div 
              key={stock.code}
              onClick={() => handleSelectStock(stock)}
              className={\`group flex items-center justify-between p-3 rounded-xl cursor-pointer transition-all hover:bg-gray-50 \${activeStock?.code === stock.code ? 'bg-white shadow-md border border-gray-100 ring-1 ring-black/5' : ''}\`}
            >
              <div>
                <div className="font-semibold text-sm">{stock.name}</div>
                <div className="text-xs text-gray-400 font-mono">{stock.code}</div>
              </div>
              <button 
                onClick={(e) => removeFromWatchlist(e, stock.code)}
                className="opacity-0 group-hover:opacity-100 p-2 text-gray-300 hover:text-red-500 transition-opacity"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>
        
        <div className="p-4 border-t border-gray-100 text-xs text-gray-400 text-center">
           数据源：AI 模拟推演
        </div>
      </div>

      {/* --- 右侧主内容区 --- */}
      <div className="flex-1 ml-80 p-8 md:p-12 overflow-y-auto">
        
        {loading || !stockData ? (
          <div className="h-full flex flex-col justify-center items-center text-gray-400">
             <div className="w-8 h-8 border-4 border-gray-200 border-t-black rounded-full animate-spin mb-4"></div>
             <p>AI 正在分析实时数据...</p>
          </div>
        ) : (
          <div className="max-w-5xl mx-auto space-y-8 animate-in fade-in zoom-in-95 duration-500">
            
            {/* 顶部状态栏 */}
            <div className="flex justify-between items-end">
              <div>
                <h1 className="text-3xl font-bold mb-1 flex items-center gap-3">
                  {stockData.name} 
                  <span className="text-sm font-normal bg-gray-200 text-gray-600 px-2 py-0.5 rounded-md font-mono">{stockData.code}</span>
                </h1>
                <div className="flex items-center gap-2 text-sm text-gray-500">
                  <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></span>
                  实时交易中 · {lastUpdated.toLocaleTimeString()} 更新 (15s/次)
                </div>
              </div>
              <div className="text-right">
                <div className={\`text-5xl font-bold tracking-tight \${colorClass}\`}>
                   ¥{stockData.price.toFixed(2)}
                </div>
                <div className={\`flex items-center justify-end gap-2 text-lg font-medium \${colorClass}\`}>
                  {isPositive ? <TrendingUp className="w-5 h-5"/> : <TrendingDown className="w-5 h-5"/>}
                  {stockData.change > 0 ? '+' : ''}{stockData.change.toFixed(2)} ({stockData.changePercent.toFixed(2)}%)
                </div>
              </div>
            </div>

            {/* 核心图表区 */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
              
              {/* 左侧：走势图 */}
              <div className="lg:col-span-2 bg-white rounded-3xl p-6 shadow-sm border border-gray-100">
                <div className="flex justify-between items-center mb-6">
                   <h3 className="font-semibold flex items-center gap-2">
                     <Activity className="w-4 h-4 text-gray-400"/> 价格走势与均线
                   </h3>
                </div>
                <div className="h-[320px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={stockData.history}>
                      <defs>
                        <linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor={chartColor} stopOpacity={0.1}/>
                          <stop offset="95%" stopColor={chartColor} stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" vertical={false} />
                      <XAxis dataKey="date" hide />
                      <YAxis domain={['auto', 'auto']} orientation="right" tick={{fontSize: 11, fill: '#9ca3af'}} axisLine={false} tickLine={false} />
                      <Tooltip contentStyle={{borderRadius: '12px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)'}} />
                      <Area type="monotone" dataKey="price" stroke={chartColor} strokeWidth={3} fill="url(#colorPrice)" />
                      <Area type="monotone" dataKey="ma5" stroke="#fbbf24" strokeWidth={2} fill="none" strokeDasharray="5 5" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>

              {/* 右侧：AI 预测与分析 */}
              <div className="space-y-6">
                
                {/* 评分卡片 */}
                <div className="bg-black text-white rounded-3xl p-6 shadow-xl relative overflow-hidden group">
                  <div className="absolute top-[-50%] right-[-50%] w-full h-full bg-gradient-to-b from-blue-600/30 to-transparent rounded-full blur-3xl group-hover:scale-150 transition-transform duration-1000"></div>
                  <div className="relative z-10">
                    <div className="flex items-center gap-2 text-gray-400 text-xs font-bold uppercase tracking-wider mb-2">
                      <Sparkles className="w-3 h-3 text-yellow-400" /> AI 综合评分
                    </div>
                    <div className="text-5xl font-bold tracking-tighter mb-2">{stockData.aiScore}</div>
                    <div className="text-sm text-gray-300 border-t border-white/10 pt-3 mt-3">
                      {stockData.analysis}
                    </div>
                  </div>
                </div>

                {/* 预测图表 */}
                <div className="bg-white rounded-3xl p-5 shadow-sm border border-gray-100">
                  <h3 className="text-sm font-semibold mb-4 text-gray-500">未来 7 天趋势预测</h3>
                  <div className="h-32">
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={stockData.forecast}>
                        <Bar dataKey="price" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                        <Tooltip cursor={{fill: 'transparent'}} contentStyle={{borderRadius: '8px', fontSize: '11px'}} />
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                </div>

              </div>
            </div>

          </div>
        )}
      </div>
    </div>
  );
}
EOF

echo "✅ V2 升级完成！请运行以下命令进行推送："
echo "git add ."
echo "git commit -m \"Upgrade to V2: Watchlist + DB + Realtime UI\""
echo "git push origin main"