# ipm_55_main.py
"""
Main application file for the Indian Portfolio Manager MVP.
This Flask application serves as the backend for managing client stock portfolios,
generating advisory signals, and providing visual reports for advisors.
"""

from flask import Flask, jsonify, request, render_template
from flask_cors import CORS
import sqlite3
import json
from datetime import datetime, timedelta
import random
import math

app = Flask(__name__)
CORS(app)  # Enable CORS for frontend-backend communication

# Database initialization
def init_db():
    """Initialize SQLite database with required tables."""
    conn = sqlite3.connect('portfolio.db')
    cursor = conn.cursor()
    
    # Create portfolio table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS portfolios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_name TEXT NOT NULL,
        stock_symbol TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        purchase_price REAL NOT NULL,
        purchase_date TEXT NOT NULL,
        sector TEXT NOT NULL
    )
    ''')
    
    # Create market_data table for technical indicators
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS market_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_symbol TEXT NOT NULL,
        date TEXT NOT NULL,
        open_price REAL NOT NULL,
        high_price REAL NOT NULL,
        low_price REAL NOT NULL,
        close_price REAL NOT NULL,
        volume INTEGER NOT NULL
    )
    ''')
    
    # Create advisory_signals table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS advisory_signals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_symbol TEXT NOT NULL,
        signal TEXT NOT NULL,
        confidence_score REAL NOT NULL,
        generated_date TEXT NOT NULL,
        reasoning TEXT NOT NULL
    )
    ''')
    
    conn.commit()
    conn.close()

# Dummy data population
def populate_dummy_data():
    """Populate database with dummy data for demonstration."""
    conn = sqlite3.connect('portfolio.db')
    cursor = conn.cursor()
    
    # Check if data already exists
    cursor.execute("SELECT COUNT(*) FROM portfolios")
    if cursor.fetchone()[0] == 0:
        # Sample portfolio data
        portfolios = [
            ('Client A', 'RELIANCE', 10, 2450.50, '2023-01-15', 'Energy'),
            ('Client A', 'HDFCBANK', 5, 1650.75, '2023-02-20', 'Financial'),
            ('Client B', 'INFY', 8, 1850.25, '2023-03-10', 'IT'),
            ('Client B', 'TCS', 6, 3250.00, '2023-01-25', 'IT'),
            ('Client C', 'HINDUNILVR', 12, 2550.30, '2023-04-05', 'FMCG')
        ]
        
        cursor.executemany('''
        INSERT INTO portfolios (client_name, stock_symbol, quantity, purchase_price, purchase_date, sector)
        VALUES (?, ?, ?, ?, ?, ?)
        ''', portfolios)
        
        # Generate sample market data for the last 30 days
        symbols = ['RELIANCE', 'HDFCBANK', 'INFY', 'TCS', 'HINDUNILVR']
        market_data = []
        
        for symbol in symbols:
            base_price = random.uniform(1000, 3500)
            for i in range(30):
                date = (datetime.now() - timedelta(days=30-i)).strftime('%Y-%m-%d')
                open_price = base_price * random.uniform(0.95, 1.05)
                high_price = open_price * random.uniform(1.01, 1.08)
                low_price = open_price * random.uniform(0.92, 0.99)
                close_price = random.uniform(low_price, high_price)
                volume = random.randint(100000, 1000000)
                
                market_data.append((
                    symbol, date, open_price, high_price, low_price, close_price, volume
                ))
        
        cursor.executemany('''
        INSERT INTO market_data (stock_symbol, date, open_price, high_price, low_price, close_price, volume)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', market_data)
        
        conn.commit()
    
    conn.close()

# Technical Indicators Calculation
def calculate_sma(symbol, period=14):
    """Calculate Simple Moving Average for a stock."""
    conn = sqlite3.connect('portfolio.db')
    cursor = conn.cursor()
    
    cursor.execute('''
    SELECT close_price FROM market_data 
    WHERE stock_symbol = ? 
    ORDER BY date DESC LIMIT ?
    ''', (symbol, period))
    
    prices = [row[0] for row in cursor.fetchall()]
    conn.close()
    
    if len(prices) < period:
        return None
    
    return sum(prices) / period

def calculate_rsi(symbol, period=14):
    """Calculate Relative Strength Index for a stock."""
    conn = sqlite3.connect('portfolio.db')
    cursor = conn.cursor()
    
    cursor.execute('''
    SELECT close_price FROM market_data 
    WHERE stock_symbol = ? 
    ORDER BY date DESC LIMIT ?
    ''', (symbol, period + 1))
    
    prices = [row[0] for row in cursor.fetchall()]
    conn.close()
    
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

