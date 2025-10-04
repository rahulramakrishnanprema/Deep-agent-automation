import sqlite3
from flask import Flask, jsonify, request, render_template, session, redirect, url_for
from functools import wraps
import json
import random
from datetime import datetime, timedelta

app = Flask(__name__)
app.secret_key = 'your-secret-key-here'  # Change this in production

# Database setup
def init_db():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Create tables
    c.execute('''CREATE TABLE IF NOT EXISTS users
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  username TEXT UNIQUE NOT NULL,
                  password TEXT NOT NULL,
                  role TEXT NOT NULL DEFAULT 'client')''')
    
    c.execute('''CREATE TABLE IF NOT EXISTS portfolios
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id INTEGER,
                  stock_symbol TEXT NOT NULL,
                  quantity INTEGER NOT NULL,
                  purchase_price REAL NOT NULL,
                  purchase_date TEXT NOT NULL,
                  FOREIGN KEY (user_id) REFERENCES users (id))''')
    
    c.execute('''CREATE TABLE IF NOT EXISTS market_data
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  stock_symbol TEXT NOT NULL,
                  price REAL NOT NULL,
                  date TEXT NOT NULL,
                  volume INTEGER,
                  high REAL,
                  low REAL)''')
    
    # Create indexes
    c.execute('CREATE INDEX IF NOT EXISTS idx_portfolios_user_id ON portfolios (user_id)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_market_data_symbol ON market_data (stock_symbol)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_market_data_date ON market_data (date)')
    
    conn.commit()
    conn.close()

# Initialize database
init_db()

# Dummy data population
def populate_dummy_data():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Check if data already exists
    c.execute("SELECT COUNT(*) FROM users")
    if c.fetchone()[0] == 0:
        # Add sample users
        users = [
            ('advisor1', 'password123', 'advisor'),
            ('client1', 'password123', 'client'),
            ('client2', 'password123', 'client')
        ]
        c.executemany("INSERT INTO users (username, password, role) VALUES (?, ?, ?)", users)
        
        # Add sample portfolios
        stocks = ['RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK']
        portfolios = []
        for user_id in [2, 3]:  # client users
            for symbol in stocks:
                portfolios.append((
                    user_id,
                    symbol,
                    random.randint(10, 100),
                    round(random.uniform(1000, 5000), 2),
                    (datetime.now() - timedelta(days=random.randint(1, 365))).strftime('%Y-%m-%d')
                ))
        
        c.executemany("INSERT INTO portfolios (user_id, stock_symbol, quantity, purchase_price, purchase_date) VALUES (?, ?, ?, ?, ?)", portfolios)
        
        # Add sample market data
        market_data = []
        dates = [(datetime.now() - timedelta(days=i)).strftime('%Y-%m-%d') for i in range(30)]
        for symbol in stocks:
            base_price = random.uniform(1000, 5000)
            for date in dates:
                price = round(base_price * random.uniform(0.9, 1.1), 2)
                market_data.append((
                    symbol,
                    price,
                    date,
                    random.randint(10000, 1000000),
                    round(price * random.uniform(1.01, 1.05), 2),
                    round(price * random.uniform(0.95, 0.99), 2)
                ))
        
        c.executemany("INSERT INTO market_data (stock_symbol, price, date, volume, high, low) VALUES (?, ?, ?, ?, ?, ?)", market_data)
    
    conn.commit()
    conn.close()

populate_dummy_data()

# Authentication decorators
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({'error': 'Authentication required'}), 401
        return f(*args, **kwargs)
    return decorated_function

def advisor_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session or session.get('role') != 'advisor':
            return jsonify({'error': 'Advisor access required'}), 403
        return f(*args, **kwargs)
    return decorated_function

# Authentication routes
@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    c.execute("SELECT id, username, role FROM users WHERE username = ? AND password = ?", (username, password))
    user = c.fetchone()
    conn.close()
    
    if user:
        session['user_id'] = user[0]
        session['username'] = user[1]
        session['role'] = user[2]
        return jsonify({'message': 'Login successful', 'role': user[2]})
    else:
        return jsonify({'error': 'Invalid credentials'}), 401

@app.route('/api/logout')
def logout():
    session.clear()
    return jsonify({'message': 'Logout successful'})

# Portfolio management routes
@app.route('/api/portfolio', methods=['GET'])
@login_required
def get_portfolio():
    user_id = session['user_id']
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    if session.get('role') == 'advisor' and request.args.get('client_id'):
        user_id = request.args.get('client_id')
    
    c.execute('''SELECT p.stock_symbol, p.quantity, p.purchase_price, p.purchase_date, 
                        md.price as current_price
                 FROM portfolios p
                 LEFT JOIN market_data md ON p.stock_symbol = md.stock_symbol 
                 WHERE p.user_id = ? AND md.date = (SELECT MAX(date) FROM market_data WHERE stock_symbol = p.stock_symbol)''', (user_id,))
    
    portfolio = []
    for row in c.fetchall():
        current_value = row[1] * row[4]
        purchase_value = row[1] * row[2]
        gain_loss = current_value - purchase_value
        gain_loss_percent = (gain_loss / purchase_value) * 100 if purchase_value > 0 else 0
        
        portfolio.append({
            'symbol': row[0],
            'quantity': row[1],
            'purchase_price': row[2],
            'purchase_date': row[3],
            'current_price': row[4],
            'current_value': round(current_value, 2),
            'gain_loss': round(gain_loss, 2),
            'gain_loss_percent': round(gain_loss_percent, 2)
        })
    
    conn.close()
    return jsonify(portfolio)

