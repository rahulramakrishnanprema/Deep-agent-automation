"""
Main application file for Indian Portfolio Manager MVP.
This module initializes the Flask application, sets up database connections,
and registers blueprints for portfolio management and advisory signals.
"""

from flask import Flask, render_template, jsonify
from flask_cors import CORS
import sqlite3
import os
from datetime import datetime, timedelta
import random

# Initialize Flask application
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Database configuration
DATABASE = 'ipm_database.db'

def get_db_connection():
    """Establish and return a database connection."""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initialize the database with required tables."""
    conn = get_db_connection()
    
    # Create portfolios table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS portfolios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            client_name TEXT NOT NULL,
            created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Create securities table with Indian market identifiers
    conn.execute('''
        CREATE TABLE IF NOT EXISTS securities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            isin_code TEXT UNIQUE NOT NULL,
            bse_code TEXT,
            nse_symbol TEXT,
            company_name TEXT NOT NULL,
            sector TEXT NOT NULL,
            current_price REAL DEFAULT 0,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Create transactions table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            portfolio_id INTEGER NOT NULL,
            security_id INTEGER NOT NULL,
            transaction_type TEXT CHECK(transaction_type IN ('BUY', 'SELL')) NOT NULL,
            quantity INTEGER NOT NULL,
            price REAL NOT NULL,
            transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (portfolio_id) REFERENCES portfolios (id),
            FOREIGN KEY (security_id) REFERENCES securities (id)
        )
    ''')
    
    conn.commit()
    conn.close()

def populate_dummy_data():
    """Populate database with realistic Indian equity market dummy data."""
    conn = get_db_connection()
    
    # Check if data already exists
    result = conn.execute('SELECT COUNT(*) as count FROM securities').fetchone()
    if result['count'] == 0:
        # Indian equity securities data
        indian_securities = [
            # Large Cap
            ('INE009A01021', '500112', 'RELIANCE', 'Reliance Industries Ltd.', 'Energy', 2850.75),
            ('INE238A01034', '500325', 'HDFCBANK', 'HDFC Bank Ltd.', 'Banking', 1650.50),
            ('INE154A01025', '500510', 'TCS', 'Tata Consultancy Services Ltd.', 'IT', 3850.25),
            ('INE101A01026', '532540', 'INFY', 'Infosys Ltd.', 'IT', 1850.30),
            ('INE002A01018', '500520', 'ICICIBANK', 'ICICI Bank Ltd.', 'Banking', 1050.40),
            
            # Mid Cap
            ('INE844G01015', '543320', 'DEEPAKNTR', 'Deepak Nitrite Ltd.', 'Chemicals', 2450.60),
            ('INE0J1Y01017', '540777', 'APLAPOLLO', 'APL Apollo Tubes Ltd.', 'Metals', 1550.80),
            ('INE216A01023', '517354', 'HAVELLS', 'Havells India Ltd.', 'Consumer Durables', 1450.25),
            ('INE489G01015', '540673', 'NAVINFLUOR', 'Navin Fluorine International Ltd.', 'Chemicals', 4850.90),
            ('INE0CG101023', '500690', 'MRF', 'MRF Ltd.', 'Auto', 125000.75),
            
            # Small Cap
            ('INE0L3801017', '526355', 'TANLA', 'Tanla Platforms Ltd.', 'IT', 985.40),
            ('INE0M2401019', '526367', 'MOTILALOFS', 'Motilal Oswal Financial Services Ltd.', 'Financial Services', 850.60),
            ('INE0P0701021', '526371', 'NCC', 'NCC Ltd.', 'Construction', 125.75),
            ('INE0Q0701023', '526377', 'JINDALSAW', 'Jindal Saw Ltd.', 'Metals', 450.30),
            ('INE0R2401025', '526385', 'TV18BRDCST', 'TV18 Broadcast Ltd.', 'Media', 45.20)
        ]
        
        # Insert securities data
        for isin, bse, nse, name, sector, price in indian_securities:
            conn.execute('''
                INSERT INTO securities (isin_code, bse_code, nse_symbol, company_name, sector, current_price)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (isin, bse, nse, name, sector, price))
        
        # Create sample portfolios
        conn.execute('''
            INSERT INTO portfolios (name, client_name)
            VALUES ('Conservative Portfolio', 'Rahul Sharma')
        ''')
        
        conn.execute('''
            INSERT INTO portfolios (name, client_name)
            VALUES ('Growth Portfolio', 'Priya Patel')
        ''')
        
        conn.execute('''
            INSERT INTO portfolios (name, client_name)
            VALUES ('Aggressive Portfolio', 'Amit Kumar')
        ''')
        
        # Get portfolio IDs
        portfolios = conn.execute('SELECT id FROM portfolios').fetchall()
        
        # Get security IDs
        securities = conn.execute('SELECT id FROM securities').fetchall()
        
        # Create sample transactions
        transaction_types = ['BUY', 'SELL']
        for portfolio in portfolios:
            for security in securities[:5]:  # Add transactions for first 5 securities in each portfolio
                conn.execute('''
                    INSERT INTO transactions (portfolio_id, security_id, transaction_type, quantity, price, transaction_date)
                    VALUES (?, ?, ?, ?, ?, ?)
                ''', (
                    portfolio['id'],
                    security['id'],
                    random.choice(transaction_types),
                    random.randint(10, 100),
                    random.uniform(100, 5000),
                    (datetime.now() - timedelta(days=random.randint(1, 365))).strftime('%Y-%m-%d %H:%M:%S')
                ))
        
        conn.commit()
    
    conn.close()

@app.route('/')
def index():
    """Serve the main dashboard page."""
    return render_template('index.html')

@app.route('/api/portfolios', methods=['GET'])
def get_portfolios():
    """Get all portfolios with their current values."""
    try:
        conn = get_db_connection()
        
        portfolios = conn.execute('''
            SELECT p.*, 
                   SUM(t.quantity * s.current_price) as current_value,
                   COUNT(t.id) as transaction_count
            FROM portfolios p
            LEFT JOIN transactions t ON p.id = t.portfolio_id
            LEFT JOIN securities s ON t.security_id = s.id
            GROUP BY p.id
        ''').fetchall()
        
        result = []
        for portfolio in portfolios:
            result.append({
                'id': portfolio['id'],
                'name': portfolio['name'],
                'client_name': portfolio['client_name'],
                'created_date': portfolio['created_date'],
                'last_updated': portfolio['last_updated'],
                'current_value': portfolio['current_value'] or 0,
                'transaction_count': portfolio['transaction_count']
            })
        
        conn.close()
        return jsonify(result)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/portfolio/<int:portfolio_id>', methods=['GET'])
def get_portfolio_details(portfolio_id):
    """Get detailed information for a specific portfolio."""
    try:
        conn = get_db_connection()
        
        # Get portfolio basic info
        portfolio = conn.execute('''
            SELECT * FROM portfolios WHERE id = ?
        ''', (portfolio_id,)).fetchone()
        
        if not portfolio:
            return jsonify({'error': 'Portfolio not found'}), 404
        
        # Get portfolio holdings with current values
        holdings = conn.execute('''
            SELECT s.id, s.company_name, s.nse_symbol, s.sector, s.current_price,
                   SUM(CASE WHEN t.transaction_type = 'BUY' THEN t.quantity ELSE -t.quantity END) as quantity,
                   SUM(CASE WHEN t.transaction_type = 'BUY' THEN t.quantity * t.price ELSE -t.quantity * t.price END) as invested_value,
                   SUM(CASE WHEN t.transaction_type = 'BUY' THEN t.quantity ELSE -t.quantity END) * s.current_price as current_value
            FROM securities s
            JOIN transactions t ON s.id = t.security_id
            WHERE t.portfolio_id = ?
            GROUP BY s.id
            HAVING quantity > 0
        ''', (portfolio_id,)).fetchall()
        
        # Calculate advisory signals for each holding
        portfolio_holdings = []
        total_invested = 0
        total_current = 0
        
        for holding in holdings:
            invested_value = holding['invested_value'] or 0
            current_value = holding['current_value'] or 0
            total_invested += invested_value
            total_current += current_value
            
            # Generate advisory signal based on multiple factors
            signal = generate_advisory_signal(holding, invested_value, current_value)
            
            portfolio_holdings.append({
                'security_id': holding['id'],
                'company_name': holding['company_name'],
                'symbol': holding['nse_symbol'],
                'sector': holding['sector'],
                'quantity': holding['quantity'],
                'avg_price': invested_value / holding['quantity'] if holding['quantity'] > 0 else 0,
                'current_price': holding['current_price'],
                'invested_value': invested_value,
                'current_value': current_value,
                'profit_loss': current_value - invested_value,
                'profit_loss_pct': ((current_value - invested_value) / invested_value * 100) if invested_value > 0 else 0,
                'advisory_signal': signal
            })
        
        # Calculate overall portfolio performance
        overall_signal = generate_portfolio_signal(portfolio_holdings, total_invested, total_current)
        
        result = {
            'portfolio': {
                'id': portfolio['id'],
                'name': portfolio['name'],
                'client_name': portfolio['client_name'],
                'created_date': portfolio['created_date'],
                'last_updated': portfolio['last_updated']
            },
            'holdings': portfolio_holdings,
            'summary': {
                'total_invested': total_invested,
                'total_current': total_current,
                'total_profit_loss': total_current - total_invested,
                'total_profit_loss_pct': ((total_current - total_invested) / total_invested * 100) if total_invested > 0 else 0,
                'overall_signal': overall_signal
            }
        }
        
        conn.close()
        return jsonify(result)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def generate_advisory_signal(holding, invested_value, current_value):
    """
    Generate advisory signal (BUY/HOLD/SELL) based on multiple factors.
    Factors considered: Profit/Loss percentage, sector performance, holding period
    """
    profit_loss_pct = ((current_value - invested_value) / invested_value * 100) if invested_value > 0 else 0
    
    # Sector-based signals (simplified for MVP)
    sector_signals = {
        'IT': 'HOLD' if profit_loss_pct > 5 else 'BUY',
        'Banking': 'HOLD' if profit_loss_pct > 8 else 'BUY',
        'Energy': 'SELL' if profit_loss_pct < -10 else 'HOLD',
        'Chemicals': 'BUY',  # Growing sector
        'Auto': 'HOLD' if profit_loss_pct > 0 else 'SELL',
        'Consumer Durables': 'BUY',
        'Financial Services': 'HOLD',
        'Construction': 'SELL' if profit_loss_pct < -15 else 'HOLD',
        'Metals': 'BUY' if profit_loss_pct < -20 else 'HOLD',
        'Media': 'SELL'
    }
    
    # Base signal on profit/loss
    if profit_loss_pct > 25:
        signal = 'SELL'  # Take profits
    elif profit_loss_pct < -15:
        signal = 'BUY'   # Average down or buy opportunity
    else:
        signal = 'HOLD'  # Hold position
    
    # Override with sector-specific signal
    sector_signal = sector_signals.get(holding['sector'], 'HOLD')
    if sector_signal == 'BUY' and signal == 'SELL':
        signal = 'HOLD'  # Don't sell if sector is strong
    elif sector_signal == 'SELL' and signal == 'BUY':
        signal = 'HOLD'  # Don't buy if sector is weak
    
    return signal

def generate_portfolio_signal(holdings, total_invested, total_current):
    """Generate overall portfolio advisory signal."""
    if not holdings:
        return 'HOLD'
    
    profit_loss_pct = ((total_current - total_invested) / total_invested * 100) if total_invested > 0 else 0
    
    # Count signals from individual holdings
    signal_counts = {'BUY': 0, 'HOLD': 0, 'SELL': 0}
    for holding in holdings:
        signal_counts[holding['advisory_signal']] += 1
    
    # Determine overall signal
    if signal_counts['SELL'] > len(holdings) * 0.4:  # If >40% holdings suggest SELL
        return 'SELL'
    elif signal_counts['BUY'] > len(holdings) * 0.4:  # If >40% holdings suggest BUY
        return 'BUY'
    elif profit_loss_pct > 20:
        return 'SELL'  # Take profits on overall portfolio
    elif profit_loss_pct < -10:
        return 'BUY'   # Opportunity to add to portfolio
    else:
        return 'HOLD'

@app.route('/api/securities', methods=['GET'])
def get_securities():
    """Get all available securities."""
    try:
        conn = get_db_connection()
        
        securities = conn.execute('''
            SELECT id, isin_code, bse_code, nse_symbol, company_name, sector, current_price
            FROM securities
            ORDER BY company_name
        ''').fetchall()
        
        result = []
        for security in securities:
            result.append({
                'id': security['id'],
                'isin_code': security['isin_code'],
                'bse_code': security['bse_code'],
                'nse_symbol': security['nse_symbol'],
                'company_name': security['company_name'],
                'sector': security['sector'],
                'current_price': security['current_price']
            })
        
        conn.close()
        return jsonify(result)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/transactions/<int:portfolio_id>', methods=['GET'])
def get_portfolio_transactions(portfolio_id):
    """Get all transactions for a specific portfolio."""
    try:
        conn = get_db_connection()
        
        transactions = conn.execute('''
            SELECT t.*, s.nse_symbol, s.company_name
            FROM transactions t
            JOIN securities s ON t.security_id = s.id
            WHERE t.portfolio_id = ?
            ORDER BY t.transaction_date DESC
        ''', (portfolio_id,)).fetchall()
        
        result = []
        for transaction in transactions:
            result.append({
                'id': transaction['id'],
                'security_id': transaction['security_id'],
                'symbol': transaction['nse_symbol'],
                'company_name': transaction['company_name'],
                'transaction_type': transaction['transaction_type'],
                'quantity': transaction['quantity'],
                'price': transaction['price'],
                'transaction_date': transaction['transaction_date'],
                'total_value': transaction['quantity'] * transaction['price']
            })
        
        conn.close()
        return jsonify(result)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/dashboard/stats', methods=['GET'])
def get_dashboard_stats():
    """Get dashboard statistics and overview."""
    try:
        conn = get_db_connection()
        
        # Total portfolios count
        total_portfolios = conn.execute('SELECT COUNT(*) as count FROM portfolios').fetchone()['count']
        
        # Total securities count
        total_securities = conn.execute('SELECT COUNT(*) as count FROM securities').fetchone()['count']
        
        # Total transactions count
        total_transactions = conn.execute('SELECT COUNT(*) as count FROM transactions').fetchone()['count']
        
        # Total portfolio value
        total_value_result = conn.execute('''
            SELECT SUM(t.quantity * s.current_price) as total_value
            FROM transactions t
            JOIN securities s ON t.security_id = s.id
        ''').fetchone()
        total_value = total_value_result['total_value'] or 0
        
        # Sector distribution
        sector_distribution = conn.execute('''
            SELECT s.sector, SUM(t.quantity * s.current_price) as sector_value
            FROM transactions t
            JOIN securities s ON t.security_id = s.id
            GROUP BY s.sector
            ORDER BY sector_value DESC
        ''').fetchall()
        
        sectors = []
        for sector in sector_distribution:
            sectors.append({
                'sector': sector['sector'],
                'value': sector['sector_value