def calculate_macd(symbol, fast_period=12, slow_period=26, signal_period=9):
    """Calculate MACD indicator for a stock."""
    conn = sqlite3.connect('portfolio.db')
    cursor = conn.cursor()
    
    cursor.execute('''
    SELECT close_price FROM market_data 
    WHERE stock_symbol = ? 
    ORDER BY date DESC LIMIT ?
    ''', (symbol, slow_period + signal_period))
    
    prices = [row[0] for row in cursor.fetchall()]
    conn.close()
    
    if len(prices) < slow_period + signal_period:
        return None, None, None
    
    # Calculate EMAs
    def calculate_ema(prices, period):
        multiplier = 2 / (period + 1)
        ema = prices[0]
        
        for price in prices[1:]:
            ema = (price - ema) * multiplier + ema
        
        return ema
    
    fast_ema = calculate_ema(prices[:fast_period][::-1], fast_period)
    slow_ema = calculate_ema(prices[:slow_period][::-1], slow_period)
    
    macd_line = fast_ema - slow_ema
    signal_line = calculate_ema(prices[:signal_period][::-1], signal_period)
    histogram = macd_line - signal_line
    
    return macd_line, signal_line, histogram

# Advisory Signal Generation
def generate_advisory_signal(symbol):
    """Generate Buy/Hold/Sell signal based on technical indicators."""
    sma = calculate_sma(symbol)
    rsi = calculate_rsi(symbol)
    macd_line, signal_line, histogram = calculate_macd(symbol)
    
    if sma is None or rsi is None or macd_line is None:
        return "HOLD", 0.5, "Insufficient data for analysis"
    
    score = 0
    reasoning = []
    
    # SMA analysis
    current_price = get_current_price(symbol)
    if current_price > sma * 1.05:
        score += 1
        reasoning.append("Price above SMA")
    elif current_price < sma * 0.95:
        score -= 1
        reasoning.append("Price below SMA")
    
    # RSI analysis
    if rsi > 70:
        score -= 1
        reasoning.append("RSI indicates overbought")
    elif rsi < 30:
        score += 1
        reasoning.append("RSI indicates oversold")
    
    # MACD analysis
    if macd_line > signal_line and histogram > 0:
        score += 1
        reasoning.append("MACD bullish")
    elif macd_line < signal_line and histogram < 0:
        score -= 1
        reasoning.append("MACD bearish")
    
    # Determine signal
    if score >= 2:
        signal = "BUY"
        confidence = min(0.9, 0.5 + score * 0.1)
    elif score <= -2:
        signal = "SELL"
        confidence = min(0.9, 0.5 + abs(score) * 0.1)
    else:
        signal = "HOLD"
        confidence = 0.5
    
    return signal, confidence, "; ".join(reasoning)

def get_current_price(symbol):
    """Get the most recent price for a symbol."""
    conn = sqlite3.connect('portfolio.db')
    cursor = conn.cursor()
    
    cursor.execute('''
    SELECT close_price FROM market_data 
    WHERE stock_symbol = ? 
    ORDER BY date DESC LIMIT 1
    ''', (symbol,))
    
    result = cursor.fetchone()
    conn.close()
    
    return result[0] if result else None

# Sector Potential Evaluation
def evaluate_sector_potential():
    """Evaluate potential of different sectors."""
    sectors = ['Energy', 'Financial', 'IT', 'FMCG', 'Healthcare', 'Automobile']
    sector_scores = {}
    
    for sector in sectors:
        # Simple scoring based on random factors for demo
        score = random.uniform(0.3, 0.9)
        sector_scores[sector] = {
            'score': score,
            'outlook': 'Bullish' if score > 0.6 else 'Neutral' if score > 0.4 else 'Bearish'
        }
    
    return sector_scores

# Market Buzz Integration (simulated)
def get_market_buzz():
    """Get simulated market sentiment data."""
    buzz_topics = [
        "RBI policy announcement expected",
        "IT sector showing strong growth",
        "Energy sector reforms underway",
        "FMCG demand rising in urban areas",
        "Banking sector NPA concerns"
    ]
    
    return random.sample(buzz_topics, 3)

