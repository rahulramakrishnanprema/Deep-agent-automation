# ipm_55_main.py
"""
Main application file for IPM-55 MVP portfolio management system.
This module serves as the entry point for the Flask web application.
"""

from flask import Flask, render_template, jsonify, request, session, redirect, url_for
from flask_cors import CORS
import sqlite3
import json
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import yfinance as yf
import requests
from functools import wraps

# Initialize Flask application
app = Flask(__name__)
app.secret_key = 'ipm55_secret_key_2024'  # For session management
CORS(app)  # Enable CORS for API endpoints

# Database configuration
DATABASE = 'portfolio.db'

# Advisor credentials (dummy data for MVP)
ADVISORS = {
    'advisor1': {'password': 'pass123', 'name': 'Raj Sharma'},
    'advisor2': {'password': 'pass456', 'name': 'Priya Patel'}
}

# Indian equity market symbols (Nifty 50 representative sample)
INDIAN_STOCKS = {
    'RELIANCE.NS': 'Reliance Industries',
    'TCS.NS': 'Tata Consultancy Services',
    'HDFCBANK.NS': 'HDFC Bank',
    'INFY.NS': 'Infosys',
    'ICICIBANK.NS': 'ICICI Bank',
    'HINDUNILVR.NS': 'Hindustan Unilever',
    'SBIN.NS': 'State Bank of India',
    'BAJFINANCE.NS': 'Bajaj Finance',
    'BHARTIARTL.NS': 'Bharti Airtel',
    'ITC.NS': 'ITC Limited'
}

# Sector mapping for Indian stocks
SECTOR_MAPPING = {
    'RELIANCE.NS': 'Energy',
    'TCS.NS': 'IT',
    'HDFCBANK.NS': 'Banking',
    'INFY.NS': 'IT',
    'ICICIBANK.NS': 'Banking',
    'HINDUNILVR.NS': 'FMCG',
    'SBIN.NS': 'Banking',
    'BAJFINANCE.NS': 'Financial Services',
    'BHARTIARTL.NS': 'Telecom',
    'ITC.NS': 'FMCG'
}

def get_db_connection():
    """Establish connection to SQLite database."""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initialize database with required tables."""
    conn = get_db_connection()
    
    # Portfolio table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS portfolios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_name TEXT NOT NULL,
            advisor_id TEXT NOT NULL,
            created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Holdings table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            portfolio_id INTEGER,
            stock_symbol TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            purchase_price REAL NOT NULL,
            purchase_date DATE NOT NULL,
            FOREIGN KEY (portfolio_id) REFERENCES portfolios (id)
        )
    ''')
    
    # Advisor sessions table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS advisor_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            advisor_id TEXT NOT NULL,
            session_token TEXT NOT NULL,
            created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    conn.commit()
    conn.close()

def advisor_required(f):
    """Decorator to ensure advisor authentication."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'advisor_id' not in session:
            return jsonify({'error': 'Advisor authentication required'}), 401
        return f(*args, **kwargs)
    return decorated_function

