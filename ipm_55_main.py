# ipm_55_main.py
"""
Main application file for IPM-55 MVP web application.
This file serves as the entry point for the Flask backend application.
"""

from flask import Flask, jsonify, request, session, render_template
from flask_cors import CORS
import sqlite3
import json
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import yfinance as yf
import warnings
warnings.filterwarnings('ignore')

app = Flask(__name__)
app.secret_key = 'ipm_55_secret_key'  # For session management
CORS(app)  # Enable CORS for frontend-backend communication

# Database configuration
DB_PATH = 'ipm_55_portfolio.db'

def init_db():
    """Initialize database with required tables"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Clients table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT,
        risk_profile TEXT,
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    ''')
    
    # Portfolios table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS portfolios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER,
        stock_symbol TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        purchase_price REAL NOT NULL,
        purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (client_id) REFERENCES clients (id)
    )
    ''')
    
    # Users table (for authentication)
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'advisor',
        created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    ''')
    
    # Market data cache table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS market_data (
        symbol TEXT PRIMARY KEY,
        data JSON,
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    ''')
    
    # Insert dummy data if tables are empty
    if cursor.execute('SELECT COUNT(*) FROM clients').fetchone()[0] == 0:
        # Add sample clients
        sample_clients = [
            ('Rajesh Kumar', 'rajesh@example.com', '9876543210', 'Moderate'),
            ('Priya Sharma', 'priya@example.com', '8765432109', 'Conservative'),
            ('Vikram Singh', 'vikram@example.com', '7654321098', 'Aggressive')
        ]
        cursor.executemany('INSERT INTO clients (name, email, phone, risk_profile) VALUES (?, ?, ?, ?)', sample_clients)
        
        # Add sample portfolios
        sample_portfolios = [
            (1, 'RELIANCE.NS', 10, 2450.50),
            (1, 'HDFCBANK.NS', 5, 1450.75),
            (2, 'INFY.NS', 8, 1650.25),
            (2, 'TCS.NS', 6, 3350.00),
            (3, 'BAJFINANCE.NS', 12, 6850.30),
            (3, 'HINDUNILVR.NS', 15, 2450.60)
        ]
        cursor.executemany('INSERT INTO portfolios (client_id, stock_symbol, quantity, purchase_price) VALUES (?, ?, ?, ?)', sample_portfolios)
        
        # Add default admin user
        cursor.execute('INSERT INTO users (username, password, role) VALUES (?, ?, ?)', 
                     ('admin', 'admin123', 'admin'))
        cursor.execute('INSERT INTO users (username, password, role) VALUES (?, ?, ?)', 
                     ('advisor1', 'advisor123', 'advisor'))
    
    conn.commit()
    conn.close()

def get_db_connection():
    """Get database connection"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def generate_dummy_market_data():
    """Generate dummy market data for Indian equities"""
    nifty_50_stocks = [
        'RELIANCE.NS', 'HDFCBANK.NS', 'INFY.NS', 'ICICIBANK.NS', 'TCS.NS',
        'KOTAKBANK.NS', 'HINDUNILVR.NS', 'ITC.NS', 'AXISBANK.NS', 'LT.NS',
        'SBIN.NS', 'BAJFINANCE.NS', 'HCLTECH.NS', 'ASIANPAINT.NS', 'MARUTI.NS',
        'BHARTIARTL.NS', 'TITAN.NS', 'M&M.NS', 'SUNPHARMA.NS', 'TECHM.NS'
    ]
    
    market_data = {}
    for symbol in nifty_50_stocks:
        # Generate realistic price data with some randomness
        base_price = np.random.uniform(500, 5000)
        current_price = base_price * np.random.uniform(0.9, 1.1)
        high_price = current_price * np.random.uniform(1.01, 1.05)
        low_price = current_price * np.random.uniform(0.95, 0.99)
        volume = np.random.randint(100000, 1000000)
        
        market_data[symbol] = {
            'symbol': symbol,
            'current_price': round(current_price, 2),
            'high': round(high_price, 2),
            'low': round(low_price, 2),
            'volume': volume,
            'change': round(current_price - base_price, 2),
            'change_percent': round(((current_price - base_price) / base_price) * 100, 2),
            'last_updated': datetime.now().isoformat()
        }
    
    return market_data

