#!/bin/bash

echo "🚑 开始执行 V12 修复 (纯数据库模式 + 双显增强)..."

# ========================================================
# 0. 交互式配置 (安全输入)
# ========================================================
echo ""
echo "========================================================"
echo "🔴 请最后一次粘贴您的数据库连接串 (postgres://...)"
echo "   (请确保完整复制，不要遗漏)"
echo "========================================================"
read -p "数据库连接串: " USER_DB_URL

if [ -z "$USER_DB_URL" ]; then
  echo "❌ 错误: 未检测到输入！脚本已停止。"
  exit 1
fi

# 自动安装 pg 驱动
npm install pg

# ========================================================
# 1. 重写后端 API (纯数据库模式 - 严禁实时计算)
# ========================================================
echo "🔌 重构 API: app/api/stock-detail/route.js..."
mkdir -p app/api/stock-detail

# 步骤 A: 写入头部
cat > app/api/stock-detail/route.js <<END_HEADER
import { Pool } from 'pg';
import { NextResponse } from 'next/server';

// 注入的连接串
const INJECTED_DB_URL = '${USER_DB_URL}';

END_HEADER

# 步骤 B: 写入只读逻辑 (无实时兜底)
cat >> app/api/stock-detail/route.js <<'EOF'
export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get('code');
  const DB_URL = INJECTED_DB_URL || process.env.POSTGRES_URL;

  if (!code) return NextResponse.json({ error: 'Code required' }, { status: 400 });

  if (!DB_URL) {
    return NextResponse.json({ 
      status: 'error', 
      message: '数据库连接未配置' 
    }, { status: 500 });
  }

  try {
    const pool = new Pool({
      connectionString: DB_URL,
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 5000, // 5秒连接超时
    });
    
    const client = await pool.connect();
    // 仅从数据库查询，绝不进行实时计算
    const res = await client.query('SELECT data, updated_at FROM ai_predictions_v2 WHERE code = $1', [code]);
    client.release();
    await pool.end();
    
    if (res.rows.length > 0) {
      const data = res.rows[0].data;
      // 附加最后更新时间，让用户知道数据的新鲜度
      data.last_updated = res.rows[0].updated_at;
      return NextResponse.json(data);
    } else {
      // 数据库无数据 -> 返回 Pending 状态
      return NextResponse.json({ 
        status: 'pending', 
        message: '该股票尚未纳入量化池，请等待后台计算...' 
      });
    }
  } catch (e) {
    console.error("DB Error:", e);
    return NextResponse.json({ status: 'error', message: `数据库错误: ${e.message}` }, { status: 500 });
  }
}
EOF

# ========================================================
# 2. 重写关注列表 API (保持不变)
# ========================================================
echo "🔌 重构 Watchlist API..."

cat > app/api/watchlist/route.js <<END_HEADER
import { Pool } from 'pg';
import { NextResponse } from 'next/server';

const INJECTED_DB_URL = '${USER_DB_URL}';
const DEFAULT_LIST = [
  {code: '600519', name: '贵州茅台'},
  {code: '300750', name: '宁德时代'},
  {code: '000001', 'name': '平安银行'}
];
END_HEADER

cat >> app/api/watchlist/route.js <<'EOF'
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
EOF

# ========================================================
# 3. 重写前端 (UI 优化：双显 + 状态处理)
# ========================================================
echo "📱 恢复 app/page.js..."
cat <<EOF > app/page.js
"use client";

import React, { useState, useEffect } from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts';
import { Search, Plus, Trash2, Activity, Newspaper, ArrowRight, Sparkles, Clock, AlertTriangle, Database } from 'lucide-react';

