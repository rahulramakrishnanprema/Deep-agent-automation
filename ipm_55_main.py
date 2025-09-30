from flask import Flask, jsonify, request, render_template, session, redirect, url_for
import sqlite3
import json
import os
from datetime import datetime, timedelta
import random

app = Flask(__name__)
app.secret_key = 'your-secret-key-here'  # Change this in production

# Database initialization
def init_db():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Create users table
    c.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'client',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Create portfolios table
    c.execute('''
        CREATE TABLE IF NOT EXISTS portfolios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # Create holdings table
    c.execute('''
        CREATE TABLE IF NOT EXISTS holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            portfolio_id INTEGER NOT NULL,
            stock_symbol TEXT NOT NULL,
            stock_name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            average_price REAL NOT NULL,
            sector TEXT NOT NULL,
            exchange TEXT DEFAULT 'NSE',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (portfolio_id) REFERENCES portfolios (id)
        )
    ''')
    
    # Create transactions table
    c.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            portfolio_id INTEGER NOT NULL,
            stock_symbol TEXT NOT NULL,
            transaction_type TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            price REAL NOT NULL,
            transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (portfolio_id) REFERENCES portfolios (id)
        )
    ''')
    
    # Create advisory_signals table
    c.execute('''
        CREATE TABLE IF NOT EXISTS advisory_signals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stock_symbol TEXT NOT NULL,
            signal TEXT NOT NULL,
            confidence_score REAL NOT NULL,
            reasoning TEXT,
            generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Insert dummy data if tables are empty
    c.execute("SELECT COUNT(*) FROM users")
    if c.fetchone()[0] == 0:
        # Insert sample users
        users = [
            ('client1', 'password123', 'client'),
            ('client2', 'password123', 'client'),
            ('advisor1', 'password123', 'advisor'),
            ('admin', 'admin123', 'admin')
        ]
        c.executemany("INSERT INTO users (username, password, role) VALUES (?, ?, ?)", users)
        
        # Insert sample portfolios
        portfolios = [
            (1, 'Retirement Portfolio', 'Long-term retirement investments'),
            (1, 'Growth Portfolio', 'Aggressive growth strategy'),
            (2, 'Conservative Portfolio', 'Low-risk investments')
        ]
        c.executemany("INSERT INTO portfolios (user_id, name, description) VALUES (?, ?, ?)", portfolios)
        
        # Insert sample holdings for Indian stocks
        indian_stocks = [
            (1, 'RELIANCE', 'Reliance Industries Ltd.', 10, 2450.50, 'Energy', 'NSE'),
            (1, 'TCS', 'Tata Consultancy Services Ltd.', 5, 3250.75, 'IT', 'NSE'),
            (1, 'HDFCBANK', 'HDFC Bank Ltd.', 8, 1450.25, 'Banking', 'NSE'),
            (2, 'INFY', 'Infosys Ltd.', 12, 1550.30, 'IT', 'NSE'),
            (2, 'ITC', 'ITC Ltd.', 15, 420.75, 'FMCG', 'NSE'),
            (3, 'SBIN', 'State Bank of India', 20, 550.60, 'Banking', 'NSE')
        ]
        c.executemany('''INSERT INTO holdings 
            (portfolio_id, stock_symbol, stock_name, quantity, average_price, sector, exchange) 
            VALUES (?, ?, ?, ?, ?, ?, ?)''', indian_stocks)
        
        # Generate sample advisory signals
        generate_dummy_signals(c)
    
    conn.commit()
    conn.close()

def generate_dummy_signals(cursor):
    """Generate dummy advisory signals for Indian stocks"""
    stocks = ['RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ITC', 'SBIN', 'HINDUNILVR', 'ICICIBANK', 'BAJFINANCE', 'AXISBANK']
    sectors = ['Energy', 'IT', 'Banking', 'IT', 'FMCG', 'Banking', 'FMCG', 'Banking', 'Financial Services', 'Banking']
    
    signals = []
    for i, stock in enumerate(stocks):
        signal_type = random.choice(['BUY', 'HOLD', 'SELL'])
        confidence = round(random.uniform(0.6, 0.95), 2)
        
        reasoning_templates = {
            'BUY': [
                f"Strong technical indicators showing upward momentum for {stock}",
                f"Positive sector outlook for {sectors[i]} supports BUY recommendation",
                f"Market buzz indicates institutional buying in {stock}"
            ],
            'HOLD': [
                f"{stock} showing stable performance, maintain current position",
                f"Mixed signals suggest holding until clearer trend emerges",
                f"Sector consolidation phase, recommend HOLD for {stock}"
            ],
            'SELL': [
                f"Technical indicators showing weakness in {stock}",
                f"Sector headwinds suggest reducing exposure to {stock}",
                f"Market sentiment turning negative for {sectors[i]} stocks"
            ]
        }
        
        reasoning = random.choice(reasoning_templates[signal_type])
        signals.append((stock, signal_type, confidence, reasoning))
    
    cursor.executemany('''INSERT INTO advisory_signals 
        (stock_symbol, signal, confidence_score, reasoning) 
        VALUES (?, ?, ?, ?)''', signals)

class DatabaseHandler:
    """Handles database operations for the portfolio management system"""
    
    @staticmethod
    def get_connection():
        """Get a database connection"""
        return sqlite3.connect('portfolio.db')
    
    @staticmethod
    def get_user_portfolios(user_id):
        """Get all portfolios for a user"""
        conn = DatabaseHandler.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT id, name, description, created_at 
            FROM portfolios 
            WHERE user_id = ?
        ''', (user_id,))
        
        portfolios = []
        for row in cursor.fetchall():
            portfolios.append({
                'id': row[0],
                'name': row[1],
                'description': row[2],
                'created_at': row[3]
            })
        
        conn.close()
        return portfolios
    
    @staticmethod
    def get_portfolio_holdings(portfolio_id):
        """Get all holdings for a portfolio"""
        conn = DatabaseHandler.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT h.id, h.stock_symbol, h.stock_name, h.quantity, h.average_price, 
                   h.sector, h.exchange, h.created_at
            FROM holdings h
            WHERE h.portfolio_id = ?
        ''', (portfolio_id,))
        
        holdings = []
        for row in cursor.fetchall():
            holdings.append({
                'id': row[0],
                'symbol': row[1],
                'name': row[2],
                'quantity': row[3],
                'average_price': row[4],
                'sector': row[5],
                'exchange': row[6],
                'created_at': row[7]
            })
        
        conn.close()
        return holdings
    
    @staticmethod
    def get_advisory_signals():
        """Get all advisory signals"""
        conn = DatabaseHandler.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT stock_symbol, signal, confidence_score, reasoning, generated_at
            FROM advisory_signals
            ORDER BY generated_at DESC
        ''')
        
        signals = []
        for row in cursor.fetchall():
            signals.append({
                'symbol': row[0],
                'signal': row[1],
                'confidence': row[2],
                'reasoning': row[3],
                'generated_at': row[4]
            })
        
        conn.close()
        return signals
    
    @staticmethod
    def get_user_by_credentials(username, password):
        """Get user by credentials (simple authentication for demo)"""
        conn = DatabaseHandler.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT id, username, role FROM users 
            WHERE username = ? AND password = ?
        ''', (username, password))
        
        user = cursor.fetchone()
        conn.close()
        
        if user:
            return {
                'id': user[0],
                'username': user[1],
                'role': user[2]
            }
        return None

class AdvisoryEngine:
    """Generates advisory signals based on multiple factors"""
    
    @staticmethod
    def generate_signal(stock_data):
        """
        Generate advisory signal based on multiple factors
        Returns: {'signal': 'BUY/HOLD/SELL', 'confidence': float, 'reasoning': str}
        """
        # Mock implementation for MVP - in production, this would use real data analysis
        factors = {
            'technical_score': random.uniform(0.4, 0.9),
            'sector_outlook': random.uniform(0.3, 0.8),
            'market_sentiment': random.uniform(0.5, 0.95),
            'historical_performance': random.uniform(0.6, 0.85)
        }
        
        # Weighted average calculation
        total_score = (
            factors['technical_score'] * 0.3 +
            factors['sector_outlook'] * 0.25 +
            factors['market_sentiment'] * 0.25 +
            factors['historical_performance'] * 0.2
        )
        
        if total_score > 0.7:
            signal = 'BUY'
            confidence = total_score
            reasoning = f"Strong positive indicators across technical analysis ({factors['technical_score']:.2f}), sector outlook ({factors['sector_outlook']:.2f}), and market sentiment ({factors['market_sentiment']:.2f})"
        elif total_score > 0.5:
            signal = 'HOLD'
            confidence = total_score
            reasoning = f"Mixed signals with moderate performance. Technical score: {factors['technical_score']:.2f}, Sector outlook: {factors['sector_outlook']:.2f}"
        else:
            signal = 'SELL'
            confidence = 1 - total_score
            reasoning = f"Negative indicators suggest caution. Technical score: {factors['technical_score']:.2f}, Market sentiment: {factors['market_sentiment']:.2f}"
        
        return {
            'signal': signal,
            'confidence': round(confidence, 2),
            'reasoning': reasoning
        }

# Flask Routes
@app.route('/')
def index():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        user = DatabaseHandler.get_user_by_credentials(username, password)
        if user:
            session['user_id'] = user['id']
            session['username'] = user['username']
            session['role'] = user['role']
            return redirect(url_for('index'))
        else:
            return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/api/portfolios')
def get_portfolios():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    portfolios = DatabaseHandler.get_user_portfolios(session['user_id'])
    return jsonify(portfolios)

@app.route('/api/portfolio/<int:portfolio_id>/holdings')
def get_portfolio_holdings(portfolio_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    holdings = DatabaseHandler.get_portfolio_holdings(portfolio_id)
    return jsonify(holdings)

@app.route('/api/advisory-signals')
def get_advisory_signals():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    if session.get('role') != 'advisor':
        return jsonify({'error': 'Access denied. Advisor role required'}), 403
    
    signals = DatabaseHandler.get_advisory_signals()
    return jsonify(signals)

@app.route('/api/generate-signal/<stock_symbol>')
def generate_signal(stock_symbol):
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    # Mock stock data - in production, this would fetch real data
    stock_data = {
        'symbol': stock_symbol,
        'price': random.uniform(100, 5000),
        'volume': random.randint(1000, 100000),
        'sector': random.choice(['IT', 'Banking', 'Energy', 'FMCG', 'Pharma'])
    }
    
    signal = AdvisoryEngine.generate_signal(stock_data)
    return jsonify(signal)

@app.route('/api/portfolio-metrics')
def get_portfolio_metrics():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    if session.get('role') != 'advisor':
        return jsonify({'error': 'Access denied. Advisor role required'}), 403
    
    # Mock portfolio metrics for visualization
    metrics = {
        'total_value': random.uniform(500000, 2000000),
        'daily_change': random.uniform(-50000, 50000),
        'sector_allocation': {
            'IT': random.uniform(0.1, 0.4),
            'Banking': random.uniform(0.1, 0.3),
            'Energy': random.uniform(0.05, 0.2),
            'FMCG': random.uniform(0.05, 0.15),
            'Pharma': random.uniform(0.05, 0.1),
            'Others': random.uniform(0.05, 0.1)
        },
        'top_performers': [
            {'symbol': 'RELIANCE', 'return': random.uniform(0.15, 0.35)},
            {'symbol': 'TCS', 'return': random.uniform(0.12, 0.28)},
            {'symbol': 'HDFCBANK', 'return': random.uniform(0.08, 0.22)}
        ]
    }
    
    return jsonify(metrics)

if __name__ == '__main__':
    init_db()
    app.run(debug=True, host='0.0.0.0', port=5000)