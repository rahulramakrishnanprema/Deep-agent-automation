# ipm_55_main.py
"""
Main Flask application for IPM-55 MVP Portfolio Management System.
This file serves as the entry point for the web application.
"""

from flask import Flask, render_template, jsonify, request, session, redirect, url_for
import sqlite3
import json
from datetime import datetime
import os

app = Flask(__name__)
app.secret_key = 'ipm55_secret_key_development_only'  # Change in production

# Database configuration
DATABASE = 'portfolio.db'

def get_db_connection():
    """Establish connection to SQLite database"""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initialize database with required tables"""
    conn = get_db_connection()
    
    # Portfolio table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS portfolios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_name TEXT NOT NULL,
            stock_symbol TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            purchase_price REAL NOT NULL,
            purchase_date TEXT NOT NULL,
            sector TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Advisory signals table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS advisory_signals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stock_symbol TEXT NOT NULL,
            signal_type TEXT NOT NULL,
            confidence_score REAL NOT NULL,
            reasoning TEXT NOT NULL,
            generated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            valid_until TEXT NOT NULL
        )
    ''')
    
    # Users table for role-based access
    conn.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'client',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    conn.commit()
    conn.close()

def insert_dummy_data():
    """Insert dummy portfolio data for demonstration"""
    conn = get_db_connection()
    
    # Check if data already exists
    existing = conn.execute('SELECT COUNT(*) as count FROM portfolios').fetchone()['count']
    
    if existing == 0:
        dummy_portfolios = [
            ('Client A', 'RELIANCE', 10, 2500.50, '2024-01-15', 'Energy'),
            ('Client A', 'INFY', 25, 1650.75, '2024-02-10', 'IT'),
            ('Client B', 'HDFCBANK', 15, 1450.25, '2024-01-20', 'Banking'),
            ('Client B', 'TCS', 8, 3800.00, '2024-03-05', 'IT'),
            ('Client C', 'ICICIBANK', 20, 950.80, '2024-02-28', 'Banking'),
            ('Client C', 'BAJFINANCE', 12, 7200.50, '2024-03-12', 'Financial Services')
        ]
        
        for portfolio in dummy_portfolios:
            conn.execute('''
                INSERT INTO portfolios (client_name, stock_symbol, quantity, purchase_price, purchase_date, sector)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', portfolio)
        
        # Insert dummy advisory signals
        dummy_signals = [
            ('RELIANCE', 'BUY', 0.85, 'Strong technical indicators and positive sector outlook', '2024-12-31'),
            ('INFY', 'HOLD', 0.70, 'Stable performance but limited upside potential', '2024-12-31'),
            ('HDFCBANK', 'BUY', 0.90, 'Excellent fundamentals and market position', '2024-12-31'),
            ('TCS', 'SELL', 0.60, 'Valuation concerns and sector headwinds', '2024-12-31'),
            ('ICICIBANK', 'BUY', 0.80, 'Strong growth trajectory in banking sector', '2024-12-31'),
            ('BAJFINANCE', 'HOLD', 0.75, 'Wait for better entry point', '2024-12-31')
        ]
        
        for signal in dummy_signals:
            conn.execute('''
                INSERT INTO advisory_signals (stock_symbol, signal_type, confidence_score, reasoning, valid_until)
                VALUES (?, ?, ?, ?, ?)
            ''', signal)
        
        # Insert demo users
        demo_users = [
            ('advisor', 'advisor123', 'advisor'),  # In production, use proper password hashing
            ('client', 'client123', 'client')
        ]
        
        for user in demo_users:
            conn.execute('''
                INSERT INTO users (username, password_hash, role)
                VALUES (?, ?, ?)
            ''', user)
        
        conn.commit()
    
    conn.close()

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('index.html')

@app.route('/api/portfolio')
def get_portfolio():
    """API endpoint to fetch portfolio data"""
    try:
        conn = get_db_connection()
        portfolios = conn.execute('SELECT * FROM portfolios').fetchall()
        conn.close()
        
        portfolio_list = []
        for row in portfolios:
            portfolio_list.append(dict(row))
        
        return jsonify({'success': True, 'data': portfolio_list})
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/advisory-signals')
def get_advisory_signals():
    """API endpoint to fetch advisory signals"""
    try:
        conn = get_db_connection()
        signals = conn.execute('SELECT * FROM advisory_signals').fetchall()
        conn.close()
        
        signals_list = []
        for row in signals:
            signals_list.append(dict(row))
        
        return jsonify({'success': True, 'data': signals_list})
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/portfolio/<int:portfolio_id>', methods=['DELETE'])
def delete_portfolio_item(portfolio_id):
    """API endpoint to delete a portfolio item"""
    try:
        conn = get_db_connection()
        conn.execute('DELETE FROM portfolios WHERE id = ?', (portfolio_id,))
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Portfolio item deleted successfully'})
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/generate-signal', methods=['POST'])
def generate_advisory_signal():
    """API endpoint to generate advisory signal for a stock"""
    try:
        data = request.get_json()
        stock_symbol = data.get('stock_symbol')
        
        if not stock_symbol:
            return jsonify({'success': False, 'error': 'Stock symbol required'}), 400
        
        # Mock signal generation - in real implementation, this would use actual analysis
        signals = ['BUY', 'HOLD', 'SELL']
        signal_type = signals[hash(stock_symbol) % 3]  # Simple deterministic mock
        confidence = round(0.5 + (hash(stock_symbol) % 50) / 100, 2)  # 0.5-1.0
        
        reasoning_map = {
            'BUY': 'Strong technical indicators and positive market sentiment',
            'HOLD': 'Mixed signals, recommend holding current position',
            'SELL': 'Technical indicators suggest downward trend'
        }
        
        signal_data = {
            'stock_symbol': stock_symbol,
            'signal_type': signal_type,
            'confidence_score': confidence,
            'reasoning': reasoning_map[signal_type],
            'valid_until': '2024-12-31'
        }
        
        # Store in database
        conn = get_db_connection()
        conn.execute('''
            INSERT INTO advisory_signals (stock_symbol, signal_type, confidence_score, reasoning, valid_until)
            VALUES (?, ?, ?, ?, ?)
        ''', (signal_data['stock_symbol'], signal_data['signal_type'], 
              signal_data['confidence_score'], signal_data['reasoning'], 
              signal_data['valid_until']))
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'data': signal_data})
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/login', methods=['POST'])
def login():
    """Handle user login"""
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        
        # Simple authentication - in production, use proper password hashing
        conn = get_db_connection()
        user = conn.execute(
            'SELECT * FROM users WHERE username = ? AND password_hash = ?',
            (username, password)
        ).fetchone()
        conn.close()
        
        if user:
            session['user_id'] = user['id']
            session['username'] = user['username']
            session['role'] = user['role']
            return jsonify({'success': True, 'role': user['role']})
        else:
            return jsonify({'success': False, 'error': 'Invalid credentials'}), 401
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/logout')
def logout():
    """Handle user logout"""
    session.clear()
    return redirect(url_for('index'))

@app.route('/api/advisor-reports')
def get_advisor_reports():
    """API endpoint for advisor-only reports"""
    if session.get('role') != 'advisor':
        return jsonify({'success': False, 'error': 'Access denied'}), 403
    
    try:
        # Generate comprehensive advisor reports
        conn = get_db_connection()
        
        # Portfolio summary
        portfolio_summary = conn.execute('''
            SELECT sector, COUNT(*) as holdings, SUM(quantity * purchase_price) as total_value
            FROM portfolios 
            GROUP BY sector
        ''').fetchall()
        
        # Performance metrics
        performance_data = conn.execute('''
            SELECT stock_symbol, AVG(purchase_price) as avg_price, SUM(quantity) as total_quantity
            FROM portfolios 
            GROUP BY stock_symbol
        ''').fetchall()
        
        conn.close()
        
        reports = {
            'portfolio_summary': [dict(row) for row in portfolio_summary],
            'performance_metrics': [dict(row) for row in performance_data],
            'generated_at': datetime.now().isoformat()
        }
        
        return jsonify({'success': True, 'data': reports})
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/add-portfolio', methods=['POST'])
def add_portfolio_item():
    """API endpoint to add new portfolio item"""
    try:
        data = request.get_json()
        
        required_fields = ['client_name', 'stock_symbol', 'quantity', 'purchase_price', 'purchase_date', 'sector']
        if not all(field in data for field in required_fields):
            return jsonify({'success': False, 'error': 'Missing required fields'}), 400
        
        conn = get_db_connection()
        conn.execute('''
            INSERT INTO portfolios (client_name, stock_symbol, quantity, purchase_price, purchase_date, sector)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (data['client_name'], data['stock_symbol'], data['quantity'], 
              data['purchase_price'], data['purchase_date'], data['sector']))
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Portfolio item added successfully'})
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    # Initialize database and insert dummy data
    if not os.path.exists(DATABASE):
        init_db()
        insert_dummy_data()
        print("Database initialized with dummy data")
    
    # Run the Flask application
    app.run(debug=True, host='0.0.0.0', port=5000)