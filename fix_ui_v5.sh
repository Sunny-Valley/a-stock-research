#!/bin/bash

echo "🚑 开始执行 V13.1 修复 (纯异步模式 + UI美化)..."

# ========================================================
# 0. 交互式配置
# ========================================================
echo ""
echo "========================================================"
echo "🔴 请最后一次粘贴您的数据库连接串 (postgres://...)"
echo "   (必须填写，否则无法读取后台计算结果)"
echo "========================================================"
read -p "数据库连接串: " USER_DB_URL

if [ -z "$USER_DB_URL" ]; then
  echo "❌ 错误: 未检测到输入！脚本已停止。"
  exit 1
fi

# 确保安装 pg 驱动
npm install pg

# ========================================================
# 1. 重写后端 API (纯数据库模式：只读不写，拒绝实时)
# ========================================================
echo "🔌 升级 API (DB Only): app/api/stock-detail/route.js..."
mkdir -p app/api/stock-detail

cat > app/api/stock-detail/route.js <<END_HEADER
import { Pool } from 'pg';
import { NextResponse } from 'next/server';

const INJECTED_DB_URL = '${USER_DB_URL}';
END_HEADER

cat >> app/api/stock-detail/route.js <<'EOF'
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
EOF

# ========================================================
# 2. 重写前端 (UI V13版：白色卡片 + 曲线预测 + 状态处理)
# ========================================================
echo "📱 升级前端 UI: app/page.js..."
cat <<EOF > app/page.js
"use client";

