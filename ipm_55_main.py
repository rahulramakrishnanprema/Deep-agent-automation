# ipm_55_main.py
"""
Main entry point for the Indian Portfolio Management MVP application.
This module initializes the Flask application, sets up database connections,
and registers all API endpoints for portfolio management and advisory signals.
"""

from flask import Flask, jsonify, request, session, redirect, url_for, render_template
from flask_cors import CORS
import sqlite3
import json
import random
from datetime import datetime, timedelta
import functools

# Initialize Flask application
app = Flask(__name__)
app.secret_key = 'ipm_55_secret_key_2024'  # For session management
CORS(app)  # Enable CORS for frontend-backend communication

# Database configuration
DATABASE = 'ipm_portfolio.db'

def get_db_connection():
    """Establish and return a database connection."""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initialize the database with required tables."""
    conn = get_db_connection()
    
    # Users table for advisor authentication
    conn.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT DEFAULT 'advisor',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Portfolio holdings table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS portfolio_holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            symbol TEXT NOT NULL,
            company_name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            average_price REAL NOT NULL,
            sector TEXT NOT NULL,
            exchange TEXT DEFAULT 'NSE',
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # Advisory signals table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS advisory_signals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT NOT NULL,
            signal TEXT NOT NULL,
            confidence_score REAL NOT NULL,
            reasoning TEXT NOT NULL,
            generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            valid_until TIMESTAMP,
            is_active BOOLEAN DEFAULT TRUE
        )
    ''')
    
    # Transactions table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            symbol TEXT NOT NULL,
            transaction_type TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            price REAL NOT NULL,
            transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    conn.commit()
    conn.close()

def advisor_required(f):
    """Decorator to ensure user is authenticated as advisor."""
    @functools.wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session or session.get('role') != 'advisor':
            return jsonify({'error': 'Advisor access required'}), 403
        return f(*args, **kwargs)
    return decorated_function

def generate_dummy_data():
    """Generate and populate dummy data for demonstration."""
    conn = get_db_connection()
    
    # Create default advisor user
    try:
        conn.execute(
            "INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)",
            ('advisor', 'dummy_password_hash', 'advisor')
        )
    except sqlite3.IntegrityError:
        pass  # User already exists
    
    # Indian equity symbols with sectors
    indian_equities = [
        ('RELIANCE', 'Reliance Industries Ltd.', 'Energy'),
        ('TCS', 'Tata Consultancy Services Ltd.', 'IT'),
        ('HDFCBANK', 'HDFC Bank Ltd.', 'Banking'),
        ('INFY', 'Infosys Ltd.', 'IT'),
        ('ICICIBANK', 'ICICI Bank Ltd.', 'Banking'),
        ('HINDUNILVR', 'Hindustan Unilever Ltd.', 'FMCG'),
        ('SBIN', 'State Bank of India', 'Banking'),
        ('BAJFINANCE', 'Bajaj Finance Ltd.', 'Financial Services'),
        ('BHARTIARTL', 'Bharti Airtel Ltd.', 'Telecom'),
        ('ITC', 'ITC Ltd.', 'FMCG')
    ]
    
    # Insert dummy portfolio holdings
    user_id = 1  # Default advisor user
    for symbol, company_name, sector in indian_equities:
        try:
            conn.execute(
                '''INSERT INTO portfolio_holdings 
                   (user_id, symbol, company_name, quantity, average_price, sector)
                   VALUES (?, ?, ?, ?, ?, ?)''',
                (user_id, symbol, company_name, random.randint(10, 1000), 
                 random.uniform(100, 5000), sector)
            )
        except sqlite3.IntegrityError:
            pass
    
    # Generate advisory signals
    signals = ['BUY', 'HOLD', 'SELL']
    for symbol, company_name, sector in indian_equities:
        signal = random.choice(signals)
        conn.execute(
            '''INSERT INTO advisory_signals 
               (symbol, signal, confidence_score, reasoning, valid_until)
               VALUES (?, ?, ?, ?, ?)''',
            (symbol, signal, round(random.uniform(0.6, 0.95), 2),
             f'{signal} signal based on technical analysis and market trends',
             datetime.now() + timedelta(days=7))
        )
    
    # Generate some transaction history
    for _ in range(20):
        symbol, company_name, sector = random.choice(indian_equities)
        conn.execute(
            '''INSERT INTO transactions 
               (user_id, symbol, transaction_type, quantity, price)
               VALUES (?, ?, ?, ?, ?)''',
            (user_id, symbol, random.choice(['BUY', 'SELL']), 
             random.randint(1, 100), random.uniform(100, 5000))
        )
    
    conn.commit()
    conn.close()

@app.route('/')
def index():
    """Serve the main dashboard page."""
    return render_template('index.html')

@app.route('/api/login', methods=['POST'])
def login():
    """Handle advisor login."""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    # Dummy authentication - in production, use proper password hashing
    if username == 'advisor' and password == 'password':
        session['user_id'] = 1
        session['username'] = username
        session['role'] = 'advisor'
        return jsonify({'message': 'Login successful', 'user': username})
    
    return jsonify({'error': 'Invalid credentials'}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    """Handle user logout."""
    session.clear()
    return jsonify({'message': 'Logout successful'})

@app.route('/api/portfolio', methods=['GET'])
@advisor_required
def get_portfolio():
    """Retrieve advisor's portfolio holdings."""
    user_id = session.get('user_id')
    conn = get_db_connection()
    
    holdings = conn.execute(
        '''SELECT symbol, company_name, quantity, average_price, sector, exchange,
                  quantity * average_price as current_value
           FROM portfolio_holdings 
           WHERE user_id = ?''',
        (user_id,)
    ).fetchall()
    
    conn.close()
    
    portfolio_data = [dict(holding) for holding in holdings]
    total_value = sum(holding['current_value'] for holding in portfolio_data)
    
    return jsonify({
        'holdings': portfolio_data,
        'total_value': total_value,
        'count': len(portfolio_data)
    })

