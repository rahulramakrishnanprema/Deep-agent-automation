"""
IPM-55 Main Application File
MVP web application for managing client stock portfolios in Indian equity markets.
This file serves as the main Flask application entry point.
"""

from flask import Flask, render_template, jsonify, request, session, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import yfinance as yf
import json
import os
from functools import wraps

# Initialize Flask application
app = Flask(__name__)
app.config['SECRET_KEY'] = 'ipm-55-mvp-secret-key'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///portfolio_management.db'
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

class ClientPortfolio(db.Model):
    __tablename__ = 'client_portfolios'
    id = db.Column(db.Integer, primary_key=True)
    client_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    stock_symbol = db.Column(db.String(20), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    purchase_price = db.Column(db.Float, nullable=False)
    purchase_date = db.Column(db.DateTime, nullable=False)
    sector = db.Column(db.String(50), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class AdvisorySignal(db.Model):
    __tablename__ = 'advisory_signals'
    id = db.Column(db.Integer, primary_key=True)
    stock_symbol = db.Column(db.String(20), nullable=False)
    signal = db.Column(db.String(10), nullable=False)  # 'BUY', 'HOLD', 'SELL'
    confidence_score = db.Column(db.Float, nullable=False)
    reasoning = db.Column(db.Text, nullable=False)
    generated_at = db.Column(db.DateTime, default=datetime.utcnow)
    advisor_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

class MarketData(db.Model):
    __tablename__ = 'market_data'
    id = db.Column(db.Integer, primary_key=True)
    stock_symbol = db.Column(db.String(20), nullable=False)
    date = db.Column(db.DateTime, nullable=False)
    open_price = db.Column(db.Float, nullable=False)
    high_price = db.Column(db.Float, nullable=False)
    low_price = db.Column(db.Float, nullable=False)
    close_price = db.Column(db.Float, nullable=False)
    volume = db.Column(db.BigInteger, nullable=False)
    sector = db.Column(db.String(50), nullable=False)

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

def advisor_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or current_user.role != 'advisor':
            return jsonify({'error': 'Advisor access required'}), 403
        return f(*args, **kwargs)
    return decorated_function

# Technical Indicators Calculation
class TechnicalIndicators:
    @staticmethod
    def calculate_sma(prices, window=20):
        """Calculate Simple Moving Average"""
        return prices.rolling(window=window).mean()
    
    @staticmethod
    def calculate_rsi(prices, window=14):
        """Calculate Relative Strength Index"""
        delta = prices.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=window).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=window).mean()
        rs = gain / loss
        return 100 - (100 / (1 + rs))
    
    @staticmethod
    def calculate_macd(prices, fast=12, slow=26, signal=9):
        """Calculate MACD indicator"""
        ema_fast = prices.ewm(span=fast).mean()
        ema_slow = prices.ewm(span=slow).mean()
        macd_line = ema_fast - ema_slow
        signal_line = macd_line.ewm(span=signal).mean()
        histogram = macd_line - signal_line
        return macd_line, signal_line, histogram

