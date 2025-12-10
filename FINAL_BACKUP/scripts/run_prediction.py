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
