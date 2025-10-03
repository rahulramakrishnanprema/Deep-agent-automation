# ipm_55_main.py
"""
Main application file for IPM-55 MVP web application.
This file serves as the entry point for the Flask backend application.
"""

from flask import Flask, jsonify, request, session, redirect, url_for, render_template
from flask_cors import CORS
import sqlite3
import json
import os
from datetime import datetime, timedelta
import random
import numpy as np
from functools import wraps

# Initialize Flask application
app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY') or 'dev-secret-key-ipm55'
app.config['DATABASE'] = 'ipm55_portfolio.db'
CORS(app, supports_credentials=True)

# Database initialization
def init_db():
    """Initialize the SQLite database with required tables"""
    conn = sqlite3.connect(app.config['DATABASE'])
    cursor = conn.cursor()
    
    # Users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'client',
            email TEXT UNIQUE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Portfolios table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS portfolios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # Portfolio holdings table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS portfolio_holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            portfolio_id INTEGER NOT NULL,
            stock_symbol TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            purchase_price REAL NOT NULL,
            purchase_date DATE NOT NULL,
            sector TEXT,
            FOREIGN KEY (portfolio_id) REFERENCES portfolios (id)
        )
    ''')
    
    # Market data table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS market_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stock_symbol TEXT NOT NULL,
            date DATE NOT NULL,
            open_price REAL,
            high_price REAL,
            low_price REAL,
            close_price REAL,
            volume INTEGER,
            sector TEXT,
            company_name TEXT,
            UNIQUE(stock_symbol, date)
        )
    ''')
    
    # Advisory signals table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS advisory_signals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stock_symbol TEXT NOT NULL,
            signal_type TEXT NOT NULL,
            confidence_score REAL,
            generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            reasoning TEXT,
            technical_indicators TEXT,
            sector_analysis TEXT,
            sentiment_score REAL
        )
    ''')
    
    conn.commit()
    conn.close()

def get_db_connection():
    """Get a database connection"""
    conn = sqlite3.connect(app.config['DATABASE'])
    conn.row_factory = sqlite3.Row
    return conn

# Authentication decorator
def advisor_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session or session.get('role') != 'advisor':
            return jsonify({'error': 'Advisor access required'}), 403
        return f(*args, **kwargs)
    return decorated_function

# Dummy data generation
def generate_dummy_market_data():
    """Generate realistic Indian equity market dummy data"""
    indian_stocks = [
        {'symbol': 'RELIANCE', 'name': 'Reliance Industries Ltd.', 'sector': 'Energy'},
        {'symbol': 'TCS', 'name': 'Tata Consultancy Services Ltd.', 'sector': 'IT'},
        {'symbol': 'HDFCBANK', 'name': 'HDFC Bank Ltd.', 'sector': 'Banking'},
        {'symbol': 'INFY', 'name': 'Infosys Ltd.', 'sector': 'IT'},
        {'symbol': 'ICICIBANK', 'name': 'ICICI Bank Ltd.', 'sector': 'Banking'},
        {'symbol': 'HINDUNILVR', 'name': 'Hindustan Unilever Ltd.', 'sector': 'FMCG'},
        {'symbol': 'SBIN', 'name': 'State Bank of India', 'sector': 'Banking'},
        {'symbol': 'BHARTIARTL', 'name': 'Bharti Airtel Ltd.', 'sector': 'Telecom'},
        {'symbol': 'ITC', 'name': 'ITC Ltd.', 'sector': 'FMCG'},
        {'symbol': 'BAJFINANCE', 'name': 'Bajaj Finance Ltd.', 'sector': 'Financial Services'}
    ]
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Generate data for last 90 days
    end_date = datetime.now()
    start_date = end_date - timedelta(days=90)
    
    for stock in indian_stocks:
        current_price = random.uniform(1000, 5000)
        
        current_date = start_date
        while current_date <= end_date:
            # Simulate price movement
            price_change = random.uniform(-0.05, 0.05)
            current_price *= (1 + price_change)
            
            volume = random.randint(100000, 1000000)
            
            cursor.execute('''
                INSERT OR IGNORE INTO market_data 
                (stock_symbol, date, open_price, high_price, low_price, close_price, volume, sector, company_name)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                stock['symbol'],
                current_date.date(),
                current_price * (1 - random.uniform(0.01, 0.03)),
                current_price * (1 + random.uniform(0.01, 0.03)),
                current_price * (1 - random.uniform(0.02, 0.05)),
                current_price,
                volume,
                stock['sector'],
                stock['name']
            ))
            
            current_date += timedelta(days=1)
    
    conn.commit()
    conn.close()

