# ipm_55_py.py
"""
IPM-55: Main application module for Indian Portfolio Manager
Combines portfolio management, advisory signals, and dashboard functionality
"""

import os
import json
import datetime
import pandas as pd
import numpy as np
from typing import Dict, List, Optional, Tuple
from flask import Flask, request, jsonify, render_template, session, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from werkzeug.security import generate_password_hash, check_password_hash
import yfinance as yf
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
import threading
import time

# Initialize Flask application
app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///ipm.db')
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
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='client')  # 'admin', 'advisor', 'client'
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)
    
    portfolios = db.relationship('Portfolio', backref='owner', lazy=True)
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Portfolio(db.Model):
    __tablename__ = 'portfolios'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
    
    holdings = db.relationship('Holding', backref='portfolio', lazy=True, cascade='all, delete-orphan')

class Holding(db.Model):
    __tablename__ = 'holdings'
    id = db.Column(db.Integer, primary_key=True)
    portfolio_id = db.Column(db.Integer, db.ForeignKey('portfolios.id'), nullable=False)
    symbol = db.Column(db.String(20), nullable=False)  # NSE symbol format: RELIANCE.NS, INFY.NS
    quantity = db.Column(db.Integer, nullable=False)
    average_price = db.Column(db.Float, nullable=False)
    added_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)

class AdvisorySignal(db.Model):
    __tablename__ = 'advisory_signals'
    id = db.Column(db.Integer, primary_key=True)
    symbol = db.Column(db.String(20), nullable=False)
    signal = db.Column(db.String(10), nullable=False)  # BUY, HOLD, SELL
    confidence = db.Column(db.Float, nullable=False)  # 0.0 to 1.0
    reasoning = db.Column(db.Text, nullable=False)
    generated_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)
    valid_until = db.Column(db.DateTime, nullable=False)

# Market Data Integration
class MarketData:
    def __init__(self):
        self.indian_indices = ['^NSEI', '^CNX100', '^NSMIDCP']  # Nifty 50, Nifty 100, Nifty Midcap
        self.update_interval = 300  # 5 minutes in seconds
        self.current_data = {}
        self.lock = threading.Lock()
        
        # Start background update thread
        self.update_thread = threading.Thread(target=self._background_updater)
        self.update_thread.daemon = True
        self.update_thread.start()
    
    def _background_updater(self):
        while True:
            try:
                self.update_market_data()
            except Exception as e:
                print(f"Error updating market data: {e}")
            time.sleep(self.update_interval)
    
    def update_market_data(self):
        """Fetch latest market data for Indian indices and popular stocks"""
        symbols = self.indian_indices + ['RELIANCE.NS', 'TCS.NS', 'HDFCBANK.NS', 'INFY.NS', 'ICICIBANK.NS']
        new_data = {}
        
        for symbol in symbols:
            try:
                ticker = yf.Ticker(symbol)
                info = ticker.info
                history = ticker.history(period='1d', interval='1m')
                
                if not history.empty:
                    latest = history.iloc[-1]
                    new_data[symbol] = {
                        'price': latest['Close'],
                        'change': latest['Close'] - history.iloc[0]['Open'],
                        'change_percent': (latest['Close'] - history.iloc[0]['Open']) / history.iloc[0]['Open'] * 100,
                        'volume': latest['Volume'],
                        'last_updated': datetime.datetime.utcnow()
                    }
            except Exception as e:
                print(f"Failed to fetch data for {symbol}: {e}")
                continue
        
        with self.lock:
            self.current_data = new_data
    
    def get_data(self, symbol=None):
        """Get market data for specific symbol or all symbols"""
        with self.lock:
            if symbol:
                return self.current_data.get(symbol, {})
            return self.current_data

# Advisory Signal Engine
class AdvisoryEngine:
    def __init__(self):
        self.model = RandomForestClassifier(n_estimators=100, random_state=42)
        self.scaler = StandardScaler()
        self.training_data = self._prepare_training_data()
        self._train_model()
    
    def _prepare_training_data(self):
        """Prepare historical training data for Indian stocks"""
        # This would normally come from a proper historical database
        # For demonstration, we'll create some synthetic data
        symbols = ['RELIANCE.NS', 'TCS.NS', 'HDFCBANK.NS', 'INFY.NS']
        training_data = []
        
        for symbol in symbols:
            try:
                ticker = yf.Ticker(symbol)
                history = ticker.history(period='2y')
                
                if len(history) > 100:
                    # Calculate features
                    history['Returns'] = history['Close'].pct_change()
                    history['Volatility'] = history['Returns'].rolling(20).std()
                    history['MA_50'] = history['Close'].rolling(50).mean()
                    history['MA_200'] = history['Close'].rolling(200).mean()
                    history['RSI'] = self._calculate_rsi(history['Close'])
                    
                    # Create labels (1 if next day return > 0, else 0)
                    history['Label'] = (history['Returns'].shift(-1) > 0).astype(int)
                    
                    # Clean data
                    history = history.dropna()
                    
                    for i in range(50, len(history)-1):
                        features = [
                            history['Returns'].iloc[i],
                            history['Volatility'].iloc[i],
                            history['MA_50'].iloc[i] / history['Close'].iloc[i] - 1,
                            history['MA_200'].iloc[i] / history['Close'].iloc[i] - 1,
                            history['RSI'].iloc[i]
                        ]
                        training_data.append((features, history['Label'].iloc[i]))
            except Exception as e:
                print(f"Failed to prepare training data for {symbol}: {e}")
                continue
        
        return training_data
    
    def _calculate_rsi(self, prices, period=14):
        """Calculate Relative Strength Index"""
        deltas = prices.diff()
        gains = deltas.where(deltas > 0, 0)
        losses = -deltas.where(deltas < 0, 0)
        
        avg_gain = gains.rolling(period).mean()
        avg_loss = losses.rolling(period).mean()
        
        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))
        return rsi
    
    def _train_model(self):
        """Train the machine learning model"""
        if not self.training_data:
            return
        
        X = [data[0] for data in self.training_data]
        y = [data[1] for data in self.training_data]
        
        X_scaled = self.scaler.fit_transform(X)
        self.model.fit(X_scaled, y)
    
    def generate_signal(self, symbol):
        """Generate advisory signal for a given symbol"""
        try:
            ticker = yf.Ticker(symbol)
            history = ticker.history(period='60d')
            
            if len(history) < 50:
                return {
                    'signal': 'HOLD',
                    'confidence': 0.5,
                    'reasoning': 'Insufficient historical data for analysis'
                }
            
            # Calculate features
            returns = history['Close'].pct_change().iloc[-1]
            volatility = history['Close'].pct_change().rolling(20).std().iloc[-1]
            ma_50 = history['Close'].rolling(50).mean().iloc[-1]
            ma_200 = history['Close'].rolling(200).mean().iloc[-1]
            rsi = self._calculate_rsi(history['Close']).iloc[-1]
            
            features = [returns, volatility, ma_50/history['Close'].iloc[-1]-1, 
                       ma_200/history['Close'].iloc[-1]-1, rsi]
            
            # Scale features and predict
            features_scaled = self.scaler.transform([features])
            prediction = self.model.predict_proba(features_scaled)[0]
            
            # Determine signal
            buy_prob = prediction[1]
            sell_prob = prediction[0]
            
            if buy_pr
# Code truncated at 10000 characters