def get_market_data(symbols=None):
    """Get market data for given symbols, use cache if available"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    if symbols is None:
        # Get all symbols from portfolios
        cursor.execute('SELECT DISTINCT stock_symbol FROM portfolios')
        symbols = [row['stock_symbol'] for row in cursor.fetchall()]
    
    market_data = {}
    current_time = datetime.now()
    
    for symbol in symbols:
        # Check cache first
        cursor.execute('SELECT data, last_updated FROM market_data WHERE symbol = ?', (symbol,))
        row = cursor.fetchone()
        
        if row and (current_time - datetime.fromisoformat(row['last_updated'])) < timedelta(minutes=30):
            # Use cached data if less than 30 minutes old
            market_data[symbol] = json.loads(row['data'])
        else:
            # Generate new dummy data
            dummy_data = generate_dummy_market_data()
            if symbol in dummy_data:
                market_data[symbol] = dummy_data[symbol]
                # Update cache
                cursor.execute('''
                    INSERT OR REPLACE INTO market_data (symbol, data, last_updated)
                    VALUES (?, ?, ?)
                ''', (symbol, json.dumps(dummy_data[symbol]), current_time.isoformat()))
    
    conn.commit()
    conn.close()
    return market_data

def calculate_technical_indicators(symbol, market_data):
    """Calculate technical indicators for a stock"""
    # Simplified technical indicator calculation
    price_data = market_data[symbol]
    current_price = price_data['current_price']
    
    # Mock RSI calculation
    rsi = np.random.uniform(30, 70)
    
    # Mock moving averages
    ma_50 = current_price * np.random.uniform(0.95, 1.05)
    ma_200 = current_price * np.random.uniform(0.9, 1.1)
    
    return {
        'rsi': round(rsi, 2),
        'ma_50': round(ma_50, 2),
        'ma_200': round(ma_200, 2),
        'trend': 'bullish' if ma_50 > ma_200 else 'bearish'
    }

def generate_advisory_signal(client_id, stock_symbol):
    """Generate advisory signal (Buy/Hold/Sell) for a stock in client's portfolio"""
    market_data = get_market_data([stock_symbol])
    
    if stock_symbol not in market_data:
        return {'signal': 'HOLD', 'confidence': 0.5, 'reason': 'Insufficient market data'}
    
    stock_data = market_data[stock_symbol]
    technicals = calculate_technical_indicators(stock_symbol, market_data)
    
    # Get client risk profile
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT risk_profile FROM clients WHERE id = ?', (client_id,))
    client = cursor.fetchone()
    conn.close()
    
    risk_profile = client['risk_profile'] if client else 'Moderate'
    
    # Signal generation logic
    score = 0
    
    # Technical analysis (40% weight)
    if technicals['rsi'] < 30:
        score += 40  # Oversold - bullish
    elif technicals['rsi'] > 70:
        score -= 40  # Overbought - bearish
    
    # Price momentum (30% weight)
    if stock_data['change_percent'] > 2:
        score += 30
    elif stock_data['change_percent'] < -2:
        score -= 30
    
    # Volume analysis (20% weight)
    if stock_data['volume'] > 500000:
        score += 20 if stock_data['change_percent'] > 0 else -20
    
    # Risk profile adjustment (10% weight)
    if risk_profile == 'Conservative' and score > 50:
        score = 50  # Conservative clients shouldn't get strong buy signals
    elif risk_profile == 'Aggressive' and score < -50:
        score = -50  # Aggressive clients shouldn't get strong sell signals
    
    # Determine final signal
    if score >= 70:
        signal = 'BUY'
        confidence = score / 100
        reason = 'Strong bullish indicators across technical, momentum, and volume analysis'
    elif score >= 30:
        signal = 'HOLD'
        confidence = (score - 30) / 40
        reason = 'Mixed signals with slight bullish bias'
    elif score >= -30:
        signal = 'HOLD'
        confidence = (30 + score) / 60
        reason = 'Neutral market conditions'
    elif score >= -70:
        signal = 'SELL'
        confidence = (-score - 30) / 40
        reason = 'Mixed signals with slight bearish bias'
    else:
        signal = 'SELL'
        confidence = -score / 100
        reason = 'Strong bearish indicators across technical, momentum, and volume analysis'
    
    return {
        'signal': signal,
        'confidence': round(confidence, 2),
        'reason': reason,
        'technical_analysis': technicals,
        'market_data': stock_data,
        'generated_at': datetime.now().isoformat()
    }

# API Routes
@app.route('/')
def home():
    """Serve the main application page"""
    return render_template('index.html')