# Technical indicators analysis
def calculate_technical_indicators(stock_symbol, days=14):
    """Calculate technical indicators for a given stock"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT date, close_price FROM market_data 
        WHERE stock_symbol = ? 
        ORDER BY date DESC LIMIT ?
    ''', (stock_symbol, days * 2))
    
    data = cursor.fetchall()
    if not data:
        return None
    
    closes = [row['close_price'] for row in data]
    closes.reverse()
    
    # Simple Moving Average
    sma = sum(closes[-days:]) / days
    
    # RSI Calculation
    gains = []
    losses = []
    for i in range(1, len(closes)):
        change = closes[i] - closes[i-1]
        if change > 0:
            gains.append(change)
            losses.append(0)
        else:
            gains.append(0)
            losses.append(abs(change))
    
    avg_gain = sum(gains[-days:]) / days if gains else 0
    avg_loss = sum(losses[-days:]) / days if losses else 0
    
    if avg_loss == 0:
        rsi = 100
    else:
        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))
    
    # MACD (simplified)
    ema_12 = calculate_ema(closes, 12)
    ema_26 = calculate_ema(closes, 26)
    macd = ema_12 - ema_26 if ema_12 and ema_26 else 0
    
    conn.close()
    
    return {
        'sma': sma,
        'rsi': rsi,
        'macd': macd,
        'current_price': closes[-1],
        'signal': 'Buy' if rsi < 30 else 'Sell' if rsi > 70 else 'Hold'
    }

def calculate_ema(prices, period):
    """Calculate Exponential Moving Average"""
    if len(prices) < period:
        return None
    
    multiplier = 2 / (period + 1)
    ema = prices[0]
    
    for price in prices[1:]:
        ema = (price - ema) * multiplier + ema
    
    return ema

# Sector analysis
def analyze_sector_potential(sector):
    """Analyze sector potential based on historical performance"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT stock_symbol, close_price, date 
        FROM market_data 
        WHERE sector = ? 
        ORDER BY date DESC 
        LIMIT 100
    ''', (sector,))
    
    data = cursor.fetchall()
    if not data:
        return {'potential': 'Neutral', 'score': 0.5}
    
    # Simple sector momentum analysis
    recent_prices = {}
    for row in data:
        if row['stock_symbol'] not in recent_prices:
            recent_prices[row['stock_symbol']] = row['close_price']
    
    # Calculate average performance
    performance_scores = []
    for symbol, current_price in recent_prices.items():
        cursor.execute('''
            SELECT close_price FROM market_data 
            WHERE stock_symbol = ? 
            ORDER BY date DESC LIMIT 30, 1
        ''', (symbol,))
        
        old_data = cursor.fetchone()
        if old_data:
            old_price = old_data['close_price']
            performance = (current_price - old_price) / old_price
            performance_scores.append(performance)
    
    avg_performance = sum(performance_scores) / len(performance_scores) if performance_scores else 0
    
    if avg_performance > 0.05:
        potential = 'High'
        score = 0.8
    elif avg_performance > 0:
        potential = 'Moderate'
        score = 0.6
    elif avg_performance > -0.05:
        potential = 'Low'
        score = 0.4
    else:
        potential = 'Very Low'
        score = 0.2
    
    conn.close()
    
    return {'potential': potential, 'score': score, 'avg_performance': avg_performance}

# Market buzz integration (simulated)
def get_market_sentiment(stock_symbol):
    """Get simulated market sentiment for a stock"""
    # In a real implementation, this would integrate with news APIs, social media, etc.
    sentiments = ['Positive', 'Neutral', 'Negative']
    weights = [0.4, 0.3, 0.3]  # Weighted random choice
    
    sentiment = random.choices(sentiments, weights=weights, k=1)[0]
    score = random.uniform(0.3, 0.9) if sentiment == 'Positive' else random.uniform(0.1, 0.7)
    
    return {'sentiment': sentiment, 'score': score}

# Advisory signal generation
def generate_advisory_signals():
    """Generate advisory signals combining technical, sector, and sentiment analysis"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute('SELECT DISTINCT stock_symbol FROM market_data')
    stocks = cursor.fetchall()
    
    for stock_row in stocks:
        stock_symbol = stock_row['stock_symbol']
        
        # Technical analysis
        technicals = calculate_technical_indicators(stock_symbol)
        if not technicals:
            continue
        
        # Sector analysis
        cursor.execute('SELECT DISTINCT sector FROM market_data WHERE stock_symbol = ?', (stock_symbol,))
        sector_row = cursor.fetchone()
        sector = sector_row['sector'] if sector_row else 'Unknown'
        sector_analysis = analyze_sector_potential(sector)
        
        # Sentiment analysis
        sentiment_analysis = get_market_sentiment(stock_symbol)
        
        # Combine signals
        technical_weight = 0.4
        sector_weight = 0.3
        sentiment_weight = 0.3
        
        technical_score = 0.8 if technicals['signal'] == 'Buy' else 0.5 if technicals['signal'] == 'Hold' else 0.2
        combined_score = (
            technical_score * technical_weight +
            sector_analysis['score'] * sector_weight +
            sentiment_analysis['score'] * sentiment_weight
        )
        
        if combined_score >= 0.7:
            final_signal = 'Buy'
        elif combined_score >= 0.4:
            final_signal = 'Hold'
        else:
            final_signal = 'Sell'
        
        # Store signal
        cursor.execute('''
            INSERT INTO advisory_signals 
            (stock_symbol, signal_type, confidence_score, reasoning, technical_indicators, sector_analysis, sentiment_score)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            stock_symbol,
            final_signal,
            combined_score,
            f'Technical: {technicals["signal"]}, Sector: {sector_analysis["potential"]}, Sentiment: {sentiment_analysis["sentiment"]}',
            json.dumps(technicals),
            json.dumps(sector_analysis),
            sentiment_analysis['score']
        ))
    
    conn.commit()
    conn.close()

