import sqlite3
from flask import Flask, jsonify, request, render_template
import json
from datetime import datetime

app = Flask(__name__)

# Database initialization function
def init_db():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Create tables
    c.execute('''CREATE TABLE IF NOT EXISTS clients
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  name TEXT NOT NULL,
                  email TEXT UNIQUE NOT NULL,
                  risk_profile TEXT CHECK(risk_profile IN ('Low', 'Medium', 'High')) NOT NULL)''')
    
    c.execute('''CREATE TABLE IF NOT EXISTS portfolios
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  client_id INTEGER NOT NULL,
                  name TEXT NOT NULL,
                  created_date DATE NOT NULL,
                  FOREIGN KEY (client_id) REFERENCES clients (id))''')
    
    c.execute('''CREATE TABLE IF NOT EXISTS indian_equities
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  symbol TEXT UNIQUE NOT NULL,
                  name TEXT NOT NULL,
                  sector TEXT NOT NULL,
                  current_price REAL NOT NULL,
                  pe_ratio REAL,
                  market_cap REAL)''')
    
    c.execute('''CREATE TABLE IF NOT EXISTS portfolio_holdings
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  portfolio_id INTEGER NOT NULL,
                  equity_id INTEGER NOT NULL,
                  quantity INTEGER NOT NULL,
                  purchase_price REAL NOT NULL,
                  purchase_date DATE NOT NULL,
                  FOREIGN KEY (portfolio_id) REFERENCES portfolios (id),
                  FOREIGN KEY (equity_id) REFERENCES indian_equities (id))''')
    
    # Insert dummy data if tables are empty
    if c.execute("SELECT COUNT(*) FROM clients").fetchone()[0] == 0:
        c.execute("INSERT INTO clients (name, email, risk_profile) VALUES 
                  ('Rahul Sharma', 'rahul.sharma@email.com', 'Medium'),
                  ('Priya Patel', 'priya.patel@email.com', 'High'),
                  ('Amit Kumar', 'amit.kumar@email.com', 'Low')")
    
    if c.execute("SELECT COUNT(*) FROM indian_equities").fetchone()[0] == 0:
        c.execute("INSERT INTO indian_equities (symbol, name, sector, current_price, pe_ratio, market_cap) VALUES 
                  ('RELIANCE', 'Reliance Industries Ltd.', 'Energy', 2850.75, 27.3, 1500000),
                  ('TCS', 'Tata Consultancy Services Ltd.', 'IT', 3450.20, 32.1, 1200000),
                  ('HDFCBANK', 'HDFC Bank Ltd.', 'Banking', 1650.50, 22.5, 900000),
                  ('INFY', 'Infosys Ltd.', 'IT', 1850.30, 25.7, 800000),
                  ('ITC', 'ITC Ltd.', 'FMCG', 420.15, 18.9, 350000),
                  ('SBIN', 'State Bank of India', 'Banking', 650.80, 15.2, 450000),
                  ('BAJFIN', 'Bajaj Finance Ltd.', 'Financial Services', 7200.45, 35.8, 400000),
                  ('BHARTI', 'Bharti Airtel Ltd.', 'Telecom', 890.60, 20.3, 500000),
                  ('LT', 'Larsen & Toubro Ltd.', 'Construction', 2150.25, 24.6, 300000),
                  ('HINDUNIL', 'Hindustan Unilever Ltd.', 'FMCG', 2450.90, 45.2, 550000)")
    
    conn.commit()
    conn.close()

# Advisory signal generation algorithm
def generate_advisory_signal(equity_data, client_risk_profile):
    """
    Generate Buy/Hold/Sell recommendations based on multiple factors
    considering Indian equity market context and client risk profile
    """
    price = equity_data['current_price']
    pe_ratio = equity_data['pe_ratio']
    sector = equity_data['sector']
    
    # Simple algorithm based on P/E ratio and sector trends
    if pe_ratio < 15:
        base_signal = 'Buy'
    elif pe_ratio < 25:
        base_signal = 'Hold'
    else:
        base_signal = 'Sell'
    
    # Adjust based on risk profile
    if client_risk_profile == 'Low':
        if base_signal == 'Buy' and pe_ratio > 12:
            return 'Hold'
        elif base_signal == 'Sell':
            return 'Hold'
    elif client_risk_profile == 'High':
        if base_signal == 'Buy':
            return 'Buy'
        elif base_signal == 'Hold':
            return 'Buy'
    
    return base_signal

# Portfolio analysis and dashboard data generation
def generate_portfolio_analysis(portfolio_id):
    """
    Generate comprehensive portfolio analysis for advisor dashboard
    """
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Get portfolio holdings with current prices
    c.execute('''SELECT ph.quantity, ph.purchase_price, ie.symbol, ie.name, 
                        ie.current_price, ie.sector, ie.pe_ratio
                 FROM portfolio_holdings ph
                 JOIN indian_equities ie ON ph.equity_id = ie.id
                 WHERE ph.portfolio_id = ?''', (portfolio_id,))
    
    holdings = c.fetchall()
    total_investment = 0
    current_value = 0
    sector_allocation = {}
    performance_data = []
    
    for holding in holdings:
        quantity, purchase_price, symbol, name, current_price, sector, pe_ratio = holding
        investment = quantity * purchase_price
        current_val = quantity * current_price
        gain_loss = current_val - investment
        
        total_investment += investment
        current_value += current_val
        
        # Sector allocation
        if sector not in sector_allocation:
            sector_allocation[sector] = 0
        sector_allocation[sector] += current_val
        
        # Performance data
        performance_data.append({
            'symbol': symbol,
            'name': name,
            'investment': investment,
            'current_value': current_val,
            'gain_loss': gain_loss,
            'gain_loss_percent': (gain_loss / investment) * 100 if investment > 0 else 0
        })
    
    conn.close()
    
    # Generate advisory signals for each holding
    c.execute('SELECT risk_profile FROM clients c JOIN portfolios p ON c.id = p.client_id WHERE p.id = ?', (portfolio_id,))
    risk_profile = c.fetchone()[0]
    
    for item in performance_data:
        equity_data = next((h for h in holdings if h[2] == item['symbol']), None)
        if equity_data:
            item['recommendation'] = generate_advisory_signal({
                'current_price': equity_data[4],
                'pe_ratio': equity_data[6],
                'sector': equity_data[5]
            }, risk_profile)
    
    return {
        'total_investment': total_investment,
        'current_value': current_value,
        'overall_gain_loss': current_value - total_investment,
        'overall_gain_loss_percent': ((current_value - total_investment) / total_investment * 100) if total_investment > 0 else 0,
        'sector_allocation': sector_allocation,
        'holdings_performance': performance_data
    }

# Flask API Routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/portfolios', methods=['GET'])
def get_portfolios():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    c.execute('''SELECT p.id, p.name, c.name as client_name, p.created_date 
                 FROM portfolios p JOIN clients c ON p.client_id = c.id''')
    portfolios = c.fetchall()
    conn.close()
    
    return jsonify([{
        'id': p[0],
        'name': p[1],
        'client_name': p[2],
        'created_date': p[3]
    } for p in portfolios])

@app.route('/api/portfolio/<int:portfolio_id>', methods=['GET'])
def get_portfolio(portfolio_id):
    analysis = generate_portfolio_analysis(portfolio_id)
    return jsonify(analysis)

@app.route('/api/portfolio', methods=['POST'])
def create_portfolio():
    data = request.json
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    c.execute('INSERT INTO portfolios (client_id, name, created_date) VALUES (?, ?, ?)',
              (data['client_id'], data['name'], datetime.now().date()))
    portfolio_id = c.lastrowid
    
    # Add holdings
    for holding in data['holdings']:
        c.execute('''INSERT INTO portfolio_holdings 
                    (portfolio_id, equity_id, quantity, purchase_price, purchase_date)
                    VALUES (?, ?, ?, ?, ?)''',
                 (portfolio_id, holding['equity_id'], holding['quantity'], 
                  holding['purchase_price'], datetime.now().date()))
    
    conn.commit()
    conn.close()
    return jsonify({'message': 'Portfolio created successfully', 'portfolio_id': portfolio_id})

@app.route('/api/equities', methods=['GET'])
def get_equities():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    c.execute('SELECT * FROM indian_equities')
    equities = c.fetchall()
    conn.close()
    
    return jsonify([{
        'id': e[0],
        'symbol': e[1],
        'name': e[2],
        'sector': e[3],
        'current_price': e[4],
        'pe_ratio': e[5],
        'market_cap': e[6]
    } for e in equities])

@app.route('/api/advisory/<symbol>/<risk_profile>', methods=['GET'])
def get_advisory(symbol, risk_profile):
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    c.execute('SELECT * FROM indian_equities WHERE symbol = ?', (symbol,))
    equity = c.fetchone()
    conn.close()
    
    if equity:
        signal = generate_advisory_signal({
            'current_price': equity[4],
            'pe_ratio': equity[5],
            'sector': equity[3]
        }, risk_profile)
        
        return jsonify({
            'symbol': symbol,
            'recommendation': signal,
            'reasoning': f"Based on P/E ratio of {equity[5]} and {risk_profile} risk profile"
        })
    
    return jsonify({'error': 'Equity not found'}), 404

@app.route('/api/dashboard')
def get_dashboard():
    # Generate sample dashboard data
    return jsonify({
        'total_portfolios': 15,
        'total_clients': 8,
        'total_aum': 12500000,
        'top_performers': [
            {'symbol': 'RELIANCE', 'return': 18.5},
            {'symbol': 'TCS', 'return': 15.2},
            {'symbol': 'HDFCBANK', 'return': 12.8}
        ],
        'recent_activity': [
            {'client': 'Rahul Sharma', 'action': 'Portfolio Created', 'time': '2 hours ago'},
            {'client': 'Priya Patel', 'action': 'Advisory Signal Generated', 'time': '4 hours ago'}
        ]
    })

if __name__ == '__main__':
    init_db()
    app.run(debug=True)