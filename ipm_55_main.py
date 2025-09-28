import json
import random
import datetime
from typing import List, Dict, Any, Optional
import pandas as pd
import numpy as np
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, session
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
import yfinance as yf
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)
app.secret_key = 'your-secret-key-here'  # Change this in production

# Initialize Flask-Login
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# Dummy user data storage
users = {
    'advisor1': {
        'password': generate_password_hash('password123'),
        'role': 'advisor',
        'name': 'Financial Advisor'
    },
    'client1': {
        'password': generate_password_hash('client123'),
        'role': 'client',
        'name': 'Investment Client'
    }
}

class User(UserMixin):
    def __init__(self, user_id, user_data):
        self.id = user_id
        self.role = user_data['role']
        self.name = user_data['name']

@login_manager.user_loader
def load_user(user_id):
    if user_id in users:
        return User(user_id, users[user_id])
    return None

# Dummy portfolio data storage
portfolios = {
    'client1': {
        'holdings': [
            {'symbol': 'RELIANCE.NS', 'quantity': 10, 'avg_price': 2500},
            {'symbol': 'TCS.NS', 'quantity': 5, 'avg_price': 3200},
            {'symbol': 'HDFCBANK.NS', 'quantity': 8, 'avg_price': 1400},
            {'symbol': 'INFY.NS', 'quantity': 12, 'avg_price': 1500}
        ],
        'cash_balance': 50000
    }
}

class TechnicalIndicators:
    @staticmethod
    def calculate_sma(prices: List[float], window: int = 20) -> List[float]:
        """Calculate Simple Moving Average"""
        return pd.Series(prices).rolling(window=window).mean().tolist()

    @staticmethod
    def calculate_rsi(prices: List[float], window: int = 14) -> List[float]:
        """Calculate Relative Strength Index"""
        delta = pd.Series(prices).diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=window).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=window).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        return rsi.fillna(50).tolist()

    @staticmethod
    def calculate_macd(prices: List[float], fast: int = 12, slow: int = 26, signal: int = 9) -> Dict[str, List[float]]:
        """Calculate MACD indicator"""
        fast_ema = pd.Series(prices).ewm(span=fast).mean()
        slow_ema = pd.Series(prices).ewm(span=slow).mean()
        macd_line = fast_ema - slow_ema
        signal_line = macd_line.ewm(span=signal).mean()
        histogram = macd_line - signal_line
        
        return {
            'macd_line': macd_line.tolist(),
            'signal_line': signal_line.tolist(),
            'histogram': histogram.tolist()
        }

class PortfolioAnalyzer:
    def __init__(self):
        self.indicators = TechnicalIndicators()
    
    def generate_advisory_signal(self, symbol: str, historical_data: pd.DataFrame) -> str:
        """Generate Buy/Hold/Sell signal based on technical analysis"""
        prices = historical_data['Close'].tolist()
        
        # Calculate technical indicators
        sma_20 = self.indicators.calculate_sma(prices, 20)[-1]
        sma_50 = self.indicators.calculate_sma(prices, 50)[-1]
        rsi = self.indicators.calculate_rsi(prices)[-1]
        macd = self.indicators.calculate_macd(prices)
        
        current_price = prices[-1]
        
        # Simple signal generation logic
        signal_score = 0
        
        # Price vs SMA comparison
        if current_price > sma_20:
            signal_score += 1
        if current_price > sma_50:
            signal_score += 1
            
        # RSI analysis
        if rsi < 30:
            signal_score += 2  # Oversold - bullish
        elif rsi > 70:
            signal_score -= 2  # Overbought - bearish
            
        # MACD analysis
        if macd['macd_line'][-1] > macd['signal_line'][-1]:
            signal_score += 1
            
        # Generate final signal
        if signal_score >= 3:
            return 'Buy'
        elif signal_score <= -2:
            return 'Sell'
        else:
            return 'Hold'
    
    def analyze_sector_potential(self, sector: str) -> Dict[str, Any]:
        """Assess sector potential based on market sentiment"""
        # Dummy sector analysis
        sector_potentials = {
            'Technology': {'potential': 'High', 'outlook': 'Bullish', 'score': 85},
            'Financial': {'potential': 'Medium', 'outlook': 'Neutral', 'score': 65},
            'Healthcare': {'potential': 'High', 'outlook': 'Bullish', 'score': 80},
            'Energy': {'potential': 'Low', 'outlook': 'Bearish', 'score': 40},
            'Consumer': {'potential': 'Medium', 'outlook': 'Neutral', 'score': 60}
        }
        
        return sector_potentials.get(sector, {'potential': 'Unknown', 'outlook': 'Neutral', 'score': 50})
    
    def integrate_market_sentiment(self) -> Dict[str, float]:
        """Integrate market sentiment data"""
        # Dummy sentiment scores
        return {
            'overall_sentiment': random.uniform(0.4, 0.8),
            'bullish_ratio': random.uniform(0.3, 0.7),
            'market_volatility': random.uniform(0.1, 0.4)
        }

