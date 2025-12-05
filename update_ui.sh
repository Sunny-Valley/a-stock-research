#!/bin/bash

echo "🎨 开始升级 UI 为 Apple 极简风格..."

# 1. 更新 layout.js (设置浅灰色背景)
echo "📄 更新 app/layout.js..."
cat <<EOF > app/layout.js
import "./globals.css";

export const metadata = {
  title: "A股智投 AI",
  description: "极简主义 A股 AI 分析工具",
};

export default function RootLayout({ children }) {
  return (
    <html lang="zh-CN">
      <body className="bg-[#f5f5f7] text-gray-900 antialiased selection:bg-blue-500 selection:text-white">
        {children}
      </body>
    </html>
  );
}
EOF

# 2. 更新 globals.css (清理样式)
echo "🎨 更新 app/globals.css..."
cat <<EOF > app/globals.css
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji";
}

body {
  font-family: var(--font-sans);
}

::-webkit-scrollbar {
  width: 0px;
  background: transparent;
}
EOF

# 3. 更新 page.js (核心 UI 重写)
echo "📱 更新 app/page.js..."
cat <<EOF > app/page.js
"use client";

import React, { useState, useEffect } from 'react';
import { 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, 
  Tooltip, ResponsiveContainer, BarChart, Bar 
} from 'recharts';
import { 
  Search, TrendingUp, TrendingDown, Sparkles, 
  ArrowRight, Activity, BarChart3
} from 'lucide-react';

const MOCK_DB = {
  '600519': { name: '贵州茅台', sector: '白酒 · 消费' },
  '300750': { name: '宁德时代', sector: '新能源 · 电池' },
  '000001': { name: '平安银行', sector: '银行 · 金融' },
  '601127': { name: '赛力斯', sector: '汽车 · 智驾' },
  '002594': { name: '比亚迪', sector: '汽车 · 制造' },
};