@app.route('/api/portfolio/<symbol>', methods=['PUT'])
@advisor_required
def update_holding(symbol):
    """Update a specific portfolio holding."""
    user_id = session.get('user_id')
    data = request.get_json()
    
    conn = get_db_connection()
    conn.execute(
        '''UPDATE portfolio_holdings 
           SET quantity = ?, average_price = ?, last_updated = CURRENT_TIMESTAMP
           WHERE user_id = ? AND symbol = ?''',
        (data['quantity'], data['average_price'], user_id, symbol)
    )
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Holding updated successfully'})

@app.route('/api/portfolio/<symbol>', methods=['DELETE'])
@advisor_required
def delete_holding(symbol):
    """Delete a specific portfolio holding."""
    user_id = session.get('user_id')
    
    conn = get_db_connection()
    conn.execute(
        'DELETE FROM portfolio_holdings WHERE user_id = ? AND symbol = ?',
        (user_id, symbol)
    )
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Holding deleted successfully'})

@app.route('/api/advisory-signals', methods=['GET'])
@advisor_required
def get_advisory_signals():
    """Retrieve current advisory signals."""
    conn = get_db_connection()
    
    signals = conn.execute(
        '''SELECT symbol, signal, confidence_score, reasoning, generated_at, valid_until
           FROM advisory_signals 
           WHERE is_active = TRUE AND valid_until > CURRENT_TIMESTAMP
           ORDER BY confidence_score DESC'''
    ).fetchall()
    
    conn.close()
    
    return jsonify([dict(signal) for signal in signals])

@app.route('/api/transactions', methods=['GET'])
@advisor_required
def get_transactions():
    """Retrieve transaction history."""
    user_id = session.get('user_id')
    conn = get_db_connection()
    
    transactions = conn.execute(
        '''SELECT symbol, transaction_type, quantity, price, transaction_date
           FROM transactions 
           WHERE user_id = ? 
           ORDER BY transaction_date DESC
           LIMIT 50''',
        (user_id,)
    ).fetchall()
    
    conn.close()
    
    return jsonify([dict(transaction) for transaction in transactions])

@app.route('/api/portfolio-summary', methods=['GET'])
@advisor_required
def get_portfolio_summary():
    """Get portfolio summary statistics."""
    user_id = session.get('user_id')
    conn = get_db_connection()
    
    # Sector distribution
    sector_distribution = conn.execute(
        '''SELECT sector, SUM(quantity * average_price) as value
           FROM portfolio_holdings 
           WHERE user_id = ?
           GROUP BY sector''',
        (user_id,)
    ).fetchall()
    
    # Top holdings
    top_holdings = conn.execute(
        '''SELECT symbol, company_name, quantity * average_price as value
           FROM portfolio_holdings 
           WHERE user_id = ?
           ORDER BY value DESC
           LIMIT 5''',
        (user_id,)
    ).fetchall()
    
    conn.close()
    
    return jsonify({
        'sector_distribution': [dict(row) for row in sector_distribution],
        'top_holdings': [dict(row) for row in top_holdings]
    })

@app.route('/api/generate-signals', methods=['POST'])
@advisor_required
def generate_signals():
    """Generate new advisory signals based on Indian market factors."""
    # This is a dummy implementation - in production, integrate with real market data
    conn = get_db_connection()
    
    # Clear existing signals
    conn.execute('UPDATE advisory_signals SET is_active = FALSE')
    
    # Get all portfolio symbols
    symbols = conn.execute(
        'SELECT DISTINCT symbol FROM portfolio_holdings'
    ).fetchall()
    
    signals = ['BUY', 'HOLD', 'SELL']
    factors = [
        'technical analysis', 'market trends', 'volume patterns',
        'support resistance levels', 'moving averages', 'RSI indicators'
    ]
    
    for symbol_row in symbols:
        symbol = symbol_row['symbol']
        signal = random.choice(signals)
        reasoning = f'{signal} signal based on {random.choice(factors)} and Indian market conditions'
        
        conn.execute(
            '''INSERT INTO advisory_signals 
               (symbol, signal, confidence_score, reasoning, valid_until)
               VALUES (?, ?, ?, ?, ?)''',
            (symbol, signal, round(random.uniform(0.65, 0.92), 2),
             reasoning, datetime.now() + timedelta(days=5))
        )
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Advisory signals generated successfully'})

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    # Initialize database and dummy data
    init_db()
    generate_dummy_data()
    
    # Start Flask development server
    app.run(debug=True, host='0.0.0.0', port=5000)