class DataVisualizer:
    @staticmethod
    def prepare_portfolio_chart_data(portfolio_value_history: List[Dict]) -> Dict[str, Any]:
        """Prepare data for portfolio value charts"""
        dates = [item['date'] for item in portfolio_value_history]
        values = [item['value'] for item in portfolio_value_history]
        
        return {
            'dates': dates,
            'values': values,
            'performance': ((values[-1] - values[0]) / values[0]) * 100 if len(values) > 1 else 0
        }
    
    @staticmethod
    def prepare_sector_allocation(holdings: List[Dict]) -> Dict[str, float]:
        """Prepare sector allocation data for pie charts"""
        # Dummy sector mapping
        sector_mapping = {
            'RELIANCE.NS': 'Energy',
            'TCS.NS': 'Technology',
            'HDFCBANK.NS': 'Financial',
            'INFY.NS': 'Technology'
        }
        
        sector_values = {}
        for holding in holdings:
            sector = sector_mapping.get(holding['symbol'], 'Other')
            current_price = yf.Ticker(holding['symbol']).history(period='1d')['Close'].iloc[-1]
            value = holding['quantity'] * current_price
            
            if sector in sector_values:
                sector_values[sector] += value
            else:
                sector_values[sector] = value
        
        return sector_values

@app.route('/')
@login_required
def dashboard():
    """Main dashboard showing portfolio overview"""
    if current_user.role == 'client':
        portfolio = portfolios.get(current_user.id, {'holdings': [], 'cash_balance': 0})
        analyzer = PortfolioAnalyzer()
        visualizer = DataVisualizer()
        
        # Calculate current portfolio value
        total_value = portfolio['cash_balance']
        holdings_data = []
        
        for holding in portfolio['holdings']:
            try:
                ticker = yf.Ticker(holding['symbol'])
                hist = ticker.history(period='1d')
                current_price = hist['Close'].iloc[-1] if not hist.empty else holding['avg_price']
                
                holding_value = holding['quantity'] * current_price
                total_value += holding_value
                
                # Generate advisory signal
                historical_data = ticker.history(period='1mo')
                signal = analyzer.generate_advisory_signal(holding['symbol'], historical_data)
                
                holdings_data.append({
                    'symbol': holding['symbol'],
                    'quantity': holding['quantity'],
                    'avg_price': holding['avg_price'],
                    'current_price': current_price,
                    'value': holding_value,
                    'pnl': holding_value - (holding['quantity'] * holding['avg_price']),
                    'signal': signal
                })
                
            except Exception as e:
                print(f"Error processing {holding['symbol']}: {e}")
                continue
        
        # Prepare chart data
        portfolio_history = [
            {'date': (datetime.datetime.now() - datetime.timedelta(days=i)).strftime('%Y-%m-%d'), 
             'value': total_value * random.uniform(0.95, 1.05)}
            for i in range(30, 0, -1)
        ]
        chart_data = visualizer.prepare_portfolio_chart_data(portfolio_history)
        sector_data = visualizer.prepare_sector_allocation(portfolio['holdings'])
        
        market_sentiment = analyzer.integrate_market_sentiment()
        
        return render_template('dashboard.html',
                             holdings=holdings_data,
                             cash_balance=portfolio['cash_balance'],
                             total_value=total_value,
                             chart_data=chart_data,
                             sector_data=json.dumps(sector_data),
                             market_sentiment=market_sentiment)
    
    else:
        # Advisor view - show all client portfolios
        client_portfolios = []
        for client_id, portfolio in portfolios.items():
            if client_id in users and users[client_id]['role'] == 'client':
                client_portfolios.append({
                    'client_id': client_id,
                    'client_name': users[client_id]['name'],
                    'portfolio_value': sum([h['quantity'] * h['avg_price'] for h in portfolio['holdings']]) + portfolio['cash_balance']
                })
        
        return render_
# Code truncated at 10000 characters