const generateMarketData = (code) => {
  const stockInfo = MOCK_DB[code] || { name: \`A股代码 \${code}\`, sector: '未知板块' };
  const basePrice = Math.random() * 200 + 10;
  const volatility = basePrice * 0.05;
  
  const history = [];
  let currentPrice = basePrice;
  const now = new Date();
  
  for (let i = 30; i >= 0; i--) {
      const date = new Date(now);
      date.setDate(date.getDate() - i);
      const change = (Math.random() - 0.48) * volatility;
      currentPrice += change;
      if (currentPrice < 0) currentPrice = 1;
      history.push({
          date: date.toISOString().split('T')[0].slice(5),
          price: parseFloat(currentPrice.toFixed(2)),
      });
  }
  const latest = history[history.length - 1];
  const prev = history[history.length - 2];
  const change = latest.price - prev.price;
  const changePercent = (change / prev.price) * 100;

  const next7Days = [];
  let predPrice = latest.price;
  for(let i=1; i<=7; i++) {
      predPrice = predPrice * (1 + (Math.random() - 0.45) * 0.03);
      next7Days.push({ day: \`T+\${i}\`, price: parseFloat(predPrice.toFixed(2)) });
  }

  return {
      code, ...stockInfo, price: latest.price, change: parseFloat(change.toFixed(2)),
      changePercent: parseFloat(changePercent.toFixed(2)),
      volume: (latest.volume / 10000).toFixed(1) + '万',
      marketCap: (Math.random() * 1000 + 100).toFixed(0) + '亿',
      pe: (Math.random() * 50 + 5).toFixed(1),
      history, forecast: next7Days, aiScore: Math.floor(Math.random() * 40) + 60,
      sentiment: Math.random() > 0.5 ? '积极看多' : '谨慎观望',
      mainNetInflow: (Math.random() * 2 - 1).toFixed(2) + '亿'
  };
};

export default function Home() {
  const [query, setQuery] = useState('600519');
  const [stockData, setStockData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 10);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleSearch = (e) => {
      if (e) e.preventDefault();
      setLoading(true);
      setTimeout(() => {
          setStockData(generateMarketData(query));
          setLoading(false);
      }, 600);
  };

  useEffect(() => { handleSearch(); }, []);

  const isPositive = stockData?.change >= 0;
  const appleRed = "#FF3B30";   
  const appleGreen = "#34C759"; 
  const colorClass = isPositive ? 'text-[#FF3B30]' : 'text-[#34C759]';
  const chartColor = isPositive ? appleRed : appleGreen;

  return (
      <div className="min-h-screen text-gray-900 font-sans pb-20">
          <nav className={\`fixed top-0 w-full z-50 transition-all duration-300 border-b \${scrolled ? 'bg-white/70 backdrop-blur-xl border-gray-200/50 shadow-sm' : 'bg-transparent border-transparent'}\`}>
              <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
                  <div className="flex items-center gap-2">
                      <div className="bg-black text-white p-1.5 rounded-lg"><Activity className="w-4 h-4" /></div>
                      <span className="font-semibold text-lg tracking-tight">StockAI</span>
                  </div>
                  <div className="hidden md:flex items-center gap-8 text-sm font-medium text-gray-500">
                      <a href="#" className="hover:text-black transition-colors">行情</a>
                      <a href="#" className="hover:text-black transition-colors">自选</a>
                  </div>
              </div>
          </nav>

          <main className="max-w-4xl mx-auto px-6 pt-32">
              <div className="text-center mb-16 animate-in fade-in slide-in-from-bottom-4 duration-700">
                  <h1 className="text-4xl md:text-5xl font-bold mb-6 tracking-tight text-gray-900">智能洞察，<br className="md:hidden" />先人一步。</h1>
                  <p className="text-gray-500 mb-8 text-lg">基于 AI 的 A股实时分析与预测系统。</p>
                  <div className="max-w-lg mx-auto relative group">
                      <form onSubmit={handleSearch}>
                          <input type="text" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="输入代码，如 600519" className="w-full bg-white border border-gray-200 rounded-full py-4 pl-12 pr-12 text-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-black/5 focus:border-gray-300 transition-all hover:shadow-md"/>
                          <div className="absolute left-4 top-4 text-gray-400"><Search className="w-6 h-6" /></div>
                          <button type="submit" className="absolute right-3 top-3 bg-black text-white rounded-full p-2 hover:scale-105 transition-transform"><ArrowRight className="w-5 h-5" /></button>
                      </form>
                  </div>
              </div>

              {loading ? (
                 <div className="flex justify-center py-20"><div className="w-8 h-8 border-4 border-gray-200 border-t-black rounded-full animate-spin"></div></div>
              ) : stockData && (
                  <div className="space-y-8 animate-in fade-in zoom-in-95 duration-500">
                      <div className="bg-white rounded-3xl p-8 shadow-[0_8px_30px_rgb(0,0,0,0.04)] border border-gray-100 flex flex-col md:flex-row justify-between items-start md:items-center relative overflow-hidden">
                          <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-gray-200 to-transparent"></div>
                          <div>
                              <div className="flex items-center gap-3 mb-2"><h2 className="text-3xl font-bold text-gray-900">{stockData.name}</h2><span className="bg-gray-100 text-gray-500 text-xs font-semibold px-2.5 py-1 rounded-full">{stockData.code}</span></div>
                              <p className="text-gray-400 text-sm font-medium">{stockData.sector}</p>
                          </div>
                          <div className="mt-6 md:mt-0 text-right">
                              <div className={\`text-6xl font-semibold tracking-tighter \${colorClass}\`}><span className="text-3xl align-top mr-1">¥</span>{stockData.price.toFixed(2)}</div>
                              <div className={\`flex items-center justify-end gap-2 mt-1 font-medium \${colorClass}\`}>
                                  {isPositive ? <TrendingUp className="w-5 h-5" /> : <TrendingDown className="w-5 h-5" />}
                                  <span>{stockData.change > 0 ? '+' : ''}{stockData.change}</span><span>({stockData.changePercent}%)</span>
                              </div>
                          </div>
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
                          <div className="md:col-span-2 bg-white rounded-3xl p-6 shadow-[0_8px_30px_rgb(0,0,0,0.04)] border border-gray-100">
                              <div className="h-[280px]">
                                  <ResponsiveContainer width="100%" height="100%">
                                      <AreaChart data={stockData.history}>
                                          <defs><linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor={chartColor} stopOpacity={0.1}/><stop offset="95%" stopColor={chartColor} stopOpacity={0}/></linearGradient></defs>
                                          <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" vertical={false} />
                                          <XAxis dataKey="date" stroke="#9ca3af" tick={{fontSize: 10}} tickLine={false} axisLine={false} dy={10} />
                                          <YAxis domain={['auto', 'auto']} stroke="#9ca3af" tick={{fontSize: 10}} tickLine={false} axisLine={false} tickFormatter={(val) => \`¥\${val}\`} />
                                          <Tooltip contentStyle={{backgroundColor: '#fff', borderRadius: '12px', boxShadow: '0 4px 12px rgba(0,0,0,0.1)', border: 'none', fontSize: '12px'}} />
                                          <Area type="monotone" dataKey="price" stroke={chartColor} strokeWidth={2.5} fill="url(#colorPrice)" />
                                      </AreaChart>
                                  </ResponsiveContainer>
                              </div>
                          </div>
                          <div className="bg-black text-white rounded-3xl p-6 shadow-xl flex flex-col justify-between relative overflow-hidden group">
                              <div className="absolute top-[-50%] right-[-50%] w-full h-full bg-gradient-to-b from-blue-500/20 to-transparent rounded-full blur-3xl group-hover:scale-150 transition-transform duration-700"></div>
                              <div>
                                  <div className="flex items-center gap-2 mb-4 text-gray-400"><Sparkles className="w-5 h-5 text-yellow-300" /><span className="text-xs font-bold uppercase tracking-wider">AI 综合评分</span></div>
                                  <div className="flex items-baseline gap-2"><span className="text-6xl font-bold tracking-tighter">{stockData.aiScore}</span><span className="text-lg text-gray-500 font-medium">/ 100</span></div>
                                  <div className="mt-4 inline-flex items-center gap-2 bg-white/10 px-3 py-1.5 rounded-full backdrop-blur-md border border-white/5"><span className={\`w-2 h-2 rounded-full \${stockData.aiScore > 60 ? 'bg-green-400' : 'bg-red-400'}\`}></span><span className="text-sm font-medium">{stockData.sentiment}</span></div>
                              </div>
                              <div className="mt-8"><p className="text-sm text-gray-400 leading-relaxed border-t border-white/10 pt-4">{stockData.aiScore > 75 ? "AI 模型检测到多头排列，量价配合理想，建议继续持有。" : "短期动能减弱，建议保持谨慎，等待明确信号。"}</p></div>
                          </div>
                      </div>

                      <div className="bg-white rounded-3xl p-6 shadow-[0_8px_30px_rgb(0,0,0,0.04)] border border-gray-100">
                          <h3 className="font-semibold text-gray-900 mb-6 flex items-center gap-2"><BarChart3 className="w-5 h-5 text-gray-400" /> 未来 7 日预测</h3>
                          <div className="h-48">
                              <ResponsiveContainer width="100%" height="100%">
                                  <BarChart data={stockData.forecast} barSize={40}>
                                      <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" vertical={false} />
                                      <XAxis dataKey="day" stroke="#9ca3af" tick={{fontSize: 12}} axisLine={false} tickLine={false} dy={10} />
                                      <Tooltip cursor={{fill: '#f9fafb'}} contentStyle={{backgroundColor: '#fff', borderRadius: '8px', border: '1px solid #e5e7eb'}} />
                                      <Bar dataKey="price" fill="#3b82f6" radius={[6, 6, 0, 0]} />
                                  </BarChart>
                              </ResponsiveContainer>
                          </div>
                      </div>

                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                          {[
                              { label: '成交量', val: stockData.volume },
                              { label: '市盈率', val: stockData.pe },
                              { label: '总市值', val: stockData.marketCap },
                              { label: '主力净流', val: stockData.mainNetInflow, highlight: true }
                          ].map((item, i) => (
                              <div key={i} className="bg-gray-50 rounded-2xl p-4 text-center border border-gray-100/50">
                                  <div className="text-xs text-gray-400 mb-1">{item.label}</div>
                                  <div className={\`font-semibold \${item.highlight ? (stockData.mainNetInflow.includes('-') ? 'text-[#34C759]' : 'text-[#FF3B30]') : 'text-gray-900'}\`}>{item.val}</div>
                              </div>
                          ))}
                      </div>
                  </div>
              )}
          </main>
      </div>
  );
}
EOF

echo "✅ UI 升级脚本执行完毕！请运行 git push 上传更新。"