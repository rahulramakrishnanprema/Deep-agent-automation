import os
import json
import sqlite3
from datetime import datetime, timedelta
from flask import Flask, render_template, jsonify, request, session, redirect, url_for
from flask_cors import CORS
import pandas as pd
import numpy as np
from werkzeug.security import generate_password_hash, check_password_hash
import yfinance as yf
from ta import add_all_ta_features
from ta.momentum import RSIIndicator
from ta.trend import MACD
from ta.volatility import BollingerBands

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY') or 'dev-secret-key-mvp'
app.config['DATABASE'] = 'portfolio_management.db'
CORS(app)

# Database initialization
def init_db():
    conn = sqlite3.connect(app.config['DATABASE'])
    cursor = conn.cursor()
    
    # Users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'advisor',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Clients table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            phone TEXT,
            risk_profile TEXT DEFAULT 'Moderate',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Portfolios table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS portfolios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL,
            advisor_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            total_value REAL DEFAULT 0,
            cash_balance REAL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (client_id) REFERENCES clients (id),
            FOREIGN KEY (advisor_id) REFERENCES users (id)
        )
    ''')
    
    # Holdings table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            portfolio_id INTEGER NOT NULL,
            symbol TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            average_price REAL NOT NULL,
            current_price REAL,
            sector TEXT,
            exchange TEXT DEFAULT 'NSE',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (portfolio_id) REFERENCES portfolios (id)
        )
    ''')
    
    # Transactions table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            portfolio_id INTEGER NOT NULL,
            symbol TEXT NOT NULL,
            transaction_type TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            price REAL NOT NULL,
            total_amount REAL NOT NULL,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (portfolio_id) REFERENCES portfolios (id)
        )
    ''')
    
    # Advisory signals table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS advisory_signals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT NOT NULL,
            signal_type TEXT NOT NULL,
            confidence_score REAL,
            reasoning TEXT,
            generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            valid_until TIMESTAMP
        )
    ''')
    
    conn.commit()
    conn.close()

def get_db_connection():
    conn = sqlite3.connect(app.config['DATABASE'])
    conn.row_factory = sqlite3.Row
    return conn

# Authentication and authorization decorators
def login_required(f):
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({'error': 'Authentication required'}), 401
        return f(*args, **kwargs)
    decorated_function.__name__ = f.__name__
    return decorated_function

def advisor_required(f):
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({'error': 'Authentication required'}), 401
        
        conn = get_db_connection()
        user = conn.execute('SELECT role FROM users WHERE id = ?', (session['user_id'],)).fetchone()
        conn.close()
        
        if user and user['role'] == 'advisor':
            return f(*args, **kwargs)
        else:
            return jsonify({'error': 'Advisor access required'}), 403
    decorated_function.__name__ = f.__name__
    return decorated_function

# Dummy data generation
def generate_dummy_data():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Create demo advisor user
    try:
        cursor.execute(
            'INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)',
            ('demo_advisor', generate_password_hash('password123'), 'advisor')
        )
        advisor_id = cursor.lastrowid
    except sqlite3.IntegrityError:
        cursor.execute('SELECT id FROM users WHERE username = ?', ('demo_advisor',))
        advisor_id = cursor.fetchone()['id']
    
    # Indian equity symbols
    indian_stocks = [
        'RELIANCE.NS', 'TCS.NS', 'HDFCBANK.NS', 'INFY.NS', 'ICICIBANK.NS',
        'HINDUNILVR.NS', 'SBIN.NS', 'BHARTIARTL.NS', 'ITC.NS', 'KOTAKBANK.NS',
        'AXISBANK.NS', 'LT.NS', 'HCLTECH.NS', 'BAJFINANCE.NS', 'ASIANPAINT.NS'
    ]
    
    sectors = {
        'RELIANCE.NS': 'Energy', 'TCS.NS': 'IT', 'HDFCBANK.NS': 'Banking',
        'INFY.NS': 'IT', 'ICICIBANK.NS': 'Banking', 'HINDUNILVR.NS': 'FMCG',
        'SBIN.NS': 'Banking', 'BHARTIARTL.NS': 'Telecom', 'ITC.NS': 'FMCG',
        'KOTAKBANK.NS': 'Banking', 'AXISBANK.NS': 'Banking', 'LT.NS': 'Construction',
        'HCLTECH.NS': 'IT', 'BAJFINANCE.NS': 'Financial Services', 'ASIANPAINT.NS': 'Chemicals'
    }
    
    # Create demo clients
    clients = [
        ('Rahul Sharma', 'rahul.sharma@email.com', '9876543210', 'Aggressive'),
        ('Priya Patel', 'priya.patel@email.com', '8765432109', 'Moderate'),
        ('Amit Kumar', 'amit.kumar@email.com', '7654321098', 'Conservative')
    ]
    
    for client in clients:
        try:
            cursor.execute(
                'INSERT INTO clients (name, email, phone, risk_profile) VALUES (?, ?, ?, ?)',
                client
            )
            client_id = cursor.lastrowid
            
            # Create portfolio for each client
            cursor.execute(
                'INSERT INTO portfolios (client_id, advisor_id, name, total_value, cash_balance) VALUES (?, ?, ?, ?, ?)',
                (client_id, advisor_id, f'{client[0]} Portfolio', 1000000, 200000)
            )
            portfolio_id = cursor.lastrowid
            
            # Create holdings for each portfolio
            for symbol in np.random.choice(indian_stocks, 8, replace=False):
                quantity = np.random.randint(10, 100)
                avg_price = np.random.uniform(1000, 5000)
                current_price = avg_price * np.random.uniform(0.8, 1.2)
                
                cursor.execute(
                    'INSERT INTO holdings (portfolio_id, symbol, quantity, average_price, current_price, sector, exchange) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    (portfolio_id, symbol, quantity, avg_price, current_price, sectors.get(symbol, 'Unknown'), 'NSE')
                )
                
                # Create some transactions
                for _ in range(3):
                    transaction_type = np.random.choice(['BUY', 'SELL'])
                    price = np.random.uniform(800, 6000)
                    qty = np.random.randint(5, 30)
                    
                    cursor.execute(
                        'INSERT INTO transactions (portfolio_id, symbol, transaction_type, quantity, price, total_amount) VALUES (?, ?, ?, ?, ?, ?)',
                        (portfolio_id, symbol, transaction_type, qty, price, qty * price)
                    )
        
        except sqlite3.IntegrityError:
            continue
    
    # Generate advisory signals
    for symbol in indian_stocks:
        signal_type = np.random.choice(['BUY', 'SELL', 'HOLD'])
        confidence = np.random.uniform(0.6, 0.95)
        reasoning = f"Technical analysis suggests {signal_type} signal based on market conditions"
        
        cursor.execute(
            'INSERT INTO advisory_signals (symbol, signal_type, confidence_score, reasoning, valid_until) VALUES (?, ?, ?, ?, ?)',
            (symbol, signal_type, confidence, reasoning, (datetime.now() + timedelta(days=1)).isoformat())
        )
    
    conn.commit()
    conn.close()

