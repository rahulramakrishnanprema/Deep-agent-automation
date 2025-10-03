"""
Main application file for the Indian Portfolio Manager MVP.
This file initializes and runs the Flask web application.
"""

from flask import Flask, render_template, jsonify, request, session, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
import os

# Initialize Flask application
app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY') or 'dev-secret-key-ipm-55'

# Database configuration
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL') or 'sqlite:///ipm_portfolio.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize database
db = SQLAlchemy(app)

# Database Models
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)
    role = db.Column(db.String(20), default='client')  # 'client' or 'advisor'
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    portfolios = db.relationship('Portfolio', backref='user', lazy=True)

class Portfolio(db.Model):
    __tablename__ = 'portfolios'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    holdings = db.relationship('Holding', backref='portfolio', lazy=True, cascade='all, delete-orphan')

class Holding(db.Model):
    __tablename__ = 'holdings'
    id = db.Column(db.Integer, primary_key=True)
    portfolio_id = db.Column(db.Integer, db.ForeignKey('portfolios.id'), nullable=False)
    stock_symbol = db.Column(db.String(20), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    purchase_price = db.Column(db.Float, nullable=False)
    purchase_date = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Add index for better query performance
    __table_args__ = (db.Index('idx_portfolio_stock', 'portfolio_id', 'stock_symbol'),)

class AdvisorySignal(db.Model):
    __tablename__ = 'advisory_signals'
    id = db.Column(db.Integer, primary_key=True)
    stock_symbol = db.Column(db.String(20), nullable=False)
    signal = db.Column(db.String(10), nullable=False)  # 'BUY', 'HOLD', 'SELL'
    confidence = db.Column(db.Float, default=0.0)
    reasoning = db.Column(db.Text)
    generated_at = db.Column(db.DateTime, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)

# Helper Functions
def calculate_technical_indicators(stock_data):
    """Calculate technical indicators for a stock"""
    # Simple Moving Averages
    stock_data['SMA_20'] = stock_data['Close'].rolling(window=20).mean()
    stock_data['SMA_50'] = stock_data['Close'].rolling(window=50).mean()
    
    # RSI (Relative Strength Index)
    delta = stock_data['Close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / loss
    stock_data['RSI'] = 100 - (100 / (1 + rs))
    
    # MACD
    exp12 = stock_data['Close'].ewm(span=12, adjust=False).mean()
    exp26 = stock_data['Close'].ewm(span=26, adjust=False).mean()
    stock_data['MACD'] = exp12 - exp26
    stock_data['Signal_Line'] = stock_data['MACD'].ewm(span=9, adjust=False).mean()
    
    return stock_data

def generate_advisory_signal(stock_symbol):
    """Generate advisory signal for a given stock"""
    try:
        # Fetch historical data
        stock = yf.Ticker(f"{stock_symbol}.NS")  # .NS for NSE
        hist = stock.history(period="6mo")
        
        if hist.empty:
            return None
            
        # Calculate technical indicators
        hist = calculate_technical_indicators(hist)
        
        # Get current price
        current_price = hist['Close'].iloc[-1]
        
        # Calculate performance metrics
        price_1m_ago = hist['Close'].iloc[-22] if len(hist) > 22 else hist['Close'].iloc[0]
        price_3m_ago = hist['Close'].iloc[-66] if len(hist) > 66 else hist['Close'].iloc[0]
        
        performance_1m = (current_price - price_1m_ago) / price_1m_ago * 100
        performance_3m = (current_price - price_3m_ago) / price_3m_ago * 100
        
        # Technical analysis signals
        rsi = hist['RSI'].iloc[-1] if not pd.isna(hist['RSI'].iloc[-1]) else 50
        macd_signal = hist['MACD'].iloc[-1] > hist['Signal_Line'].iloc[-1]
        
        # Sector potential (dummy implementation)
        sector_score = np.random.uniform(0.4, 0.9)
        
        # Market buzz (dummy implementation)
        market_buzz = np.random.uniform(0.3, 0.8)
        
        # Generate composite score
        composite_score = (
            (min(performance_1m, 20) / 20 * 0.25) +  # Performance weight
            (min(performance_3m, 30) / 30 * 0.25) +  # Performance weight
            ((100 - abs(rsi - 50)) / 100 * 0.2) +    # RSI weight
            (1.0 if macd_signal else 0.5) * 0.1 +    # MACD weight
            sector_score * 0.1 +                     # Sector weight
            market_buzz * 0.1                        # Market buzz weight
        )
        
        # Determine signal
        if composite_score >= 0.7:
            signal = "BUY"
            confidence = composite_score
            reasoning = f"Strong fundamentals with {performance_1m:.1f}% 1M gain. Technical indicators bullish."
        elif composite_score >= 0.5:
            signal = "HOLD"
            confidence = composite_score
            reasoning = f"Moderate performance ({performance_1m:.1f}% 1M). Mixed technical signals."
        else:
            signal = "SELL"
            confidence = 1 - composite_score
            reasoning = f"Weak performance ({performance_1m:.1f}% 1M). Technical indicators bearish."
            
        return {
            'stock_symbol': stock_symbol,
            'signal': signal,
            'confidence': round(confidence, 2),
            'reasoning': reasoning,
            'current_price': round(current_price, 2),
            'performance_1m': round(performance_1m, 1),
            'performance_3m': round(performance_3m, 1)
        }
        
    except Exception as e:
        print(f"Error generating signal for {stock_symbol}: {e}")
        return None

# Authentication and Authorization
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        user = User.query.filter_by(username=username).first()
        
        if user and check_password_hash(user.password_hash, password):
            session['user_id'] = user.id
            session['username'] = user.username
            session['role'] = user.role
            return redirect(url_for('portfolio_overview'))
        
        return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        role = request.form.get('role', 'client')
        
        if User.query.filter_by(username=username).first():
            return render_template('register.html', error='Username already exists')
        
        user = User(
            username=username,
            password_hash=generate_password_hash(password),
            role=role
        )
        
        db.session.add(user)
        db.session.commit()
        
        session['user_id'] = user.id
        session['username'] = user.username
        session['role'] = user.role
        
        return redirect(url_for('portfolio_overview'))
    
    return render_template('register.html')

# Portfolio Management
@app.route('/')
def index():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    return redirect(url_for('portfolio_overview'))

@app.route('/portfolio')
def portfolio_overview():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    user_id = session['user_id']
    portfolios = Portfolio.query.filter_by(user_id=user_id).all()
    
    # Calculate portfolio values
    portfolio_data = []
    for portfolio in portfolios:
        total_value = 0
        for holding in portfolio.holdings:
            signal_data = generate_advisory_signal(holding.stock_symbol)
            current_price = signal_data['current_price'] if signal_data else holding.purchase_price
            holding_value = holding.quantity * current_price
            total_value += holding_value
        
        portfolio_data.append({
            'portfolio': portfolio,
            'total_value': round(total_value, 2),
            'holdings_count': len(portfolio.holdings)
        })
    
    return render_template('portfolio_overview.html', 
                          portfolios=portfolio_data,
                          username=session['username'])

@app.route('/portfolio/<int:portfolio_id>')
def portfolio_detail(portfolio_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    portfolio = Portfolio.query.get_or_404(portfolio_id)
    
    # Verify ownership
    if portfolio.user_id != session['user_id'] and session['role'] != 'advisor':
        return redirect(url_for('portfolio_overview'))
    
    holdings_data = []
    total_investment = 0
    total_current_value = 0
    
    for holding in portfolio.holdings:
        signal_data = generate_advisory_signal(holding.stock_symbol)
        current_price = signal_data['current_price'] if signal_data else holding.purchase_price
        investment = holding.quantity * holding.purchase_price
        current_value = holding.quantity * current_price
        profit_loss = current_value - investment
        profit_loss_percent = (profit_loss / investment) * 100 if investment > 0 else 0
        
        holdings_data.append({
            'holding': holding,
            'current_price': round(current_price, 2),
            'investment': round(investment, 2),
            'current_value': round(current_value, 2),
            'profit_loss': round(profit_loss, 2),
            'profit_loss_percent': round(profit_loss_percent, 2),
            'signal': signal_data
        })
        
        total_investment += investment
        total_current_value += current_value
    
    total_profit_loss = total_current_value - total_investment
    total_profit_loss_percent = (total_profit_loss / total_investment) * 100 if total_investment > 0 else 0
    
    return render_template('portfolio_detail.html',
                          portfolio=portfolio,
                          holdings=holdings_data,
                          total_investment=round(total_investment, 2),
                          total_current_value=round(total_current_value, 2),
                          total_profit_loss=round(total_profit_loss, 2),
                          total_profit_loss_percent=round(total_profit_loss_percent, 2))

@app.route('/api/portfolio/<int:portfolio_id>/holdings', methods=['GET'])
def api_portfolio_holdings(portfolio_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    
    portfolio = Portfolio.query.get_or_404(portfolio_id)
    
    if portfolio.user_id != session['user_id'] and session['role'] != 'advisor':
        return jsonify({'error': 'Forbidden'}), 403
    
    holdings_data = []
    for holding in portfolio.holdings:
        signal_data = generate_advisory_signal(holding.stock_symbol)
        
        holdings_data.append({
            'id': holding.id,
            'stock_symbol': holding.stock_symbol,
            'quantity': holding.quantity,
            'purchase_price': holding.purchase_price,
            'purchase_date': holding.purchase_date.isoformat(),
            'current_price': signal_data['current_price'] if signal_data else holding.purchase_price,
            'signal': signal_data['signal'] if signal_data else 'HOLD',
            'confidence': signal_data['confidence'] if signal_data else 0.5
        })
    
    return jsonify(holdings_data)

# Advisory Signals
@app.route('/advisory/signals')
def advisory_signals():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    # Get unique stocks from all portfolios
    user_id = session['user_id']
    if session['role'] == 'advisor':
        portfolios = Portfolio.query.all()
    else:
        portfolios = Portfolio.query.filter_by(user_id=user_id).all()
    
    unique_stocks = set()
    for portfolio in portfolios:
        for holding in portfolio.holdings:
            unique_stocks.add(holding.stock_symbol)
    
    signals = []
    for stock in unique_stocks:
        signal_data = generate_advisory_signal(stock)
        if signal_data:
            signals.append(signal_data)
    
    # Sort by confidence (descending)
    signals.sort(key=lambda x: x['confidence'], reverse=True)
    
    return render_template('advisory_signals.html', signals=signals)

@app.route('/api/advisory/signals')
def api_advisory_signals():
    if 'user_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    
    # Get parameter for specific stock or all
    stock_symbol = request.args.get('stock')
    
    if stock_symbol:
        signal_data = generate_advisory_signal(stock_symbol)
        if signal_data:
            return jsonify(signal_data)
        else:
            return jsonify({'error': 'Stock not found'}), 404
    else:
        # Return signals for all stocks in user's portfolios
        user_id = session['user_id']
        if session['role'] == 'advisor':
            portfolios = Portfolio.query.all()
        else:
            portfolios = Portfolio.query.filter_by(user_id=user_id).all()
        
        unique_stocks = set()
        for portfolio in portfolios:
            for holding in portfolio.holdings:
                unique_stocks.add(holding.stock_symbol)
        
        signals = []
        for stock in unique_stocks:
            signal_data = generate_advisory_signal(stock)
            if signal_data:
                signals.append(signal_data)
        
        return jsonify(signals)

# Visual Reports (Advisor Only)
@app.route('/reports')
def reports_dashboard():
    if 'user_id' not in session or session['role'] != 'advisor':
        return redirect(url_for('login'))
    
    # Get analytics data
    total_users = User.query.count()
    total_portfolios = Portfolio.query.count()
    total_holdings = Holding.query.count()
    
    # Portfolio value distribution
    portfolio_values = []
    for portfolio in Portfolio.query.all():
        total_value = sum(
            holding.quantity * generate_advisory_signal(holding.stock_symbol)['current_price'] 
            for holding in portfolio.holdings 
            if generate_advisory_signal(holding.stock_symbol)
        )
        portfolio_values.append(total_value)
    
    # Signal distribution
    signals = {'BUY': 0, 'HOLD': 0, 'SELL': 0}
    all_stocks = set(h.stock_symbol for h in Holding.query.all())
    
    for stock in all_stocks:
        signal_data = generate_advisory_signal(stock)
        if signal_data:
            signals[signal_data['signal']] += 1
    
    return render_template('reports_dashboard.html',
                          total_users=total_users,
                          total_portfolios=total_portfolios,
                          total_holdings=total_holdings,
                          portfolio_values=portfolio_values,
                          signals=signals)

@app.route('/api/reports/portfolio-growth')
def api_portfolio_growth():
    if 'user_id' not in session or session['role'] != 'advisor':
        return jsonify({'error': 'Unauthorized'}), 401
    
    # Generate dummy portfolio growth data
    dates = pd.date_range(end=datetime.now(), periods=30, freq='D')
    growth_data = []
    
    for i, date in enumerate(dates):
        growth_data.append({
            'date': date.isoformat(),
            'value': 100000 + (i * 2000) + np.random.randint(-1000, 1000)
        })
    
    return jsonify(growth_data)

@app.route('/api/reports/sector-performance')
def api_sector_performance():
    if 'user_id' not in session or session['role'] != 'advisor':
        return jsonify({'error': 'Unauthorized'}), 401
    
    # Dummy sector performance data
    sectors = ['IT', 'Finance', 'Healthcare', 'Automobile