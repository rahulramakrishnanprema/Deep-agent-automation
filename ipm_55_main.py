# ipm_55_main.py - Main Flask application for Indian Portfolio Manager MVP
# This file serves as the entry point for the web application, integrating all components

from flask import Flask, render_template, jsonify, request, session, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import yfinance as yf
import json
import os

# Initialize Flask application
app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key-here'  # Change in production
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///portfolio.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize extensions
db = SQLAlchemy(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# Database Models
class User(UserMixin, db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='client')  # 'advisor' or 'client'
    email = db.Column(db.String(120), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Portfolio(db.Model):
    __tablename__ = 'portfolios'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    stock_symbol = db.Column(db.String(20), nullable=False)
    stock_name = db.Column(db.String(100), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    purchase_price = db.Column(db.Float, nullable=False)
    purchase_date = db.Column(db.DateTime, nullable=False)
    sector = db.Column(db.String(50), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class AdvisorySignal(db.Model):
    __tablename__ = 'advisory_signals'
    id = db.Column(db.Integer, primary_key=True)
    stock_symbol = db.Column(db.String(20), nullable=False)
    signal = db.Column(db.String(10), nullable=False)  # 'BUY', 'HOLD', 'SELL'
    confidence = db.Column(db.Float, nullable=False)
    reasoning = db.Column(db.Text, nullable=False)
    generated_at = db.Column(db.DateTime, default=datetime.utcnow)
    technical_score = db.Column(db.Float)
    fundamental_score = db.Column(db.Float)
    sector_score = db.Column(db.Float)
    market_buzz_score = db.Column(db.Float)

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Advisory Signal Generation Functions
class AdvisorySignalGenerator:
    @staticmethod
    def calculate_technical_indicators(stock_symbol):
        """Calculate technical indicators for a stock"""
        try:
            # Fetch historical data
            end_date = datetime.now()
            start_date = end_date - timedelta(days=365)
            
            stock_data = yf.download(f"{stock_symbol}.NS", start=start_date, end=end_date)
            
            if stock_data.empty:
                return 0.5  # Neutral score if no data
            
            # Calculate RSI
            delta = stock_data['Close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
            rs = gain / loss
            rsi = 100 - (100 / (1 + rs))
            rsi_score = 1.0 if rsi.iloc[-1] < 30 else 0.0 if rsi.iloc[-1] > 70 else 0.5
            
            # Calculate Moving Averages
            ma_50 = stock_data['Close'].rolling(window=50).mean()
            ma_200 = stock_data['Close'].rolling(window=200).mean()
            ma_score = 1.0 if ma_50.iloc[-1] > ma_200.iloc[-1] else 0.0
            
            # Calculate MACD
            exp12 = stock_data['Close'].ewm(span=12, adjust=False).mean()
            exp26 = stock_data['Close'].ewm(span=26, adjust=False).mean()
            macd = exp12 - exp26
            signal = macd.ewm(span=9, adjust=False).mean()
            macd_score = 1.0 if macd.iloc[-1] > signal.iloc[-1] else 0.0
            
            # Average technical score
            technical_score = (rsi_score + ma_score + macd_score) / 3
            return technical_score
            
        except Exception as e:
            print(f"Error calculating technical indicators: {e}")
            return 0.5

    @staticmethod
    def calculate_fundamental_score(stock_symbol):
        """Calculate fundamental analysis score"""
        # Simplified fundamental analysis
        try:
            stock = yf.Ticker(f"{stock_symbol}.NS")
            info = stock.info
            
            pe_ratio = info.get('trailingPE', 25)
            pb_ratio = info.get('priceToBook', 2)
            debt_to_equity = info.get('debtToEquity', 0.5)
            
            # Score based on ratios (lower is better for these metrics)
            pe_score = 1.0 if pe_ratio < 15 else 0.0 if pe_ratio > 25 else 0.5
            pb_score = 1.0 if pb_ratio < 1.5 else 0.0 if pb_ratio > 3 else 0.5
            debt_score = 1.0 if debt_to_equity < 0.5 else 0.0 if debt_to_equity > 1 else 0.5
            
            fundamental_score = (pe_score + pb_score + debt_score) / 3
            return fundamental_score
            
        except Exception as e:
            print(f"Error calculating fundamental score: {e}")
            return 0.5

    @staticmethod
    def calculate_sector_potential(sector):
        """Calculate sector potential score"""
        # Simplified sector analysis - in real application, use market data
        sector_potentials = {
            'Technology': 0.8,
            'Healthcare': 0.7,
            'Financial': 0.6,
            'Automobile': 0.5,
            'Energy': 0.4,
            'Consumer': 0.65,
            'Pharmaceutical': 0.75,
            'Infrastructure': 0.55
        }
        return sector_potentials.get(sector, 0.5)

    @staticmethod
    def calculate_market_buzz(stock_symbol):
        """Calculate market buzz score"""
        # Simplified market sentiment analysis
        # In real application, integrate with news APIs and social media sentiment analysis
        popular_stocks = ['RELIANCE', 'TCS', 'INFY', 'HDFCBANK', 'ICICIBANK']
        if stock_symbol in popular_stocks:
            return 0.8
        return 0.5

    @staticmethod
    def generate_signal(stock_symbol, sector):
        """Generate advisory signal for a stock"""
        try:
            technical_score = AdvisorySignalGenerator.calculate_technical_indicators(stock_symbol)
            fundamental_score = AdvisorySignalGenerator.calculate_fundamental_score(stock_symbol)
            sector_score = AdvisorySignalGenerator.calculate_sector_potential(sector)
            market_buzz_score = AdvisorySignalGenerator.calculate_market_buzz(stock_symbol)
            
            # Weighted average score
            total_score = (
                technical_score * 0.3 +
                fundamental_score * 0.3 +
                sector_score * 0.2 +
                market_buzz_score * 0.2
            )
            
            # Determine signal
            if total_score >= 0.7:
                signal = 'BUY'
                confidence = total_score
                reasoning = f"Strong technical indicators, good fundamentals, positive sector outlook, and market sentiment"
            elif total_score >= 0.4:
                signal = 'HOLD'
                confidence = total_score
                reasoning = f"Mixed signals with neutral technical indicators and fundamentals"
            else:
                signal = 'SELL'
                confidence = 1 - total_score
                reasoning = f"Weak technical indicators, poor fundamentals, and negative market sentiment"
            
            return {
                'signal': signal,
                'confidence': confidence,
                'reasoning': reasoning,
                'technical_score': technical_score,
                'fundamental_score': fundamental_score,
                'sector_score': sector_score,
                'market_buzz_score': market_buzz_score
            }
            
        except Exception as e:
            print(f"Error generating signal: {e}")
            return {
                'signal': 'HOLD',
                'confidence': 0.5,
                'reasoning': 'Unable to generate signal due to data issues',
                'technical_score': 0.5,
                'fundamental_score': 0.5,
                'sector_score': 0.5,
                'market_buzz_score': 0.5
            }

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
        
        user = User.query.filter_by(username=username).first()
        if user and user.password == password:  # In production, use proper password hashing
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
def client_portfolio():
    if current_user.role != 'client':
        return redirect(url_for('home'))
    
    portfolios = Portfolio.query.filter_by(user_id=current_user.id).all()
    portfolio_data = []
    
    for portfolio in portfolios:
        signal_data = AdvisorySignalGenerator.generate_signal(portfolio.stock_symbol, portfolio.sector)
        portfolio_data.append({
            'id': portfolio.id,
            'stock_symbol': portfolio.stock_symbol,
            'stock_name': portfolio.stock_name,
            'quantity': portfolio.quantity,
            'purchase_price': portfolio.purchase_price,
            'current_price': get_current_price(portfolio.stock_symbol),
            'sector': portfolio.sector,
            'signal': signal_data['signal'],
            'confidence': signal_data['confidence'],
            'reasoning': signal_data['reasoning']
        })
    
    return render_template('client_portfolio.html', portfolios=portfolio_data)

@app.route('/advisor/dashboard')
@login_required
def advisor_dashboard():
    if current_user.role != 'advisor':
        return redirect(url_for('home'))
    
    # Get all client portfolios
    all_portfolios = Portfolio.query.all()
    
    # Generate analytics data
    sector_analysis = analyze_sector_performance()
    top_signals = get_top_advisory_signals()
    client_summary = get_client_summary()
    
    return render_template('advisor_dashboard.html',
                         sector_analysis=sector_analysis,
                         top_signals=top_signals,
                         client_summary=client_summary)

@app.route('/api/portfolio', methods=['GET', 'POST'])
@login_required
def api_portfolio():
    if request.method == 'GET':
        portfolios = Portfolio.query.filter_by(user_id=current_user.id).all()
        return jsonify([{
            'id': p.id,
            'stock_symbol': p.stock_symbol,
            'stock_name': p.stock_name,
            'quantity': p.quantity,
            'purchase_price': p.purchase_price,
            'sector': p.sector
        } for p in portfolios])
    
    elif request.method == 'POST':
        data = request.json
        new_portfolio = Portfolio(
            user_id=current_user.id,
            stock_symbol=data['stock_symbol'],
            stock_name=data['stock_name'],
            quantity=data['quantity'],
            purchase_price=data['purchase_price'],
            purchase_date=datetime.now(),
            sector=data['sector']
        )
        db.session.add(new_portfolio)
        db.session.commit()
        return jsonify({'message': 'Portfolio item added successfully'})

@app.route('/api/advisory/signal/<stock_symbol>')
@login_required
def api_advisory_signal(stock_symbol):
    sector = request.args.get('sector', 'Technology')
    signal_data = AdvisorySignalGenerator.generate_signal(stock_symbol, sector)
    return jsonify(signal_data)

@app.route('/api/analytics/sector')
@login_required
def api_sector_analytics():
    if current_user.role != 'advisor':
        return jsonify({'error': 'Access denied'}), 403
    
    sector_data = analyze_sector_performance()
    return jsonify(sector_data)

# Helper Functions
def get_current_price(stock_symbol):
    """Get current stock price using yfinance"""
    try:
        stock = yf.Ticker(f"{stock_symbol}.NS")
        return stock.info.get('regularMarketPrice', 0)
    except:
        return 0

def analyze_sector_performance():
    """Analyze sector performance for advisor dashboard"""
    sectors = db.session.query(Portfolio.sector).distinct().all()
    sector_data = []
    
    for sector in sectors:
        sector = sector[0]
        sector_portfolios = Portfolio.query.filter_by(sector=sector).all()
        
        total_investment = sum(p.quantity * p.purchase_price for p in sector_portfolios)
        current_value = sum(p.quantity * get_current_price(p.stock_symbol) for p in sector_portfolios)
        
        sector_data.append({
            'sector': sector,
            'total_investment': total_investment,
            'current_value': current_value,
            'profit_loss': current_value - total_investment,
            'profit_loss_percent': ((current_value - total_investment) / total_investment * 100) if total_investment > 0 else 0
        })
    
    return sector_data

def get_top_advisory_signals():
    """Get top advisory signals for dashboard"""
    # This would typically query the database for recent signals
    # For now, generate sample signals for top Indian stocks
    top_stocks = ['RELIANCE', 'TCS', 'INFY', 'HDFCBANK', 'ICICIBANK']
    signals = []
    
    for stock in top_stocks:
        signal_data = AdvisorySignalGenerator.generate_signal(stock, 'Technology')
        signals.append({
            'stock_symbol': stock,
            'signal': signal_data['signal'],
            'confidence': signal_data['confidence'],
            'reasoning': signal_data['reasoning']
        })
    
    return signals

def get_client_summary():
    """Get client portfolio summary for advisor dashboard"""
    clients = User.query.filter_by(role='client').all()
    summary = []
    
    for client in clients:
        portfolios = Portfolio.query.filter_by(user_id=client.id).all()
        total_investment = sum(p.quantity * p.purchase_price for p in portfolios)
        current_value = sum(p.quantity * get_current_price(p.stock_symbol) for p in portfolios)
        
        summary.append({
            'client_id': client.id,
            'client_name': client.username,
            'total_investment': total_investment,
            'current_value': current_value,
            'profit_loss': current_value - total_investment,
            'portfolio_count': len(portfolios)
        })
    
    return summary

def create_dummy_data():
    """Create dummy data for testing"""
    # Create admin user
    admin = User(username='admin', password='admin123', role='advisor', email='admin@ipm.com')
    db.session.add(admin)
    
    # Create client users
    clients = [
        User(username='client1', password='client123', role='client', email='client1@ipm.com'),
        User(username='client2', password='client123', role='client', email='client2@ipm.com')
    ]
    db.session.add_all(clients)
    
    # Indian stocks data
    indian_stocks = [
        {'symbol': 'RELIANCE', 'name': 'Reliance Industries Ltd.', 'sector': 'Energy'},
        {'symbol': 'TCS', 'name': 'Tata Consultancy Services Ltd.', 'sector': 'Technology'},
        {'symbol': 'INFY', 'name': 'Infosys Ltd.', 'sector': 'Technology'},
        {'symbol': 'HDFCBANK', 'name': 'HDFC Bank Ltd.', 'sector': 'Financial'},
        {'symbol': 'ICICIBANK', 'name': 'ICICI Bank Ltd.', 'sector': 'Financial'},
        {'symbol': 'HINDUNILVR', 'name': 'Hindustan Unilever Ltd.', 'sector': 'Consumer'},
        {'symbol': 'ITC', 'name': 'ITC Ltd.', 'sector': 'Consumer'},
        {'symbol': 'SBIN', 'name': 'State Bank of India', 'sector': 'Financial'}
    ]
    
    # Create sample portfolios
    portfolios = []
    for client in clients:
        for i in range(3):
            stock = indian_stocks[i % len(indian_stocks)]
            portfolio = Portfolio(
                user_id=client.id,
                stock_symbol=stock['symbol'],
                stock_name=stock['name'],
                quantity=100 * (i + 1),
                purchase_price=1000 + (i *