# API Routes
@app.route('/api/login', methods=['POST'])
def login():
    """User login endpoint"""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')  # In production, use proper password hashing
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute('SELECT * FROM users WHERE username = ? AND password_hash = ?', 
                  (username, password))  # Simplified for demo
    
    user = cursor.fetchone()
    conn.close()
    
    if user:
        session['user_id'] = user['id']
        session['username'] = user['username']
        session['role'] = user['role']
        return jsonify({'message': 'Login successful', 'role': user['role']})
    
    return jsonify({'error': 'Invalid credentials'}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    """User logout endpoint"""
    session.clear()
    return jsonify({'message': 'Logout successful'})

@app.route('/api/portfolios', methods=['GET'])
@advisor_required
def get_portfolios():
    """Get all portfolios (advisor only)"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT p.*, u.username 
        FROM portfolios p 
        JOIN users u ON p.user_id = u.id
    ''')
    
    portfolios = cursor.fetchall()
    conn.close()
    
    return jsonify([dict(portfolio) for portfolio in portfolios])

@app.route('/api/portfolio/<int:portfolio_id>', methods=['GET'])
@advisor_required
def get_portfolio_details(portfolio_id):
    """Get specific portfolio details with holdings"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute('SELECT * FROM portfolios WHERE id = ?', (portfolio_id,))
    portfolio = cursor.fetchone()
    
    if not portfolio:
        return jsonify({'error': 'Portfolio not found'}), 404
    
    cursor.execute('''
        SELECT ph.*, md.sector 
        FROM portfolio_holdings ph 
        LEFT JOIN market_data md ON ph.stock_symbol = md.stock_symbol 
        WHERE ph.portfolio_id = ? 
        GROUP BY ph.id
    ''', (portfolio_id,))
    
    holdings = cursor.fetchall()
    conn.close()
    
    return jsonify({
        'portfolio': dict(portfolio),
        'holdings': [dict(holding) for holding in holdings]
    })

@app.route('/api/advisory/signals', methods=['GET'])
@advisor_required
def get_advisory_signals():
    """Get latest advisory signals"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT * FROM advisory_signals 
        ORDER BY generated_at DESC 
        LIMIT 50
    ''')
    
    signals = cursor.fetchall()
    conn.close()
    
    return jsonify([dict(signal) for signal in signals])

@app.route('/api/market/data', methods=['GET'])
def get_market_data():
    """Get market data for visualization"""
    symbol = request.args.get('symbol')
    days = int(request.args.get('days', 30))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    if symbol:
        cursor.execute('''
            SELECT date, close_price FROM market_data 
            WHERE stock_symbol = ? 
            ORDER BY date DESC LIMIT ?
        ''', (symbol, days))
    else:
        cursor.execute('''
            SELECT stock_symbol, date, close_price FROM market_data 
            ORDER BY date DESC LIMIT ?
        ''', (days * 10,))  # Limit for demo
    
    data = cursor.fetchall()
    conn.close()
    
    return jsonify([dict(row) for row in data])

@app.route('/api/sector/analysis', methods=['GET'])
@advisor_required
def get_sector_analysis():
    """Get sector analysis data"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute('SELECT DISTINCT sector FROM market_data WHERE sector IS NOT NULL')
    sectors = [row['sector'] for row in cursor.fetchall()]
    
    analysis = {}
    for sector in sectors:
        analysis[sector] = analyze_sector_potential(sector)
    
    conn.close()
    
    return jsonify(analysis)

# Frontend routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/advisor')
@advisor_required
def advisor_dashboard():
    return render_template('advisor_dashboard.html')

@app.route('/client')
def client_portfolio():
    return render_template('client_portfolio.html')

# Initialize application
@app.before_first_request
def initialize_app():
    init_db()
    generate_dummy