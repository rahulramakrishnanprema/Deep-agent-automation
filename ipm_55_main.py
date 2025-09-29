# ipm_55_main.py
# Main Flask application for IPM-55 MVP portfolio management system

from flask import Flask, jsonify, request, render_template
import sqlite3
import json
from datetime import datetime, timedelta
import random

app = Flask(__name__)

# Database initialization
def init_db():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Create portfolios table
    c.execute('''CREATE TABLE IF NOT EXISTS portfolios
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  client_name TEXT NOT NULL,
                  stock_symbol TEXT NOT NULL,
                  quantity INTEGER NOT NULL,
                  purchase_price REAL NOT NULL,
                  purchase_date TEXT NOT NULL,
                  sector TEXT NOT NULL)''')
    
    # Create advisory_signals table
    c.execute('''CREATE TABLE IF NOT EXISTS advisory_signals
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  stock_symbol TEXT NOT NULL,
                  signal TEXT NOT NULL,
                  confidence_score REAL NOT NULL,
                  reasoning TEXT NOT NULL,
                  generated_date TEXT NOT NULL)''')
    
    # Create market_data table for historical performance
    c.execute('''CREATE TABLE IF NOT EXISTS market_data
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  stock_symbol TEXT NOT NULL,
                  date TEXT NOT NULL,
                  price REAL NOT NULL,
                  volume INTEGER NOT NULL)''')
    
    conn.commit()
    conn.close()

# Generate dummy data for demonstration
def generate_dummy_data():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Check if data already exists
    c.execute("SELECT COUNT(*) FROM portfolios")
    if c.fetchone()[0] == 0:
        # Sample Indian stocks
        stocks = [
            ('RELIANCE', 'Energy', 2500, 2800),
            ('INFY', 'IT', 1500, 1800),
            ('HDFCBANK', 'Banking', 1600, 1700),
            ('TCS', 'IT', 3200, 3400),
            ('ICICIBANK', 'Banking', 900, 950),
            ('SBIN', 'Banking', 550, 600),
            ('BHARTIARTL', 'Telecom', 800, 850),
            ('LT', 'Construction', 3200, 3300),
            ('HINDUNILVR', 'FMCG', 2400, 2500),
            ('ITC', 'FMCG', 420, 450)
        ]
        
        clients = ['Client A', 'Client B', 'Client C', 'Client D', 'Client E']
        
        # Insert portfolio data
        for client in clients:
            for i in range(3):
                stock = random.choice(stocks)
                c.execute('''INSERT INTO portfolios 
                          (client_name, stock_symbol, quantity, purchase_price, purchase_date, sector)
                          VALUES (?, ?, ?, ?, ?, ?)''',
                          (client, stock[0], random.randint(10, 100), 
                           random.uniform(stock[2], stock[3]),
                           (datetime.now() - timedelta(days=random.randint(30, 365))).strftime('%Y-%m-%d'),
                           stock[1]))
        
        # Generate market data
        current_date = datetime.now()
        for stock in stocks:
            base_price = random.uniform(stock[2], stock[3])
            for days_ago in range(90, 0, -1):
                date = (current_date - timedelta(days=days_ago)).strftime('%Y-%m-%d')
                price_variation = random.uniform(-0.05, 0.05)
                price = base_price * (1 + price_variation)
                volume = random.randint(100000, 1000000)
                c.execute('''INSERT INTO market_data 
                          (stock_symbol, date, price, volume)
                          VALUES (?, ?, ?, ?)''',
                          (stock[0], date, price, volume))
        
        # Generate advisory signals
        signals = ['BUY', 'HOLD', 'SELL']
        reasoning_templates = {
            'BUY': [
                'Strong technical indicators showing upward trend',
                'Sector showing strong growth potential',
                'Positive market buzz and analyst recommendations',
                'Oversold condition with high rebound potential'
            ],
            'HOLD': [
                'Market consolidation phase, wait for clearer signals',
                'Adequate performance with stable technical indicators',
                'Sector showing mixed signals, maintain position',
                'Balanced risk-reward ratio suggests holding'
            ],
            'SELL': [
                'Technical indicators showing downward trend',
                'Sector facing headwinds and negative sentiment',
                'Overbought condition with correction expected',
                'Negative market buzz and analyst downgrades'
            ]
        }
        
        for stock in stocks:
            signal = random.choice(signals)
            confidence = random.uniform(0.6, 0.95)
            reasoning = random.choice(reasoning_templates[signal])
            
            c.execute('''INSERT INTO advisory_signals 
                      (stock_symbol, signal, confidence_score, reasoning, generated_date)
                      VALUES (?, ?, ?, ?, ?)''',
                      (stock[0], signal, confidence, reasoning, current_date.strftime('%Y-%m-%d')))
    
    conn.commit()
    conn.close()

@app.route('/')
def index():
    """Serve the main HTML page"""
    return render_template('index.html')

