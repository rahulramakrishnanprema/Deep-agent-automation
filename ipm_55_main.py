"""
Main application file for IPM-55 MVP: Indian Equity Portfolio Management System
This file sets up the Flask application, configures routes, and integrates all components.
"""

from flask import Flask, render_template, jsonify, request, session, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import json
from datetime import datetime
import functools

# Initialize Flask application
app = Flask(__name__)
app.config['SECRET_KEY'] = 'ipm-55-secret-key-for-mvp'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///ipm_portfolio.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize database
db = SQLAlchemy(app)

# Database Models
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='client')  # 'advisor' or 'client'
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Portfolio(db.Model):
    __tablename__ = 'portfolios'
    id = db.Column(db.Integer, primary_key=True)
    client_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Equity(db.Model):
    __tablename__ = 'equities'
    id = db.Column(db.Integer, primary_key=True)
    symbol = db.Column(db.String(20), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    sector = db.Column(db.String(50))
    current_price = db.Column(db.Float, nullable=False)
    last_updated = db.Column(db.DateTime, default=datetime.utcnow)

class PortfolioHolding(db.Model):
    __tablename__ = 'portfolio_holdings'
    id = db.Column(db.Integer, primary_key=True)
    portfolio_id = db.Column(db.Integer, db.ForeignKey('portfolios.id'), nullable=False)
    equity_id = db.Column(db.Integer, db.ForeignKey('equities.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    purchase_price = db.Column(db.Float, nullable=False)
    purchase_date = db.Column(db.DateTime, default=datetime.utcnow)

class AdvisorySignal(db.Model):
    __tablename__ = 'advisory_signals'
    id = db.Column(db.Integer, primary_key=True)
    equity_id = db.Column(db.Integer, db.ForeignKey('equities.id'), nullable=False)
    signal = db.Column(db.String(10), nullable=False)  # 'BUY', 'HOLD', 'SELL'
    confidence = db.Column(db.Float)  # 0.0 to 1.0
    reasoning = db.Column(db.Text)
    generated_at = db.Column(db.DateTime, default=datetime.utcnow)

# Authentication decorator for advisor-only access
def advisor_required(f):
    @functools.wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session or session.get('user_role') != 'advisor':
            return jsonify({'error': 'Advisor access required'}), 403
        return f(*args, **kwargs)
    return decorated_function

# Advisory signal generation algorithm
def generate_advisory_signals():
    """
    Generate advisory signals based on Indian market factors
    Simple MVP implementation using price momentum and sector trends
    """
    equities = Equity.query.all()
    
    for equity in equities:
        # Simple algorithm for MVP - in production, this would use more complex factors
        price_change = (equity.current_price - 100) / 100  # Dummy baseline price of 100
        
        if price_change > 0.1:  # Price increased more than 10%
            signal = 'HOLD'
            confidence = 0.7
            reasoning = f"Strong positive momentum for {equity.name}"
        elif price_change < -0.1:  # Price decreased more than 10%
            signal = 'SELL'
            confidence = 0.6
            reasoning = f"Negative momentum for {equity.name}"
        else:
            signal = 'BUY'
            confidence = 0.5
            reasoning = f"Stable performance for {equity.name}"
        
        # Update or create advisory signal
        existing_signal = AdvisorySignal.query.filter_by(equity_id=equity.id).first()
        if existing_signal:
            existing_signal.signal = signal
            existing_signal.confidence = confidence
            existing_signal.reasoning = reasoning
            existing_signal.generated_at = datetime.utcnow()
        else:
            new_signal = AdvisorySignal(
                equity_id=equity.id,
                signal=signal,
                confidence=confidence,
                reasoning=reasoning
            )
            db.session.add(new_signal)
    
    db.session.commit()

# Routes
@app.route('/')
def index():
    if 'user_id' in session:
        if session.get('user_role') == 'advisor':
            return redirect(url_for('advisor_dashboard'))
        else:
            return redirect(url_for('client_dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        user = User.query.filter_by(username=username).first()
        if user and check_password_hash(user.password_hash, password):
            session['user_id'] = user.id
            session['username'] = user.username
            session['user_role'] = user.role
            return redirect(url_for('index'))
        
        return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/client/dashboard')
def client_dashboard():
    if 'user_id' not in session or session.get('user_role') != 'client':
        return redirect(url_for('login'))
    
    user_id = session['user_id']
    portfolios = Portfolio.query.filter_by(client_id=user_id).all()
    return render_template('client_dashboard.html', portfolios=portfolios)

@app.route('/advisor/dashboard')
@advisor_required
def advisor_dashboard():
    portfolios = Portfolio.query.all()
    signals = AdvisorySignal.query.join(Equity).all()
    return render_template('advisor_dashboard.html', portfolios=portfolios, signals=signals)

# API Routes
@app.route('/api/portfolios', methods=['GET'])
def get_portfolios():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    user_id = session['user_id']
    user_role = session.get('user_role')
    
    if user_role == 'advisor':
        portfolios = Portfolio.query.all()
    else:
        portfolios = Portfolio.query.filter_by(client_id=user_id).all()
    
    result = []
    for portfolio in portfolios:
        result.append({
            'id': portfolio.id,
            'name': portfolio.name,
            'description': portfolio.description,
            'client_id': portfolio.client_id
        })
    
    return jsonify(result)

@app.route('/api/portfolios', methods=['POST'])
def create_portfolio():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    portfolio = Portfolio(
        client_id=session['user_id'],
        name=data.get('name'),
        description=data.get('description')
    )
    db.session.add(portfolio)
    db.session.commit()
    
    return jsonify({'message': 'Portfolio created', 'id': portfolio.id}), 201

@app.route('/api/portfolios/<int:portfolio_id>', methods=['GET'])
def get_portfolio(portfolio_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    portfolio = Portfolio.query.get_or_404(portfolio_id)
    
    # Check authorization
    user_role = session.get('user_role')
    if user_role != 'advisor' and portfolio.client_id != session['user_id']:
        return jsonify({'error': 'Access denied'}), 403
    
    holdings = PortfolioHolding.query.filter_by(portfolio_id=portfolio_id).join(Equity).all()
    holdings_data = []
    total_value = 0
    
    for holding in holdings:
        current_value = holding.quantity * holding.equity.current_price
        total_value += current_value
        holdings_data.append({
            'id': holding.id,
            'equity_symbol': holding.equity.symbol,
            'equity_name': holding.equity.name,
            'quantity': holding.quantity,
            'purchase_price': holding.purchase_price,
            'current_price': holding.equity.current_price,
            'current_value': current_value,
            'gain_loss': current_value - (holding.quantity * holding.purchase_price)
        })
    
    return jsonify({
        'portfolio': {
            'id': portfolio.id,
            'name': portfolio.name,
            'description': portfolio.description,
            'client_id': portfolio.client_id
        },
        'holdings': holdings_data,
        'total_value': total_value
    })

@app.route('/api/portfolios/<int:portfolio_id>/holdings', methods=['POST'])
def add_holding(portfolio_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    portfolio = Portfolio.query.get_or_404(portfolio_id)
    
    # Check authorization
    if session.get('user_role') != 'advisor' and portfolio.client_id != session['user_id']:
        return jsonify({'error': 'Access denied'}), 403
    
    data = request.get_json()
    equity = Equity.query.filter_by(symbol=data.get('symbol')).first()
    if not equity:
        return jsonify({'error': 'Equity not found'}), 404
    
    holding = PortfolioHolding(
        portfolio_id=portfolio_id,
        equity_id=equity.id,
        quantity=data.get('quantity'),
        purchase_price=data.get('purchase_price')
    )
    db.session.add(holding)
    db.session.commit()
    
    return jsonify({'message': 'Holding added', 'id': holding.id}), 201

@app.route('/api/advisory/signals', methods=['GET'])
@advisor_required
def get_advisory_signals():
    signals = AdvisorySignal.query.join(Equity).all()
    result = []
    
    for signal in signals:
        result.append({
            'id': signal.id,
            'equity_symbol': signal.equity.symbol,
            'equity_name': signal.equity.name,
            'signal': signal.signal,
            'confidence': signal.confidence,
            'reasoning': signal.reasoning,
            'generated_at': signal.generated_at.isoformat()
        })
    
    return jsonify(result)

@app.route('/api/advisory/generate', methods=['POST'])
@advisor_required
def generate_signals():
    generate_advisory_signals()
    return jsonify({'message': 'Advisory signals generated'})

@app.route('/api/reports/portfolio-performance')
@advisor_required
def get_portfolio_performance_report():
    portfolios = Portfolio.query.all()
    report_data = []
    
    for portfolio in portfolios:
        holdings = PortfolioHolding.query.filter_by(portfolio_id=portfolio.id).join(Equity).all()
        total_investment = sum(h.quantity * h.purchase_price for h in holdings)
        total_current = sum(h.quantity * h.equity.current_price for h in holdings)
        
        report_data.append({
            'portfolio_id': portfolio.id,
            'portfolio_name': portfolio.name,
            'total_investment': total_investment,
            'total_current_value': total_current,
            'overall_return': total_current - total_investment,
            'return_percentage': ((total_current - total_investment) / total_investment * 100) if total_investment > 0 else 0
        })
    
    return jsonify(report_data)

# Initialize dummy data
def init_dummy_data():
    """Initialize the database with dummy data for testing"""
    # Create advisor user
    advisor = User(
        username='advisor',
        password_hash=generate_password_hash('advisor123'),
        role='advisor'
    )
    
    # Create client user
    client = User(
        username='client',
        password_hash=generate_password_hash('client123'),
        role='client'
    )
    
    db.session.add(advisor)
    db.session.add(client)
    db.session.commit()
    
    # Create sample Indian equities
    indian_equities = [
        {'symbol': 'RELIANCE', 'name': 'Reliance Industries Ltd', 'sector': 'Energy', 'current_price': 2456.75},
        {'symbol': 'TCS', 'name': 'Tata Consultancy Services Ltd', 'sector': 'IT', 'current_price': 3210.50},
        {'symbol': 'HDFCBANK', 'name': 'HDFC Bank Ltd', 'sector': 'Banking', 'current_price': 1452.30},
        {'symbol': 'INFY', 'name': 'Infosys Ltd', 'sector': 'IT', 'current_price': 1520.45},
        {'symbol': 'ITC', 'name': 'ITC Ltd', 'sector': 'FMCG', 'current_price': 215.80}
    ]
    
    for equity_data in indian_equities:
        equity = Equity(**equity_data)
        db.session.add(equity)
    
    # Create sample portfolio for client
    portfolio = Portfolio(client_id=client.id, name='My Investment Portfolio', description='Primary investment portfolio')
    db.session.add(portfolio)
    db.session.commit()
    
    # Add sample holdings
    equities = Equity.query.all()
    holdings = [
        {'portfolio_id': portfolio.id, 'equity_id': equities[0].id, 'quantity': 10, 'purchase_price': 2300.00},
        {'portfolio_id': portfolio.id, 'equity_id': equities[1].id, 'quantity': 5, 'purchase_price': 3000.00},
        {'portfolio_id': portfolio.id, 'equity_id': equities[2].id, 'quantity': 8, 'purchase_price': 1400.00}
    ]
    
    for holding_data in holdings:
        holding = PortfolioHolding(**holding_data)
        db.session.add(holding)
    
    db.session.commit()
    
    # Generate initial advisory signals
    generate_advisory_signals()

# Main application entry point
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        
        # Check if we need to initialize dummy data
        if User.query.count() == 0:
            init_dummy_data()
            print("Dummy data initialized")
    
    app.run(debug=True, host='0.0.0.0', port=5000)