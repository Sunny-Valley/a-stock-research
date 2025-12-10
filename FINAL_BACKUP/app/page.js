"use client";

import React, { useState, useEffect } from 'react';
import { 
  LineChart, Line, AreaChart, Area, XAxis, YAxis, CartesianGrid, 
  Tooltip, ResponsiveContainer, ReferenceLine, BarChart, Bar 
} from 'recharts';
import { 
  Search, TrendingUp, TrendingDown, Activity, BrainCircuit, 
  Zap, AlertTriangle, BarChart2, Target 
} from 'lucide-react';

const MOCK_DB = {
  '600519': { name: '贵州茅台', sector: '白酒/消费' },
  '300750': { name: '宁德时代', sector: '新能源/电池' },
  '000001': { name: '平安银行', sector: '银行/金融' },
  '601127': { name: '赛力斯', sector: '新能源汽车' },
  '002594': { name: '比亚迪', sector: '汽车制造' },
  '601318': { name: '中国平安', sector: '保险/金融' },
  '688981': { name: '中芯国际', sector: '半导体/芯片' }
};

const generateMarketData = (code) => {
  const stockInfo = MOCK_DB[code] || { name: `A股代码 ${code}`, sector: '未知板块' };
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
          volume: Math.floor(Math.random() * 1000000) + 500000,
          ma5: parseFloat((currentPrice + (Math.random() * 10 - 5)).toFixed(2))
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
      next7Days.push({ day: `T+${i}`, price: parseFloat(predPrice.toFixed(2)) });
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

const LoadingSpinner = () => (
  <div className="flex justify-center items-center h-64">
      <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-red-500"></div>
  </div>
);

export default function Home() {
  const [query, setQuery] = useState('600519');
  const [stockData, setStockData] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleSearch = (e) => {
      if (e) e.preventDefault();
      setLoading(true);
      setTimeout(() => {
          setStockData(generateMarketData(query));
          setLoading(false);
      }, 800);
  };
  useEffect(() => { handleSearch(); }, []);
  const isPositive = stockData?.change >= 0;
  const colorClass = isPositive ? 'text-red-500' : 'text-green-500';
  const chartColor = isPositive ? '#ef4444' : '#22c55e';

  return (
      <div className="min-h-screen bg-slate-900 text-slate-100 pb-10 font-sans">
          <nav className="border-b border-slate-800 bg-slate-900/50 backdrop-blur sticky top-0 z-50">
              <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
                  <div className="flex items-center gap-2">
                      <div className="p-2 bg-red-600 rounded-lg"><BrainCircuit className="w-6 h-6 text-white" /></div>
                      <span className="font-bold text-xl tracking-tight">A股智投 AI</span>
                  </div>
                  <div className="hidden md:flex gap-6 text-sm font-medium text-slate-400">
                      <a href="#" className="text-white hover:text-red-400">市场概览</a>
                      <a href="#" className="hover:text-red-400">自选股</a>
                  </div>
              </div>
          </nav>
          <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-8">
              <div className="max-w-xl mx-auto mb-10">
                  <form onSubmit={handleSearch} className="relative group">
                      <input type="text" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="输入股票代码" className="w-full bg-slate-800 border-2 border-slate-700 rounded-full py-3 px-12 text-white placeholder-slate-500 focus:outline-none focus:border-red-500 transition-all shadow-lg"/>
                      <div className="absolute left-4 top-3.5 text-slate-500 group-focus-within:text-red-500"><Search className="w-5 h-5" /></div>
                      <button type="submit" className="absolute right-2 top-2 bg-red-600 hover:bg-red-700 text-white rounded-full px-4 py-1.5 text-sm font-medium">分析</button>
                  </form>
              </div>
              {loading ? <LoadingSpinner /> : stockData && (
                  <div className="space-y-6">
                      <div className="flex flex-col md:flex-row justify-between items-end gap-4 border-b border-slate-800 pb-6">
                          <div>
                              <div className="flex items-center gap-3 mb-1"><h1 className="text-3xl font-bold">{stockData.name}</h1><span className="bg-slate-800 text-slate-400 text-xs px-2 py-1 rounded">{stockData.code}</span></div>
                              <div className="flex items-baseline gap-4"><span className={`text-5xl font-bold ${colorClass}`}>¥{stockData.price.toFixed(2)}</span><div className={`flex flex-col text-sm font-semibold ${colorClass}`}><span>{stockData.change > 0 ? '+' : ''}{stockData.change}</span><span>{stockData.change > 0 ? '+' : ''}{stockData.changePercent}%</span></div></div>
                          </div>
                      </div>
                      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                          <div className="lg:col-span-2 bg-slate-800 rounded-2xl p-6 border border-slate-700">
                              <div className="h-[350px] w-full">
                                  <ResponsiveContainer width="100%" height="100%">
                                      <AreaChart data={stockData.history}>
                                          <defs><linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1"><stop offset="5%" stopColor={chartColor} stopOpacity={0.3}/><stop offset="95%" stopColor={chartColor} stopOpacity={0}/></linearGradient></defs>
                                          <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
                                          <XAxis dataKey="date" stroke="#64748b" tick={{fontSize: 12}} tickLine={false} axisLine={false} />
                                          <YAxis domain={['auto', 'auto']} stroke="#64748b" tick={{fontSize: 12}} tickLine={false} axisLine={false} />
                                          <Tooltip contentStyle={{backgroundColor: '#1e293b', borderColor: '#334155'}} />
                                          <Area type="monotone" dataKey="price" stroke={chartColor} strokeWidth={2} fillOpacity={1} fill="url(#colorPrice)" />
                                      </AreaChart>
                                  </ResponsiveContainer>
                              </div>
                          </div>
                          <div className="bg-slate-800 rounded-2xl p-6 border border-slate-700">
                              <h3 className="font-semibold text-lg mb-4 flex gap-2"><Target className="w-5 h-5"/> AI 预测</h3>
                              <div className="h-64">
                                  <ResponsiveContainer width="100%" height="100%">
                                      <BarChart data={stockData.forecast}>
                                          <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
                                          <XAxis dataKey="day" stroke="#64748b" tick={{fontSize: 12}} axisLine={false} />
                                          <Tooltip contentStyle={{backgroundColor: '#1e293b', borderColor: '#334155'}} />
                                          <Bar dataKey="price" fill="#6366f1" radius={[4, 4, 0, 0]} />
                                      </BarChart>
                                  </ResponsiveContainer>
                              </div>
                          </div>
                      </div>
                  </div>
              )}
          </main>
      </div>
  );
}
