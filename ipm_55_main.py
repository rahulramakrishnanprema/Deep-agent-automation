"""
IPM-55 Main Application File
MVP web application for managing client stock portfolios in Indian equity markets.
This file serves as the main Flask application entry point.
"""

from flask import Flask, jsonify, request, render_template, session, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
import json
import random
import numpy as np
import pandas as pd
from functools import wraps

# Initialize Flask application
app = Flask(__name__)
app.config['SECRET_KEY'] = 'ipm-55-secret-key'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///portfolio_management.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize database
db = SQLAlchemy(app)

# Database Models
class User(db.Model):
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True)
    username = Column(String(80), unique=True, nullable=False)
    password = Column(String(120), nullable=False)
    role = Column(String(20), nullable=False)  # 'advisor' or 'client'
    email = Column(String(120), unique=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    portfolios = relationship('Portfolio', backref='user', lazy=True)

class Portfolio(db.Model):
    __tablename__ = 'portfolios'
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    name = Column(String(100), nullable=False)
    description = Column(String(255))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    holdings = relationship('Holding', backref='portfolio', lazy=True)

class Holding(db.Model):
    __tablename__ = 'holdings'
    id = Column(Integer, primary_key=True)
    portfolio_id = Column(Integer, ForeignKey('portfolios.id'), nullable=False)
    stock_symbol = Column(String(20), nullable=False)
    quantity = Column(Integer, nullable=False)
    purchase_price = Column(Float, nullable=False)
    purchase_date = Column(DateTime, default=datetime.utcnow)
    sector = Column(String(50))

class MarketData(db.Model):
    __tablename__ = 'market_data'
    id = Column(Integer, primary_key=True)
    stock_symbol = Column(String(20), nullable=False)
    price = Column(Float, nullable=False)
    volume = Column(Integer)
    high = Column(Float)
    low = Column(Float)
    timestamp = Column(DateTime, default=datetime.utcnow)
    sector = Column(String(50))

class AdvisorySignal(db.Model):
    __tablename__ = 'advisory_signals'
    id = Column(Integer, primary_key=True)
    stock_symbol = Column(String(20), nullable=False)
    signal = Column(String(10), nullable=False)  # 'BUY', 'SELL', 'HOLD'
    confidence = Column(Float)
    reasoning = Column(String(255))
    generated_at = Column(DateTime, default=datetime.utcnow)
    sector = Column(String(50))

# Authentication decorator
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

# Advisory Signal Generation Modules
class HistoricalPerformanceAnalyzer:
    @staticmethod
    def analyze(stock_symbol, historical_data):
        """Analyze historical performance for a stock"""
        if len(historical_data) < 10:
            return {'signal': 'HOLD', 'confidence': 0.5, 'reasoning': 'Insufficient historical data'}
        
        returns = np.diff([d['price'] for d in historical_data]) / [d['price'] for d in historical_data[:-1]]
        avg_return = np.mean(returns)
        volatility = np.std(returns)
        
        if avg_return > 0.02 and volatility < 0.15:
            return {'signal': 'BUY', 'confidence': 0.7, 'reasoning': 'Strong historical performance with low volatility'}
        elif avg_return < -0.02:
            return {'signal': 'SELL', 'confidence': 0.6, 'reasoning': 'Poor historical performance'}
        else:
            return {'signal': 'HOLD', 'confidence': 0.5, 'reasoning': 'Moderate historical performance'}

class TechnicalIndicatorCalculator:
    @staticmethod
    def calculate_rsi(prices, period=14):
        """Calculate Relative Strength Index"""
        if len(prices) < period + 1:
            return 50  # Neutral RSI
        
        deltas = np.diff(prices)
        gains = np.where(deltas > 0, deltas, 0)
        losses = np.where(deltas < 0, -deltas, 0)
        
        avg_gain = np.mean(gains[:period])
        avg_loss = np.mean(losses[:period])
        
        for i in range(period, len(prices)-1):
            avg_gain = (avg_gain * (period-1) + gains[i]) / period
            avg_loss = (avg_loss * (period-1) + losses[i]) / period
        
        if avg_loss == 0:
            return 100
        rs = avg_gain / avg_loss
        return 100 - (100 / (1 + rs))
    
    @staticmethod
    def calculate_moving_average(prices, period=20):
        """Calculate simple moving average"""
        if len(prices) < period:
            return np.mean(prices)
        return np.mean(prices[-period:])
    
    @staticmethod
    def analyze(stock_symbol, price_data):
        """Generate technical analysis signal"""
        prices = [d['price'] for d in price_data]
        
        if len(prices) < 20:
            return {'signal': 'HOLD', 'confidence': 0.5, 'reasoning': 'Insufficient data for technical analysis'}
        
        rsi = TechnicalIndicatorCalculator.calculate_rsi(prices)
        ma_20 = TechnicalIndicatorCalculator.calculate_moving_average(prices, 20)
        ma_50 = TechnicalIndicatorCalculator.calculate_moving_average(prices, 50)
        current_price = prices[-1]
        
        if rsi < 30 and current_price > ma_20 and ma_20 > ma_50:
            return {'signal': 'BUY', 'confidence': 0.8, 'reasoning': 'Oversold with bullish trend'}
        elif rsi > 70 and current_price < ma_20 and ma_20 < ma_50:
            return {'signal': 'SELL', 'confidence': 0.75, 'reasoning': 'Overbought with bearish trend'}
        else:
            return {'signal': 'HOLD', 'confidence': 0.6, 'reasoning': 'Neutral technical indicators'}

class SectorAnalyzer:
    @staticmethod
    def analyze(sector):
        """Analyze sector potential"""
        sector_potentials = {
            'Technology': {'signal': 'BUY', 'confidence': 0.8, 'reasoning': 'High growth potential in tech sector'},
            'Healthcare': {'signal': 'BUY', 'confidence': 0.7, 'reasoning': 'Stable growth in healthcare'},
            'Finance': {'signal': 'HOLD', 'confidence': 0.6, 'reasoning': 'Moderate growth expected'},
            'Energy': {'signal': 'SELL', 'confidence': 0.65, 'reasoning': 'Volatile market conditions'},
            'Consumer': {'signal': 'HOLD', 'confidence': 0.55, 'reasoning': 'Stable but slow growth'}
        }
        
        return sector_potentials.get(sector, {'signal': 'HOLD', 'confidence': 0.5, 'reasoning': 'Sector analysis not available'})

class SentimentAnalyzer:
    @staticmethod
    def analyze(stock_symbol):
        """Analyze market sentiment/buzz"""
        # Simulated sentiment analysis
        sentiments = ['positive', 'negative', 'neutral']
        weights = [0.4, 0.3, 0.3]
        sentiment = random.choices(sentiments, weights=weights, k=1)[0]
        
        if sentiment == 'positive':
            return {'signal': 'BUY', 'confidence': 0.65, 'reasoning': 'Positive market sentiment'}
        elif sentiment == 'negative':
            return {'signal': 'SELL', 'confidence': 0.6, 'reasoning': 'Negative market sentiment'}
        else:
            return {'signal': 'HOLD', 'confidence': 0.5, 'reasoning': 'Neutral market sentiment'}

class AdvisoryEngine:
    @staticmethod
    def generate_signal(stock_symbol, sector):
        """Generate unified advisory signal by combining all analysis components"""
        # Get historical data (last 60 days)
        historical_data = MarketData.query.filter_by(stock_symbol=stock_symbol)\
            .order_by(MarketData.timestamp.desc()).limit(60).all()
        
        if not historical_data:
            return {'signal': 'HOLD', 'confidence': 0.5, 'reasoning': 'No market data available'}
        
        historical_data = [{'price': data.price, 'timestamp': data.timestamp} for data in historical_data]
        
        # Get analysis from all components
        historical_analysis = HistoricalPerformanceAnalyzer.analyze(stock_symbol, historical_data)
        technical_analysis = TechnicalIndicatorAnalyzer.analyze(stock_symbol, historical_data)
        sector_analysis = SectorAnalyzer.analyze(sector)
        sentiment_analysis = SentimentAnalyzer.analyze(stock_symbol)
        
        # Weighted combination of signals
        analyses = [
            (historical_analysis, 0.3),
            (technical_analysis, 0.3),
            (sector_analysis, 0.2),
            (sentiment_analysis, 0.2)
        ]
        
        signal_scores = {'BUY': 0, 'SELL': 0, 'HOLD': 0}
        total_confidence = 0
        
        for analysis, weight in analyses:
            signal = analysis['signal']
            confidence = analysis['confidence'] * weight
            signal_scores[signal] += confidence
            total_confidence += confidence
        
        # Determine final signal
        final_signal = max(signal_scores, key=signal_scores.get)
        final_confidence = signal_scores[final_signal] / total_confidence if total_confidence > 0 else 0.5
        
        reasoning = f"Combined analysis: Historical({historical_analysis['signal']}), "\
                   f"Technical({technical_analysis['signal']}), Sector({sector_analysis['signal']}), "\
                   f"Sentiment({sentiment_analysis['signal']})"
        
        return {
            'signal': final_signal,
            'confidence': round(final_confidence, 2),
            'reasoning': reasoning
        }

# Routes
@app.route('/')
def home():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        user = User.query.filter_by(username=username, password=password).first()
        if user:
            session['user_id'] = user.id
            session['username'] = user.username
            session['role'] = user.role
            return redirect(url_for('home'))
        
        return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/api/portfolios', methods=['GET'])
def get_portfolios():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    user_id = session['user_id']
    portfolios = Portfolio.query.filter_by(user_id=user_id).all()
    
    result = []
    for portfolio in portfolios:
        result.append({
            'id': portfolio.id,
            'name': portfolio.name,
            'description': portfolio.description,
            'created_at': portfolio.created_at.isoformat(),
            'updated_at': portfolio.updated_at.isoformat()
        })
    
    return jsonify(result)

@app.route('/api/portfolios', methods=['POST'])
def create_portfolio():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    portfolio = Portfolio(
        user_id=session['user_id'],
        name=data['name'],
        description=data.get('description', '')
    )
    
    db.session.add(portfolio)
    db.session.commit()
    
    return jsonify({'id': portfolio.id, 'message': 'Portfolio created successfully'})

@app.route('/api/portfolios/<int:portfolio_id>/holdings', methods=['GET'])
def get_holdings(portfolio_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    portfolio = Portfolio.query.filter_by(id=portfolio_id, user_id=session['user_id']).first()
    if not portfolio:
        return jsonify({'error': 'Portfolio not found'}), 404
    
    holdings = Holding.query.filter_by(portfolio_id=portfolio_id).all()
    result = []
    
    for holding in holdings:
        # Get current market price
        market_data = MarketData.query.filter_by(stock_symbol=holding.stock_symbol)\
            .order_by(MarketData.timestamp.desc()).first()
        
        current_price = market_data.price if market_data else holding.purchase_price
        current_value = holding.quantity * current_price
        investment = holding.quantity * holding.purchase_price
        gain_loss = current_value - investment
        
        result.append({
            'id': holding.id,
            'stock_symbol': holding.stock_symbol,
            'quantity': holding.quantity,
            'purchase_price': holding.purchase_price,
            'current_price': current_price,
            'current_value': current_value,
            'investment': investment,
            'gain_loss': gain_loss,
            'sector': holding.sector,
            'purchase_date': holding.purchase_date.isoformat()
        })
    
    return jsonify(result)

@app.route('/api/portfolios/<int:portfolio_id>/holdings', methods=['POST'])
def add_holding(portfolio_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    portfolio = Portfolio.query.filter_by(id=portfolio_id, user_id=session['user_id']).first()
    if not portfolio:
        return jsonify({'error': 'Portfolio not found'}), 404
    
    data = request.get_json()
    holding = Holding(
        portfolio_id=portfolio_id,
        stock_symbol=data['stock_symbol'],
        quantity=data['quantity'],
        purchase_price=data['purchase_price'],
        sector=data.get('sector', 'Unknown')
    )
    
    db.session.add(holding)
    db.session.commit()
    
    return jsonify({'id': holding.id, 'message': 'Holding added successfully'})

@app.route('/api/advisory/<string:stock_symbol>')
def get_advisory_signal(stock_symbol):
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    # Check if we have a recent signal
    recent_signal = AdvisorySignal.query.filter_by(stock_symbol=stock_symbol)\
        .order_by(AdvisorySignal.generated_at.desc()).first()
    
    # If signal is recent (within 1 hour), return it
    if recent_signal and (datetime.utcnow() - recent_signal.generated_at).total_seconds() < 3600:
        return jsonify({
            'signal': recent_signal.signal,
            'confidence': recent_signal.confidence,
            'reasoning': recent_signal.reasoning,
            'generated_at': recent_signal.generated_at.isoformat()
        })
    
    # Get sector from market data or holdings
    market_data = MarketData.query.filter_by(stock_symbol=stock_symbol)\
        .order_by(MarketData.timestamp.desc()).first()
    sector = market_data.sector if market_data else 'Unknown'
    
    # Generate new signal
    signal_data = AdvisoryEngine.generate_signal(stock_symbol, sector)
    
    # Store the signal
    advisory_signal = AdvisorySignal(
        stock_symbol=stock_symbol,
        signal=signal_data['signal'],
        confidence=signal_data['confidence'],
        reasoning=signal_data['reasoning'],
        sector=sector
    )
    
    db.session.add(advisory_signal)
    db.session.commit()
    
    return jsonify({
        'signal': signal_data['signal'],
        'confidence': signal_data['confidence'],
        'reasoning': signal_data['reasoning'],
        'generated_at': advisory_signal.generated_at.isoformat()
    })

@app.route('/api/dashboard/analytics')
@advisor_required
def get_dashboard_analytics():
    """Advisor-only dashboard analytics"""
    # Portfolio statistics
    total_portfolios = Portfolio.query.count()
    total_holdings = Holding.query.count()
    total_users = User.query.count()
    
    # Sector distribution
    sector_holdings = db.session.query(
        Holding.sector, 
        db.func.sum(Holding.quantity * Holding.purchase_price).label('total_value')
    ).group_by(Holding.sector).all()
    
    sector_data = [{'sector': s[0], 'value': s[1]} for s in sector_holdings if s[0]]
    
    # Recent signals
