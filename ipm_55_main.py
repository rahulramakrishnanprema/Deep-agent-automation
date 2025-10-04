import os
import json
import sqlite3
from datetime import datetime, timedelta
from flask import Flask, render_template, jsonify, request, session, redirect, url_for
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
import yfinance as yf
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
import io
import base64
from functools import wraps

app = Flask(__name__)
app.secret_key = 'your-secret-key-here'
app.config['SQLITE_DB'] = 'portfolio_management.db'

# Initialize login manager
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# Database setup
def init_db():
    """Initialize the SQLite database with required tables"""
    conn = sqlite3.connect(app.config['SQLITE_DB'])
    cursor = conn.cursor()
    
    # Users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'client',
            email TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Stocks table (Indian equity focus)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS stocks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            sector TEXT NOT NULL,
            exchange TEXT DEFAULT 'NSE',
            current_price REAL,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Portfolio table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS portfolio (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            stock_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            purchase_price REAL NOT NULL,
            purchase_date DATE NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (stock_id) REFERENCES stocks (id)
        )
    ''')
    
    # Advisory signals table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS advisory_signals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stock_id INTEGER NOT NULL,
            signal_type TEXT NOT NULL,
            confidence_score REAL,
            reasoning TEXT,
            generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            valid_until TIMESTAMP,
            FOREIGN KEY (stock_id) REFERENCES stocks (id)
        )
    ''')
    
    # User roles table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_roles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            role_name TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    conn.commit()
    conn.close()

# User class for Flask-Login
class User(UserMixin):
    def __init__(self, id, username, role):
        self.id = id
        self.username = username
        self.role = role

@login_manager.user_loader
def load_user(user_id):
    conn = sqlite3.connect(app.config['SQLITE_DB'])
    cursor = conn.cursor()
    cursor.execute('SELECT id, username, role FROM users WHERE id = ?', (user_id,))
    user_data = cursor.fetchone()
    conn.close()
    
    if user_data:
        return User(user_data[0], user_data[1], user_data[2])
    return None

def role_required(role):
    """Decorator to require specific role for access"""
    def decorator(f):
        @wraps(f)
        @login_required
        def decorated_function(*args, **kwargs):
            if current_user.role != role:
                return jsonify({'error': 'Access denied'}), 403
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def generate_dummy_data():
    """Generate dummy data for Indian equity markets"""
    conn = sqlite3.connect(app.config['SQLITE_DB'])
    cursor = conn.cursor()
    
    # Indian stocks data
    indian_stocks = [
        ('RELIANCE', 'Reliance Industries Ltd', 'Energy', 2750.50),
        ('TCS', 'Tata Consultancy Services Ltd', 'IT', 3850.75),
        ('HDFCBANK', 'HDFC Bank Ltd', 'Banking', 1650.25),
        ('INFY', 'Infosys Ltd', 'IT', 1850.30),
        ('ICICIBANK', 'ICICI Bank Ltd', 'Banking', 950.40),
        ('HINDUNILVR', 'Hindustan Unilever Ltd', 'FMCG', 2450.60),
        ('SBIN', 'State Bank of India', 'Banking', 650.15),
        ('BHARTIARTL', 'Bharti Airtel Ltd', 'Telecom', 850.80),
        ('ITC', 'ITC Ltd', 'FMCG', 450.25),
        ('AXISBANK', 'Axis Bank Ltd', 'Banking', 1050.35)
    ]
    
    # Insert stocks
    for symbol, name, sector, price in indian_stocks:
        cursor.execute('''
            INSERT OR IGNORE INTO stocks (symbol, name, sector, current_price)
            VALUES (?, ?, ?, ?)
        ''', (symbol, name, sector, price))
    
    # Create demo users
    demo_users = [
        ('advisor', 'advisor123', 'advisor', 'advisor@example.com'),
        ('client', 'client123', 'client', 'client@example.com')
    ]
    
    for username, password, role, email in demo_users:
        cursor.execute('''
            INSERT OR IGNORE INTO users (username, password, role, email)
            VALUES (?, ?, ?, ?)
        ''', (username, password, role, email))
    
    # Get user IDs
    cursor.execute('SELECT id FROM users WHERE username = "client"')
    client_id = cursor.fetchone()[0]
    
    # Create sample portfolio for client
    for i, (symbol, _, _, _) in enumerate(indian_stocks[:5]):
        cursor.execute('SELECT id FROM stocks WHERE symbol = ?', (symbol,))
        stock_id = cursor.fetchone()[0]
        
        cursor.execute('''
            INSERT INTO portfolio (user_id, stock_id, quantity, purchase_price, purchase_date)
            VALUES (?, ?, ?, ?, ?)
        ''', (client_id, stock_id, (i+1)*10, price * 0.9, 
              (datetime.now() - timedelta(days=30+i*5)).strftime('%Y-%m-%d')))
    
    conn.commit()
    conn.close()

