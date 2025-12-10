#!/bin/bash

echo "🚑 开始执行终极 UI 修复 (强制三栏布局 + 90天数据可视化)..."

# 重写 app/page.js
cat <<EOF > app/page.js
"use client";

import React, { useState, useEffect } from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar } from 'recharts';
import { Search, TrendingUp, TrendingDown, Sparkles, Plus, Trash2, Activity, Newspaper, ArrowRight, Calendar } from 'lucide-react';

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
      if (list.length > 0) {
        setWatchlist(list);
        handleSelectStock(list[0]);
      } else {
        const defaultStock = {code: '600519', name: '贵州茅台'};
        await addToWatchlist(defaultStock.code, defaultStock.name);
      }
    } catch (e) {
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
    } catch (e) { console.error(e); }
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
      if (activeStock?.code === code && newList.length > 0) handleSelectStock(newList[0]);
    } catch(e) {}
  };

  const handleSelectStock = (stock) => {
    setActiveStock(stock);
    setLoading(true);
    
    // 模拟网络延迟
    setTimeout(() => {
       const basePrice = 100 + Math.random() * 50;
       
       // --- 关键：生成过去 90 天 (3个月) 的数据 ---
       const history = [];
       let price = basePrice;
       const now = new Date();
       
       // 倒序生成，从90天前到现在
       for (let i = 90; i >= 0; i--) {
         const date = new Date(now);
         date.setDate(date.getDate() - i);
         
         // 模拟波动算法
         const changePercent = (Math.random() - 0.48) * 0.04; 
         price = price * (1 + changePercent);
         
         history.push({
           // 格式化日期为 MM-DD
           date: \`\${date.getMonth()+1}-\${date.getDate()}\`, 
           price: parseFloat(price.toFixed(2)),
           // 5日均线模拟
           ma5: parseFloat((price * (1 + (Math.random()-0.5)*0.02)).toFixed(2)) 
         });
       }
       
       const lastPrice = history[history.length-1].price;
       const prevPrice = history[history.length-2].price;
       const change = lastPrice - prevPrice;
       const aiScore = Math.floor(Math.random() * 40) + 60;

       // 模拟新闻数据
       const news = [
         { type: '公告', title: \`\${stock.name}: 2024年半年度业绩预告\`, time: '10分钟前' },
         { type: '资金', title: \`北向资金今日大幅净买入\${stock.name}\`, time: '45分钟前' },
         { type: '研报', title: \`\${stock.name}深度报告：拐点已至，价值重估\`, time: '2小时前' },
         { type: '行业', title: \`行业利好政策落地，产业链全线受益\`, time: '昨天' },
         { type: '动态', title: \`\${stock.name}召开投资者交流会\`, time: '昨天' }
       ];

       setStockData({
         ...stock, 
         price: lastPrice, 
         change: change, 
         changePercent: (change/prevPrice)*100,
         history: history, 
         aiScore: aiScore, 
         analysis: aiScore > 80 
           ? 'AI 模型识别到强劲的上升趋势，资金流入明显，技术指标呈多头排列。建议：买入/持有。' 
           : '当前股价处于箱体震荡区间，多空博弈激烈，缺乏明确方向。建议：观望/轻仓。',
         forecast: Array.from({length: 7}, (_, i) => ({ day: \`+\${i+1}\`, price: parseFloat((lastPrice * (1 + (Math.random()-0.4)*0.03)).toFixed(2)) })),
         news: news
       });
       setLoading(false);
    }, 400);
  };

  const isPositive = stockData?.change >= 0;
  const colorClass = isPositive ? 'text-[#FF3B30]' : 'text-[#34C759]'; // A股红涨绿跌
  const chartColor = isPositive ? '#FF3B30' : '#34C759';

  if (!mounted) return null;

  return (
    // 强制全屏 flex 布局，禁止 body 滚动
    <div className="flex flex-row h-screen w-screen bg-[#f5f5f7] font-sans text-gray-900 overflow-hidden">
      
      {/* --- 左栏：股票池 (固定宽度 240px) --- */}
      <aside className="w-[240px] flex-shrink-0 bg-white border-r border-gray-200 flex flex-col z-20">
        <div className="p-4 border-b border-gray-100 bg-white/80 backdrop-blur-md">
          <div className="flex items-center gap-2 mb-3 text-gray-900 font-bold text-lg">
             <Activity className="w-5 h-5 text-blue-600" /> StockAI
          </div>
          <div className="relative group">
            <input 
              type="text" value={query} onChange={e => setQuery(e.target.value)}
              placeholder="添加代码"
              className="w-full bg-gray-100 border-none rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 transition-all"
              onKeyDown={e => e.key === 'Enter' && query && addToWatchlist(query, \`\${query}\`)}
            />
            <Plus className="w-4 h-4 text-gray-400 absolute right-3 top-2.5 cursor-pointer hover:text-blue-600" onClick={() => query && addToWatchlist(query, \`\${query}\`)} />
          </div>
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-1 custom-scrollbar">
          {watchlist.map(s => (
            <div key={s.code} onClick={() => handleSelectStock(s)} 
                 className={\`p-3 rounded-lg cursor-pointer flex justify-between items-center group transition-all \${activeStock?.code === s.code ? 'bg-blue-50 ring-1 ring-blue-100 shadow-sm' : 'hover:bg-gray-50'}\`}>
              <div>
                <div className={\`font-medium text-sm \${activeStock?.code === s.code ? 'text-blue-700' : 'text-gray-700'}\`}>{s.name}</div>
                <div className="text-xs text-gray-400 font-mono mt-0.5">{s.code}</div>
              </div>
              <button onClick={(e) => removeFromWatchlist(e, s.code)} className="opacity-0 group-hover:opacity-100 hover:text-red-500 p-1.5 rounded-full hover:bg-red-50"><Trash2 className="w-3.5 h-3.5"/></button>
            </div>
          ))}
        </div>
      </aside>

      {/* --- 中栏：核心分析 (自适应宽度 flex-1) --- */}
      <main className="flex-1 flex flex-col min-w-0 bg-[#f5f5f7] relative overflow-hidden">
        {!stockData || loading ? (
           <div className="absolute inset-0 flex items-center justify-center bg-white/50 backdrop-blur-sm z-50">
             <div className="flex flex-col items-center gap-3">
               <div className="w-8 h-8 border-4 border-blue-500/30 border-t-blue-600 rounded-full animate-spin"></div>
               <span className="text-sm text-gray-500 font-medium">正在分析 90 天数据...</span>
             </div>
           </div>
        ) : null}

        {stockData && (
          <div className="flex-1 overflow-y-auto p-6 space-y-6 custom-scrollbar">
             
             {/* 1. 顶部行情头 */}
             <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100/50 flex justify-between items-center">
                <div>
                   <h1 className="text-2xl font-bold flex items-center gap-3 text-gray-900">
                     {stockData.name} <span className="text-lg font-normal text-gray-400 font-mono bg-gray-50 px-2 py-0.5 rounded">{stockData.code}</span>
                   </h1>
                   <div className="text-xs text-gray-500 mt-2 flex items-center gap-2">
                     <span className="relative flex h-2 w-2">
                       <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                       <span className="relative inline-flex rounded-full h-2 w-2 bg-green-500"></span>
                     </span>
                     实时交易中
                   </div>
                </div>
                <div className="text-right">
                   <div className={\`text-5xl font-bold tracking-tight \${colorClass}\`}>¥{stockData.price.toFixed(2)}</div>
                   <div className={\`font-medium text-lg mt-1 \${colorClass}\`}>
                     {stockData.change > 0 ? '+' : ''}{stockData.change.toFixed(2)} ({stockData.changePercent.toFixed(2)}%)
                   </div>
                </div>
             </div>

             {/* 2. 价格走势图 (90天) */}
             <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100/50">
                <div className="flex justify-between items-center mb-6">
                  <h3 className="text-sm font-bold text-gray-800 flex items-center gap-2">
                    <Calendar className="w-4 h-4 text-gray-500"/> 近 3 个月收盘价走势
                  </h3>
                  <div className="flex bg-gray-100 rounded-lg p-0.5">
                    {['日K', '周K', '月K'].map((t, i) => (
                      <span key={t} className={\`text-xs px-3 py-1 rounded-md cursor-pointer transition-all \${i===0 ? 'bg-white shadow text-gray-900 font-medium' : 'text-gray-500 hover:text-gray-900'}\`}>{t}</span>
                    ))}
                  </div>
                </div>
                <div className="h-[350px] w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={stockData.history} margin={{ top: 5, right: 0, left: 0, bottom: 0 }}>
                       <defs>
                          <linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1">
                             <stop offset="5%" stopColor={chartColor} stopOpacity={0.2}/>
                             <stop offset="95%" stopColor={chartColor} stopOpacity={0}/>
                          </linearGradient>
                       </defs>
                       <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                       {/* 关键修复：设置 minTickGap 防止 X 轴文字重叠 */}
                       <XAxis dataKey="date" tick={{fontSize: 10, fill: '#9ca3af'}} axisLine={false} tickLine={false} dy={10} minTickGap={40} />
                       <YAxis domain={['auto', 'auto']} orientation="right" tick={{fontSize: 11, fill: '#9ca3af'}} axisLine={false} tickLine={false} tickFormatter={v => v.toFixed(0)} />
                       <Tooltip 
                          contentStyle={{borderRadius:'12px', border:'none', boxShadow:'0 10px 15px -3px rgba(0, 0, 0, 0.1)', padding: '12px'}}
                          itemStyle={{fontSize: '13px', fontWeight: 600, color: '#1f2937'}}
                          labelStyle={{fontSize: '11px', color: '#9ca3af', marginBottom: '4px'}}
                       />
                       <Area type="monotone" dataKey="price" stroke={chartColor} strokeWidth={2} fill="url(#colorPrice)" activeDot={{r: 6, strokeWidth: 0}} />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
             </div>

             <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
                {/* 3. AI 分析结论 */}
                <div className="bg-gray-900 text-white p-6 rounded-2xl shadow-lg relative overflow-hidden flex flex-col justify-between">
                   <div className="relative z-10">
                      <div className="flex items-center justify-between mb-4">
                        <div className="text-xs font-bold text-gray-400 uppercase flex items-center gap-2"><Sparkles className="w-3 h-3 text-yellow-400"/> AI 决策模型</div>
                        <div className="bg-white/10 px-2 py-1 rounded text-xs font-mono text-gray-300">V2.0</div>
                      </div>
                      <div className="flex items-end gap-3 mb-6">
                        <span className="text-6xl font-bold tracking-tighter">{stockData.aiScore}</span>
                        <div className="flex flex-col mb-2">
                          <span className="text-sm text-gray-400">综合评分</span>
                          <span className="text-xs text-green-400">击败 85% 股票</span>
                        </div>
                      </div>
                      <div className="text-sm text-gray-200 border-t border-white/10 pt-4 leading-relaxed font-light">
                         "{stockData.analysis}"
                      </div>
                   </div>
                   {/* 背景装饰 */}
                   <div className="absolute top-0 right-0 w-64 h-64 bg-blue-600 rounded-full blur-[100px] opacity-20 pointer-events-none -mr-16 -mt-16"></div>
                </div>

                {/* 4. 预测图表 */}
                <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100/50 flex flex-col">
                   <h3 className="text-sm font-bold text-gray-800 mb-4 flex items-center gap-2"><ArrowRight className="w-4 h-4 text-blue-500"/> 未来 7 日趋势预测</h3>
                   <div className="flex-1 min-h-[160px]">
                     <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={stockData.forecast} barSize={28}>
                           <Bar dataKey="price" fill="#3b82f6" radius={[4,4,0,0]} />
                           <Tooltip cursor={{fill:'#f3f4f6'}} contentStyle={{borderRadius:'8px', fontSize: '11px', border: 'none', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'}}/>
                        </BarChart>
                     </ResponsiveContainer>
                   </div>
                </div>
             </div>
          </div>
        )}
      </main>

      {/* --- 右栏：新闻公告 (固定宽度 280px) --- */}
      <aside className="w-[280px] flex-shrink-0 bg-white border-l border-gray-200 flex flex-col z-20">
        <div className="p-4 border-b border-gray-100 font-bold text-sm text-gray-800 flex items-center gap-2 bg-white">
           <Newspaper className="w-4 h-4 text-orange-500"/> 智能资讯
        </div>
        <div className="flex-1 overflow-y-auto p-4 space-y-4 custom-scrollbar bg-gray-50/50">
           {!stockData ? (
             <div className="text-gray-400 text-xs text-center mt-10">选择股票查看关联资讯</div>
           ) : (
             stockData.news.map((n, i) => (
               <div key={i} className="bg-white p-3.5 rounded-xl border border-gray-100 shadow-[0_2px_8px_rgba(0,0,0,0.02)] hover:shadow-md transition-all cursor-pointer group">
                  <div className="flex items-center justify-between mb-2">
                     <span className={\`text-[10px] px-1.5 py-0.5 rounded font-medium \${n.type==='公告'?'bg-blue-50 text-blue-600':(n.type==='资金'?'bg-red-50 text-red-600':'bg-orange-50 text-orange-600')}\`}>
                        {n.type}
                     </span>
                     <span className="text-[10px] text-gray-400">{n.time}</span>
                  </div>
                  <h4 className="text-xs font-medium text-gray-700 leading-snug group-hover:text-blue-600 transition-colors">{n.title}</h4>
               </div>
             ))
           )}
        </div>
      </aside>

    </div>
  );
}
EOF

echo "✅ 界面布局已彻底重构！请运行以下命令进行推送："
echo "git add ."
echo "git commit -m \"Final UI Fix: 3-Column Layout + 90 Day Chart\""
echo "git push origin main"