@app.route('/api/login', methods=['POST'])
def login():
    """User login endpoint"""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM users WHERE username = ? AND password = ?', (username, password))
    user = cursor.fetchone()
    conn.close()
    
    if user:
        session['user_id'] = user['id']
        session['username'] = user['username']
        session['role'] = user['role']
        return jsonify({
            'success': True,
            'user': {
                'id': user['id'],
                'username': user['username'],
                'role': user['role']
            }
        })
    else:
        return jsonify({'success': False, 'error': 'Invalid credentials'}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    """User logout endpoint"""
    session.clear()
    return jsonify({'success': True})

@app.route('/api/clients')
def get_clients():
    """Get all clients"""
    if 'user_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM clients ORDER BY name')
    clients = [dict(row) for row in cursor.fetchall()]
    conn.close()
    
    return jsonify(clients)

@app.route('/api/portfolio/<int:client_id>')
def get_portfolio(client_id):
    """Get portfolio for a specific client"""
    if 'user_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Get portfolio items
    cursor.execute('''
        SELECT p.*, c.name as client_name 
        FROM portfolios p 
        JOIN clients c ON p.client_id = c.id 
        WHERE p.client_id = ?
    ''', (client_id,))
    
    portfolio_items = [dict(row) for row in cursor.fetchall()]
    conn.close()
    
    # Get current market data for all stocks in portfolio
    symbols = [item['stock_symbol'] for item in portfolio_items]
    market_data = get_market_data(symbols)
    
    # Calculate current values and returns
    for item in portfolio_items:
        symbol = item['stock_symbol']
        if symbol in market_data:
            current_price = market_data[symbol]['current_price']
            purchase_price = item['purchase_price']
            quantity = item['quantity']
            
            item['current_price'] = current_price
            item['current_value'] = round(current_price * quantity, 2)
            item['investment_value'] = round(purchase_price * quantity, 2)
            item['profit_loss'] = round((current_price - purchase_price) * quantity, 2)
            item['profit_loss_percent'] = round(((current_price - purchase_price) / purchase_price) * 100, 2)
            
            # Generate advisory signal
            item['advisory_signal'] = generate_advisory_signal(client_id, symbol)
        else:
            item['current_price'] = None
            item['current_value'] = None
            item['profit_loss'] = None
            item['profit_loss_percent'] = None
            item['advisory_signal'] = {'signal': 'N/A', 'reason': 'No market data available'}
    
    return jsonify(portfolio_items)

@app.route('/api/portfolio/<int:client_id>', methods=['POST'])
def add_to_portfolio(client_id):
    """Add stock to client portfolio"""
    if 'user_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.get_json()
    stock_symbol = data.get('stock_symbol')
    quantity = data.get('quantity')
    purchase_price = data.get('purchase_price')
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            INSERT INTO portfolios (client_id, stock_symbol, quantity, purchase_price)
            VALUES (?, ?, ?, ?)
        ''', (client_id, stock_symbol, quantity, purchase_price))
        
        conn.commit()
        portfolio_id = cursor.lastrowid
        
        cursor.execute('''
            SELECT p.*, c.name as client_name 
            FROM portfolios p 
            JOIN clients c ON p.client_id = c.id 
            WHERE p.id = ?
        ''', (portfolio_id,))
        
        new_item = dict(cursor.fetchone())
        conn.close()
        
        return jsonify(new_item)
    
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 400

@app.route('/api/portfolio/item/<int:item_id>', methods=['DELETE'])
def remove_from_portfolio(item_id):
    """Remove stock from portfolio"""
    if 'user_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute('DELETE FROM portfolios WHERE id = ?', (item_id,))
        conn.commit()
        conn.close()
        
        return jsonify({'success': True})
    
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 400

@app.route('/api/analytics/overview')
def get_analytics_overview():
    """Get analytics overview for advisors only"""
    if 'user_id' not in session or session.get('role') != 'advisor':
        return jsonify({'error': 'Unauthorized - Advisor access required'}), 403
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Get total portfolio statistics
    cursor.execute('''
        SELECT COUNT(DISTINCT client_id) as total_clients,
               COUNT(*) as total_holdings,
               SUM(quantity * purchase_price) as total_investment
        FROM portfolios
    ''')
    
    stats = dict(cursor.fetchone())
    
    # Get performance by client
    cursor.execute('''
        SELECT c.id, c.name, c.risk_profile,
               COUNT(p.id) as holdings_count,
               SUM(p.quantity * p.purchase_price) as total_investment
        FROM clients c
        LEFT JOIN portfolios p ON c.id = p.client_id
        GROUP BY c.id
    ''')
    
    clients_performance = [dict(row) for row in cursor.fetchall()]
    conn.close()
    
    # Get market data for all symbols in portfolios
    symbols = []
    for client in clients_performance:
        if client['holdings_count'] > 0:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute('SELECT DISTINCT stock_symbol FROM portfolios WHERE client_id = ?', (client['id'],))
            client_symbols = [row['stock_symbol'] for