@app.route('/api/portfolios')
def get_portfolios():
    """Get all portfolios with current market data"""
    try:
        conn = sqlite3.connect('portfolio.db')
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        c.execute('''SELECT * FROM portfolios ORDER BY client_name, stock_symbol''')
        portfolios = [dict(row) for row in c.fetchall()]
        
        # Add current price and performance data
        for portfolio in portfolios:
            c.execute('''SELECT price FROM market_data 
                      WHERE stock_symbol = ? 
                      ORDER BY date DESC LIMIT 1''',
                      (portfolio['stock_symbol'],))
            current_price_row = c.fetchone()
            if current_price_row:
                current_price = current_price_row['price']
                portfolio['current_price'] = current_price
                portfolio['value_change'] = current_price - portfolio['purchase_price']
                portfolio['percent_change'] = ((current_price - portfolio['purchase_price']) / 
                                             portfolio['purchase_price'] * 100)
        
        conn.close()
        return jsonify(portfolios)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/portfolios', methods=['POST'])
def add_portfolio():
    """Add a new portfolio entry"""
    try:
        data = request.get_json()
        conn = sqlite3.connect('portfolio.db')
        c = conn.cursor()
        
        c.execute('''INSERT INTO portfolios 
                  (client_name, stock_symbol, quantity, purchase_price, purchase_date, sector)
                  VALUES (?, ?, ?, ?, ?, ?)''',
                  (data['client_name'], data['stock_symbol'], data['quantity'],
                   data['purchase_price'], data['purchase_date'], data['sector']))
        
        conn.commit()
        conn.close()
        return jsonify({'message': 'Portfolio added successfully'}), 201
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/advisory-signals')
def get_advisory_signals():
    """Get all advisory signals"""
    try:
        conn = sqlite3.connect('portfolio.db')
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        c.execute('''SELECT * FROM advisory_signals 
                  ORDER BY generated_date DESC, confidence_score DESC''')
        signals = [dict(row) for row in c.fetchall()]
        
        conn.close()
        return jsonify(signals)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/analytics/portfolio-performance')
def get_portfolio_performance():
    """Get portfolio performance analytics (advisor only)"""
    try:
        conn = sqlite3.connect('portfolio.db')
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        # Get total portfolio value by client
        c.execute('''SELECT client_name, 
                     SUM(quantity * purchase_price) as initial_value,
                     SUM(quantity * (SELECT price FROM market_data 
                                   WHERE stock_symbol = portfolios.stock_symbol 
                                   ORDER BY date DESC LIMIT 1)) as current_value
                     FROM portfolios
                     GROUP BY client_name''')
        
        performance_data = []
        for row in c.fetchall():
            initial_value = row['initial_value']
            current_value = row['current_value']
            performance_data.append({
                'client_name': row['client_name'],
                'initial_value': initial_value,
                'current_value': current_value,
                'absolute_return': current_value - initial_value,
                'percent_return': ((current_value - initial_value) / initial_value * 100) if initial_value else 0
            })
        
        conn.close()
        return jsonify(performance_data)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/analytics/sector-performance')
def get_sector_performance():
    """Get sector-wise performance analytics (advisor only)"""
    try:
        conn = sqlite3.connect('portfolio.db')
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        # Get sector performance data
        c.execute('''SELECT sector,
                     SUM(quantity * purchase_price) as initial_value,
                     SUM(quantity * (SELECT price FROM market_data 
                                   WHERE stock_symbol = portfolios.stock_symbol 
                                   ORDER BY date DESC LIMIT 1)) as current_value
                     FROM portfolios
                     GROUP BY sector''')
        
        sector_data = []
        for row in c.fetchall():
            initial_value = row['initial_value']
            current_value = row['current_value']
            sector_data.append({
                'sector': row['sector'],
                'initial_value': initial_value,
                'current_value': current_value,
                'absolute_return': current_value - initial_value,
                'percent_return': ((current_value - initial_value) / initial_value * 100) if initial_value else 0
            })
        
        conn.close()
        return jsonify(sector_data)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/analytics/stock-performance')
def get_stock_performance():
    """Get stock-wise performance analytics (advisor only)"""
    try:
        conn = sqlite3.connect('portfolio.db')
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        # Get stock performance data
        c.execute('''SELECT stock_symbol, sector,
                     SUM(quantity * purchase_price) as initial_value,
                     SUM(quantity * (SELECT price FROM market_data 
                                   WHERE stock_symbol = portfolios.stock_symbol 
                                   ORDER BY date DESC LIMIT 1)) as current_value
                     FROM portfolios
                     GROUP BY stock_symbol, sector''')
        
        stock_data = []
        for row in c.fetchall():
            initial_value = row['initial_value']
            current_value = row['current_value']
            stock_data.append({
                'stock_symbol': row['stock_symbol'],
                'sector': row['sector'],
                'initial_value': initial_value,
                'current_value': current_value,
                'absolute_return': current_value - initial_value,
                'percent_return': ((current_value - initial_value) / initial_value * 100) if initial_value else 0
            })
        
        conn.close()
        return jsonify(stock_data)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/market-data/<stock_symbol>')
def get_market_data(stock_symbol):
    """Get historical market data for a specific stock"""
    try:
        conn = sqlite3.connect('portfolio.db')
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        c.execute('''SELECT date, price, volume FROM market_data 
                  WHERE stock_symbol = ? 
                  ORDER BY date''', (stock_symbol,))
        
        market_data = [dict(row) for row in c.fetchall()]
        conn.close()
        return jsonify(market_data)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    # Initialize database and generate dummy data
    init_db()
    generate_dummy_data()
    
    # Run the Flask application
    app.run(debug=True, host='0.0.0.0', port=5000)