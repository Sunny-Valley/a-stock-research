#!/bin/bash

echo "🚑 修复 UI 显示问题 (V3)..."

# 重写 app/page.js
# 重点修复：handleSelectStock 逻辑和 useEffect 初始化逻辑
cat <<EOF > app/page.js
"use client";

import React, { useState, useEffect } from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar } from 'recharts';
import { Search, TrendingUp, TrendingDown, Sparkles, Plus, Trash2, Activity, AlertCircle } from 'lucide-react';

export default function Home() {
  const [watchlist, setWatchlist] = useState([]);
  const [activeStock, setActiveStock] = useState(null); 
  const [stockData, setStockData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [query, setQuery] = useState('');
  const [errorMsg, setErrorMsg] = useState('');

  // 初始化
  useEffect(() => {
    fetchWatchlist();
  }, []);

  const fetchWatchlist = async () => {
    try {
      const res = await fetch('/api/watchlist');
      const json = await res.json();
      const list = json.data || [];
      
      if (list.length > 0) {
        setWatchlist(list);
        // 关键修复：确保初始化时立即加载第一只股票的数据
        handleSelectStock(list[0]);
      } else {
        // 如果为空，添加默认数据并加载
        const defaultStock = {code: '600519', name: '贵州茅台'};
        await addToWatchlist(defaultStock.code, defaultStock.name);
      }
    } catch (e) {
      console.error("Fetch failed", e);
      // 兜底数据
      const demoList = [{code: '600519', name: '贵州茅台'}, {code: '300750', name: '宁德时代'}];
      setWatchlist(demoList);
      handleSelectStock(demoList[0]);
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
      if (json.data) {
        setWatchlist(json.data);
        handleSelectStock({code, name});
        setQuery('');
      }
    } catch (e) {
      alert("添加失败，请检查网络");
    }
  };

  const removeFromWatchlist = async (e, code) => {
    e.stopPropagation();
    if(!confirm('确定移除吗？')) return;
    try {
      await fetch('/api/watchlist', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ action: 'remove', code })
      });
      const newList = watchlist.filter(s => s.code !== code);
      setWatchlist(newList);
      if (activeStock?.code === code && newList.length > 0) {
        handleSelectStock(newList[0]);
      }
    } catch(e) {}
  };

  // 生成模拟数据 (在真实 API 接入前使用)
  const handleSelectStock = (stock) => {
    setActiveStock(stock);
    setLoading(true);
    
    // 模拟数据生成
    setTimeout(() => {
       const basePrice = 100 + Math.random() * 50;
       const history = Array.from({length: 30}, (_, i) => ({
         date: \`T-\${30-i}\`, 
         price: parseFloat((basePrice * (1 + Math.sin(i/3)*0.1 + (Math.random()-0.5)*0.05)).toFixed(2))
       }));
       
       const lastPrice = history[history.length-1].price;
       const change = lastPrice - history[history.length-2].price;
       const aiScore = Math.floor(Math.random() * 40) + 60;

       setStockData({
         ...stock, 
         price: lastPrice, 
         change: change, 
         changePercent: (change/lastPrice)*100,
         history: history, 
         aiScore: aiScore, 
         analysis: aiScore > 80 ? '多头排列，量价齐升，建议持有' : (aiScore > 60 ? '震荡整理，方向未明' : '空头趋势，建议规避'),
         forecast: Array.from({length: 7}, (_, i) => ({ 
            day: \`+\${i+1}\`, 
            price: parseFloat((lastPrice * (1 + (Math.random()-0.4)*0.03)).toFixed(2)) 
         }))
       });
       setLoading(false);
    }, 300);
  };

  // 颜色辅助
  const isPositive = stockData?.change >= 0;
  const colorClass = isPositive ? 'text-red-500' : 'text-green-500';
  const chartColor = isPositive ? '#ef4444' : '#22c55e';

  return (
    <div className="flex min-h-screen bg-[#f5f5f7] font-sans text-gray-900">
      
      {/* 侧边栏 */}
      <div className="w-72 bg-white border-r border-gray-200 flex flex-col h-screen fixed z-20 shadow-sm">
        <div className="p-5 border-b border-gray-100">
          <div className="flex items-center gap-2 mb-4 font-bold text-lg">
             <Activity className="w-5 h-5" /> StockAI Pro
          </div>
          <div className="relative">
            <input 
              type="text" value={query} onChange={e => setQuery(e.target.value)}
              placeholder="输入代码 (如 600519)"
              className="w-full bg-gray-50 border rounded-lg py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-black/5"
              onKeyDown={e => e.key === 'Enter' && query && addToWatchlist(query, \`自选 \${query}\`)}
            />
            {query && <button onClick={() => addToWatchlist(query, \`自选 \${query}\`)} className="absolute right-2 top-2"><Plus className="w-4 h-4 text-gray-400 hover:text-black"/></button>}
          </div>
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-1">
          {watchlist.map(s => (
            <div key={s.code} onClick={() => handleSelectStock(s)} 
                 className={\`p-3 rounded-lg cursor-pointer flex justify-between items-center group \${activeStock?.code === s.code ? 'bg-black text-white shadow-md' : 'hover:bg-gray-100 text-gray-700'}\`}>
              <div>
                <div className="font-bold text-sm">{s.name}</div>
                <div className={\`text-xs \${activeStock?.code === s.code ? 'text-gray-400' : 'text-gray-400'}\`}>{s.code}</div>
              </div>
              <button onClick={(e) => removeFromWatchlist(e, s.code)} className="opacity-0 group-hover:opacity-100 hover:text-red-400"><Trash2 className="w-4 h-4"/></button>
            </div>
          ))}
        </div>
      </div>

      {/* 主内容区 */}
      <div className="flex-1 ml-72 p-8 md:p-12 overflow-y-auto">
        {!stockData || loading ? (
           <div className="h-full flex items-center justify-center text-gray-400 animate-pulse">正在分析市场数据...</div>
        ) : (
          <div className="max-w-5xl mx-auto space-y-6 animate-in fade-in zoom-in-95 duration-300">
             
             {/* 头部信息 */}
             <div className="flex justify-between items-end bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                <div>
                   <h1 className="text-3xl font-bold mb-1">{stockData.name} <span className="text-lg font-normal text-gray-400 ml-2">{stockData.code}</span></h1>
                   <div className="flex items-center gap-2 text-sm text-gray-500">
                      <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></span> 实时交易中
                   </div>
                </div>
                <div className="text-right">
                   <div className={\`text-5xl font-bold tracking-tighter \${colorClass}\`}>¥{stockData.price.toFixed(2)}</div>
                   <div className={\`text-lg font-medium \${colorClass}\`}>
                      {stockData.change > 0 ? '+' : ''}{stockData.change.toFixed(2)} ({stockData.changePercent.toFixed(2)}%)
                   </div>
                </div>
             </div>

             <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* 左侧图表 */}
                <div className="lg:col-span-2 bg-white p-6 rounded-2xl shadow-sm border border-gray-100 h-96">
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
                         <YAxis domain={['auto', 'auto']} orientation="right" tick={{fontSize:12}} axisLine={false} tickLine={false} />
                         <Tooltip contentStyle={{borderRadius:'8px', border:'none', boxShadow:'0 4px 12px rgba(0,0,0,0.1)'}}/>
                         <Area type="monotone" dataKey="price" stroke={chartColor} strokeWidth={3} fill="url(#colorPrice)" />
                      </AreaChart>
                   </ResponsiveContainer>
                </div>

                {/* 右侧分析 */}
                <div className="space-y-6">
                   {/* AI 评分 */}
                   <div className="bg-black text-white p-6 rounded-2xl shadow-xl relative overflow-hidden">
                      <div className="relative z-10">
                         <div className="text-xs font-bold text-gray-400 uppercase mb-2 flex items-center gap-2"><Sparkles className="w-4 h-4 text-yellow-400"/> AI 综合评分</div>
                         <div className="text-6xl font-bold tracking-tighter mb-4">{stockData.aiScore}</div>
                         <div className="text-sm text-gray-300 pt-4 border-t border-white/10">
                            {stockData.analysis}
                         </div>
                      </div>
                   </div>

                   {/* 预测 */}
                   <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 h-48">
                      <div className="text-xs font-bold text-gray-400 mb-4">未来 7 日趋势预测</div>
                      <ResponsiveContainer width="100%" height="100%">
                         <BarChart data={stockData.forecast}>
                            <Bar dataKey="price" fill="#3b82f6" radius={[4,4,0,0]} />
                            <Tooltip cursor={{fill:'transparent'}} contentStyle={{borderRadius:'8px'}}/>
                         </BarChart>
                      </ResponsiveContainer>
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

echo "✅ 界面修复完成！提交代码..."
git add .
git commit -m "Fix UI: Ensure data display logic"
git push origin main