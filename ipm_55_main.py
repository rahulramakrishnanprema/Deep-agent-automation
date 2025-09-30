import sqlite3
import json
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from flask import Flask, render_template, jsonify, request
import yfinance as yf

app = Flask(__name__)

# Database setup
def init_db():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Create portfolios table
    c.execute('''CREATE TABLE IF NOT EXISTS portfolios
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  client_name TEXT NOT NULL,
                  total_value REAL,
                  created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
    # Create holdings table
    c.execute('''CREATE TABLE IF NOT EXISTS holdings
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  portfolio_id INTEGER,
                  stock_symbol TEXT NOT NULL,
                  quantity INTEGER,
                  purchase_price REAL,
                  purchase_date DATE,
                  sector TEXT,
                  FOREIGN KEY (portfolio_id) REFERENCES portfolios (id))''')
    
    # Create advisory_signals table
    c.execute('''CREATE TABLE IF NOT EXISTS advisory_signals
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  stock_symbol TEXT NOT NULL,
                  signal TEXT,
                  confidence_score REAL,
                  reasoning TEXT,
                  generated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
    conn.commit()
    conn.close()

# Generate dummy data
def generate_dummy_data():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Clear existing data
    c.execute("DELETE FROM portfolios")
    c.execute("DELETE FROM holdings")
    c.execute("DELETE FROM advisory_signals")
    
    # Insert dummy portfolios
    portfolios = [
        ('Rahul Sharma', 1250000),
        ('Priya Patel', 850000),
        ('Amit Kumar', 2100000)
    ]
    c.executemany("INSERT INTO portfolios (client_name, total_value) VALUES (?, ?)", portfolios)
    
    # Get portfolio IDs
    c.execute("SELECT id FROM portfolios")
    portfolio_ids = [row[0] for row in c.fetchall()]
    
    # Indian stock symbols with sectors
    indian_stocks = [
        ('RELIANCE', 'Energy'), ('INFY', 'IT'), ('HDFCBANK', 'Banking'),
        ('TCS', 'IT'), ('ICICIBANK', 'Banking'), ('SBIN', 'Banking'),
        ('BHARTIARTL', 'Telecom'), ('LT', 'Construction'), ('MARUTI', 'Automobile'),
        ('AXISBANK', 'Banking'), ('ITC', 'FMCG'), ('ONGC', 'Energy'),
        ('HINDUNILVR', 'FMCG'), ('BAJFINANCE', 'Financial Services'),
        ('WIPRO', 'IT'), ('HINDALCO', 'Metals'), ('TECHM', 'IT'),
        ('ADANIPORTS', 'Infrastructure'), ('TATAMOTORS', 'Automobile'),
        ('NTPC', 'Power')
    ]
    
    # Insert dummy holdings
    holdings = []
    for portfolio_id in portfolio_ids:
        num_holdings = np.random.randint(5, 12)
        selected_stocks = np.random.choice(len(indian_stocks), num_holdings, replace=False)
        
        for stock_idx in selected_stocks:
            symbol, sector = indian_stocks[stock_idx]
            quantity = np.random.randint(10, 101) * 10
            purchase_price = np.random.uniform(100, 5000)
            purchase_date = datetime.now() - timedelta(days=np.random.randint(1, 365))
            
            holdings.append((
                portfolio_id, symbol, quantity, purchase_price,
                purchase_date.strftime('%Y-%m-%d'), sector
            ))
    
    c.executemany('''INSERT INTO holdings 
                    (portfolio_id, stock_symbol, quantity, purchase_price, purchase_date, sector)
                    VALUES (?, ?, ?, ?, ?, ?)''', holdings)
    
    # Generate initial advisory signals
    generate_advisory_signals()
    
    conn.commit()
    conn.close()

# Advisory signal generation logic
def generate_advisory_signals():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Get unique stocks from holdings
    c.execute("SELECT DISTINCT stock_symbol FROM holdings")
    stocks = [row[0] for row in c.fetchall()]
    
    signals = []
    
    for symbol in stocks:
        try:
            # Get historical data using yfinance (for demonstration)
            stock_data = yf.Ticker(symbol + ".NS")
            hist = stock_data.history(period="1mo")
            
            if len(hist) > 0:
                # Simple technical indicators
                current_price = hist['Close'].iloc[-1]
                sma_20 = hist['Close'].rolling(window=20).mean().iloc[-1]
                rsi = calculate_rsi(hist['Close'])
                
                # Sector potential (dummy weights)
                sector_potential = {
                    'IT': 0.8, 'Banking': 0.6, 'Energy': 0.7, 'FMCG': 0.9,
                    'Automobile': 0.5, 'Telecom': 0.4, 'Construction': 0.6,
                    'Financial Services': 0.7, 'Metals': 0.5, 'Infrastructure': 0.8,
                    'Power': 0.7
                }
                
                # Get sector for this stock
                c.execute("SELECT sector FROM holdings WHERE stock_symbol = ? LIMIT 1", (symbol,))
                sector_row = c.fetchone()
                sector = sector_row[0] if sector_row else 'Unknown'
                
                # Market buzz (dummy sentiment)
                market_buzz = np.random.uniform(0.3, 0.9)
                
                # Generate signal based on factors
                signal, confidence, reasoning = generate_signal(
                    current_price, sma_20, rsi, 
                    sector_potential.get(sector, 0.5), 
                    market_buzz
                )
                
                signals.append((symbol, signal, confidence, reasoning))
                
        except Exception as e:
            print(f"Error processing {symbol}: {e}")
            continue
    
    # Insert signals
    c.executemany('''INSERT INTO advisory_signals 
                    (stock_symbol, signal, confidence_score, reasoning)
                    VALUES (?, ?, ?, ?)''', signals)
    
    conn.commit()
    conn.close()