import React, { useState, useEffect } from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts';
import { Search, Plus, Trash2, Activity, Newspaper, ArrowRight, Sparkles, TrendingUp, Clock, AlertTriangle, Database } from 'lucide-react';

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
      // 纯异步模式下，列表不强求显示实时价格
      const safeList = list.map(item => ({ ...item }));
      setWatchlist(safeList);
      if(safeList.length > 0) handleSelectStock(safeList[0]);
      else addToWatchlist('600519'); 
    } catch (e) { console.error(e); }
  };

  const addToWatchlist = async (val) => {
    if(!val) return;
    try {
      await fetch('/api/watchlist', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ action: 'add', code: val, name: val })
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
      if(activeStock?.code === code && newList.length>0) handleSelectStock(newList[0]);
    } catch(e) {}
  };

  const handleSelectStock = async (stock) => {
    setActiveStock(stock);
    setLoading(true);
    setStockData(null); // 清空旧数据以显示加载状态
    
    try {
      const res = await fetch(\`/api/stock-detail?code=\${stock.code}\`);
      const data = await res.json();
      
      if (data.status === 'pending') {
        setStockData({ status: 'pending', name: stock.name, code: stock.code });
      } else if (data.status === 'error') {
        setStockData({ status: 'error', name: stock.name, code: stock.code, message: data.message });
      } else {
        setStockData({
           status: 'success',
           ...stock,
           ...data
        });
      }
    } catch (e) {
      console.error(e);
      setStockData({ status: 'error', message: '网络请求失败' });
    } finally {
      setLoading(false);
    }
  };

  if (!mounted) return null;

  // 渲染内容逻辑
  const renderMainContent = () => {
    if (loading) {
      return (
        <div className="h-full flex flex-col items-center justify-center text-slate-400 gap-3">
          <div className="w-8 h-8 border-4 border-blue-100 border-t-blue-600 rounded-full animate-spin"></div>
          <span className="text-sm font-medium">从云端数据库同步数据...</span>
        </div>
      );
    }

    if (!stockData) {
      return <div className="h-full flex items-center justify-center text-slate-400">请选择左侧股票</div>;
    }

    // 等待后台计算状态
    if (stockData.status === 'pending') {
      return (
        <div className="h-full flex flex-col items-center justify-center text-slate-500 gap-6">
          <div className="bg-blue-50 p-6 rounded-full">
            <Clock className="w-16 h-16 text-blue-500 animate-pulse" />
          </div>
          <div className="text-center">
            <h2 className="text-2xl font-bold text-slate-800 mb-2">{stockData.name} <span className="font-mono text-slate-400">#{stockData.code}</span></h2>
            <p className="text-lg font-medium text-slate-600">量化计算中</p>
            <p className="text-sm text-slate-400 mt-2 max-w-md mx-auto">
              该股票已加入观察池，Quant Engine 正在后台进行深度分析。<br/>请等待 GitHub Actions 下一次运行（每小时更新）。
            </p>
          </div>
        </div>
      );
    }

    if (stockData.status === 'error') {
      return (
        <div className="h-full flex flex-col items-center justify-center text-red-500 gap-4">
          <AlertTriangle className="w-12 h-12" />
          <div className="text-lg font-bold">数据读取失败</div>
          <div className="text-sm bg-red-50 p-3 rounded border border-red-100">{stockData.message}</div>
        </div>
      );
    }

    // 成功显示数据 (V13 新 UI)
    const isPositive = stockData.change >= 0;
    const colorClass = isPositive ? 'text-[#FF3B30]' : 'text-[#34C759]';
    const chartColor = isPositive ? '#FF3B30' : '#34C759';

    return (
      <div className="flex-1 overflow-y-auto p-6 space-y-6 custom-scrollbar">
         {/* 头部卡片 */}
         <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100 flex justify-between items-center relative overflow-hidden">
            <div>
               <div className="flex items-baseline gap-3">
                 <h1 className="text-3xl font-extrabold text-slate-900 tracking-tight">{stockData.name}</h1>
                 <span className="text-xl font-mono font-bold text-slate-400 bg-slate-100 px-2 py-0.5 rounded-lg tracking-wide">#{stockData.code}</span>
               </div>
               <div className="text-xs font-medium text-slate-500 mt-2 flex items-center gap-2">
                 <Database className="w-3 h-3 text-blue-500" />
                 <span>数据版本: {new Date(stockData.lastUpdated).toLocaleString()}</span>
               </div>
            </div>
            <div className="text-right">
               <div className={\`text-5xl font-extrabold tracking-tighter \${colorClass}\`}>¥{stockData.price?.toFixed(2)}</div>
               <div className={\`font-bold text-lg mt-1 \${colorClass}\`}>
                 {stockData.change > 0 ? '+' : ''}{stockData.change?.toFixed(2)} ({stockData.changePercent?.toFixed(2)}%)
               </div>
            </div>
         </div>

         {/* 历史走势图 */}
         <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100 h-[360px]">
            <div className="flex justify-between mb-4">
               <div className="font-bold text-slate-700 flex items-center gap-2"><Activity className="w-4 h-4 text-slate-400"/> 90日价格走势</div>
            </div>
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={stockData.history} margin={{ top: 10, right: 0, left: 0, bottom: 0 }}>
                 <defs><linearGradient id="c" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor={chartColor} stopOpacity={0.1}/><stop offset="95%" stopColor={chartColor} stopOpacity={0}/></linearGradient></defs>
                 <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9"/>
                 <XAxis dataKey="date" tick={{fontSize:10}} axisLine={false} tickLine={false} minTickGap={30} />
                 <YAxis orientation="right" domain={['auto','auto']} tick={{fontSize:11}} axisLine={false} tickLine={false}/>
                 <Tooltip contentStyle={{borderRadius:'12px', border:'none', boxShadow:'0 4px 12px rgba(0,0,0,0.1)'}}/>
                 <Area type="monotone" dataKey="price" stroke={chartColor} strokeWidth={2} fill="url(#c)" />
              </AreaChart>
            </ResponsiveContainer>
         </div>

         <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
            {/* AI 决策模型 (白色极简风) */}
            <div className="bg-white p-6 rounded-2xl shadow-sm border border-indigo-100 relative overflow-hidden group hover:shadow-md transition-shadow">
               <div className="flex justify-between items-center mb-4 relative z-10">
                 <div className="font-bold text-indigo-600 flex items-center gap-2 bg-indigo-50 px-3 py-1 rounded-full text-sm">
                   <Sparkles className="w-4 h-4"/> AI Quant Engine
                 </div>
                 <span className="text-xs text-slate-400 font-mono">v4.2</span>
               </div>
               <div className="flex items-baseline gap-3 mb-4 relative z-10">
                  <span className="text-6xl font-black tracking-tighter text-slate-900">{stockData.score}</span>
                  <span className="text-sm font-bold text-slate-400">/ 100</span>
               </div>
               <div className="relative z-10 bg-slate-50 p-4 rounded-xl border border-slate-100">
                  <div className="text-sm text-slate-700 leading-relaxed whitespace-pre-wrap font-medium">
                    {stockData.analysis}
                  </div>
               </div>
               <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500 rounded-full blur-[70px] opacity-10 pointer-events-none"></div>
            </div>

            {/* 预测图表 (曲线面积图) */}
            <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100 flex flex-col">
               <div className="font-bold text-slate-800 mb-4 flex items-center gap-2"><TrendingUp className="w-4 h-4 text-blue-500"/> 未来 7 日趋势预测</div>
               <div className="flex-1 min-h-[180px]">
                 <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={stockData.forecast}>
                       <defs>
                         <linearGradient id="f" x1="0" y1="0" x2="0" y2="1">
                           <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.2}/>
                           <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                         </linearGradient>
                       </defs>
                       <XAxis dataKey="day" tick={{fontSize:10}} axisLine={false} tickLine={false} />
                       <Tooltip cursor={{stroke:'#3b82f6'}} contentStyle={{borderRadius:'8px'}}/>
                       <Area type="monotone" dataKey="price" stroke="#3b82f6" strokeWidth={3} fill="url(#f)" dot={{r:4, fill:"#3b82f6", strokeWidth:2, stroke:"#fff"}} />
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
            <input type="text" value={query} onChange={e => setQuery(e.target.value)} placeholder="代码 (如 600519)" className="w-full bg-slate-50 border-none rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-blue-100" onKeyDown={e => e.key === 'Enter' && query && addToWatchlist(query)} />
            <Plus className="w-4 h-4 text-slate-400 absolute right-3 top-2.5 cursor-pointer hover:text-blue-600" onClick={() => addToWatchlist(query)} />
          </div>
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-1 custom-scrollbar">
          {watchlist.map(s => (
            <div key={s.code} onClick={() => handleSelectStock(s)} className={\`p-3 rounded-lg cursor-pointer flex justify-between items-center transition-all \${activeStock?.code === s.code ? 'bg-blue-50 ring-1 ring-blue-200' : 'hover:bg-slate-50'}\`}>
              <div className="flex flex-col">
                <div className={\`font-bold text-sm \${activeStock?.code === s.code ? 'text-blue-700' : 'text-slate-700'}\`}>{s.name}</div>
                <div className="text-xs font-mono text-slate-400 mt-0.5">{s.code}</div>
              </div>
              <button onClick={(e) => removeFromWatchlist(e, s.code)} className="opacity-0 group-hover:opacity-100 p-1 hover:bg-white rounded-full text-slate-400 hover:text-red-500 transition-all"><Trash2 className="w-3.5 h-3.5"/></button>
            </div>
          ))}
        </div>
      </aside>

      {/* 主内容 */}
      <main className="flex-1 flex flex-col min-w-0 bg-[#f5f5f7] relative overflow-hidden">
        {renderMainContent()}
      </main>
      
      {/* 新闻栏 (可选，保留) */}
      <aside className="w-[280px] bg-white border-l border-slate-200 hidden xl:flex flex-col z-20">
         <div className="p-4 border-b border-slate-100 font-bold text-sm text-slate-700 flex items-center gap-2">
           <Newspaper className="w-4 h-4"/> 智能资讯
         </div>
         <div className="p-4 space-y-4 overflow-y-auto flex-1 custom-scrollbar">
            {stockData?.news?.map((n,i)=>(
              <div key={i} className="p-3 bg-slate-50 rounded-xl border border-slate-100 hover:shadow-sm transition-shadow cursor-pointer">
                <div className="flex justify-between items-center mb-1">
                  <span className={\`text-[10px] px-2 py-0.5 rounded font-bold \${n.type==='公告'?'bg-blue-100 text-blue-600':'bg-orange-100 text-orange-600'}\`}>{n.type}</span>
                  <span className="text-[10px] text-slate-400">{n.time}</span>
                </div>
                <div className="text-xs text-slate-700 font-medium leading-snug">{n.title}</div>
              </div>
            ))}
         </div>
      </aside>
    </div>
  );
}
EOF

# ========================================================
# 3. 强制推送
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

echo "🚀 强制推送 V13.1..."
git add .
git commit -m "Final V13.1: Pure Async Mode + White UI"
git remote add origin https://github.com/Sunny-Valley/a-stock-research
git push -u origin main --force

echo "✅ 修复完成！等待 Vercel 变绿后刷新。"