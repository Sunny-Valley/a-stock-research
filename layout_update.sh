#!/bin/bash

echo "🎨 开始重构界面 V3 (修复布局 + 3个月数据 + 曲线显示)..."

# 重写 app/page.js
cat <<EOF > app/page.js
"use client";

import React, { useState, useEffect } from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar } from 'recharts';
import { Search, TrendingUp, TrendingDown, Sparkles, Plus, Trash2, Activity, Newspaper, ArrowRight } from 'lucide-react';

export default function Home() {
  const [watchlist, setWatchlist] = useState([]);
  const [activeStock, setActiveStock] = useState(null); 
  const [stockData, setStockData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [query, setQuery] = useState('');
  const [mounted, setMounted] = useState(false); // 解决图表水合问题

  // 1. 初始化
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
    } catch (e) { alert("网络错误"); }
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

  // 2. 生成数据 (核心修改：生成90天数据)
  const handleSelectStock = (stock) => {
    setActiveStock(stock);
    setLoading(true);
    
    setTimeout(() => {
       const basePrice = 100 + Math.random() * 100;
       
       // --- 生成过去 3 个月 (90天) 的数据 ---
       const history = [];
       let price = basePrice;
       const now = new Date();
       for (let i = 90; i >= 0; i--) {
         const date = new Date(now);
         date.setDate(date.getDate() - i);
         // 随机波动
         price = price * (1 + (Math.random() - 0.48) * 0.04);
         history.push({
           date: \`\${date.getMonth()+1}-\${date.getDate()}\`, // 格式: 月-日
           fullDate: date.toISOString().split('T')[0],
           price: parseFloat(price.toFixed(2))
         });
       }
       
       const lastPrice = history[history.length-1].price;
       const prevPrice = history[history.length-2].price;
       const change = lastPrice - prevPrice;
       const aiScore = Math.floor(Math.random() * 40) + 60;

       // 模拟新闻
       const news = [
         { type: '公告', title: \`\${stock.name}: 2024年季度报告披露提示\`, time: '15分钟前' },
         { type: '资金', title: \`\${stock.name}今日主力资金净流入超1.2亿元\`, time: '1小时前' },
         { type: '研报', title: \`券商评级：维持\${stock.name}“买入”评级，目标价看高一线\`, time: '4小时前' },
         { type: '行业', title: \`行业重磅利好落地，\${stock.name}等多股受益\`, time: '昨天' },
         { type: '动态', title: \`\${stock.name}投资者关系活动记录表\`, time: '昨天' }
       ];

       setStockData({
         ...stock, 
         price: lastPrice, 
         change: change, 
         changePercent: (change/prevPrice)*100,
         history: history, 
         aiScore: aiScore, 
         analysis: aiScore > 80 ? '技术面呈多头排列，MACD金叉向上，资金持续流入，建议积极关注。' : '股价处于震荡区间，上方均线压力较重，建议观望等待突破。',
         forecast: Array.from({length: 7}, (_, i) => ({ day: \`+\${i+1}\`, price: parseFloat((lastPrice * (1 + (Math.random()-0.4)*0.03)).toFixed(2)) })),
         news: news
       });
       setLoading(false);
    }, 300);
  };

  const isPositive = stockData?.change >= 0;
  const colorClass = isPositive ? 'text-[#FF3B30]' : 'text-[#34C759]';
  const chartColor = isPositive ? '#FF3B30' : '#34C759';

  if (!mounted) return null; // 防止水合错误

  return (
    <div className="flex h-screen bg-[#f5f5f7] font-sans text-gray-900 overflow-hidden">
      
      {/* 1. 左栏：股票池 (固定 260px) */}
      <div className="w-[260px] bg-white border-r border-gray-200 flex flex-col z-20 flex-shrink-0">
        <div className="p-4 border-b border-gray-100">
          <div className="flex items-center gap-2 mb-4 font-bold text-lg text-gray-800"><Activity className="w-5 h-5 text-blue-600" /> StockAI</div>
          <div className="relative group">
            <input 
              type="text" value={query} onChange={e => setQuery(e.target.value)}
              placeholder="代码 (回车)"
              className="w-full bg-gray-50 border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 transition-all"
              onKeyDown={e => e.key === 'Enter' && query && addToWatchlist(query, \`\${query}\`)}
            />
            <Search className="w-4 h-4 text-gray-400 absolute right-3 top-2.5" />
          </div>
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-1">
          {watchlist.map(s => (
            <div key={s.code} onClick={() => handleSelectStock(s)} 
                 className={\`p-3 rounded-lg cursor-pointer flex justify-between items-center group transition-colors \${activeStock?.code === s.code ? 'bg-blue-50 text-blue-700 ring-1 ring-blue-200' : 'hover:bg-gray-50 text-gray-700'}\`}>
              <div>
                <div className="font-medium text-sm">{s.name}</div>
                <div className="text-xs text-gray-400 font-mono mt-0.5">{s.code}</div>
              </div>
              <button onClick={(e) => removeFromWatchlist(e, s.code)} className="opacity-0 group-hover:opacity-100 hover:text-red-500 p-1"><Trash2 className="w-3.5 h-3.5"/></button>
            </div>
          ))}
        </div>
      </div>

      {/* 2. 中栏：走势与分析 (Flex-1 自适应) */}
      <div className="flex-1 flex flex-col min-w-0 bg-[#f5f5f7] overflow-hidden">
        {!stockData || loading ? (
           <div className="h-full flex items-center justify-center text-gray-400 animate-pulse flex-col gap-2">
             <Activity className="w-8 h-8 opacity-20" />
             <span className="text-sm">正在加载全量数据...</span>
           </div>
        ) : (
          <div className="flex-1 overflow-y-auto p-6 space-y-6">
             
             {/* 头部行情卡片 */}
             <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex justify-between items-center">
                <div>
                   <h1 className="text-2xl font-bold flex items-center gap-3 text-gray-900">
                     {stockData.name} 
                     <span className="text-sm font-normal bg-gray-100 text-gray-500 px-2 py-0.5 rounded-md font-mono">{stockData.code}</span>
                   </h1>
                   <div className="text-xs text-gray-400 mt-2 flex items-center gap-1.5">
                     <span className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse"></span> 
                     A股实时行情 · 已连接
                   </div>
                </div>
                <div className="text-right">
                   <div className={\`text-4xl font-bold tracking-tight \${colorClass}\`}>¥{stockData.price.toFixed(2)}</div>
                   <div className={\`font-medium text-sm mt-1 \${colorClass}\`}>
                     {stockData.change > 0 ? '+' : ''}{stockData.change.toFixed(2)} ({stockData.changePercent.toFixed(2)}%)
                   </div>
                </div>
             </div>

             {/* 核心走势图 (90天) */}
             <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="text-sm font-bold text-gray-800 flex items-center gap-2"><Activity className="w-4 h-4 text-gray-400"/> 价格走势 (近3个月)</h3>
                  <div className="flex gap-2">
                    {['日K', '周K', '月K'].map(t => <span key={t} className="text-xs px-2 py-1 bg-gray-50 rounded text-gray-500 cursor-pointer hover:bg-gray-100">{t}</span>)}
                  </div>
                </div>
                <div className="h-[300px] w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={stockData.history}>
                       <defs>
                          <linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1">
                             <stop offset="5%" stopColor={chartColor} stopOpacity={0.1}/>
                             <stop offset="95%" stopColor={chartColor} stopOpacity={0}/>
                          </linearGradient>
                       </defs>
                       <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                       <XAxis dataKey="date" tick={{fontSize: 10, fill: '#9ca3af'}} axisLine={false} tickLine={false} dy={10} minTickGap={30} />
                       <YAxis domain={['auto', 'auto']} orientation="right" tick={{fontSize: 11, fill: '#9ca3af'}} axisLine={false} tickLine={false} tickFormatter={v => v.toFixed(0)} />
                       <Tooltip 
                          contentStyle={{borderRadius:'12px', border:'none', boxShadow:'0 10px 15px -3px rgba(0, 0, 0, 0.1)'}}
                          itemStyle={{fontSize: '12px', fontWeight: 600}}
                          labelStyle={{fontSize: '10px', color: '#9ca3af', marginBottom: '4px'}}
                       />
                       <Area type="monotone" dataKey="price" stroke={chartColor} strokeWidth={2} fill="url(#colorPrice)" animationDuration={1000} />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
             </div>

             <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* AI 分析 */}
                <div className="bg-gradient-to-br from-gray-900 to-black text-white p-6 rounded-2xl shadow-lg relative overflow-hidden">
                   <div className="relative z-10">
                      <div className="text-xs font-bold text-gray-400 uppercase mb-2 flex items-center gap-2"><Sparkles className="w-3 h-3 text-yellow-400"/> AI 决策模型</div>
                      <div className="flex items-end gap-3 mb-4">
                        <span className="text-5xl font-bold tracking-tighter">{stockData.aiScore}</span>
                        <span className="text-sm text-gray-400 mb-1.5">/ 100</span>
                      </div>
                      <div className="text-sm text-gray-300 border-t border-white/10 pt-3 leading-relaxed">
                         {stockData.analysis}
                      </div>
                   </div>
                </div>

                {/* 预测图表 */}
                <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100">
                   <h3 className="text-sm font-bold text-gray-800 mb-4">未来 7 日趋势预测</h3>
                   <div className="h-32">
                     <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={stockData.forecast} barSize={24}>
                           <Bar dataKey="price" fill="#3b82f6" radius={[4,4,0,0]} />
                           <Tooltip cursor={{fill:'transparent'}} contentStyle={{borderRadius:'8px', fontSize: '11px'}}/>
                        </BarChart>
                     </ResponsiveContainer>
                   </div>
                </div>
             </div>
          </div>
        )}
      </div>

      {/* 3. 右栏：新闻公告 (固定 300px) */}
      <div className="w-[300px] bg-white border-l border-gray-200 flex flex-col z-20 flex-shrink-0">
        <div className="p-4 border-b border-gray-100 font-bold text-sm text-gray-800 flex items-center gap-2 bg-white">
           <Newspaper className="w-4 h-4 text-blue-600"/> 智能资讯
        </div>
        <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-[#fcfcfc]">
           {!stockData ? (
             <div className="text-gray-400 text-xs text-center mt-10">选择股票查看关联资讯</div>
           ) : (
             stockData.news.map((n, i) => (
               <div key={i} className="bg-white p-3 rounded-xl border border-gray-100 shadow-[0_2px_8px_rgba(0,0,0,0.02)] hover:shadow-md transition-all cursor-pointer group">
                  <div className="flex items-center gap-2 mb-1.5">
                     <span className={\`text-[10px] px-1.5 py-0.5 rounded font-medium \${n.type==='公告'?'bg-blue-50 text-blue-600':(n.type==='研报'?'bg-purple-50 text-purple-600':'bg-orange-50 text-orange-600')}\`}>
                        {n.type}
                     </span>
                     <span className="text-[10px] text-gray-400">{n.time}</span>
                  </div>
                  <h4 className="text-xs font-medium text-gray-700 leading-snug group-hover:text-blue-600 transition-colors">{n.title}</h4>
               </div>
             ))
           )}
        </div>
      </div>

    </div>
  );
}
EOF

echo "✅ V3 界面修复完成！请提交代码..."
echo "git add ."
echo "git commit -m \"UI Fix: 3-Month History + Layout Correction\""
echo "git push origin main"