# Advisory Signal Generation
class AdvisoryEngine:
    def __init__(self):
        self.technical_indicators = TechnicalIndicators()
        self.sector_weights = {
            'Technology': 1.2,
            'Finance': 1.1,
            'Healthcare': 1.15,
            'Energy': 0.9,
            'Consumer': 1.05,
            'Industrial': 1.0
        }
    
    def generate_signal(self, stock_symbol, historical_data):
        """Generate advisory signal based on multiple factors"""
        try:
            # Technical Analysis
            technical_score = self._calculate_technical_score(historical_data)
            
            # Historical Performance
            historical_score = self._calculate_historical_score(historical_data)
            
            # Sector Analysis
            sector_score = self._calculate_sector_score(historical_data['sector'].iloc[0])
            
            # Market Buzz (simulated)
            market_buzz_score = self._simulate_market_buzz(stock_symbol)
            
            # Composite Score
            composite_score = (
                technical_score * 0.4 +
                historical_score * 0.3 +
                sector_score * 0.2 +
                market_buzz_score * 0.1
            )
            
            # Generate Signal
            if composite_score >= 0.7:
                signal = 'BUY'
                confidence = composite_score
                reasoning = f"Strong buy signal based on technical indicators, historical performance, and sector outlook"
            elif composite_score >= 0.4:
                signal = 'HOLD'
                confidence = composite_score
                reasoning = f"Neutral position recommended based on mixed signals"
            else:
                signal = 'SELL'
                confidence = 1 - composite_score
                reasoning = f"Sell recommendation due to weak technicals and poor outlook"
            
            return {
                'signal': signal,
                'confidence': confidence,
                'reasoning': reasoning,
                'scores': {
                    'technical': technical_score,
                    'historical': historical_score,
                    'sector': sector_score,
                    'market_buzz': market_buzz_score
                }
            }
            
        except Exception as e:
            return {
                'signal': 'HOLD',
                'confidence': 0.5,
                'reasoning': f'Error in signal generation: {str(e)}',
                'scores': {'technical': 0.5, 'historical': 0.5, 'sector': 0.5, 'market_buzz': 0.5}
            }
    
    def _calculate_technical_score(self, data):
        """Calculate technical analysis score"""
        prices = data['close_price']
        
        # Calculate indicators
        sma_20 = self.technical_indicators.calculate_sma(prices, 20)
        rsi = self.technical_indicators.calculate_rsi(prices)
        macd_line, signal_line, histogram = self.technical_indicators.calculate_macd(prices)
        
        # Analyze signals
        current_price = prices.iloc[-1]
        sma_20_current = sma_20.iloc[-1]
        rsi_current = rsi.iloc[-1] if not pd.isna(rsi.iloc[-1]) else 50
        macd_signal = 1 if macd_line.iloc[-1] > signal_line.iloc[-1] else -1
        
        # Score components
        price_vs_sma = 1 if current_price > sma_20_current else 0
        rsi_score = max(0, min(1, (rsi_current - 30) / 40))  # Normalize RSI between 0-1
        macd_score = (macd_signal + 1) / 2  # Convert -1/1 to 0/1
        
        return (price_vs_sma + rsi_score + macd_score) / 3
    
    def _calculate_historical_score(self, data):
        """Calculate historical performance score"""
        prices = data['close_price']
        
        # Calculate returns
 returns = prices.pct_change().dropna()
        if len(returns) == 0:
            return 0.5
        
        # Recent performance (last 30 days)
        recent_returns = returns.tail(30)
        recent_mean_return = recent_returns.mean()
        recent_volatility = recent_returns.std()
        
        # Long-term performance (all data)
        long_term_mean = returns.mean()
        long_term_volatility = returns.std()
        
        # Score based on risk-adjusted returns
        if recent_volatility > 0 and long_term_volatility > 0:
            sharpe_recent = recent_mean_return / recent_volatility * np.sqrt(252)
            sharpe_long_term = long_term_mean / long_term_volatility * np.sqrt(252)
            score = (sharpe_recent + sharpe_long_term) / 2
            return max(0, min(1, (score + 1) / 2))  # Normalize to 0-1
        return 0.5
    
    def _calculate_sector_score(self, sector):
        """Calculate sector outlook score"""
        return self.sector_weights.get(sector, 1.0)
    
    def _simulate_market_buzz(self, stock_symbol):
        """Simulate market buzz factor (dummy implementation)"""
        # In real implementation, this would integrate with news APIs, social media, etc.
        buzz_factors = {
            'RELIANCE': 0.8,
            'TCS': 0.9,
            'HDFCBANK': 0.7,
            'INFY': 0.85,
            'ICICIBANK': 0.75
        }
        return buzz_factors.get(stock_symbol, 0.6)