# Technical analysis functions
def fetch_market_data(symbol):
    """Fetch historical market data for technical analysis"""
    try:
        stock = yf.Ticker(symbol)
        hist = stock.history(period="3mo")
        return hist
    except Exception as e:
        print(f"Error fetching data for {symbol}: {e}")
        return None

def calculate_technical_indicators(df):
    """Calculate various technical indicators"""
    if df is None or len(df) < 20:
        return None
    
    try:
        # Add all technical analysis features
        df = add_all_ta_features(df, open="Open", high="High", low="Low", close="Close", volume="Volume")
        
        # Calculate additional indicators
        rsi = RSIIndicator(df['Close'])
        macd = MACD(df['Close'])
        bb = BollingerBands(df['Close'])
        
        return {
            'rsi': rsi.rsi().iloc[-1],
            'macd': macd.macd().iloc[-1],
            'macd_signal': macd.macd_signal().iloc[-1],
            'bb_upper': bb.bollinger_hband().iloc[-1],
            'bb_lower': bb.bollinger_lband().iloc[-1],
            'bb_middle': bb.bollinger_mavg().iloc[-1]
        }
    except Exception as e:
        print(f"Error calculating indicators: {e}")
        return None

def generate_advisory_signal(symbol):
    """Generate advisory signal based on technical indicators"""
    df = fetch_market_data(symbol)
    if df is None:
        return None
    
    indicators = calculate_technical_indicators(df)
    if indicators is None:
        return None
    
    # Simple signal generation logic
    current_price = df['Close'].iloc[-1]
    rsi = indicators['rsi']
    macd_diff = indicators['macd'] - indicators['macd_signal']
    
    if pd.isna(rsi) or pd.isna(macd_diff):
        return None
    
    signal_type = "HOLD"
    confidence = 0.5
    reasoning = []
    
    if rsi < 30:
        signal_type = "BUY"
        confidence += 0.2
        reasoning.append("Oversold condition (RSI < 30)")
    elif rsi > 70:
        signal_type = "SELL"
        confidence += 0.2
        reasoning.append("Overbought condition (RSI > 70)")
    
    if macd_diff > 0:
        if signal_type == "BUY":
            confidence += 0.1
            reasoning.append("MACD bullish crossover")
        elif signal_type == "HOLD":
            signal_type = "BUY"
            confidence += 0.15
    elif macd_diff < 0:
        if signal_type == "SELL":
            confidence += 0.1
            reasoning.append("MACD bearish crossover")
        elif signal_type == "HOLD":
            signal_type = "SELL"
            confidence += 0.15
    
    # Ensure confidence is within bounds
    confidence = min(max(confidence, 0.1), 0.95)
    
    return {
        'symbol': symbol,
        'signal_type': signal_type,
        'confidence_score': round(confidence, 2),
        'reasoning': '; '.join(reasoning) if reasoning else "Neutral market conditions",
        'current_price': round(current_price, 2),
        'indicators': indicators
    }