# Portfolio Analysis
def analyze_portfolio_performance(client_name):
    """Analyze historical performance of a client's portfolio."""
    conn = sqlite3.connect('portfolio.db')
    cursor = conn.cursor()
    
    cursor.execute('''
    SELECT stock_symbol, quantity, purchase_price, purchase_date 
    FROM portfolios WHERE client_name = ?
    ''', (client_name,))
    
    holdings = cursor.fetchall()
    performance_data = []
    total_investment = 0
    total_current_value = 0
    
    for holding in holdings:
        symbol, quantity, purchase_price, purchase_date = holding
        current_price = get_current_price(symbol)
        
        if current_price is not None:
            investment = quantity * purchase_price
            current_value = quantity * current_price
            gain_loss = current_value - investment
            gain_loss_percent = (gain_loss / investment) * 100 if investment > 0 else 0
            
            total_investment += investment
            total_current_value += current_value
            
            performance_data.append({
                'symbol': symbol,
                'quantity': quantity,
                'purchase_price': purchase_price,
                'current_price': current_price,
                'investment': investment,
                'current_value': current_value,
                'gain_loss': gain_loss,
                'gain_loss_percent': gain_loss_percent
            })
    
    conn.close()
    
    overall_gain_loss = total_current_value - total_investment
    overall_gain_loss_percent = (overall_gain_loss / total_investment) * 100 if total_investment > 0 else 0
    
    return {
        'holdings': performance_data,
        'summary': {
            'total_investment': total_investment,
            'total_current_value': total_current_value,
            'overall_gain_loss': overall_gain_loss,
            'overall_gain_loss_percent': overall_gain_loss_percent
        }
    }

# API Routes
@app.route('/')
def index():
    """Serve the main dashboard page."""
    return render_template('index.html')

@app.route('/api/portfolio/<client_name>')
def get_portfolio(client_name):
    """Get portfolio details for a specific client."""
    conn = sqlite3.connect('portfolio.db')
    cursor = conn.cursor()
    
    cursor.execute('''
    SELECT stock_symbol, quantity, purchase_price, purchase_date, sector 
    FROM portfolios WHERE client_name = ?
    ''', (client_name,))
    
    holdings = []
    for row in cursor.fetchall():
        symbol, quantity, price, date, sector = row
        current_price = get_current_price(symbol)
        signal, confidence, reasoning = generate_advisory_signal(symbol)
        
        holdings.append({
            'symbol': symbol,
            'quantity': quantity,
            'purchase_price': price,
            'purchase_date': date,
            'sector': sector,
            'current_price': current_price,
            'signal': signal,
            'confidence': confidence,
            'reasoning': reasoning
        })
    
    conn.close()
    return jsonify({'client': client_name, 'holdings': holdings})

@app.route('/api/portfolio/performance/<client_name>')
def get_portfolio_performance(client_name):
    """Get performance analysis for a client's portfolio."""
    performance = analyze_portfolio_performance(client_name)
    return jsonify(performance)

@app.route('/api/sector-analysis')
def get_sector_analysis():
    """Get sector potential evaluation."""
    sector_scores = evaluate_sector_potential()
    return jsonify(sector_scores)

@app.route('/api/market-buzz')
def get_market_buzz_api():
    """Get market buzz/sentiment data."""
    buzz = get_market_buzz()
    return jsonify({'buzz_topics': buzz})

@app.route('/api/advisory-signals')
def get_advisory_signals():
    """Get advisory signals for all stocks in portfolio."""
    conn = sqlite3.connect('portfolio.db')
    cursor = conn.cursor()
    
    cursor.execute('SELECT DISTINCT stock_symbol FROM portfolios')
    symbols = [row[0] for row in cursor.fetchall()]
    conn.close()
    
    signals = []
    for symbol in symbols:
        signal, confidence, reasoning = generate_advisory_signal(symbol)
        signals.append({
            'symbol': symbol,
            'signal': signal,
            'confidence': confidence,
            'reasoning': reasoning,
            'timestamp': datetime.now().isoformat()
        })
    
    return jsonify({'signals': signals})

@app.route('/api/technical-indicators/<symbol>')
def get_technical_indicators(symbol):
    """Get technical indicators for a specific stock."""
    sma = calculate_sma(symbol)
    rsi = calculate_rsi(symbol)
    macd_line, signal_line, histogram = calculate_macd(symbol)
    current_price = get_current_price(symbol)
    
    return jsonify({
        'symbol': symbol,
        'current_price': current_price,
        'sma': sma,
        'rsi': rsi,
        'macd': {
            'macd_line': macd_line,
            'signal_line': signal_line,
            'histogram': histogram
        }
    })

# Error handling
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Resource not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

# Main application entry point
if __name__ == '__main__':
    init_db()
    populate_dummy_data()
    app.run(debug=True, host='0.0.0.0', port=5000)