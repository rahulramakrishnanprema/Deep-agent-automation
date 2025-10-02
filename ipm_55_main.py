import os
import sqlite3
from datetime import datetime, timedelta
import random
from flask import Flask, render_template, request, jsonify, redirect, url_for, session, flash
from werkzeug.security import generate_password_hash, check_password_hash
import yfinance as yf
import pandas as pd
import numpy as np
from functools import wraps

app = Flask(__name__)
app.secret_key = 'your-secret-key-here'  # Change this in production

# Database initialization
def init_db():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Users table
    c.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'advisor',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Clients table
    c.execute('''
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
    c.execute('''
        CREATE TABLE IF NOT EXISTS portfolios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (client_id) REFERENCES clients (id)
        )
    ''')
    
    # Holdings table
    c.execute('''
        CREATE TABLE IF NOT EXISTS holdings (
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
    
    # Advisory signals table
    c.execute('''
        CREATE TABLE IF NOT EXISTS advisory_signals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stock_symbol TEXT NOT NULL,
            signal_type TEXT NOT NULL,
            strength REAL NOT NULL,
            reasoning TEXT,
            generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Insert dummy data if tables are empty
    c.execute("SELECT COUNT(*) FROM users")
    if c.fetchone()[0] == 0:
        # Create admin user
        password_hash = generate_password_hash('admin123')
        c.execute("INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)", 
                 ('admin', password_hash, 'admin'))
        
        # Create advisor user
        password_hash = generate_password_hash('advisor123')
        c.execute("INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)", 
                 ('advisor', password_hash, 'advisor'))
    
    c.execute("SELECT COUNT(*) FROM clients")
    if c.fetchone()[0] == 0:
        clients = [
            ('Rahul Sharma', 'rahul.sharma@email.com', '9876543210', 'Aggressive'),
            ('Priya Patel', 'priya.patel@email.com', '9876543211', 'Moderate'),
            ('Amit Kumar', 'amit.kumar@email.com', '9876543212', 'Conservative'),
            ('Sneha Gupta', 'sneha.gupta@email.com', '9876543213', 'Aggressive'),
            ('Vikram Singh', 'vikram.singh@email.com', '9876543214', 'Moderate')
        ]
        for client in clients:
            c.execute("INSERT INTO clients (name, email, phone, risk_profile) VALUES (?, ?, ?, ?)", client)
    
    c.execute("SELECT COUNT(*) FROM portfolios")
    if c.fetchone()[0] == 0:
        portfolios = [
            (1, 'Growth Portfolio', 'High growth potential stocks'),
            (2, 'Balanced Portfolio', 'Mix of growth and dividend stocks'),
            (3, 'Conservative Portfolio', 'Low risk, stable returns'),
            (4, 'Sector Focus', 'Technology and healthcare focus'),
            (5, 'Dividend Portfolio', 'High dividend yielding stocks')
        ]
        for portfolio in portfolios:
            c.execute("INSERT INTO portfolios (client_id, name, description) VALUES (?, ?, ?)", portfolio)
    
    conn.commit()
    conn.close()

# Authentication decorator
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('Please log in to access this page.', 'danger')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def advisor_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('Please log in to access this page.', 'danger')
            return redirect(url_for('login'))
        if session.get('user_role') != 'advisor' and session.get('user_role') != 'admin':
            flash('Access denied. Advisor privileges required.', 'danger')
            return redirect(url_for('dashboard'))
        return f(*args, **kwargs)
    return decorated_function

# Routes
@app.route('/')
def home():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return render_template('login.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        conn = sqlite3.connect('portfolio.db')
        c = conn.cursor()
        c.execute("SELECT id, username, password_hash, role FROM users WHERE username = ?", (username,))
        user = c.fetchone()
        conn.close()
        
        if user and check_password_hash(user[2], password):
            session['user_id'] = user[0]
            session['username'] = user[1]
            session['user_role'] = user[3]
            flash('Login successful!', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('Invalid username or password', 'danger')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out.', 'info')
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Get portfolio summary
    c.execute('''
        SELECT p.id, p.name, c.name as client_name, COUNT(h.id) as holding_count
        FROM portfolios p
        JOIN clients c ON p.client_id = c.id
        LEFT JOIN holdings h ON p.id = h.portfolio_id
        GROUP BY p.id
    ''')
    portfolios = c.fetchall()
    
    # Get recent advisory signals
    c.execute('''
        SELECT stock_symbol, signal_type, strength, reasoning, generated_at
        FROM advisory_signals
        ORDER BY generated_at DESC
        LIMIT 5
    ''')
    recent_signals = c.fetchall()
    
    conn.close()
    
    return render_template('dashboard.html', 
                         portfolios=portfolios, 
                         recent_signals=recent_signals,
                         username=session.get('username'))

@app.route('/portfolio/<int:portfolio_id>')
@login_required
def portfolio_detail(portfolio_id):
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Get portfolio details
    c.execute('''
        SELECT p.*, c.name as client_name
        FROM portfolios p
        JOIN clients c ON p.client_id = c.id
        WHERE p.id = ?
    ''', (portfolio_id,))
    portfolio = c.fetchone()
    
    # Get holdings
    c.execute('''
        SELECT h.*, 
               (SELECT close FROM stock_prices WHERE symbol = h.stock_symbol ORDER BY date DESC LIMIT 1) as current_price
        FROM holdings h
        WHERE h.portfolio_id = ?
    ''', (portfolio_id,))
    holdings = c.fetchall()
    
    # Calculate portfolio performance
    total_investment = sum(h[3] * h[4] for h in holdings)  # quantity * purchase_price
    current_value = sum(h[3] * (h[7] or h[4]) for h in holdings)  # quantity * current_price (or purchase_price if None)
    
    conn.close()
    
    return render_template('portfolio_detail.html', 
                         portfolio=portfolio, 
                         holdings=holdings,
                         total_investment=total_investment,
                         current_value=current_value)

@app.route('/api/portfolio/<int:portfolio_id>/performance')
@login_required
def portfolio_performance(portfolio_id):
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Get historical performance data (simplified)
    dates = [(datetime.now() - timedelta(days=i)).strftime('%Y-%m-%d') for i in range(30, 0, -1)]
    performance_data = [random.uniform(0.95, 1.15) for _ in range(30)]
    
    conn.close()
    
    return jsonify({
        'dates': dates,
        'values': performance_data
    })

@app.route('/api/advisory/signals')
@advisor_required
def advisory_signals():
    # Generate advisory signals based on various factors
    signals = generate_advisory_signals()
    return jsonify(signals)

@app.route('/api/portfolio/<int:portfolio_id>/analysis')
@advisor_required
def portfolio_analysis(portfolio_id):
    # Generate comprehensive portfolio analysis
    analysis = generate_portfolio_analysis(portfolio_id)
    return jsonify(analysis)

# Helper functions for advisory signals
def generate_advisory_signals():
    """Generate advisory signals based on historical performance, technical indicators, etc."""
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Popular Indian stocks
    indian_stocks = ['RELIANCE.NS', 'TCS.NS', 'HDFCBANK.NS', 'INFY.NS', 'ICICIBANK.NS',
                    'HINDUNILVR.NS', 'SBIN.NS', 'BAJFINANCE.NS', 'BHARTIARTL.NS', 'ITC.NS']
    
    signals = []
    for stock in indian_stocks:
        try:
            # Get stock data
            stock_data = yf.download(stock, period='6mo', progress=False)
            
            if len(stock_data) > 0:
                # Calculate technical indicators
                current_price = stock_data['Close'].iloc[-1]
                sma_50 = stock_data['Close'].rolling(window=50).mean().iloc[-1]
                sma_200 = stock_data['Close'].rolling(window=200).mean().iloc[-1]
                rsi = calculate_rsi(stock_data['Close'])
                
                # Generate signal based on indicators
                signal_type, strength, reasoning = generate_signal_logic(
                    current_price, sma_50, sma_200, rsi, stock
                )
                
                signals.append({
                    'stock_symbol': stock,
                    'signal_type': signal_type,
                    'strength': strength,
                    'reasoning': reasoning
                })
                
                # Store signal in database
                c.execute('''
                    INSERT INTO advisory_signals (stock_symbol, signal_type, strength, reasoning)
                    VALUES (?, ?, ?, ?)
                ''', (stock, signal_type, strength, reasoning))
                
        except Exception as e:
            print(f"Error processing {stock}: {e}")
            continue
    
    conn.commit()
    conn.close()
    return signals

def calculate_rsi(prices, period=14):
    """Calculate Relative Strength Index"""
    if len(prices) < period:
        return 50  # Neutral
    
    deltas = np.diff(prices)
    gains = np.where(deltas > 0, deltas, 0)
    losses = np.where(deltas < 0, -deltas, 0)
    
    avg_gain = np.mean(gains[:period])
    avg_loss = np.mean(losses[:period])
    
    for i in range(period, len(prices)-1):
        avg_gain = (avg_gain * (period - 1) + gains[i]) / period
        avg_loss = (avg_loss * (period - 1) + losses[i]) / period
    
    if avg_loss == 0:
        return 100
    
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

def generate_signal_logic(current_price, sma_50, sma_200, rsi, stock_symbol):
    """Generate buy/sell/hold signal based on technical analysis"""
    
    if pd.isna(sma_50) or pd.isna(sma_200) or pd.isna(rsi):
        return "HOLD", 0.5, "Insufficient data for analysis"
    
    # Trend analysis
    trend_strength = 0
    reasoning = []
    
    # Price vs moving averages
    if current_price > sma_50 > sma_200:
        trend_strength += 0.4
        reasoning.append("Strong uptrend: Price above both 50-day and 200-day SMA")
    elif current_price < sma_50 < sma_200:
        trend_strength -= 0.4
        reasoning.append("Strong downtrend: Price below both 50-day and 200-day SMA")
    
    # RSI analysis
    if rsi > 70:
        trend_strength -= 0.3
        reasoning.append("Overbought conditions (RSI > 70)")
    elif rsi < 30:
        trend_strength += 0.3
        reasoning.append("Oversold conditions (RSI < 30)")
    else:
        reasoning.append("RSI in neutral territory")
    
    # Sector-specific considerations (simplified)
    sector_buzz = random.uniform(-0.2, 0.2)
    trend_strength += sector_buzz
    reasoning.append(f"Sector sentiment: {'Positive' if sector_buzz > 0 else 'Negative'}")
    
    # Determine final signal
    if trend_strength > 0.5:
        signal = "BUY"
        strength = min(0.9, trend_strength)
    elif trend_strength < -0.5:
        signal = "SELL"
        strength = min(0.9, -trend_strength)
    else:
        signal = "HOLD"
        strength = 0.5
    
    reasoning_str = ". ".join(reasoning)
    return signal, round(strength, 2), reasoning_str

def generate_portfolio_analysis(portfolio_id):
    """Generate comprehensive analysis for a portfolio"""
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Get portfolio holdings
    c.execute('''
        SELECT h.stock_symbol, h.quantity, h.purchase_price, h.sector
        FROM holdings h
        WHERE h.portfolio_id = ?
    ''', (portfolio_id,))
    holdings = c.fetchall()
    
    analysis = {
        'sector_allocation': {},
        'performance_metrics': {},
        'risk_analysis': {},
        'recommendations': []
    }
    
    # Calculate sector allocation
    for holding in holdings:
        sector = holding[3] or 'Unknown'
        analysis['sector_allocation'][sector] = analysis['sector_allocation'].get(sector, 0) + 1
    
    # Generate performance metrics (simplified)
    analysis['performance_metrics'] = {
        'estimated_return': round(random.uniform(-5, 15), 2),
        'volatility': round(random.uniform(5, 25), 2),
        'sharpe_ratio': round(random.uniform(0.5, 2.5), 2)
    }
    
    # Risk analysis
    analysis['risk_analysis'] = {
        'concentration_risk': 'Moderate',
        'sector_risk': 'Low' if len(analysis['sector_allocation']) >= 3 else 'High',
        'market_risk': 'Moderate to High'
    }
    
    # Generate recommendations
    recommendations = [
        "Consider diversifying across more sectors",
        "Rebalance portfolio to maintain target allocations",
        "Review high-volatility positions",
        "Consider adding defensive stocks in current market conditions"
    ]
    analysis['recommendations'] = random.sample(recommendations, 2)
    
    conn.close()
    return analysis

# Initialize database and create dummy data
def create_dummy_data():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Create dummy holdings
    stocks = ['RELIANCE.NS', 'TCS.NS', 'HDFCBANK.NS', 'INFY.NS', 'ICICIBANK.NS',
             'HINDUNILVR.NS', 'SBIN.NS', 'BAJFINANCE.NS', 'BHARTIARTL.NS', 'ITC.NS']
    sectors = ['Energy', 'Technology', 'Banking', 'Technology', 'Banking',
              'Consumer Goods', 'Banking', 'Financial Services', 'Telecom', 'Consumer Goods']
    
    for portfolio_id in range(1, 6):
        num_holdings = random.randint(3, 8)
        selected_stocks = random.sample(list(zip(stocks, sectors)), num_holdings)
        
        for stock, sector in selected_stocks:
            quantity = random.randint(10, 100) * 10
            purchase_price = round(random.uniform(500, 5000), 2)
            purchase_date = (datetime.now() - timedelta(days=random.randint(30, 365))).strftime('%Y-%m-%d')
            
            c.execute('''
                INSERT INTO holdings (portfolio_id, stock_symbol, quantity, purchase_price, purchase_date, sector)
                VALUES (?, ?, ?, ?,