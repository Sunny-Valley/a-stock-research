import os
import akshare as ak
import psycopg2
import pandas as pd
from datetime import datetime, timedelta

# 连接数据库
def get_db_connection():
    dsn = os.environ.get("POSTGRES_URL")
    if not dsn: return None
    try:
        return psycopg2.connect(dsn)
    except:
        return None

def fetch_watchlist(conn):
    """从数据库获取用户关注的股票"""
    cur = conn.cursor()
    # 确保表存在
    cur.execute("""
        CREATE TABLE IF NOT EXISTS watchlist (
            code VARCHAR(10) PRIMARY KEY,
            name VARCHAR(50),
            added_at TIMESTAMP DEFAULT NOW()
        );
    """)
    conn.commit()
    
    cur.execute("SELECT code, name FROM watchlist")
    rows = cur.fetchall()
    
    # 如果数据库为空，返回默认列表
    if not rows:
        defaults = [("600519", "贵州茅台"), ("300750", "宁德时代"), ("000001", "平安银行")]
        for code, name in defaults:
            cur.execute("INSERT INTO watchlist (code, name) VALUES (%s, %s) ON CONFLICT DO NOTHING", (code, name))
        conn.commit()
        return defaults
        
    return rows

def fetch_and_predict():
    conn = get_db_connection()
    if not conn:
        print("No DB Connection")
        return

    watchlist = fetch_watchlist(conn)
    print(f"Analyzing {len(watchlist)} stocks from Watchlist...")
    
    cur = conn.cursor()
    # 确保预测表存在
    cur.execute("""
        CREATE TABLE IF NOT EXISTS ai_predictions (
            id SERIAL PRIMARY KEY,
            code VARCHAR(10) NOT NULL,
            predict_date DATE NOT NULL,
            current_price DECIMAL(10, 2),
            predicted_change DECIMAL(10, 2),
            confidence_score INTEGER,
            analysis_text TEXT,
            created_at TIMESTAMP DEFAULT NOW(),
            UNIQUE(code, predict_date)
        );
    """)
    conn.commit()

    predict_date = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
    start_date = (datetime.now() - timedelta(days=200)).strftime("%Y%m%d")

    for code, name in watchlist:
        try:
            print(f"Processing {name} ({code})...")
            # 获取数据
            df = ak.stock_zh_a_hist(symbol=code, period="daily", start_date=start_date, adjust="qfq")
            if df.empty: continue
            
            # --- 简单的 AI 逻辑模拟 (实际可替换为 Qlib) ---
            # 1. 计算均线
            df['MA5'] = df['收盘'].rolling(5).mean()
            df['MA20'] = df['收盘'].rolling(20).mean()
            
            latest = df.iloc[-1]
            price = float(latest['收盘'])
            ma5 = float(latest['MA5'])
            ma20 = float(latest['MA20'])
            
            # 2. 评分系统
            score = 50
            analysis = []
            
            if price > ma20:
                score += 20
                analysis.append("股价站上20日线，趋势向好")
            else:
                score -= 10
                analysis.append("股价受制于20日线，趋势偏弱")
                
            if price > ma5:
                score += 10
                analysis.append("短线动能强劲")
            
            # 3. 量能分析
            vol_mean = df['成交量'].tail(5).mean()
            if latest['成交量'] > vol_mean * 1.5:
                score += 10
                analysis.append("近期明显放量，资金关注度高")
            
            score = max(0, min(100, score))
            change_pred = (score - 50) / 10.0
            
            analysis_str = "。".join(analysis)
            
            # 存入数据库
            cur.execute("""
                INSERT INTO ai_predictions (code, predict_date, current_price, predicted_change, confidence_score, analysis_text)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (code, predict_date) 
                DO UPDATE SET 
                    current_price = EXCLUDED.current_price,
                    predicted_change = EXCLUDED.predicted_change,
                    confidence_score = EXCLUDED.confidence_score,
                    analysis_text = EXCLUDED.analysis_text,
                    created_at = NOW();
            """, (code, predict_date, price, change_pred, int(score), analysis_str))
            
        except Exception as e:
            print(f"Error {code}: {e}")
            
    conn.commit()
    cur.close()
    conn.close()

if __name__ == "__main__":
    fetch_and_predict()
