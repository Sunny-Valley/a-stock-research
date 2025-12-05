#!/bin/bash

echo "🚀 开始自动部署 A-Share AI 项目..."

# 1. 创建必要的目录结构
echo "📂 创建目录结构..."
mkdir -p .devcontainer
mkdir -p .github/workflows
mkdir -p scripts
mkdir -p app

# 2. 创建 requirements.txt
echo "📄 创建 requirements.txt..."
cat <<EOF > requirements.txt
akshare
pandas
scikit-learn
psycopg2-binary
pyqlib
EOF

# 3. 创建 devcontainer.json
echo "⚙️ 创建 Codespaces 配置..."
cat <<EOF > .devcontainer/devcontainer.json
{
  "name": "A-Share AI Quant Dev",
  "image": "mcr.microsoft.com/devcontainers/python:3.9",
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/node:1": {} 
  },
  "postCreateCommand": "sudo apt-get update && sudo apt-get install -y cmake bison flex libopenmpi-dev && pip install -r requirements.txt && npm install",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "esbenp.prettier-vscode"
      ]
    }
  }
}
EOF

# 4. 创建 run_prediction.py
echo "🧠 创建 AI 核心脚本..."
cat <<EOF > scripts/run_prediction.py
import sys
import os
import pandas as pd
import akshare as ak
import psycopg2
from datetime import datetime, timedelta

try:
    import qlib
    from qlib.data import D
except ImportError:
    print("Warning: Qlib not installed completely. Using simplified AI logic.")

TARGET_STOCKS = ["600519", "300750", "000001", "601127"] 

def get_db_connection():
    dsn = os.environ.get("POSTGRES_URL")
    if not dsn:
        print("Error: POSTGRES_URL environment variable not found.")
        return None
    try:
        conn = psycopg2.connect(dsn)
        return conn
    except Exception as e:
        print(f"Database connection failed: {e}")
        return None

def init_db(conn):
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS ai_predictions (
            id SERIAL PRIMARY KEY,
            code VARCHAR(10) NOT NULL,
            predict_date DATE NOT NULL,
            current_price DECIMAL(10, 2),
            predicted_change DECIMAL(10, 2),
            confidence_score INTEGER,
            created_at TIMESTAMP DEFAULT NOW(),
            UNIQUE(code, predict_date)
        );
    """)
    conn.commit()
    cur.close()

def fetch_and_predict():
    print(f"Starting AI Analysis for {len(TARGET_STOCKS)} stocks...")
    results = []
    predict_date = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
    start_date = (datetime.now() - timedelta(days=100)).strftime("%Y%m%d")

    for code in TARGET_STOCKS:
        try:
            print(f"Fetching data for {code}...")
            df = ak.stock_zh_a_hist(symbol=code, period="daily", start_date=start_date, adjust="qfq")
            if df.empty: continue
                
            latest_row = df.iloc[-1]
            latest_close = float(latest_row['收盘'])
            
            df['MA5'] = df['收盘'].rolling(window=5).mean()
            df['MA20'] = df['收盘'].rolling(window=20).mean()
            ma5 = df['MA5'].iloc[-1]
            ma20 = df['MA20'].iloc[-1]
            
            score = 50
            if latest_close > ma20: score += 20
            else: score -= 10
            if latest_close > ma5: score += 15
            
            score = max(0, min(100, score))
            predicted_change = (score - 50) / 10.0
            
            results.append({
                "code": code,
                "price": latest_close,
                "change": round(predicted_change, 2),
                "score": int(score),
                "date": predict_date
            })
        except Exception as e:
            print(f"Error processing {code}: {e}")
            continue
    return results

def save_to_db(data):
    conn = get_db_connection()
    if not conn: return
    init_db(conn)
    cur = conn.cursor()
    print(f"Saving {len(data)} records...")
    for item in data:
        sql = """
            INSERT INTO ai_predictions (code, predict_date, current_price, predicted_change, confidence_score)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (code, predict_date) 
            DO UPDATE SET 
                current_price = EXCLUDED.current_price,
                predicted_change = EXCLUDED.predicted_change,
                confidence_score = EXCLUDED.confidence_score,
                created_at = NOW();
        """
        cur.execute(sql, (item['code'], item['date'], item['price'], item['change'], item['score']))
    conn.commit()
    cur.close()
    conn.close()

if __name__ == "__main__":
    data = fetch_and_predict()
    if data: save_to_db(data)
EOF

# 5. 创建 GitHub Action
echo "🤖 创建 GitHub Action Workflow..."
cat <<EOF > .github/workflows/daily_ai.yml
name: A-Share AI Daily Run
on:
  schedule:
    - cron: '0 10 * * 1-5'
  workflow_dispatch:
jobs:
  ai-inference:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
          cache: 'pip'
      - name: Install System Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y cmake bison flex libopenmpi-dev
      - name: Install Python Libraries
        run: |
          pip install --upgrade pip
          pip install akshare pandas scikit-learn psycopg2-binary
          pip install pyqlib || echo "Qlib install failed, using fallback mode"
      - name: Run AI Prediction Script
        env:
          POSTGRES_URL: \${{ secrets.POSTGRES_URL }}
        run: |
          python scripts/run_prediction.py
EOF

# 6. 创建 Next.js 首页 (覆盖 page.js)
echo "🌐 创建 Next.js 首页..."
cat <<EOF > app/page.js
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
                              <div className="flex items-baseline gap-4"><span className={\`text-5xl font-bold \${colorClass}\`}>¥{stockData.price.toFixed(2)}</span><div className={\`flex flex-col text-sm font-semibold \${colorClass}\`}><span>{stockData.change > 0 ? '+' : ''}{stockData.change}</span><span>{stockData.change > 0 ? '+' : ''}{stockData.changePercent}%</span></div></div>
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
EOF

echo "✅ 所有文件已生成完毕！请提交 (Commit) 代码。"