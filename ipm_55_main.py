from flask import Flask, render_template, request, jsonify, redirect, url_for, session
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import json
from datetime import datetime
import random

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key-here'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///portfolio.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# Database Models
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)
    is_advisor = db.Column(db.Boolean, default=False)

class Portfolio(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    stock_symbol = db.Column(db.String(20), nullable=False)
    stock_name = db.Column(db.String(100), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    purchase_price = db.Column(db.Float, nullable=False)
    purchase_date = db.Column(db.DateTime, nullable=False)
    sector = db.Column(db.String(50), nullable=False)

class StockData(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    symbol = db.Column(db.String(20), unique=True, nullable=False)
    current_price = db.Column(db.Float, nullable=False)
    pe_ratio = db.Column(db.Float, nullable=False)
    market_cap = db.Column(db.Float, nullable=False)
    volatility = db.Column(db.Float, nullable=False)
    last_updated = db.Column(db.DateTime, nullable=False)

# Authentication Decorator
def advisor_required(f):
    from functools import wraps
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session or not User.query.get(session['user_id']).is_advisor:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# Advisory Signal Algorithm
def generate_advisory_signal(stock_data, portfolio_data):
    """
    Generate advisory signal (Buy/Hold/Sell) based on multiple factors
    Factors considered: P/E ratio, market cap, volatility, and portfolio concentration
    """
    pe_score = 1 if stock_data.pe_ratio < 20 else (0.5 if stock_data.pe_ratio < 30 else 0)
    market_cap_score = 1 if stock_data.market_cap > 10000 else (0.5 if stock_data.market_cap > 5000 else 0)
    volatility_score = 1 if stock_data.volatility < 0.2 else (0.5 if stock_data.volatility < 0.4 else 0)
    
    # Calculate portfolio concentration risk
    total_value = sum([p.quantity * stock_data.current_price for p in portfolio_data if p.stock_symbol == stock_data.symbol])
    portfolio_value = sum([p.quantity * StockData.query.filter_by(symbol=p.stock_symbol).first().current_price 
                         for p in portfolio_data])
    concentration_score = 0.5 if total_value/portfolio_value > 0.1 else 1
    
    total_score = (pe_score * 0.3 + market_cap_score * 0.3 + 
                  volatility_score * 0.2 + concentration_score * 0.2)
    
    if total_score >= 0.7:
        return "Buy", total_score
    elif total_score >= 0.4:
        return "Hold", total_score
    else:
        return "Sell", total_score

# Routes
@app.route('/')
def home():
    if 'user_id' in session:
        user = User.query.get(session['user_id'])
        if user.is_advisor:
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
        
        if user and check_password_hash(user.password_hash, password):
            session['user_id'] = user.id
            if user.is_advisor:
                return redirect(url_for('advisor_dashboard'))
            else:
                return redirect(url_for('client_portfolio'))
        return render_template('login.html', error='Invalid credentials')
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('user_id', None)
    return redirect(url_for('login'))

@app.route('/advisor/dashboard')
@advisor_required
def advisor_dashboard():
    portfolios = Portfolio.query.all()
    clients = User.query.filter_by(is_advisor=False).all()
    
    portfolio_data = []
    for portfolio in portfolios:
        stock_data = StockData.query.filter_by(symbol=portfolio.stock_symbol).first()
        signal, score = generate_advisory_signal(stock_data, [portfolio])
        portfolio_data.append({
            'portfolio': portfolio,
            'current_price': stock_data.current_price,
            'signal': signal,
            'score': score
        })
    
    return render_template('advisor_dashboard.html', 
                         portfolio_data=portfolio_data,
                         clients=clients)

@app.route('/api/portfolio/<int:client_id>')
@advisor_required
def api_portfolio(client_id):
    portfolios = Portfolio.query.filter_by(user_id=client_id).all()
    portfolio_data = []
    
    for portfolio in portfolios:
        stock_data = StockData.query.filter_by(symbol=portfolio.stock_symbol).first()
        signal, score = generate_advisory_signal(stock_data, portfolios)
        
        portfolio_data.append({
            'id': portfolio.id,
            'stock_symbol': portfolio.stock_symbol,
            'stock_name': portfolio.stock_name,
            'quantity': portfolio.quantity,
            'purchase_price': portfolio.purchase_price,
            'current_price': stock_data.current_price,
            'sector': portfolio.sector,
            'signal': signal,
            'confidence': score
        })
    
    return jsonify(portfolio_data)

@app.route('/api/portfolio/add', methods=['POST'])
@advisor_required
def api_portfolio_add():
    try:
        data = request.get_json()
        new_portfolio = Portfolio(
            user_id=data['client_id'],
            stock_symbol=data['symbol'],
            stock_name=data['name'],
            quantity=data['quantity'],
            purchase_price=data['price'],
            purchase_date=datetime.now(),
            sector=data['sector']
        )
        db.session.add(new_portfolio)
        db.session.commit()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/portfolio/delete/<int:portfolio_id>', methods=['DELETE'])
@advisor_required
def api_portfolio_delete(portfolio_id):
    try:
        portfolio = Portfolio.query.get(portfolio_id)
        if portfolio:
            db.session.delete(portfolio)
            db.session.commit()
            return jsonify({'success': True})
        return jsonify({'success': False, 'error': 'Portfolio not found'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/client/portfolio')
def client_portfolio():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    user = User.query.get(session['user_id'])
    if user.is_advisor:
        return redirect(url_for('advisor_dashboard'))
    
    portfolios = Portfolio.query.filter_by(user_id=user.id).all()
    portfolio_value = 0
    for portfolio in portfolios:
        stock_data = StockData.query.filter_by(symbol=portfolio.stock_symbol).first()
        portfolio_value += portfolio.quantity * stock_data.current_price
    
    return render_template('client_portfolio.html', 
                         portfolios=portfolios,
                         portfolio_value=portfolio_value)

# Initialize dummy data
def init_dummy_data():
    # Create advisor user
    advisor = User(username='advisor', 
                  password_hash=generate_password_hash('password'),
                  is_advisor=True)
    db.session.add(advisor)
    
    # Create client users
    for i in range(3):
        client = User(username=f'client{i+1}', 
                     password_hash=generate_password_hash('password'),
                     is_advisor=False)
        db.session.add(client)
    
    # Create stock data
    stocks = [
        {'symbol': 'RELIANCE', 'name': 'Reliance Industries', 'price': 2500, 'pe': 22.5, 'cap': 150000, 'vol': 0.15},
        {'symbol': 'TCS', 'name': 'Tata Consultancy Services', 'price': 3200, 'pe': 28.3, 'cap': 120000, 'vol': 0.12},
        {'symbol': 'HDFCBANK', 'name': 'HDFC Bank', 'price': 1400, 'pe': 18.7, 'cap': 80000, 'vol': 0.18},
        {'symbol': 'INFY', 'name': 'Infosys', 'price': 1500, 'pe': 25.1, 'cap': 70000, 'vol': 0.14},
        {'symbol': 'ICICIBANK', 'name': 'ICICI Bank', 'price': 900, 'pe': 16.8, 'cap': 60000, 'vol': 0.22}
    ]
    
    for stock in stocks:
        stock_data = StockData(
            symbol=stock['symbol'],
            current_price=stock['price'],
            pe_ratio=stock['pe'],
            market_cap=stock['cap'],
            volatility=stock['vol'],
            last_updated=datetime.now()
        )
        db.session.add(stock_data)
    
    # Create sample portfolios
    clients = User.query.filter_by(is_advisor=False).all()
    sectors = ['Technology', 'Banking', 'Energy', 'Healthcare', 'Automobile']
    
    for client in clients:
        for i in range(random.randint(2, 5)):
            stock = random.choice(stocks)
            portfolio = Portfolio(
                user_id=client.id,
                stock_symbol=stock['symbol'],
                stock_name=stock['name'],
                quantity=random.randint(10, 100),
                purchase_price=stock['price'] * random.uniform(0.8, 1.2),
                purchase_date=datetime.now(),
                sector=random.choice(sectors)
            )
            db.session.add(portfolio)
    
    db.session.commit()

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        if not User.query.first():
            init_dummy_data()
    app.run(debug=True)