@app.route('/api/portfolio', methods=['POST'])
@login_required
def add_to_portfolio():
    data = request.get_json()
    stock_symbol = data.get('symbol')
    quantity = data.get('quantity')
    purchase_price = data.get('purchase_price')
    purchase_date = data.get('purchase_date') or datetime.now().strftime('%Y-%m-%d')
    
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    c.execute("INSERT INTO portfolios (user_id, stock_symbol, quantity, purchase_price, purchase_date) VALUES (?, ?, ?, ?, ?)",
              (session['user_id'], stock_symbol, quantity, purchase_price, purchase_date))
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Stock added to portfolio'})

# Advisory signal generation
def generate_advisory_signals(user_id):
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Get user's portfolio
    c.execute('''SELECT p.stock_symbol, p.quantity, p.purchase_price, p.purchase_date, 
                        md.price as current_price
                 FROM portfolios p
                 LEFT JOIN market_data md ON p.stock_symbol = md.stock_symbol 
                 WHERE p.user_id = ? AND md.date = (SELECT MAX(date) FROM market_data WHERE stock_symbol = p.stock_symbol)''', (user_id,))
    
    portfolio = c.fetchall()
    signals = []
    
    for holding in portfolio:
        symbol = holding[0]
        quantity = holding[1]
        purchase_price = holding[2]
        current_price = holding[4]
        
        # Calculate historical performance
        c.execute('''SELECT price FROM market_data 
                     WHERE stock_symbol = ? AND date >= ?
                     ORDER BY date DESC LIMIT 30''', (symbol, holding[3]))
        historical_prices = [row[0] for row in c.fetchall()]
        
        if len(historical_prices) >= 2:
            price_change = ((current_price - historical_prices[-1]) / historical_prices[-1]) * 100
        else:
            price_change = 0
        
        # Technical indicators (simplified)
        if len(historical_prices) >= 20:
            sma_20 = sum(historical_prices[:20]) / 20
            trend = 'Bullish' if current_price > sma_20 else 'Bearish'
        else:
            trend = 'Neutral'
        
        # Sector potential (dummy implementation)
        sector_score = random.uniform(0.5, 1.5)
        
        # Market buzz (dummy implementation)
        buzz_score = random.uniform(0.7, 1.3)
        
        # Generate signal
        score = price_change * 0.3 + (1 if trend == 'Bullish' else -1) * 20 + (sector_score - 1) * 50 + (buzz_score - 1) * 30
        
        if score > 30:
            signal = 'Buy'
        elif score > -10:
            signal = 'Hold'
        else:
            signal = 'Sell'
        
        signals.append({
            'symbol': symbol,
            'signal': signal,
            'score': round(score, 2),
            'price_change': round(price_change, 2),
            'trend': trend,
            'sector_score': round(sector_score, 2),
            'buzz_score': round(buzz_score, 2),
            'reasoning': f"Price change: {round(price_change, 2)}%, Trend: {trend}, Sector potential: {round(sector_score, 2)}, Market buzz: {round(buzz_score, 2)}"
        })
    
    conn.close()
    return signals

@app.route('/api/advisory-signals', methods=['GET'])
@login_required
def get_advisory_signals():
    user_id = session['user_id']
    if session.get('role') == 'advisor' and request.args.get('client_id'):
        user_id = request.args.get('client_id')
    
    signals = generate_advisory_signals(user_id)
    return jsonify(signals)

# Advisor-only reports
@app.route('/api/advisor/reports/performance', methods=['GET'])
@advisor_required
def get_performance_report():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Get all clients
    c.execute("SELECT id, username FROM users WHERE role = 'client'")
    clients = [{'id': row[0], 'name': row[1]} for row in c.fetchall()]
    
    report_data = []
    for client in clients:
        # Get client portfolio value
        c.execute('''SELECT SUM(p.quantity * md.price) as total_value
                     FROM portfolios p
                     JOIN market_data md ON p.stock_symbol = md.stock_symbol
                     WHERE p.user_id = ? AND md.date = (SELECT MAX(date) FROM market_data)''', (client['id'],))
        total_value = c.fetchone()[0] or 0
        
        # Get portfolio cost
        c.execute('''SELECT SUM(quantity * purchase_price) as total_cost
                     FROM portfolios WHERE user_id = ?''', (client['id'],))
        total_cost = c.fetchone()[0] or 0
        
        # Calculate performance
        gain_loss = total_value - total_cost
        gain_loss_percent = (gain_loss / total_cost * 100) if total_cost > 0 else 0
        
        report_data.append({
            'client_id': client['id'],
            'client_name': client['name'],
            'portfolio_value': round(total_value, 2),
            'total_cost': round(total_cost, 2),
            'gain_loss': round(gain_loss, 2),
            'gain_loss_percent': round(gain_loss_percent, 2)
        })
    
    conn.close()
    return jsonify(report_data)

@app.route('/api/advisor/reports/sector-analysis', methods=['GET'])
@advisor_required
def get_sector_analysis():
    # Dummy sector analysis
    sectors = {
        'Technology': random.uniform(0.8, 1.2),
        'Banking': random.uniform(0.7, 1.3),
        'Energy': random.uniform(0.9, 1.1),
        'Healthcare': random.uniform(0.6, 1.4),
        'Automobile': random.uniform(0.8, 1.2)
    }
    
    return jsonify([
        {'sector': sector, 'performance_score': round(score, 2)}
        for sector, score in sectors.items()
    ])

# Frontend routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/dashboard')
@login_required
def dashboard():
    return render_template('dashboard.html', role=session.get('role'))

@app.route('/advisor-dashboard')
@advisor_required
def advisor_dashboard():
    return render_template('advisor_dashboard.html')

if __name__ == '__main__':
    app.run(debug=True)