# API Routes
@app.route('/')
def index():
    return redirect(url_for('dashboard'))

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'error': 'Username and password required'}), 400
    
    conn = get_db_connection()
    user = conn.execute('SELECT * FROM users WHERE username = ?', (username,)).fetchone()
    conn.close()
    
    if user and check_password_hash(user['password_hash'], password):
        session['user_id'] = user['id']
        session['username'] = user['username']
        session['role'] = user['role']
        return jsonify({
            'message': 'Login successful',
            'user': {
                'id': user['id'],
                'username': user['username'],
                'role': user['role']
            }
        })
    
    return jsonify({'error': 'Invalid credentials'}), 401

@app.route('/logout', methods=['POST'])
def logout():
    session.clear()
    return jsonify({'message': 'Logout successful'})

@app.route('/api/dashboard')
@login_required
@advisor_required
def dashboard_data():
    conn = get_db_connection()
    
    # Get portfolio summary
    portfolios = conn.execute('''
        SELECT p.*, c.name as client_name, c.risk_profile
        FROM portfolios p
        JOIN clients c ON p.client_id = c.id
        WHERE p.advisor_id = ?
    ''', (session['user_id'],)).fetchall()
    
    portfolio_data = []
    total_portfolio_value = 0
    
    for portfolio in portfolios:
        holdings = conn.execute('''
            SELECT symbol, quantity, current_price, (quantity * current_price) as value
            FROM holdings 
            WHERE portfolio_id = ?
        ''', (portfolio['id'],)).fetchall()
        
        portfolio_value = sum(h['value'] for h in holdings) + portfolio['cash_balance']
        total_portfolio_value += portfolio_value
        
        portfolio_data.append({
            'id': portfolio['id'],
            'name': portfolio['name'],
            'client_name': portfolio['client_name'],
            'risk_profile': portfolio['risk_profile'],
            'total_value': portfolio_value,
            'cash_balance': portfolio['cash_balance'],
            'equity_value': sum(h['value'] for h in holdings),
            'holdings_count': len(holdings)
        })
    
    # Get recent transactions
    recent_transactions = conn.execute('''
        SELECT t.*, p.name as portfolio_name
        FROM transactions t
        JOIN portfolios p ON t.portfolio_id = p.id
        WHERE p.advisor_id = ?
        ORDER BY t.timestamp DESC
        LIMIT 10
    ''', (session['user_id'],)).fetchall()
    
    # Get advisory signals
    advisory_signals = conn.execute('''
        SELECT * FROM advisory_signals 
        WHERE valid_until > datetime('now')
        ORDER BY confidence_score DESC
        LIMIT 5
    ''').fetchall()
    
    conn.close()
    
    return jsonify({
        'portfolios': portfolio_data,
        'total_portfolio_value': total_portfolio_value,
        'recent_transactions': [dict(tx) for tx in recent_transactions],
        'advisory_signals': [dict(signal) for signal in advisory_signals],
        'portfolio_count': len(portfolio_data),
        'client_count': len(set(p['client_name'] for p in portfolio_data))
    })

@app.route('/api/portfolio/<int:portfolio_id>')
@login_required
@advisor_required
def portfolio_details(portfolio_id):
    conn = get_db_connection()
    
    # Verify portfolio belongs to advisor
    portfolio = conn.execute('''
        SELECT p.*, c.name as client_name 
        FROM portfolios p 
        JOIN clients c ON p.client_id = c.id 
        WHERE p.id = ? AND p.advisor_id = ?
    ''', (portfolio_id, session['user_id'])).fetchone()
    
    if not portfolio:
        conn.close()
        return jsonify({'error': 'Portfolio not found'}), 404
    
    # Get holdings
    holdings = conn.execute('''
        SELECT * FROM holdings WHERE portfolio_id = ?
    ''', (portfolio_id,)).fetchall()
    
    # Get performance data (simplified)
    performance_data = []
    for i in range(30):
        date = (datetime.now() - timedelta(days=29-i)).date()
        value = portfolio['total_value'] * (1 + np.random.normal(0, 0.02))
        performance_data.append({
            'date': date.isoformat(),
            'value': round(value, 2)
        })
    
    conn.close()
    
    return jsonify({
        'portfolio': dict(portfolio),
        'holdings': [dict(h) for h in holdings],
        'performance_data': performance_data
    })

@app.route('/api/advisory/signals')
@login_required
@advisor_required
def get_advisory_signals():
    symbols = request.args.getlist('symbols')
    
    if not symbols:
        # Get all unique symbols from holdings
        conn = get_db_connection()
        symbols_data = conn.execute('''
            SELECT DISTINCT h.symbol 
            FROM holdings h
            JOIN portfolios p ON h.portfolio_id = p.id
            WHERE p.advisor_id = ?
        ''', (session['user_id'],)).fetchall()