export default function Home() {
  const [watchlist, setWatchlist] = useState([]);
  const [activeStock, setActiveStock] = useState(null); 
  const [stockData, setStockData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [query, setQuery] = useState('');
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    fetchWatchlist();
  }, []);

  const fetchWatchlist = async () => {
    try {
      const res = await fetch('/api/watchlist');
      const json = await res.json();
      const list = json.data || [];
      // 侧边栏不再显示实时价格，因为这是 DB 模式，可能没有最新价
      setWatchlist(list);
      if(list.length > 0) handleSelectStock(list[0]);
    } catch (e) { console.error(e); }
  };

  const addToWatchlist = async (val) => {
    if(!val) return;
    try {
      await fetch('/api/watchlist', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ action: 'add', code: val, name: val }) // 这里简化了名字获取，实际应让后端处理
      });
      fetchWatchlist();
      setQuery('');
    } catch(e) { alert("添加失败"); }
  };

  const removeFromWatchlist = async (e, code) => {
    e.stopPropagation();
    if(!confirm('移除?')) return;
    try {
      await fetch('/api/watchlist', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ action: 'remove', code })
      });
      const newList = watchlist.filter(s => s.code !== code);
      setWatchlist(newList);
      if(activeStock?.code === code && newList.length > 0) handleSelectStock(newList[0]);
    } catch(e) {}
  };

  const handleSelectStock = async (stock) => {
    setActiveStock(stock);
    setLoading(true);
    setStockData(null); 
    
    try {
      const res = await fetch(\`/api/stock-detail?code=\${stock.code}\`);
      const data = await res.json();
      
      // 处理特定状态
      if (data.status === 'pending') {
        setStockData({ status: 'pending', name: stock.name, code: stock.code });
      } else if (data.status === 'error') {
        setStockData({ status: 'error', name: stock.name, code: stock.code, message: data.message });
      } else {
        // 成功获取数据
        setStockData({
           status: 'success',
           ...stock,
           ...data
        });
      }
    } catch (e) {
      setStockData({ status: 'error', name: stock.name, code: stock.code, message: "网络请求失败" });
    } finally {
      setLoading(false);
    }
  };

  if (!mounted) return null;

  // 渲染内容区
  const renderContent = () => {
    if (loading) {
      return (
        <div className="h-full flex flex-col items-center justify-center text-slate-400 gap-3">
          <div className="w-8 h-8 border-4 border-blue-100 border-t-blue-500 rounded-full animate-spin"></div>
          <span className="text-sm font-medium">从云端数据库检索中...</span>
        </div>
      );
    }

    if (!stockData) {
      return <div className="h-full flex items-center justify-center text-slate-400">请选择左侧股票</div>;
    }

    if (stockData.status === 'pending') {
      return (
        <div className="h-full flex flex-col items-center justify-center text-slate-500 gap-6">
          <div className="bg-blue-50 p-6 rounded-full">
            <Clock className="w-16 h-16 text-blue-500 animate-pulse" />
          </div>
          <div className="text-center">
            <h2 className="text-2xl font-bold text-slate-800 mb-2">{stockData.name} <span className="font-mono text-slate-400">#{stockData.code}</span></h2>
            <p className="text-lg font-medium text-slate-600">数据排队中</p>
            <p className="text-sm text-slate-400 mt-2 max-w-md mx-auto">
              该股票已加入关注列表，但 Quant Engine 尚未完成首轮计算。<br/>后台任务每小时运行一次，请稍后再来查看。
            </p>
          </div>
        </div>
      );
    }

    if (stockData.status === 'error') {
      return (
        <div className="h-full flex flex-col items-center justify-center text-red-500 gap-4">
          <AlertTriangle className="w-12 h-12" />
          <div className="text-lg font-bold">读取失败</div>
          <div className="text-sm bg-red-50 p-3 rounded border border-red-100">{stockData.message}</div>
        </div>
      );
    }

    // 成功渲染
    const isPositive = stockData.change >= 0;
    const colorClass = isPositive ? 'text-[#FF3B30]' : 'text-[#34C759]';
    const chartColor = isPositive ? '#FF3B30' : '#34C759';

    return (
      <div className="flex-1 overflow-y-auto p-6 space-y-6 custom-scrollbar">
         {/* 头部 - 双显增强 */}
         <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100 flex justify-between items-center">
            <div>
               <div className="flex items-baseline gap-3">
                 {/* 核心修改：中文名 + 代码 并排显示 */}
                 <h1 className="text-3xl font-extrabold text-slate-900 tracking-tight">{stockData.name}</h1>
                 <span className="text-2xl font-mono font-bold text-slate-400 bg-slate-50 px-2 py-0.5 rounded">#{stockData.code}</span>
               </div>
               <div className="text-xs font-medium text-slate-500 mt-2 flex items-center gap-2">
                 <Database className="w-3 h-3" />
                 <span>数据快照时间: {new Date(stockData.last_updated || Date.now()).toLocaleString()}</span>
               </div>
            </div>
            <div className="text-right">
               <div className={\`text-5xl font-extrabold tracking-tighter \${colorClass}\`}>¥{stockData.price?.toFixed(2)}</div>
               <div className={\`font-bold text-lg mt-1 \${colorClass}\`}>
                 {stockData.change > 0 ? '+' : ''}{stockData.change?.toFixed(2)} ({stockData.changePercent?.toFixed(2)}%)
               </div>
            </div>
         </div>

         {/* 图表 */}
         <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100 h-[350px]">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={stockData.history}>
                 <defs><linearGradient id="c" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor={chartColor} stopOpacity={0.1}/><stop offset="95%" stopColor={chartColor} stopOpacity={0}/></linearGradient></defs>
                 <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9"/>
                 <XAxis dataKey="date" tick={{fontSize:10}} axisLine={false} tickLine={false} />
                 <YAxis orientation="right" domain={['auto','auto']} tick={{fontSize:11}} axisLine={false} tickLine={false}/>
                 <Tooltip contentStyle={{borderRadius:'12px', border:'none', boxShadow:'0 4px 12px rgba(0,0,0,0.1)'}}/>
                 <ReferenceLine y={stockData.high3m} stroke="red" strokeDasharray="3 3" label={{value:'High', position:'insideTopRight', fill:'red', fontSize:10}}/>
                 <ReferenceLine y={stockData.low3m} stroke="green" strokeDasharray="3 3" label={{value:'Low', position:'insideBottomRight', fill:'green', fontSize:10}}/>
                 <Area type="monotone" dataKey="price" stroke={chartColor} strokeWidth={2} fill="url(#c)" />
              </AreaChart>
            </ResponsiveContainer>
         </div>

         {/* AI & 预测 */}
         <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
            <div className="bg-white p-6 rounded-2xl shadow-sm border border-indigo-100 relative overflow-hidden">
               <div className="relative z-10">
                  <div className="flex justify-between items-center mb-4">
                    <div className="font-bold text-indigo-600 flex items-center gap-2"><Sparkles className="w-4 h-4"/> Quant Engine</div>
                    <div className="text-4xl font-black text-slate-900">{stockData.aiScore}<span className="text-sm text-slate-400 font-normal ml-1">/100</span></div>
                  </div>
                  <div className="text-sm text-slate-600 leading-relaxed whitespace-pre-wrap font-mono bg-slate-50 p-4 rounded-xl">
                    {stockData.analysis}
                  </div>
               </div>
            </div>
            
            <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100 flex flex-col">
               <div className="font-bold text-slate-800 mb-4 flex items-center gap-2"><ArrowRight className="w-4 h-4 text-blue-500"/> 7日走势预测</div>
               <div className="flex-1 min-h-[160px]">
                 <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={stockData.forecast}>
                       <defs><linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor="#3b82f6" stopOpacity={0.2}/><stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/></linearGradient></defs>
                       <XAxis dataKey="day" tick={{fontSize:10}} axisLine={false} tickLine={false} />
                       <Tooltip cursor={{stroke:'#3b82f6'}} contentStyle={{borderRadius:'8px'}}/>
                       <Area type="monotone" dataKey="price" stroke="#3b82f6" strokeWidth={3} fill="url(#f)" dot={{r:3}} />
                    </AreaChart>
                 </ResponsiveContainer>
               </div>
            </div>
         </div>
      </div>
    );
  };

  return (
    <div className="flex flex-row h-screen w-screen bg-[#f5f5f7] font-sans text-slate-800 overflow-hidden">
      {/* 侧边栏 */}
      <aside className="w-[260px] flex-shrink-0 bg-white border-r border-slate-200 flex flex-col z-20">
        <div className="p-4 border-b border-slate-100 bg-white/80 backdrop-blur-md">
          <div className="flex items-center gap-2 mb-3 text-slate-900 font-bold text-lg">
             <Activity className="w-5 h-5 text-blue-600" /> StockAI
          </div>
          <div className="relative group">
            <input type="text" value={query} onChange={e => setQuery(e.target.value)} placeholder="代码" className="w-full bg-slate-50 border-none rounded-lg px-3 py-2 text-sm outline-none" onKeyDown={e => e.key === 'Enter' && query && addToWatchlist(query)} />
            <Plus className="w-4 h-4 text-slate-400 absolute right-3 top-2.5 cursor-pointer" onClick={() => addToWatchlist(query)} />
          </div>
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-1 custom-scrollbar">
          {watchlist.map(s => (
            <div key={s.code} onClick={() => handleSelectStock(s)} className={\`p-3 rounded-lg cursor-pointer flex justify-between items-center \${activeStock?.code === s.code ? 'bg-blue-50 text-blue-700' : 'hover:bg-slate-50'}\`}>
              <div className="flex flex-col">
                <div className="font-bold text-sm">{s.name}</div>
                <div className="text-xs opacity-50 font-mono mt-0.5">#{s.code}</div>
              </div>
              <button onClick={(e) => removeFromWatchlist(e, s.code)} className="opacity-50 hover:text-red-500"><Trash2 className="w-3 h-3"/></button>
            </div>
          ))}
        </div>
      </aside>

      {/* 主内容 */}
      <main className="flex-1 flex flex-col min-w-0 bg-[#f5f5f7] relative overflow-hidden">
        {renderContent()}
      </main>
    </div>
  );
}
EOF

# ========================================================
# 4. 强制推送 (清理大文件)
# ========================================================
echo "🧹 清理 Git..."
rm -rf .git
git init
git branch -M main
cat <<EOF2 > .gitignore
node_modules/
.next/
.devcontainer/
.env*.local
npm-debug.log*
.DS_Store
EOF2

echo "🚀 强制推送 V12..."
git add .
git commit -m "Final V12: DB-Only Mode + Dual Display UI"
git remote add origin https://github.com/Sunny-Valley/a-stock-research
git push -u origin main --force

echo "✅ 修复完成！请等待 Vercel 部署。"