#!/bin/bash

echo "🚑 开始应用防崩溃补丁..."

# 重写 app/page.js，增加对 API 数据的安全检查
cat <<EOF > app/page.js
"use client";

import React, { useState, useEffect } from 'react';
import { 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, 
  BarChart, Bar
} from 'recharts';
import { 
  Search, TrendingUp, TrendingDown, Sparkles, Plus, Trash2,
  Activity, RefreshCcw, AlertCircle
} from 'lucide-react';

export default function Home() {
  const [watchlist, setWatchlist] = useState([]);
  const [activeStock, setActiveStock] = useState(null); 
  const [stockData, setStockData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [query, setQuery] = useState('');
  const [lastUpdated, setLastUpdated] = useState(new Date());
  const [errorMsg, setErrorMsg] = useState('');

  // --- 1. 初始化 ---
  useEffect(() => {
    fetchWatchlist();
  }, []);

  const fetchWatchlist = async () => {
    try {
      const res = await fetch('/api/watchlist');
      if (!res.ok) throw new Error('数据库连接失败');
      
      const json = await res.json();
      // 安全检查：确保 data 是数组，否则给空数组
      const safeList = Array.isArray(json.data) ? json.data : [];
      setWatchlist(safeList);
      
      if (safeList.length > 0) {
        if (!activeStock) handleSelectStock(safeList[0]);
      } else {
        // 如果列表为空且没报错，尝试添加默认
        await addToWatchlist('600519', '贵州茅台');
      }
    } catch (e) { 
      console.error("Fetch failed", e);
      setErrorMsg("⚠️ 无法连接数据库，请检查 Vercel 环境变量 POSTGRES_URL");
      // 出错时使用本地兜底数据，防止白屏
      const fallback = [{code: '600519', name: '演示-贵州茅台'}];
      setWatchlist(fallback);
      handleSelectStock(fallback[0]);
    }
  };

  const addToWatchlist = async (code, name) => {
    try {
      const res = await fetch('/api/watchlist', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ action: 'add', code, name })
      });
      const json = await res.json();
      const safeList = Array.isArray(json.data) ? json.data : watchlist;
      setWatchlist(safeList);
      handleSelectStock({code, name}); 
      setQuery('');
    } catch (e) {
      alert("添加失败，数据库未连接");
    }
  };

  const removeFromWatchlist = async (e, code) => {
    e.stopPropagation();
    if(!confirm('确定移除吗？')) return;
    try {
      const res = await fetch('/api/watchlist', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ action: 'remove', code })
      });
      const json = await res.json();
      const safeList = Array.isArray(json.data) ? json.data : [];
      setWatchlist(safeList);
      if (activeStock?.code === code && safeList.length > 0) {
        handleSelectStock(safeList[0]);
      }
    } catch (e) { console.error(e); }
  };

  // --- 2. 模拟数据获取 ---
  const handleSelectStock = (stock) => {
    setActiveStock(stock);
    setLoading(true);
    fetchStockDetails(stock).then(() => setLoading(false));
  };

  const fetchStockDetails = async (stock) => {
    await new Promise(r => setTimeout(r, 300));
    const basePrice = getBasePrice(stock.code);
    const volatility = basePrice * 0.02;
    const randomChange = (Math.random() - 0.5) * volatility;
    const currentPrice = basePrice + randomChange;
    
    // 生成模拟历史
    const history = [];
    let p = basePrice * 0.9;
    for(let i=0; i<30; i++) {
        p = p * (1 + (Math.random() - 0.45) * 0.05);
        history.push({ date: \`T-\${30-i}\`, price: parseFloat(p.toFixed(2)), ma5: parseFloat((p*1.02).toFixed(2)) });
    }
    
    const aiScore = Math.floor(Math.random() * 30) + 60;
    
    setStockData({
      ...stock,
      price: currentPrice,
      change: randomChange,
      changePercent: (randomChange / basePrice) * 100,
      history: history,
      aiScore: aiScore,
      analysis: aiScore > 75 ? '多头排列，量价齐升' : '震荡整理，方向未明',
      forecast: Array.from({length: 7}, (_, i) => ({ day: \`未来\${i+1}天\`, price: parseFloat((currentPrice*(1+(Math.random()-0.4)*0.02)).toFixed(2)) }))
    });
    setLastUpdated(new Date());
  };

  useEffect(() => {
    if (!activeStock) return;
    const interval = setInterval(() => fetchStockDetails(activeStock), 15000);
    return () => clearInterval(interval);
  }, [activeStock]);

  const getBasePrice = (code) => {
    let hash = 0;
    for (let i = 0; i < code.length; i++) hash = code.charCodeAt(i) + ((hash << 5) - hash);
    return (Math.abs(hash) % 200) + 10;
  };

  const isPositive = stockData?.change >= 0;
  const colorClass = isPositive ? 'text-[#FF3B30]' : 'text-[#34C759]';
  const chartColor = isPositive ? '#FF3B30' : '#34C759';

  return (
    <div className="flex min-h-screen bg-[#f5f5f7] font-sans text-gray-900">
      
      {/* 左侧侧边栏 */}
      <div className="w-80 bg-white border-r border-gray-200 flex flex-col h-screen fixed left-0 top-0 z-20 shadow-sm">
        <div className="p-6 border-b border-gray-100">
          <div className="flex items-center gap-2 mb-6">
            <div className="bg-black text-white p-1.5 rounded-lg"><Activity className="w-4 h-4" /></div>
            <span className="font-bold text-lg tracking-tight">StockAI Pro</span>
          </div>
          
          {errorMsg && (
            <div className="mb-4 p-3 bg-red-50 text-red-500 text-xs rounded-lg border border-red-100 flex items-start gap-2">
              <AlertCircle className="w-4 h-4 shrink-0" />
              {errorMsg}
            </div>
          )}

          <div className="relative group">
            <input 
              type="text" value={query} onChange={e => setQuery(e.target.value)}
              onKeyDown={e => { if(e.key === 'Enter' && query) addToWatchlist(query, \`自选 \${query}\`); }}
              placeholder="添加代码 (回车)"
              className="w-full bg-gray-50 border border-gray-200 rounded-xl py-2.5 pl-9 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-black/5 transition-all"
            />
            <Search className="w-4 h-4 absolute left-3 top-3 text-gray-400" />
            {query && (
              <button onClick={() => addToWatchlist(query, \`自选 \${query}\`)} className="absolute right-2 top-2 p-1 bg-black text-white rounded-md hover:scale-105 transition-transform"><Plus className="w-3 h-3" /></button>
            )}
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-3 space-y-2">
          {watchlist.map(stock => (
            <div key={stock.code} onClick={() => handleSelectStock(stock)} className={\`group flex items-center justify-between p-3 rounded-xl cursor-pointer transition-all hover:bg-gray-50 \${activeStock?.code === stock.code ? 'bg-white shadow-md border border-gray-100 ring-1 ring-black/5' : ''}\`}>
              <div><div className="font-semibold text-sm">{stock.name}</div><div className="text-xs text-gray-400 font-mono">{stock.code}</div></div>
              <button onClick={(e) => removeFromWatchlist(e, stock.code)} className="opacity-0 group-hover:opacity-100 p-2 text-gray-300 hover:text-red-500 transition-opacity"><Trash2 className="w-4 h-4" /></button>
            </div>
          ))}
        </div>
      </div>

      {/* 右侧主内容区 */}
      <div className="flex-1 ml-80 p-8 md:p-12 overflow-y-auto">
        {loading || !stockData ? (
          <div className="h-full flex flex-col justify-center items-center text-gray-400">
             <div className="w-8 h-8 border-4 border-gray-200 border-t-black rounded-full animate-spin mb-4"></div>
             <p>AI 正在分析...</p>
          </div>
        ) : (
          <div className="max-w-5xl mx-auto space-y-8 animate-in fade-in zoom-in-95 duration-500">
            <div className="flex justify-between items-end">
              <div>
                <h1 className="text-3xl font-bold mb-1 flex items-center gap-3">{stockData.name} <span className="text-sm font-normal bg-gray-200 text-gray-600 px-2 py-0.5 rounded-md font-mono">{stockData.code}</span></h1>
                <div className="flex items-center gap-2 text-sm text-gray-500"><span className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></span> 实时交易中 · {lastUpdated.toLocaleTimeString()} 更新 (15s/次)</div>
              </div>
              <div className="text-right">
                <div className={\`text-5xl font-bold tracking-tight \${colorClass}\`}>¥{stockData.price.toFixed(2)}</div>
                <div className={\`flex items-center justify-end gap-2 text-lg font-medium \${colorClass}\`}>{isPositive ? <TrendingUp className="w-5 h-5"/> : <TrendingDown className="w-5 h-5"/>}{stockData.change > 0 ? '+' : ''}{stockData.change.toFixed(2)} ({stockData.changePercent.toFixed(2)}%)</div>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
              <div className="lg:col-span-2 bg-white rounded-3xl p-6 shadow-sm border border-gray-100">
                <div className="h-[320px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={stockData.history}>
                      <defs><linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor={chartColor} stopOpacity={0.1}/><stop offset="95%" stopColor={chartColor} stopOpacity={0}/></linearGradient></defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" vertical={false} />
                      <XAxis dataKey="date" hide />
                      <YAxis domain={['auto', 'auto']} orientation="right" tick={{fontSize: 11, fill: '#9ca3af'}} axisLine={false} tickLine={false} />
                      <Tooltip contentStyle={{borderRadius: '12px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)'}} />
                      <Area type="monotone" dataKey="price" stroke={chartColor} strokeWidth={3} fill="url(#colorPrice)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>

              <div className="space-y-6">
                <div className="bg-black text-white rounded-3xl p-6 shadow-xl relative overflow-hidden group">
                  <div className="absolute top-[-50%] right-[-50%] w-full h-full bg-gradient-to-b from-blue-600/30 to-transparent rounded-full blur-3xl group-hover:scale-150 transition-transform duration-1000"></div>
                  <div className="relative z-10">
                    <div className="flex items-center gap-2 text-gray-400 text-xs font-bold uppercase tracking-wider mb-2"><Sparkles className="w-3 h-3 text-yellow-400" /> AI 综合评分</div>
                    <div className="text-5xl font-bold tracking-tighter mb-2">{stockData.aiScore}</div>
                    <div className="text-sm text-gray-300 border-t border-white/10 pt-3 mt-3">{stockData.analysis}</div>
                  </div>
                </div>
                <div className="bg-white rounded-3xl p-5 shadow-sm border border-gray-100">
                  <h3 className="text-sm font-semibold mb-4 text-gray-500">未来 7 天趋势预测</h3>
                  <div className="h-32">
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={stockData.forecast}><Bar dataKey="price" fill="#3b82f6" radius={[4, 4, 0, 0]} /></BarChart>
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

echo "✅ 修复完成！请提交代码。"
```

### 操作指南

1.  在 Codespaces 终端运行：`bash fix_crash.sh`
2.  提交代码：
    ```bash
    git add .
    git commit -m "Fix: Add fallback for missing DB"
    git push origin main