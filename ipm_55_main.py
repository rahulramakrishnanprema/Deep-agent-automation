"""
Main application file for IPM MVP - Indian Portfolio Management System
This file sets up the Flask application, configures routes, and integrates all components.
"""

from flask import Flask, render_template, jsonify, request, session, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func
import json
import random
from datetime import datetime, timedelta
import yfinance as yf
import numpy as np
from typing import Dict, List, Any

# Initialize Flask application
app = Flask(__name__)
app.secret_key = 'ipm_mvp_secret_key_2024'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///ipm_portfolio.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize database
db = SQLAlchemy(app)

# Database Models
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)
    role = db.Column(db.String(20), nullable=False)  # 'advisor' or 'client'
    email = db.Column(db.String(120), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Portfolio(db.Model):
    __tablename__ = 'portfolios'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class PortfolioHolding(db.Model):
    __tablename__ = 'portfolio_holdings'
    id = db.Column(db.Integer, primary_key=True)
    portfolio_id = db.Column(db.Integer, db.ForeignKey('portfolios.id'), nullable=False)
    stock_symbol = db.Column(db.String(20), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    average_price = db.Column(db.Float, nullable=False)
    sector = db.Column(db.String(50))
    added_date = db.Column(db.DateTime, default=datetime.utcnow)

class AdvisorySignal(db.Model):
    __tablename__ = 'advisory_signals'
    id = db.Column(db.Integer, primary_key=True)
    stock_symbol = db.Column(db.String(20), nullable=False)
    signal_type = db.Column(db.String(10), nullable=False)  # BUY, HOLD, SELL
    confidence_score = db.Column(db.Float, nullable=False)
    reasoning = db.Column(db.Text)
    generated_at = db.Column(db.DateTime, default=datetime.utcnow)
    sector = db.Column(db.String(50))

# Technical Analysis Functions
def calculate_rsi(prices: List[float], period: int = 14) -> float:
    """Calculate Relative Strength Index"""
    if len(prices) < period + 1:
        return 50.0  # Neutral value for insufficient data
    
    deltas = np.diff(prices)
    gains = np.where(deltas > 0, deltas, 0)
    losses = np.where(deltas < 0, -deltas, 0)
    
    avg_gain = np.mean(gains[:period])
    avg_loss = np.mean(losses[:period])
    
    if avg_loss == 0:
        return 100.0
    
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    return round(rsi, 2)

def calculate_macd(prices: List[float]) -> Dict[str, float]:
    """Calculate MACD indicator"""
    if len(prices) < 26:
        return {'macd': 0, 'signal': 0, 'histogram': 0}
    
    exp12 = np.convolve(prices, np.exp(-np.arange(12) / 12 * 2)[::-1], mode='valid')[-1]
    exp26 = np.convolve(prices, np.exp(-np.arange(26) / 26 * 2)[::-1], mode='valid')[-1]
    
    macd = exp12 - exp26
    signal = np.convolve([macd] * 9, np.exp(-np.arange(9) / 9 * 2)[::-1], mode='valid')[0]
    histogram = macd - signal
    
    return {
        'macd': round(macd, 4),
        'signal': round(signal, 4),
        'histogram': round(histogram, 4)
    }

def calculate_moving_averages(prices: List[float]) -> Dict[str, float]:
    """Calculate various moving averages"""
    return {
        'sma_50': round(np.mean(prices[-50:]), 2) if len(prices) >= 50 else np.mean(prices),
        'sma_200': round(np.mean(prices[-200:]), 2) if len(prices) >= 200 else np.mean(prices),
        'ema_20': round(np.convolve(prices[-20:], np.exp(-np.arange(20) / 20 * 2)[::-1], mode='valid')[0], 2)
    }

# Advisory Signal Generation
def generate_advisory_signals() -> List[Dict[str, Any]]:
    """Generate advisory signals for Indian stocks"""
    indian_stocks = [
        'RELIANCE.NS', 'TCS.NS', 'HDFCBANK.NS', 'INFY.NS', 'ICICIBANK.NS',
        'HINDUNILVR.NS', 'SBIN.NS', 'BHARTIARTL.NS', 'ITC.NS', 'KOTAKBANK.NS',
        'BAJFINANCE.NS', 'LT.NS', 'HCLTECH.NS', 'AXISBANK.NS', 'MARUTI.NS'
    ]
    
    sectors = {
        'RELIANCE.NS': 'Energy',
        'TCS.NS': 'IT',
        'HDFCBANK.NS': 'Banking',
        'INFY.NS': 'IT',
        'ICICIBANK.NS': 'Banking',
        'HINDUNILVR.NS': 'FMCG',
        'SBIN.NS': 'Banking',
        'BHARTIARTL.NS': 'Telecom',
        'ITC.NS': 'FMCG',
        'KOTAKBANK.NS': 'Banking',
        'BAJFINANCE.NS': 'Finance',
        'LT.NS': 'Construction',
        'HCLTECH.NS': 'IT',
        'AXISBANK.NS': 'Banking',
        'MARUTI.NS': 'Automobile'
    }
    
    signals = []
    
    for symbol in indian_stocks:
        try:
            # Get historical data
            stock = yf.Ticker(symbol)
            hist = stock.history(period='6mo')
            
            if hist.empty:
                continue
                
            prices = hist['Close'].tolist()
            
            # Calculate technical indicators
            rsi = calculate_rsi(prices)
            macd = calculate_macd(prices)
            moving_avgs = calculate_moving_averages(prices)
            
            # Generate signal based on multiple factors
            current_price = prices[-1]
            price_change = ((current_price - prices[0]) / prices[0]) * 100
            
            # Technical analysis weight
            tech_score = 0
            if rsi < 30:
                tech_score += 0.3
            elif rsi > 70:
                tech_score -= 0.3
                
            if macd['histogram'] > 0:
                tech_score += 0.2
            else:
                tech_score -= 0.2
                
            if current_price > moving_avgs['sma_50']:
                tech_score += 0.2
            else:
                tech_score -= 0.2
                
            if current_price > moving_avgs['sma_200']:
                tech_score += 0.3
            else:
                tech_score -= 0.3
            
            # Historical performance weight
            hist_score = price_change / 100  # Normalize to -1 to 1 range
            
            # Sector potential (dummy implementation)
            sector_potential = {
                'IT': 0.8, 'Banking': 0.6, 'FMCG': 0.7, 
                'Energy': 0.5, 'Telecom': 0.4, 'Finance': 0.6,
                'Construction': 0.3, 'Automobile': 0.5
            }
            sector_score = sector_potential.get(sectors[symbol], 0.5)
            
            # Market buzz (random for demo)
            market_buzz = random.uniform(0.4, 0.9)
            
            # Combined score
            total_score = (
                tech_score * 0.4 + 
                hist_score * 0.2 + 
                sector_score * 0.2 + 
                market_buzz * 0.2
            )
            
            # Determine signal type
            if total_score > 0.3:
                signal_type = 'BUY'
                confidence = min(90, int((total_score - 0.3) * 150))
            elif total_score < -0.3:
                signal_type = 'SELL'
                confidence = min(90, int((-total_score - 0.3) * 150))
            else:
                signal_type = 'HOLD'
                confidence = 50
            
            reasoning = f"""
            Technical: RSI({rsi}), MACD Hist({macd['histogram']:.4f}), 
            Price vs SMA50({'Above' if current_price > moving_avgs['sma_50'] else 'Below'})
            Historical: {price_change:.2f}% change, 
            Sector: {sectors[symbol]} potential, 
            Market sentiment: {'Positive' if market_buzz > 0.6 else 'Neutral' if market_buzz > 0.4 else 'Negative'}
            """
            
            signals.append({
                'symbol': symbol.replace('.NS', ''),
                'signal_type': signal_type,
                'confidence_score': confidence,
                'reasoning': reasoning,
                'sector': sectors[symbol],
                'current_price': current_price,
                'price_change': price_change
            })
            
        except Exception as e:
            print(f"Error processing {symbol}: {str(e)}")
            continue
    
    return signals

# Dummy Data Generation
def generate_dummy_data():
    """Generate dummy data for MVP demonstration"""
    # Create test users
    if not User.query.filter_by(username='advisor1').first():
        advisor = User(
            username='advisor1',
            password='password123',
            role='advisor',
            email='advisor@ipm.com'
        )
        db.session.add(advisor)
        
        client = User(
            username='client1',
            password='password123',
            role='client',
            email='client@ipm.com'
        )
        db.session.add(client)
        db.session.commit()
        
        # Create sample portfolio
        portfolio = Portfolio(
            user_id=client.id,
            name='Main Investment Portfolio',
            description='Primary equity portfolio for long-term growth'
        )
        db.session.add(portfolio)
        db.session.commit()
        
        # Add sample holdings
        sample_holdings = [
            ('RELIANCE', 50, 2500.00, 'Energy'),
            ('TCS', 25, 3200.00, 'IT'),
            ('HDFCBANK', 75, 1400.00, 'Banking'),
            ('INFY', 40, 1600.00, 'IT'),
            ('ICICIBANK', 60, 900.00, 'Banking')
        ]
        
        for symbol, qty, price, sector in sample_holdings:
            holding = PortfolioHolding(
                portfolio_id=portfolio.id,
                stock_symbol=symbol,
                quantity=qty,
                average_price=price,
                sector=sector
            )
            db.session.add(holding)
        
        db.session.commit()
        print("Dummy data generated successfully")

# Routes
@app.route('/')
def home():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    user = User.query.get(session['user_id'])
    if user.role == 'advisor':
        return redirect(url_for('advisor_dashboard'))
    else:
        return redirect(url_for('client_portfolio'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        user = User.query.filter_by(username=username, password=password).first()
        if user:
            session['user_id'] = user.id
            session['user_role'] = user.role
            return redirect(url_for('home'))
        else:
            return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/client/portfolio')
def client_portfolio():
    if 'user_id' not in session or session.get('user_role') != 'client':
        return redirect(url_for('login'))
    
    user = User.query.get(session['user_id'])
    portfolios = Portfolio.query.filter_by(user_id=user.id).all()
    
    portfolio_data = []
    for portfolio in portfolios:
        holdings = PortfolioHolding.query.filter_by(portfolio_id=portfolio.id).all()
        total_value = sum(h.quantity * h.average_price for h in holdings)
        
        portfolio_data.append({
            'id': portfolio.id,
            'name': portfolio.name,
            'description': portfolio.description,
            'holdings': holdings,
            'total_value': total_value,
            'last_updated': portfolio.updated_at
        })
    
    return render_template('client_portfolio.html', portfolios=portfolio_data)

@app.route('/api/portfolio/<int:portfolio_id>')
def api_portfolio(portfolio_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    
    portfolio = Portfolio.query.get_or_404(portfolio_id)
    if portfolio.user_id != session['user_id'] and session.get('user_role') != 'advisor':
        return jsonify({'error': 'Access denied'}), 403
    
    holdings = PortfolioHolding.query.filter_by(portfolio_id=portfolio_id).all()
    
    portfolio_value = sum(h.quantity * h.average_price for h in holdings)
    sector_allocation = {}
    
    for holding in holdings:
        sector = holding.sector or 'Other'
        value = holding.quantity * holding.average_price
        sector_allocation[sector] = sector_allocation.get(sector, 0) + value
    
    return jsonify({
        'portfolio': {
            'id': portfolio.id,
            'name': portfolio.name,
            'total_value': portfolio_value
        },
        'holdings': [
            {
                'symbol': h.stock_symbol,
                'quantity': h.quantity,
                'average_price': h.average_price,
                'current_value': h.quantity * h.average_price,
                'sector': h.sector
            } for h in holdings
        ],
        'sector_allocation': sector_allocation
    })

@app.route('/advisor/dashboard')
def advisor_dashboard():
    if 'user_id' not in session or session.get('user_role') != 'advisor':
        return redirect(url_for('login'))
    
    # Get all client portfolios
    clients = User.query.filter_by(role='client').all()
    all_portfolios = []
    
    for client in clients:
        portfolios = Portfolio.query.filter_by(user_id=client.id).all()
        for portfolio in portfolios:
            holdings = PortfolioHolding.query.filter_by(portfolio_id=portfolio.id).all()
            total_value = sum(h.quantity * h.average_price for h in holdings)
            
            all_portfolios.append({
                'client_id': client.id,
                'client_name': client.username,
                'portfolio_id': portfolio.id,
                'portfolio_name': portfolio.name,
                'total_value': total_value,
                'holdings_count': len(holdings)
            })
    
    # Generate advisory signals
    signals = generate_advisory_signals()
    
    return render_template('advisor_dashboard.html', 
                         portfolios=all_portfolios,
                         signals=signals)

@app.route('/api/advisory/signals')
def api_advisory_signals():
    if 'user_id' not in session or session.get('user_role') != 'advisor':
        return jsonify({'error': 'Unauthorized'}), 401
    
    signals = generate_advisory_signals()
    return jsonify(signals)

@app.route('/api/portfolio/performance/<int:portfolio_id>')
def api_portfolio_performance(portfolio_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    
    portfolio = Portfolio.query.get_or_404(portfolio_id)
    if portfolio.user_id != session['user_id'] and session.get('user_role') != 'advisor':
        return jsonify({'error': 'Access denied'}), 403
    
    # Generate dummy performance data
    dates = [datetime.now() - timedelta(days=i) for i in range(30, 0, -1)]
    base_value = 1000000  # Starting value
    performance_data = []
    
    for i, date in enumerate(dates):
        # Simulate daily changes (±2%)
        daily_change = random.uniform(-0.02, 0.02)
        value = base_value * (1 + daily_change)
        performance_data.append({
            'date': date.strftime('%Y-%m-%d'),
            'value': round(value, 2)
        })
        base_value = value
    
    return jsonify(performance_data)

# Error handlers
@app.errorhandler(404)
def not_found_error