def calculate_rsi(prices, period=14):
    if len(prices) < period + 1:
        return 50  # Neutral RSI if insufficient data
    
    delta = prices.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    return rsi.iloc[-1] if not pd.isna(rsi.iloc[-1]) else 50

def generate_signal(current_price, sma_20, rsi, sector_potential, market_buzz):
    # Weighted scoring system
    weights = {
        'technical': 0.4,
        'sector': 0.3,
        'sentiment': 0.3
    }
    
    # Technical score
    price_vs_sma = current_price / sma_20
    if price_vs_sma > 1.1:
        tech_score = 0.8  # Bullish
    elif price_vs_sma < 0.9:
        tech_score = 0.2  # Bearish
    else:
        tech_score = 0.5  # Neutral
    
    # RSI adjustment
    if rsi > 70:
        tech_score *= 0.7  # Overbought
    elif rsi < 30:
        tech_score *= 1.3  # Oversold
    
    # Combined score
    total_score = (tech_score * weights['technical'] +
                  sector_potential * weights['sector'] +
                  market_buzz * weights['sentiment'])
    
    # Determine signal
    if total_score > 0.7:
        signal = "BUY"
        confidence = min(total_score * 100, 95)
        reasoning = f"Strong fundamentals: technical score {tech_score:.2f}, sector potential {sector_potential:.2f}, market sentiment {market_buzz:.2f}"
    elif total_score < 0.4:
        signal = "SELL"
        confidence = min((1 - total_score) * 100, 95)
        reasoning = f"Weak performance: technical score {tech_score:.2f}, sector potential {sector_potential:.2f}, market sentiment {market_buzz:.2f}"
    else:
        signal = "HOLD"
        confidence = abs(total_score - 0.5) * 200
        reasoning = f"Neutral outlook: technical score {tech_score:.2f}, sector potential {sector_potential:.2f}, market sentiment {market_buzz:.2f}"
    
    return signal, round(confidence, 2), reasoning

# Flask routes
@app.route('/')
def dashboard():
    return render_template('dashboard.html')

@app.route('/api/portfolios')
def get_portfolios():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    c.execute('''SELECT p.id, p.client_name, p.total_value, p.created_date,
                 COUNT(h.id) as num_holdings
                 FROM portfolios p
                 LEFT JOIN holdings h ON p.id = h.portfolio_id
                 GROUP BY p.id''')
    
    portfolios = []
    for row in c.fetchall():
        portfolios.append({
            'id': row[0],
            'client_name': row[1],
            'total_value': row[2],
            'created_date': row[3],
            'num_holdings': row[4]
        })
    
    conn.close()
    return jsonify(portfolios)

@app.route('/api/portfolio/<int:portfolio_id>')
def get_portfolio_details(portfolio_id):
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Get portfolio basic info
    c.execute("SELECT * FROM portfolios WHERE id = ?", (portfolio_id,))
    portfolio = dict(zip([description[0] for description in c.description], c.fetchone()))
    
    # Get holdings
    c.execute('''SELECT h.*, a.signal, a.confidence_score, a.reasoning
                 FROM holdings h
                 LEFT JOIN advisory_signals a ON h.stock_symbol = a.stock_symbol
                 WHERE h.portfolio_id = ?''', (portfolio_id,))
    
    holdings = []
    for row in c.fetchall():
        holding = dict(zip([description[0] for description in c.description], row))
        holdings.append(holding)
    
    portfolio['holdings'] = holdings
    conn.close()
    return jsonify(portfolio)

@app.route('/api/advisory-signals')
def get_advisory_signals():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    c.execute('''SELECT stock_symbol, signal, confidence_score, reasoning, generated_date
                 FROM advisory_signals
                 ORDER BY confidence_score DESC''')
    
    signals = []
    for row in c.fetchall():
        signals.append({
            'stock_symbol': row[0],
            'signal': row[1],
            'confidence_score': row[2],
            'reasoning': row[3],
            'generated_date': row[4]
        })
    
    conn.close()
    return jsonify(signals)

@app.route('/api/portfolio-performance')
def get_portfolio_performance():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Get portfolio value trend (dummy data for demonstration)
    dates = [datetime.now() - timedelta(days=i) for i in range(30, 0, -1)]
    values = [1000000 + i * 5000 + np.random.randint(-20000, 20000) for i in range(30)]
    
    performance_data = {
        'dates': [date.strftime('%Y-%m-%d') for date in dates],
        'values': values
    }
    
    conn.close()
    return jsonify(performance_data)

@app.route('/api/refresh-signals', methods=['POST'])
def refresh_signals():
    try:
        generate_advisory_signals()
        return jsonify({'status': 'success', 'message': 'Advisory signals refreshed successfully'})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

if __name__ == '__main__':
    init_db()
    generate_dummy_data()
    app.run(debug=True, port=5000)