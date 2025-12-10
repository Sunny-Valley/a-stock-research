import os
import json
import time
import requests
import pandas as pd
import numpy as np
import psycopg2
from psycopg2.extras import execute_values

# 注入连接串
DB_URL = "postgres://c665bdb8d82cf3a3c3d3fe13754288561d9cd8e7240d3ca3f7339fd15439a7da:sk_K4bvSlbIuv2mH6m1iRbCX@db.prisma.io:5432/postgres?sslmode=require"

def get_db_conn():
    return psycopg2.connect(DB_URL)

# 获取关注列表
def get_watchlist():
    try:
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute("CREATE TABLE IF NOT EXISTS watchlist (code VARCHAR(10) PRIMARY KEY, name VARCHAR(50), added_at TIMESTAMP DEFAULT NOW());")
        conn.commit()
        cur.execute("SELECT code, name FROM watchlist")
        rows = cur.fetchall()
        conn.close()
        
        # 如果空，初始化默认
        if not rows:
            conn = get_db_conn()
            cur = conn.cursor()
            defaults = [('600519', '贵州茅台'), ('300750', '宁德时代'), ('000001', '平安银行')]
            for c, n in defaults:
                cur.execute("INSERT INTO watchlist (code, name) VALUES (%s, %s) ON CONFLICT DO NOTHING", (c, n))
            conn.commit()
            conn.close()
            return defaults
        return rows
    except Exception as e:
        print(f"Watchlist error: {e}")
        return []

# 获取真实行情 (200天)
def fetch_history(code):
    market = '1' if code.startswith('6') else '0'
    secid = f"{market}.{code}"
    url = f"https://push2his.eastmoney.com/api/qt/stock/kline/get?secid={secid}&fields1=f1&fields2=f51,f53,f54,f55,f56,f57&klt=101&fqt=1&end=20500101&lmt=200"
    try:
        res = requests.get(url, timeout=10).json()
        if not res['data'] or not res['data']['klines']: return None
        data = []
        for k in res['data']['klines']:
            d, c, o, h, l, v = k.split(',')
            data.append({'date': d, 'close': float(c), 'high': float(h), 'low': float(l), 'vol': float(v)})
        return pd.DataFrame(data)
    except: return None

# 计算指标
def calc_indicators(df):
    delta = df['close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(14).mean()
    rs = gain / loss
    df['rsi'] = 100 - (100 / (1 + rs))
    
    exp1 = df['close'].ewm(span=12, adjust=False).mean()
    exp2 = df['close'].ewm(span=26, adjust=False).mean()
    df['macd'] = exp1 - exp2
    df['signal'] = df['macd'].ewm(span=9, adjust=False).mean()
    
    df['ma20'] = df['close'].rolling(20).mean()
    df['std'] = df['close'].rolling(20).std()
    df['upper'] = df['ma20'] + (df['std'] * 2)
    df['lower'] = df['ma20'] - (df['std'] * 2)
    return df.fillna(method='bfill')

# 生成分析
def generate_analysis(code, name, df):
    last = df.iloc[-1]
    score = 60
    reasons = []
    
    # 简单的评分逻辑演示
    if last['rsi'] > 70: score -= 10; reasons.append("RSI超买")
    elif last['rsi'] < 30: score += 15; reasons.append("RSI超卖")
    
    if last['macd'] > last['signal']: score += 10; reasons.append("MACD金叉")
    else: score -= 10; reasons.append("MACD死叉")
    
    if last['close'] > last['ma20']: score += 5; reasons.append("站上20日线")
    
    # 预测算法 (动量+均值回归)
    forecast = []
    curr = last['close']
    vol = df['close'].pct_change().std() or 0.02
    for i in range(1, 8):
        drift = (score - 50)/1000
        shock = vol * np.random.normal(0, 1)
        curr = curr * (1 + drift + shock * 0.5)
        forecast.append({"day": f"T+{i}", "price": round(curr, 2)})
        
    analysis_text = f"【StockAI 离线量化报告】\n基于 {last['date']} 收盘数据。\n1. 评分：{score}。市场情绪：{'看多' if score>60 else '谨慎'}。\n2. 逻辑：{'; '.join(reasons)}。\n3. 区间：[{round(last['lower'],2)}, {round(last['upper'],2)}]"

    return {
        "score": score,
        "analysis": analysis_text,
        "forecast": forecast,
        "price": last['close'],
        "change": round(last['close'] - df.iloc[-2]['close'], 2),
        "changePercent": round((last['close'] - df.iloc[-2]['close'])/df.iloc[-2]['close']*100, 2),
        "high3m": df['high'].tail(60).max(),
        "low3m": df['low'].tail(60).min(),
        "history": df.tail(90).apply(lambda x: {"date": x['date'][5:], "price": x['close']}, axis=1).tolist()
    }

def run_job():
    print("🚀 Quant Engine Running...")
    try:
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute("CREATE TABLE IF NOT EXISTS ai_predictions_v2 (code VARCHAR(10) PRIMARY KEY, name VARCHAR(50), data JSONB, updated_at TIMESTAMP DEFAULT NOW());")
        conn.commit()
        
        watchlist = get_watchlist()
        print(f"📋 Processing {len(watchlist)} stocks...")
        
        for code, name in watchlist:
            print(f"-> {name}")
            df = fetch_history(code)
            if df is None: continue
            df = calc_indicators(df)
            res = generate_analysis(code, name, df)
            
            cur.execute("INSERT INTO ai_predictions_v2 (code, name, data, updated_at) VALUES (%s, %s, %s, NOW()) ON CONFLICT (code) DO UPDATE SET data = EXCLUDED.data, updated_at = NOW();", (code, name, json.dumps(res)))
            
        conn.commit()
        conn.close()
        print("✅ Done.")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    run_job()