def calculate_technical_indicators(symbol, period='1y'):
    """Calculate technical indicators for a stock"""
    try:
        # Add .NS suffix for NSE stocks
        stock_data = yf.download(f'{symbol}.NS', period=period)
        
        if stock_data.empty:
            return {}
        
        # Calculate SMA
        stock_data['SMA_50'] = stock_data['Close'].rolling(window=50).mean()
        stock_data['SMA_200'] = stock_data['Close'].rolling(window=200).mean()
        
        # Calculate RSI
        delta = stock_data['Close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        stock_data['RSI'] = 100 - (100 / (1 + rs))
        
        # Calculate MACD
        exp12 = stock_data['Close'].ewm(span=12, adjust=False).mean()
        exp26 = stock_data['Close'].ewm(span=26, adjust=False).mean()
        stock_data['MACD'] = exp12 - exp26
        stock_data['Signal_Line'] = stock_data['MACD'].ewm(span=9, adjust=False).mean()
        
        latest_data = stock_data.iloc[-1]
        
        return {
            'sma_50': latest_data['SMA_50'],
            'sma_200': latest_data['SMA_200'],
            'rsi': latest_data['RSI'],
            'macd': latest_data['MACD'],
            'signal_line': latest_data['Signal_Line'],
            'current_price': latest_data['Close']
        }
    except Exception as e:
        print(f"Error calculating technical indicators for {symbol}: {e}")
        return {}

def analyze_sector_potential(sector):
    """Analyze sector potential for Indian markets"""
    sector_analysis = {
        'IT': {'potential': 'High', 'growth_outlook': 'Positive', 'reasoning': 'Digital transformation driving demand'},
        'Banking': {'potential': 'Medium', 'growth_outlook': 'Stable', 'reasoning': 'Economic recovery supporting credit growth'},
        'Energy': {'potential': 'Medium', 'growth_outlook': 'Moderate', 'reasoning': 'Renewable energy transition ongoing'},
        'FMCG': {'potential': 'High', 'growth_outlook': 'Positive', 'reasoning': 'Consumption growth in rural markets'},
        'Telecom': {'potential': 'Low', 'growth_outlook': 'Challenged', 'reasoning': 'Intense competition and ARPU pressure'}
    }
    return sector_analysis.get(sector, {'potential': 'Unknown', 'growth_outlook': 'Unknown', 'reasoning': 'No data available'})

def analyze_market_sentiment(symbol):
    """Simple market sentiment analysis based on recent performance"""
    try:
        stock_data = yf.download(f'{symbol}.NS', period='1mo')
        
        if stock_data.empty:
            return 'Neutral'
        
        price_change = (stock_data['Close'].iloc[-1] - stock_data['Close'].iloc[0]) / stock_data['Close'].iloc[0] * 100
        
        if price_change > 5:
            return 'Positive'
        elif price_change < -5:
            return 'Negative'
        else:
            return 'Neutral'
            
    except Exception as e:
        print(f"Error analyzing market sentiment for {symbol}: {e}")
        return 'Neutral'

def generate_advisory_signal(stock_id):
    """Generate advisory signal based on multiple factors"""
    conn = sqlite3.connect(app.config['SQLITE_DB'])
    cursor = conn.cursor()
    
    cursor.execute('SELECT symbol, sector FROM stocks WHERE id = ?', (stock_id,))
    stock_data = cursor.fetchone()
    
    if not stock_data:
        return None
    
    symbol, sector = stock_data
    
    # Get technical indicators
    technicals = calculate_technical_indicators(symbol)
    
    if not technicals:
        return None
    
    # Analyze sector potential
    sector_analysis = analyze_sector_potential(sector)
    
    # Analyze market sentiment
    sentiment = analyze_market_sentiment(symbol)
    
    # Generate signal based on rules
    signal_score = 0
    reasoning = []
    
    # Technical analysis (50%)
    if technicals['current_price'] > technicals['sma_50']:
        signal_score += 0.3
        reasoning.append("Price above 50-day SMA")
    else:
        signal_score -= 0.3
        reasoning.append("Price below 50-day SMA")
    
    if technicals['rsi'] < 30:
        signal_score += 0.2
        reasoning.append("RSI indicates oversold")
    elif technicals['rsi'] > 70:
        signal_score -= 0.2
        reasoning.append("RSI indicates overbought")
    
    # Sector analysis (30%)
    if sector_analysis['potential'] == 'High':
        signal_score += 0.3
        reasoning.append(f"{sector} sector has high growth potential")
    elif sector_analysis['potential'] == 'Low':
        signal_score -= 0.3
        reasoning.append(f"{sector} sector has low growth potential")
    
    # Market sentiment (20%)
    if sentiment == 'Positive':
        signal_score += 0.2
        reasoning.append("Positive market sentiment")
    elif sentiment == 'Negative':
        signal_score -= 0.2
        reasoning.append("Negative market sentiment")
    
    # Determine final signal
    if signal_score >= 0.3:
        signal_type = 'Buy'
        confidence = min(100, int((signal_score + 1) * 50))
    elif signal_score <= -0.3:
        signal_type = 'Sell'
        confidence = min(100, int((1 - signal_score) * 50))
    else:
        signal_type = 'Hold'
        confidence = 50
    
    # Store signal in database
    valid_until = (datetime.now() + timedelta(days=7)).strftime('%Y-%m-%d %H:%M:%S')
    
    cursor.execute('''
        INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, reasoning, valid_until)
        VALUES (?, ?, ?, ?, ?)
    ''', (stock_id, signal_type, confidence, ' | '.join(reasoning), valid_until))
    
    conn.commit()
    conn.close()
    
    return {
        'signal': signal_type,
        'confidence': confidence,
        'reasoning': reasoning,
        'valid_until': valid_until
    }

def create_visualization(portfolio_data):
    """Create visualization for portfolio reports"""
    plt.figure(figsize=(12, 8))
    
    # Sector allocation pie chart
    sector_allocation = {}
    for item in portfolio_data:
        sector = item['sector']
        value = item['current_value']
        sector_allocation[sector] = sector_allocation.get(sector, 0) + value
    
    plt.subplot(2, 2, 1)
    plt.pie(sector_allocation.values(), labels=sector_allocation.keys(), autopct='%1.1f%%')
    plt.title('Sector Allocation')
    
    # Performance line chart
    plt.subplot(2, 2, 2)
    symbols = [item['symbol'] for item in portfolio_data]
    performance_data = []
    
    for symbol in symbols:
        try:
            stock_history = yf.download(f'{symbol}.NS', period='3mo')
            if not stock_history.empty:
                performance_data.append({
                    'symbol': symbol,
                    'performance': (stock_history['Close'].iloc[-1] - stock_history['Close'].iloc[0]) / stock_history['Close'].iloc[0] * 100
                })
        except:
            continue
    
    if performance_data:
        performance_df = pd.DataFrame(performance_data)
        plt.bar(performance_df['symbol'], performance_df['performance'])
        plt.title('3-Month Performance (%)')
        plt.xticks(rotation=45)
    
    # Risk-return scatter plot
    plt.subplot(2, 2, 3)
    risk_return_data = []
    
    for symbol in symbols:
        try:
            stock_history = yf.download(f'{symbol}.NS', period='3mo')
            if len(stock_history) > 1:
                returns = stock_history['Close'].pct_change().dropna()
                risk_return_data.append({
                    'symbol': symbol,
                    'return': returns.mean() * 100,
                    'risk': returns.std() * 100
                })
        except:
            continue
    
    if risk_return_data:
        risk_return_df = pd.DataFrame(risk_return_data)
        plt.scatter(risk_return_df['risk'], risk_return_df['return'])
        for i, row in risk_return_df.iterrows():
            plt.annotate(row['symbol'], (row['risk'], row['return']))
        plt.xlabel('Risk (Std Dev %)')
        plt.ylabel('Return (%)')
        plt.title('Risk-Return Profile')
    
    plt.tight_layout()
    
    # Save plot to bytes buffer
    buf = io.BytesIO()
    plt.savefig(buf, format='png', dpi=100)
    buf.seek(0)
    
    # Encode plot to base64
    plot_data = base64.b64encode(buf.getvalue()).decode('utf-8')
    buf.close()
    
    return plot_data

# Routes
@app.route('/')
def home():
    if current_user.is_authenticated:
        if current_user.role == 'advisor':
            return redirect(url_for('advisor_dashboard'))
        else:
            return redirect(url_for('client_portfolio'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        conn = sqlite3.connect(app.config['SQLITE_DB'])
        cursor = conn.cursor()
        cursor.execute('SELECT id, username, password, role FROM users WHERE username = ?', (username,))
        user_data = cursor.fetchone()
        conn.close()
        
        if user_data and user_data[2] == password:  # Simple password check
            user = User(user_data[0], user_data[1], user_data[3])
            login_user(user)
            return redirect(url_for('home'))
        
        return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

@app.route('/client/portfolio')
@login_required
@role_required('client')
def client_portfolio():
    conn = sqlite3.connect(app.config['SQLITE_DB'])
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT p.id, s.symbol, s.name, s.sector, p.quantity, p.purchase_price, 
               s.current_price, p.purchase_date
        FROM portfolio p
        JOIN stocks s ON p.stock_id = s.id
        WHERE p.user_id = ?
    ''', (current_user.id,))
    
    portfolio_items = []
    total_investment = 0
    total_current = 0
    
    for item in cursor.fetchall():
        current_value = item[5] *