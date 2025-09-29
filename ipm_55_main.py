# ipm_55_main.py - Main Flask application for IPM portfolio management system

from flask import Flask, render_template, jsonify, request, session, redirect, url_for
import sqlite3
import json
from datetime import datetime, timedelta
import random
import math

app = Flask(__name__)
app.secret_key = 'ipm_55_secret_key_for_demo'
app.config['DATABASE'] = 'ipm_portfolio.db'

# Database initialization
def init_db():
    conn = sqlite3.connect(app.config['DATABASE'])
    cursor = conn.cursor()
    
    # Create tables
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'advisor',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS portfolios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_name TEXT NOT NULL,
            advisor_id INTEGER NOT NULL,
            total_value REAL NOT NULL,
            cash_balance REAL NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (advisor_id) REFERENCES users (id)
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            portfolio_id INTEGER NOT NULL,
            stock_symbol TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            avg_price REAL NOT NULL,
            sector TEXT NOT NULL,
            current_price REAL NOT NULL,
            FOREIGN KEY (portfolio_id) REFERENCES portfolios (id)
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS market_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stock_symbol TEXT NOT NULL,
            price REAL NOT NULL,
            volume INTEGER NOT NULL,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            sma_20 REAL,
            sma_50 REAL,
            rsi REAL,
            sector TEXT NOT NULL
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS advisory_signals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stock_symbol TEXT NOT NULL,
            signal TEXT NOT NULL,
            confidence REAL NOT NULL,
            reasoning TEXT NOT NULL,
            generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            sector TEXT NOT NULL
        )
    ''')
    
    # Insert dummy data
    insert_dummy_data(cursor)
    
    conn.commit()
    conn.close()

def insert_dummy_data(cursor):
    # Insert advisor user
    cursor.execute("INSERT OR IGNORE INTO users (username, password, role) VALUES (?, ?, ?)", 
                  ('advisor', 'password123', 'advisor'))
    
    # Insert market data for Indian stocks
    indian_stocks = [
        ('RELIANCE', 'Energy', 2500.0),
        ('TCS', 'IT', 3500.0),
        ('HDFCBANK', 'Financial', 1600.0),
        ('INFY', 'IT', 1400.0),
        ('ICICIBANK', 'Financial', 900.0),
        ('HINDUNILVR', 'FMCG', 2400.0),
        ('ITC', 'FMCG', 400.0),
        ('SBIN', 'Financial', 550.0),
        ('BHARTIARTL', 'Telecom', 800.0),
        ('AXISBANK', 'Financial', 950.0)
    ]
    
    for symbol, sector, base_price in indian_stocks:
        for i in range(100):
            price = base_price * (1 + random.uniform(-0.1, 0.1))
            volume = random.randint(10000, 100000)
            cursor.execute('''
                INSERT INTO market_data (stock_symbol, price, volume, sector, sma_20, sma_50, rsi)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (symbol, price, volume, sector, 
                 base_price * (1 + random.uniform(-0.05, 0.05)),
                 base_price * (1 + random.uniform(-0.08, 0.08)),
                 random.uniform(30, 70)))
    
    # Insert sample portfolios
    cursor.execute('''
        INSERT OR IGNORE INTO portfolios (client_name, advisor_id, total_value, cash_balance)
        VALUES (?, ?, ?, ?)
    ''', ('Rajesh Kumar', 1, 1500000, 250000))
    
    cursor.execute('''
        INSERT OR IGNORE INTO portfolios (client_name, advisor_id, total_value, cash_balance)
        VALUES (?, ?, ?, ?)
    ''', ('Priya Sharma', 1, 850000, 150000))
    
    # Insert sample holdings
    portfolio_holdings = [
        (1, 'RELIANCE', 100, 2450.0, 'Energy', 2500.0),
        (1, 'TCS', 50, 3400.0, 'IT', 3500.0),
        (1, 'HDFCBANK', 75, 1550.0, 'Financial', 1600.0),
        (2, 'INFY', 60, 1350.0, 'IT', 1400.0),
        (2, 'ICICIBANK', 100, 850.0, 'Financial', 900.0)
    ]
    
    for holding in portfolio_holdings:
        cursor.execute('''
            INSERT OR IGNORE INTO holdings (portfolio_id, stock_symbol, quantity, avg_price, sector, current_price)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', holding)
    
    # Generate advisory signals
    generate_advisory_signals(cursor)

def generate_advisory_signals(cursor):
    signals = ['BUY', 'HOLD', 'SELL']
    reasoning_templates = {
        'BUY': ['Strong fundamentals', 'Oversold condition', 'Sector growth potential'],
        'HOLD': ['Stable performance', 'Market uncertainty', 'Waiting for breakout'],
        'SELL': ['Overbought condition', 'Sector headwinds', 'Technical breakdown']
    }
    
    stocks = ['RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK', 'HINDUNILVR', 'ITC', 'SBIN', 'BHARTIARTL', 'AXISBANK']
    sectors = ['Energy', 'IT', 'Financial', 'FMCG', 'Telecom']
    
    for stock in stocks:
        signal = random.choice(signals)
        confidence = random.uniform(0.6, 0.95)
        reasoning = random.choice(reasoning_templates[signal])
        sector = random.choice(sectors)
        
        cursor.execute('''
            INSERT INTO advisory_signals (stock_symbol, signal, confidence, reasoning, sector)
            VALUES (?, ?, ?, ?, ?)
        ''', (stock, signal, confidence, reasoning, sector))

# Database connection helper
def get_db():
    conn = sqlite3.connect(app.config['DATABASE'])
    conn.row_factory = sqlite3.Row
    return conn

# Authentication middleware
def login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# Technical indicators calculation
def calculate_sma(symbol, period=20):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('''
        SELECT price FROM market_data 
        WHERE stock_symbol = ? 
        ORDER BY timestamp DESC 
        LIMIT ?
    ''', (symbol, period))
    
    prices = [row['price'] for row in cursor.fetchall()]
    if len(prices) < period:
        return None
    return sum(prices) / len(prices)

def calculate_rsi(symbol, period=14):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('''
        SELECT price FROM market_data 
        WHERE stock_symbol = ? 
        ORDER BY timestamp DESC 
        LIMIT ?
    ''', (symbol, period + 1))
    
    prices = [row['price'] for row in cursor.fetchall()]
    if len(prices) < period + 1:
        return None
    
    gains = []
    losses = []
    
    for i in range(1, len(prices)):
        change = prices[i] - prices[i-1]
        if change > 0:
            gains.append(change)
            losses.append(0)
        else:
            gains.append(0)
            losses.append(abs(change))
    
    avg_gain = sum(gains) / period
    avg_loss = sum(losses) / period
    
    if avg_loss == 0:
        return 100
    
    rs = avg_gain / avg_loss
    return 100 - (100 / (1 + rs))

# Sector analysis
def analyze_sector_potential(sector):
    conn = get_db()
    cursor = conn.cursor()
    
    # Get recent performance data for the sector
    cursor.execute('''
        SELECT price, timestamp FROM market_data 
        WHERE sector = ? 
        ORDER BY timestamp DESC 
        LIMIT 50
    ''', (sector,))
    
    prices = [row['price'] for row in cursor.fetchall()]
    if len(prices) < 20:
        return 0.5  # Neutral score
    
    # Calculate momentum
    recent_change = (prices[0] - prices[19]) / prices[19]
    volatility = math.sqrt(sum((prices[i] - prices[i-1])**2 for i in range(1, 20)) / 19)
    
    # Simple scoring based on momentum and volatility
    score = 0.5 + recent_change * 2 - volatility * 0.5
    return max(0.1, min(0.9, score))  # Clamp between 0.1 and 0.9

# Routes
@app.route('/')
@login_required
def index():
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM users WHERE username = ? AND password = ?', 
                      (username, password))
        user = cursor.fetchone()
        
        if user:
            session['user_id'] = user['id']
            session['username'] = user['username']
            session['role'] = user['role']
            return redirect(url_for('dashboard'))
        else:
            return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    return render_template('dashboard.html')

# API endpoints
@app.route('/api/portfolios')
@login_required
def api_portfolios():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('''
        SELECT p.*, u.username as advisor_name 
        FROM portfolios p 
        JOIN users u ON p.advisor_id = u.id 
        WHERE p.advisor_id = ?
    ''', (session['user_id'],))
    
    portfolios = [dict(row) for row in cursor.fetchall()]
    return jsonify(portfolios)

@app.route('/api/portfolio/<int:portfolio_id>')
@login_required
def api_portfolio_detail(portfolio_id):
    conn = get_db()
    cursor = conn.cursor()
    
    # Get portfolio details
    cursor.execute('SELECT * FROM portfolios WHERE id = ? AND advisor_id = ?', 
                  (portfolio_id, session['user_id']))
    portfolio = dict(cursor.fetchone())
    
    # Get holdings
    cursor.execute('SELECT * FROM holdings WHERE portfolio_id = ?', (portfolio_id,))
    holdings = [dict(row) for row in cursor.fetchall()]
    
    portfolio['holdings'] = holdings
    return jsonify(portfolio)

@app.route('/api/advisory-signals')
@login_required
def api_advisory_signals():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM advisory_signals ORDER BY generated_at DESC LIMIT 20')
    
    signals = [dict(row) for row in cursor.fetchall()]
    return jsonify(signals)

@app.route('/api/technical-indicators/<symbol>')
@login_required
def api_technical_indicators(symbol):
    sma_20 = calculate_sma(symbol, 20)
    sma_50 = calculate_sma(symbol, 50)
    rsi = calculate_rsi(symbol)
    
    return jsonify({
        'symbol': symbol,
        'sma_20': sma_20,
        'sma_50': sma_50,
        'rsi': rsi
    })

@app.route('/api/sector-analysis')
@login_required
def api_sector_analysis():
    sectors = ['Energy', 'IT', 'Financial', 'FMCG', 'Telecom']
    analysis = []
    
    for sector in sectors:
        score = analyze_sector_potential(sector)
        analysis.append({
            'sector': sector,
            'potential_score': score,
            'recommendation': 'BUY' if score > 0.7 else 'HOLD' if score > 0.4 else 'SELL'
        })
    
    return jsonify(analysis)

@app.route('/api/market-buzz')
@login_required
def api_market_buzz():
    # Simulated market buzz data for Indian markets
    buzz_items = [
        {
            'source': 'Economic Times',
            'headline': 'IT Sector Shows Strong Q3 Results',
            'sentiment': 'positive',
            'impact_score': 0.8
        },
        {
            'source': 'Business Standard',
            'headline': 'RBI Maintains Hawkish Stance on Rates',
            'sentiment': 'negative',
            'impact_score': 0.6
        },
        {
            'source': 'Moneycontrol',
            'headline': 'Energy Stocks Rally on Policy Reforms',
            'sentiment': 'positive',
            'impact_score': 0.7
        }
    ]
    
    return jsonify(buzz_items)

@app.route('/api/portfolio-performance')
@login_required
def api_portfolio_performance():
    conn = get_db()
    cursor = conn.cursor()
    
    # Get portfolio performance data
    cursor.execute('''
        SELECT p.id, p.client_name, p.total_value, p.cash_balance,
               SUM(h.quantity * h.current_price) as equity_value,
               (p.total_value - p.cash_balance) as invested_value
        FROM portfolios p
        LEFT JOIN holdings h ON p.id = h.portfolio_id
        WHERE p.advisor_id = ?
        GROUP BY p.id
    ''', (session['user_id'],))
    
    performance_data = [dict(row) for row in cursor.fetchall()]
    return jsonify(performance_data)

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    init_db()
    app.run(debug=True, port=5000)