def calculate_technical_indicators(stock_data):
    """
    Calculate technical indicators for stock data.
    Returns: dict with RSI, MACD, Moving Averages, etc.
    """
    if len(stock_data) < 20:  # Ensure sufficient data
        return {}
    
    # Convert to pandas DataFrame
    df = pd.DataFrame(stock_data)
    df['Date'] = pd.to_datetime(df['Date'])
    df.set_index('Date', inplace=True)
    
    # Calculate RSI (Relative Strength Index)
    delta = df['Close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / loss
    df['RSI'] = 100 - (100 / (1 + rs))
    
    # Calculate MACD
    exp12 = df['Close'].ewm(span=12, adjust=False).mean()
    exp26 = df['Close'].ewm(span=26, adjust=False).mean()
    df['MACD'] = exp12 - exp26
    df['Signal_Line'] = df['MACD'].ewm(span=9, adjust=False).mean()
    df['MACD_Histogram'] = df['MACD'] - df['Signal_Line']
    
    # Moving Averages
    df['MA_20'] = df['Close'].rolling(window=20).mean()
    df['MA_50'] = df['Close'].rolling(window=50).mean()
    
    # Convert back to list of dicts
    result = df.reset_index().to_dict('records')
    return result

def generate_advisory_signal(technical_data, market_buzz=None):
    """
    Generate Buy/Hold/Sell signal based on technical indicators.
    Simplified logic for MVP.
    """
    if not technical_data or len(technical_data) < 20:
        return "Hold", "Insufficient data for analysis"
    
    # Get the latest data point
    latest = technical_data[-1]
    
    # Simple signal generation logic
    signals = []
    
    # RSI-based signal
    if latest.get('RSI') < 30:
        signals.append(("RSI indicates oversold", "Buy"))
    elif latest.get('RSI') > 70:
        signals.append(("RSI indicates overbought", "Sell"))
    else:
        signals.append(("RSI neutral", "Hold"))
    
    # MACD-based signal
    if latest.get('MACD') > latest.get('Signal_Line', 0):
        signals.append(("MACD bullish crossover", "Buy"))
    else:
        signals.append(("MACD bearish", "Hold"))
    
    # Moving Average-based signal
    if latest.get('MA_20', 0) > latest.get('MA_50', 0):
        signals.append(("Short-term trend positive", "Buy"))
    else:
        signals.append(("Short-term trend negative", "Hold"))
    
    # Count signals
    buy_count = sum(1 for _, signal in signals if signal == "Buy")
    sell_count = sum(1 for _, signal in signals if signal == "Sell")
    hold_count = sum(1 for _, signal in signals if signal == "Hold")
    
    # Determine final signal
    if buy_count >= 2:
        final_signal = "Buy"
    elif sell_count >= 2:
        final_signal = "Sell"
    else:
        final_signal = "Hold"
    
    # Generate reasoning
    reasoning = "; ".join([f"{reason} ({signal})" for reason, signal in signals])
    
    return final_signal, reasoning

def analyze_sector_performance(portfolio_data):
    """
    Analyze sector performance for the portfolio.
    Returns sector-wise analysis and recommendations.
    """
    sector_data = {}
    
    for holding in portfolio_data.get('holdings', []):
        symbol = holding['stock_symbol']
        sector = SECTOR_MAPPING.get(symbol, 'Unknown')
        
        if sector not in sector_data:
            sector_data[sector] = {
                'total_investment': 0,
                'current_value': 0,
                'stocks': []
            }
        
        investment = holding['quantity'] * holding['purchase_price']
        current_price = get_current_price(symbol)
        current_val = holding['quantity'] * current_price
        
        sector_data[sector]['total_investment'] += investment
        sector_data[sector]['current_value'] += current_val
        sector_data[sector]['stocks'].append({
            'symbol': symbol,
            'investment': investment,
            'current_value': current_val
        })
    
    # Calculate sector performance
    for sector, data in sector_data.items():
        data['profit_loss'] = data['current_value'] - data['total_investment']
        data['return_percentage'] = (data['profit_loss'] / data['total_investment'] * 100) if data['total_investment'] > 0 else 0
    
    return sector_data

def get_market_buzz():
    """
    Fetch market news and sentiment data.
    Mock implementation for MVP.
    """
    # In a real implementation, this would connect to news APIs
    return [
        {"headline": "Indian markets reach all-time high", "sentiment": "positive", "sector": "General"},
        {"headline": "IT sector shows strong quarterly results", "sentiment": "positive", "sector": "IT"},
        {"headline": "Banking stocks under pressure due to rate hikes", "sentiment": "negative", "sector": "Banking"}
    ]

def get_current_price(symbol):
    """
    Get current stock price using yfinance.
    Fallback to mock data if API fails.
    """
    try:
        stock = yf.Ticker(symbol)
        hist = stock.history(period='1d')
        return hist['Close'].iloc[-1] if not hist.empty else 100.0
    except:
        # Mock prices for demo
        mock_prices = {
            'RELIANCE.NS': 2500.0,
            'TCS.NS': 3500.0,
            'HDFCBANK.NS': 1600.0,
            'INFY.NS': 1800.0,
            'ICICIBANK.NS': 950.0,
            'HINDUNILVR.NS': 2400.0,
            'SBIN.NS': 600.0,
            'BAJFINANCE.NS': 7200.0,
            'BHARTIARTL.NS': 800.0,
            'ITC.NS': 420.0
        }
        return mock_prices.get(symbol, 100.0)

def get_historical_data(symbol, period='1y'):
    """
    Fetch historical stock data using yfinance.
    Fallback to mock data if API fails.
    """
    try:
        stock = yf.Ticker(symbol)
        hist = stock.history(period=period)
        return [{
            'Date': date.strftime('%Y-%m-%d'),
            'Open': row['Open'],
            'High': row['High'],
            'Low': row['Low'],
            'Close': row['Close'],
            'Volume': row['Volume']
        } for date, row in hist.iterrows()]
    except:
        # Generate mock historical data
        dates = pd.date_range(end=datetime.now(), periods=365, freq='D')
        base_price = 100.0
        mock_data = []
        
        for i, date in enumerate(dates):
            price = base_price + (i * 0.5) + (np.random.random() * 10 - 5)
            mock_data.append({
                'Date': date.strftime('%Y-%m-%d'),
                'Open': price * 0.99,
                'High': price * 1.02,
                'Low': price * 0.98,
                'Close': price,
                'Volume': np.random.randint(100000, 1000000)
            })
        
        return mock_data

@app.route('/')
def home():
    """Home route - redirect to login for advisors."""
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Advisor login endpoint."""
    if request.method == 'POST':
        data = request.get_json()
        advisor_id = data.get('advisor_id')
        password = data.get('password')
        
        if advisor_id in ADVISORS and ADVISORS[advisor_id]['password'] == password:
            session['advisor_id'] = advisor_id
            session['advisor_name'] = ADVISORS[advisor_id]['name']
            return jsonify({'message': 'Login successful', 'advisor_name': ADVISORS[advisor_id]['name']})
        else:
            return jsonify({'error': 'Invalid credentials'}), 401
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """Logout endpoint."""
    session.clear()
    return jsonify({'message': 'Logged out successfully'})

@app.route('/api/portfolios', methods=['GET'])
@advisor_required
def get_portfolios():
    """Get all portfolios for the logged-in advisor."""
    advisor_id = session['advisor_id']
    conn = get_db_connection()
    
    portfolios = conn.execute(
        'SELECT * FROM portfolios WHERE advisor_id = ? ORDER BY created_date DESC',
        (advisor_id,)
    ).fetchall()
    
    conn.close()
    
    return jsonify([dict(portfolio) for portfolio in portfolios])

@app.route('/api/portfolios', methods=['POST'])
@advisor_required
def create_portfolio():
    """Create a new portfolio."""
    data = request.get_json()
    client_name = data.get('client_name')
    advisor_id = session['advisor_id']
    
    if not client_name:
        return jsonify({'error': 'Client name is required'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        'INSERT INTO portfolios (client_name, advisor_id) VALUES (?, ?)',
        (client_name, advisor_id)
    )
    
    portfolio_id = cursor.lastrowid
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Portfolio created', 'portfolio_id': portfolio_id})

@app.route('/api/portfolios/<int:portfolio_id>', methods=['GET'])
@advisor_required
def get_portfolio_details(portfolio_id):
    """Get detailed portfolio information including holdings."""
    conn = get_db_connection()
    
    # Verify portfolio belongs to advisor
    portfolio = conn.execute(
        'SELECT * FROM portfolios WHERE id = ? AND advisor_id = ?',
        (portfolio_id, session['advisor_id'])
    ).fetchone()
    
    if not portfolio:
        conn.close()
        return jsonify({'error': 'Portfolio not found'}), 404
    
    # Get holdings
    holdings = conn.execute(
        'SELECT * FROM holdings WHERE portfolio_id = ?',
        (portfolio_id,)
    ).fetchall()
    
    conn.close()
    
    portfolio_data = dict(portfolio)
    portfolio_data['holdings'] = [dict(holding) for holding in holdings]
    
    return jsonify(portfolio_data)

@app.route('/api/portfolios/<int:portfolio_id>/holdings', methods=['POST'])
@advisor_required
def add_holding(portfolio_id):
    """Add a stock holding to portfolio."""
    data = request.get_json()
    stock_symbol = data.get('stock_symbol')
    quantity = data.get('quantity')
    purchase_price = data.get('purchase_price')
    purchase_date = data.get('purchase_date', datetime.now().strftime('%Y-%m-%d'))
    
    # Validation
    if not all([stock_symbol, quantity, purchase_price]):
        return jsonify({'error': 'Missing required fields'}), 400
    
    if stock_symbol not in INDIAN_STOCKS:
        return jsonify({'error': 'Invalid Indian stock symbol'}), 400
    
    conn = get_db_connection()
    
    # Verify portfolio belongs to advisor
    portfolio = conn.execute(
        'SELECT * FROM portfolios WHERE id = ? AND advisor_id = ?',
        (portfolio_id, session['advisor_id'])
    ).fetchone()
    
    if not portfolio:
        conn.close()
        return jsonify({'error': 'Portfolio not found'}), 404
    
    # Add holding
    conn.execute(
        '''INSERT INTO holdings (portfolio_id, stock_symbol, quantity, purchase_price, purchase_date)
           VALUES (?, ?, ?, ?, ?)''',
        (portfolio_id, stock_symbol, quantity, purchase_price, purchase_date)
    )
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Holding added successfully'})

@app.route('/api/analysis/portfolio/<int:portfolio_id>')
@advisor_required
def analyze_portfolio(portfolio_id):
    """Comprehensive portfolio analysis with signals and recommendations."""
    # Get portfolio data
    portfolio_response = get_portfolio_details(portfolio_id)
    if portfolio_response.status_code != 200:
        return portfolio_response
    
    portfolio_data = portfolio_response.get_json()
    
    # Calculate current values and performance
    total_investment = 0
    current_value = 0
    holdings_analysis = []
    
    for holding in portfolio_data['holdings']:
        investment = holding['quantity'] * holding['purchase_price']
        current_price = get_current_price(holding['stock_symbol'])
        current_val = holding['quantity'] * current_price
        profit_loss = current_val - investment
        return_pct = (profit_loss / investment * 100) if investment > 0 else 0
        
        total_investment += investment
        current_value += current_val
        
        # Get historical data for technical analysis
        historical_data = get_historical_data(holding['stock_symbol'])
        technical_data = calculate_technical_indicators(historical_data)
        signal, reasoning = generate_advisory_signal(technical_data)
        
        holdings_analysis.append({
            **holding,
            'current_price': current_price,
            'current_value': current_val,
            'profit_loss': profit_loss,
            'return_percentage': return_pct,
            'advisory_signal': signal,
            'signal_reasoning': reasoning,
            'historical_data': historical_data[-30:]  # Last 30 days for charts
        })
    
    # Overall portfolio performance
    total_profit_loss =