# Dummy Data Generation
class DummyDataGenerator:
    @staticmethod
    def generate_dummy_data():
        """Generate dummy data for MVP testing"""
        print("Generating dummy data...")
        
        # Create admin user
        if not User.query.filter_by(username='admin').first():
            admin_user = User(
                username='admin',
                password='admin123',  # In production, use proper password hashing
                role='advisor',
                email='admin@ipm55.com'
            )
            db.session.add(admin_user)
        
        # Create sample client
        if not User.query.filter_by(username='client1').first():
            client_user = User(
                username='client1',
                password='client123',
                role='client',
                email='client1@ipm55.com'
            )
            db.session.add(client_user)
        
        db.session.commit()
        
        # Generate sample portfolios
        nifty_50_stocks = [
            {'symbol': 'RELIANCE', 'sector': 'Energy'},
            {'symbol': 'TCS', 'sector': 'Technology'},
            {'symbol': 'HDFCBANK', 'sector': 'Finance'},
            {'symbol': 'INFY', 'sector': 'Technology'},
            {'symbol': 'ICICIBANK', 'sector': 'Finance'}
        ]
        
        admin_user = User.query.filter_by(username='admin').first()
        client_user = User.query.filter_by(username='client1').first()
        
        if client_user and not ClientPortfolio.query.filter_by(client_id=client_user.id).first():
            for stock in nifty_50_stocks:
                portfolio = ClientPortfolio(
                    client_id=client_user.id,
                    stock_symbol=stock['symbol'],
                    quantity=np.random.randint(10, 100),
                    purchase_price=np.random.uniform(1000, 5000),
                    purchase_date=datetime.now() - timedelta(days=np.random.randint(30, 365)),
                    sector=stock['sector']
                )
                db.session.add(portfolio)
        
        # Generate sample market data
        if not MarketData.query.first():
            end_date = datetime.now()
            start_date = end_date - timedelta(days=365)
            
            for stock in nifty_50_stocks:
                # Download real data for better simulation
                try:
                    ticker = yf.Ticker(f"{stock['symbol']}.NS")
                    hist_data = ticker.history(start=start_date, end=end_date)
                    
                    for date, row in hist_data.iterrows():
                        market_data = MarketData(
                            stock_symbol=stock['symbol'],
                            date=date.to_pydatetime(),
                            open_price=row['Open'],
                            high_price=row['High'],
                            low_price=row['Low'],
                            close_price=row['Close'],
                            volume=row['Volume'],
                            sector=stock['sector']
                        )
                        db.session.add(market_data)
                except Exception as e:
                    print(f"Error downloading data for {stock['symbol']}: {e}")
                    # Fallback to generated data
                    base_price = np.random.uniform(1000, 5000)
                    for i in range(365):
                        date = start_date + timedelta(days=i)
                        price_change = np.random.normal(0, 0.02)  # 2% daily volatility
                        close_price = base_price * (1 + price_change)
                        
                        market_data = MarketData(
                            stock_symbol=stock['symbol'],
                            date=date,
                            open_price=close_price * (1 + np.random.uniform(-0.01, 0.01)),
                            high_price=close_price * (1 + np.random.uniform(0, 0.03)),
                            low_price=close_price * (1 - np.random.uniform(0, 0.03)),
                            close_price=close_price,
                            volume=np.random.randint(1000000, 10000000),
                            sector=stock['sector']
                        )
                        db.session.add(market_data)
                        base_price = close_price
        
        db.session.commit()
        print("Dummy data generation completed!")

# Routes
@app.route('/')
def home():
    if current_user.is_authenticated:
        if current_user.role == 'advisor':
            return redirect(url_for('advisor_dashboard'))
        else:
            return redirect(url_for('client_portfolio'))
    return render_template('login.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        user = User.query.filter_by(username=username, password=password).first()
        if user:
            login_user(user)
            if user.role == 'advisor':
                return redirect(url_for('advisor_dashboard'))
            else:
                return redirect(url_for('client_portfolio'))
        
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
        return redirect(url_for('advisor_dashboard'))
    
    portfolios = ClientPortfolio.query.filter_by(client_id=current_user.id).all()
    return render_template('client_portfolio.html', portfolios=portfolios)

@app.route('/api/portfolio/signals')
@login_required
def get_portfolio_signals():
    """Get advisory signals for client's portfolio"""
    try:
        portfolios = ClientPortfolio.query.filter_by(client_id=current_user.id).all()
        advisory_engine = AdvisoryEngine()
        signals = []
        
        for portfolio in portfolios:
            # Get historical data for the stock
            historical_data = MarketData.query.filter_by(
                stock_symbol=portfolio.stock_symbol
            ).order_by(MarketData.date).all()
            
            if historical_data:
                # Convert to DataFrame for analysis
                df = pd.DataFrame([{
                    'date': md.date,
                    'close_price': md.close_price,
                    'sector': md.sector
                } for md in historical_data])
                
                signal = advisory_engine.generate_signal(portfolio.stock_symbol, df)
                signals.append({
                    'stock_symbol': portfolio.stock_symbol,
                    'quantity': portfolio.quantity,
                    'purchase_price': portfolio.purchase_price,
                    'current_price': df['close_price'].iloc[-1],
                    'signal': signal['signal'],
                    'confidence': signal['confidence'],
                    'reasoning': signal['reasoning'],
                    'scores': signal['scores']
                })
        
        return jsonify({'signals': signals})
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/advisor/dashboard')
@login_required
@advisor_required
def advisor_dashboard():
    """Advisor-only dashboard with visual reports"""
    return render_template('advisor_dashboard.html')

@app.route('/api/advisor/portfolio-overview')
@login_required
@advisor_required
def get_portfolio_overview():
    """Get overview of all client portfolios for advisor dashboard"""
    try:
        clients = User.query.filter_by(role='client').all()
        overview = []
        
        for client in clients:
            portfolios = ClientPortfolio.query.filter_by(client_id=client.id).all()
            total_value = 0
            stocks_count = len(portfolios)
            
            for portfolio in portfolios:
                latest_price = MarketData.query.filter_by(
                    stock_symbol=portfolio.stock_symbol
                ).order_by(MarketData.date.desc()).first()
                
                if latest_price:
                    total_value += portfolio