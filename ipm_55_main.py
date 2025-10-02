# ipm_55_main.py
# Main application entry point for Investment Portfolio Management MVP

from flask import Flask, render_template, jsonify, request, session, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func
import pandas as pd
import numpy as np
import yfinance as yf
from datetime import datetime, timedelta
import json
import os
from functools import wraps

# Initialize Flask application
app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key-123')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///portfolio.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize database
db = SQLAlchemy(app)

# Database Models
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    role = db.Column(db.String(20), default='user')  # 'user' or 'advisor'
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    portfolios = db.relationship('Portfolio', backref='user', lazy=True)

class Portfolio(db.Model):
    __tablename__ = 'portfolios'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    holdings = db.relationship('PortfolioHolding', backref='portfolio', lazy=True)

class PortfolioHolding(db.Model):
    __tablename__ = 'portfolio_holdings'
    id = db.Column(db.Integer, primary_key=True)
    portfolio_id = db.Column(db.Integer, db.ForeignKey('portfolios.id'), nullable=False)
    symbol = db.Column(db.String(20), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    purchase_price = db.Column(db.Float, nullable=False)
    purchase_date = db.Column(db.DateTime, default=datetime.utcnow)
    sector = db.Column(db.String(50))

class EquityData(db.Model):
    __tablename__ = 'equity_data'
    id = db.Column(db.Integer, primary_key=True)
    symbol = db.Column(db.String(20), nullable=False)
    name = db.Column(db.String(100))
    sector = db.Column(db.String(50))
    current_price = db.Column(db.Float)
    previous_close = db.Column(db.Float)
    volume = db.Column(db.Integer)
    market_cap = db.Column(db.Float)
    last_updated = db.Column(db.DateTime, default=datetime.utcnow)

class AdvisorySignal(db.Model):
    __tablename__ = 'advisory_signals'
    id = db.Column(db.Integer, primary_key=True)
    symbol = db.Column(db.String(20), nullable=False)
    signal = db.Column(db.String(10), nullable=False)  # BUY, HOLD, SELL
    confidence = db.Column(db.Float)  # 0.0 to 1.0
    reasoning = db.Column(db.Text)
    generated_at = db.Column(db.DateTime, default=datetime.utcnow)
    technical_indicators = db.Column(db.Text)  # JSON string of indicator values

# Technical Indicators Calculator
class TechnicalIndicators:
    @staticmethod
    def calculate_rsi(prices, period=14):
        """Calculate Relative Strength Index"""
        deltas = np.diff(prices)
        seed = deltas[:period+1]
        up = seed[seed >= 0].sum() / period
        down = -seed[seed < 0].sum() / period
        rs = up / down
        rsi = np.zeros_like(prices)
        rsi[:period] = 100. - 100. / (1. + rs)

        for i in range(period, len(prices)):
            delta = deltas[i - 1]
            if delta > 0:
                up_val = delta
                down_val = 0.
            else:
                up_val = 0.
                down_val = -delta

            up = (up * (period - 1) + up_val) / period
            down = (down * (period - 1) + down_val) / period
            rs = up / down
            rsi[i] = 100. - 100. / (1. + rs)

        return rsi

    @staticmethod
    def calculate_macd(prices, fast_period=12, slow_period=26, signal_period=9):
        """Calculate MACD indicator"""
        fast_ema = pd.Series(prices).ewm(span=fast_period).mean()
        slow_ema = pd.Series(prices).ewm(span=slow_period).mean()
        macd = fast_ema - slow_ema
        signal = macd.ewm(span=signal_period).mean()
        histogram = macd - signal
        
        return {
            'macd': macd.tolist(),
            'signal': signal.tolist(),
            'histogram': histogram.tolist()
        }

    @staticmethod
    def calculate_moving_averages(prices, periods=[20, 50, 200]):
        """Calculate multiple moving averages"""
        ma_results = {}
        for period in periods:
            ma_results[f'ma_{period}'] = pd.Series(prices).rolling(window=period).mean().tolist()
        return ma_results

# Advisory Signal Generator
class AdvisorySignalGenerator:
    def __init__(self):
        self.indicators_calculator = TechnicalIndicators()
    
    def generate_signal(self, symbol, historical_data):
        """Generate Buy/Hold/Sell signal based on technical indicators"""
        prices = historical_data['Close'].tolist()
        
        # Calculate technical indicators
        rsi = self.indicators_calculator.calculate_rsi(prices)
        macd_data = self.indicators_calculator.calculate_macd(prices)
        moving_averages = self.indicators_calculator.calculate_moving_averages(prices)
        
        # Get current values
        current_rsi = rsi[-1] if len(rsi) > 0 else 50
        current_price = prices[-1] if len(prices) > 0 else 0
        ma_20 = moving_averages['ma_20'][-1] if len(moving_averages['ma_20']) > 0 else current_price
        ma_50 = moving_averages['ma_50'][-1] if len(moving_averages['ma_50']) > 0 else current_price
        
        # Signal generation logic
        signal = "HOLD"
        confidence = 0.5
        reasoning = []
        
        # RSI-based signals
        if current_rsi < 30:
            signal = "BUY"
            confidence += 0.2
            reasoning.append("Oversold condition (RSI < 30)")
        elif current_rsi > 70:
            signal = "SELL"
            confidence += 0.2
            reasoning.append("Overbought condition (RSI > 70)")
        
        # Moving average crossover
        if current_price > ma_20 > ma_50:
            signal = "BUY"
            confidence += 0.15
            reasoning.append("Bullish moving average crossover")
        elif current_price < ma_20 < ma_50:
            signal = "SELL"
            confidence += 0.15
            reasoning.append("Bearish moving average crossover")
        
        # MACD signal
        if macd_data['macd'][-1] > macd_data['signal'][-1] and macd_data['histogram'][-1] > 0:
            signal = "BUY"
            confidence += 0.1
            reasoning.append("MACD bullish crossover")
        elif macd_data['macd'][-1] < macd_data['signal'][-1] and macd_data['histogram'][-1] < 0:
            signal = "SELL"
            confidence += 0.1
            reasoning.append("MACD bearish crossover")
        
        # Confidence clamping
        confidence = max(0.1, min(0.95, confidence))
        
        return {
            'symbol': symbol,
            'signal': signal,
            'confidence': confidence,
            'reasoning': '; '.join(reasoning),
            'technical_indicators': {
                'rsi': current_rsi,
                'macd': macd_data['macd'][-1],
                'signal_line': macd_data['signal'][-1],
                'ma_20': ma_20,
                'ma_50': ma_50
            }
        }

# Dummy Data Generator for Indian Equities
class DummyDataGenerator:
    def __init__(self):
        self.indian_equities = [
            {'symbol': 'RELIANCE.NS', 'name': 'Reliance Industries Ltd', 'sector': 'Energy'},
            {'symbol': 'TCS.NS', 'name': 'Tata Consultancy Services Ltd', 'sector': 'IT'},
            {'symbol': 'HDFCBANK.NS', 'name': 'HDFC Bank Ltd', 'sector': 'Banking'},
            {'symbol': 'INFY.NS', 'name': 'Infosys Ltd', 'sector': 'IT'},
            {'symbol': 'ICICIBANK.NS', 'name': 'ICICI Bank Ltd', 'sector': 'Banking'},
            {'symbol': 'HINDUNILVR.NS', 'name': 'Hindustan Unilever Ltd', 'sector': 'FMCG'},
            {'symbol': 'SBIN.NS', 'name': 'State Bank of India', 'sector': 'Banking'},
            {'symbol': 'BAJFINANCE.NS', 'name': 'Bajaj Finance Ltd', 'sector': 'Financial Services'},
            {'symbol': 'BHARTIARTL.NS', 'name': 'Bharti Airtel Ltd', 'sector': 'Telecom'},
            {'symbol': 'ITC.NS', 'name': 'ITC Ltd', 'sector': 'FMCG'}
        ]
    
    def generate_dummy_prices(self, base_price=1000, volatility=0.02, days=30):
        """Generate dummy price data for Indian equities"""
        prices = {}
        for equity in self.indian_equities:
            symbol = equity['symbol']
            base = base_price * (0.8 + 0.4 * np.random.random())
            price_series = [base]
            
            for _ in range(days - 1):
                change = price_series[-1] * volatility * (2 * np.random.random() - 1)
                new_price = max(10, price_series[-1] + change)
                price_series.append(new_price)
            
            prices[symbol] = price_series
        
        return prices
    
    def populate_equity_data(self):
        """Populate database with dummy equity data"""
        for equity in self.indian_equities:
            existing = EquityData.query.filter_by(symbol=equity['symbol']).first()
            if not existing:
                dummy_price = 1000 * (0.5 + np.random.random())
                equity_data = EquityData(
                    symbol=equity['symbol'],
                    name=equity['name'],
                    sector=equity['sector'],
                    current_price=dummy_price,
                    previous_close=dummy_price * (0.95 + 0.1 * np.random.random()),
                    volume=int(1e6 * (0.5 + np.random.random())),
                    market_cap=dummy_price * 1e9 * (0.5 + np.random.random()),
                    last_updated=datetime.utcnow()
                )
                db.session.add(equity_data)
        
        db.session.commit()

# Authentication decorators
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def advisor_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        user = User.query.get(session['user_id'])
        if user.role != 'advisor':
            return jsonify({'error': 'Advisor access required'}), 403
        return f(*args, **kwargs)
    return decorated_function

# Routes
@app.route('/')
def index():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        user = User.query.filter_by(username=username).first()
        if user and user.password_hash == password:  # In real app, use proper password hashing
            session['user_id'] = user.id
            session['username'] = user.username
            session['role'] = user.role
            return redirect(url_for('dashboard'))
        
        return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username')
        email = request.form.get('email')
        password = request.form.get('password')
        role = request.form.get('role', 'user')
        
        if User.query.filter_by(username=username).first():
            return render_template('register.html', error='Username already exists')
        
        user = User(username=username, email=email, password_hash=password, role=role)
        db.session.add(user)
        db.session.commit()
        
        session['user_id'] = user.id
        session['username'] = user.username
        session['role'] = user.role
        return redirect(url_for('dashboard'))
    
    return render_template('register.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

@app.route('/dashboard')
@login_required
def dashboard():
    return render_template('dashboard.html')

# API Routes
@app.route('/api/portfolios', methods=['GET'])
@login_required
def get_portfolios():
    portfolios = Portfolio.query.filter_by(user_id=session['user_id']).all()
    return jsonify([{
        'id': p.id,
        'name': p.name,
        'description': p.description,
        'created_at': p.created_at.isoformat(),
        'updated_at': p.updated_at.isoformat()
    } for p in portfolios])

@app.route('/api/portfolios', methods=['POST'])
@login_required
def create_portfolio():
    data = request.get_json()
    portfolio = Portfolio(
        name=data['name'],
        description=data.get('description', ''),
        user_id=session['user_id']
    )
    db.session.add(portfolio)
    db.session.commit()
    
    return jsonify({'id': portfolio.id, 'message': 'Portfolio created successfully'})

@app.route('/api/portfolios/<int:portfolio_id>', methods=['GET'])
@login_required
def get_portfolio(portfolio_id):
    portfolio = Portfolio.query.filter_by(id=portfolio_id, user_id=session['user_id']).first()
    if not portfolio:
        return jsonify({'error': 'Portfolio not found'}), 404
    
    holdings = PortfolioHolding.query.filter_by(portfolio_id=portfolio_id).all()
    holdings_data = []
    total_value = 0
    
    for holding in holdings:
        equity = EquityData.query.filter_by(symbol=holding.symbol).first()
        current_price = equity.current_price if equity else holding.purchase_price
        market_value = holding.quantity * current_price
        total_value += market_value
        
        holdings_data.append({
            'id': holding.id,
            'symbol': holding.symbol,
            'name': equity.name if equity else holding.symbol,
            'quantity': holding.quantity,
            'purchase_price': holding.purchase_price,
            'current_price': current_price,
            'market_value': market_value,
            'gain_loss': market_value - (holding.quantity * holding.purchase_price),
            'sector': holding.sector or (equity.sector if equity else 'Unknown')
        })
    
    return jsonify({
        'portfolio': {
            'id': portfolio.id,
            'name': portfolio.name,
            'description': portfolio.description,
            'total_value': total_value,
            'holdings_count': len(holdings)
        },
        'holdings': holdings_data
    })

@app.route('/api/portfolios/<int:portfolio_id>/holdings', methods=['POST'])
@login_required
def add_holding(portfolio_id):
    data = request.get_json()
    
    portfolio = Portfolio.query.filter_by(id=portfolio_id, user_id=session['user_id']).first()
    if not portfolio:
        return jsonify({'error': 'Portfolio not found'}), 404
    
    equity = EquityData.query.filter_by(symbol=data['symbol']).first()
    sector = equity.sector if equity else data.get('sector', 'Unknown')
    
    holding = PortfolioHolding(
        portfolio_id=portfolio_id,
        symbol=data['symbol'],
        quantity=data['quantity'],
        purchase_price=data['purchase_price'],
        purchase_date=datetime.strptime(data['purchase_date'], '%Y-%m-%d') if 'purchase_date' in data else datetime.utcnow(),
        sector=sector
    )
    
    db.session.add(holding)
    db.session.commit()
    
    return jsonify({'message': 'Holding added successfully'})

@app.route('/api/advisory/signals')
@login_required