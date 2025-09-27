"""
IPM-55: Core Backend Services Implementation
This module implements user authentication/authorization, portfolio CRUD operations, and RESTful API endpoints.
"""

from flask import Flask, request, jsonify, abort
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from datetime import datetime, timedelta
import os
from typing import Dict, List, Optional

# Initialize Flask application
app = Flask(__name__)

# Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///ipm.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'super-secret-key-change-in-production')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)

# Initialize extensions
db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)

# Database Models
class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)
    
    portfolios = db.relationship('Portfolio', backref='owner', lazy=True)
    
    def set_password(self, password):
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')
    
    def check_password(self, password):
        return bcrypt.check_password_hash(self.password_hash, password)

class Portfolio(db.Model):
    __tablename__ = 'portfolios'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    holdings = db.relationship('Holding', backref='portfolio', lazy=True, cascade='all, delete-orphan')

class Holding(db.Model):
    __tablename__ = 'holdings'
    
    id = db.Column(db.Integer, primary_key=True)
    portfolio_id = db.Column(db.Integer, db.ForeignKey('portfolios.id'), nullable=False)
    symbol = db.Column(db.String(20), nullable=False)  # NSE symbol format
    quantity = db.Column(db.Integer, nullable=False)
    average_price = db.Column(db.Float, nullable=False)
    sector = db.Column(db.String(50))
    added_date = db.Column(db.DateTime, default=datetime.utcnow)

class AdvisorySignal(db.Model):
    __tablename__ = 'advisory_signals'
    
    id = db.Column(db.Integer, primary_key=True)
    symbol = db.Column(db.String(20), nullable=False)
    signal_type = db.Column(db.String(20), nullable=False)  # BUY, SELL, HOLD
    confidence_score = db.Column(db.Float, nullable=False)  # 0.0 to 1.0
    reasoning = db.Column(db.Text, nullable=False)
    generated_at = db.Column(db.DateTime, default=datetime.utcnow)
    valid_until = db.Column(db.DateTime)
    portfolio_id = db.Column(db.Integer, db.ForeignKey('portfolios.id'))

# Authentication Routes
@app.route('/api/auth/register', methods=['POST'])
def register():
    data = request.get_json()
    
    if not data or not data.get('username') or not data.get('email') or not data.get('password'):
        abort(400, description='Missing required fields')
    
    if User.query.filter_by(username=data['username']).first():
        abort(400, description='Username already exists')
    
    if User.query.filter_by(email=data['email']).first():
        abort(400, description='Email already exists')
    
    user = User(username=data['username'], email=data['email'])
    user.set_password(data['password'])
    
    db.session.add(user)
    db.session.commit()
    
    access_token = create_access_token(identity=user.id)
    return jsonify({
        'message': 'User created successfully',
        'access_token': access_token,
        'user_id': user.id
    }), 201

@app.route('/api/auth/login', methods=['POST'])
def login():
    data = request.get_json()
    
    if not data or not data.get('username') or not data.get('password'):
        abort(400, description='Missing username or password')
    
    user = User.query.filter_by(username=data['username']).first()
    
    if user and user.check_password(data['password']) and user.is_active:
        access_token = create_access_token(identity=user.id)
        return jsonify({
            'access_token': access_token,
            'user_id': user.id,
            'username': user.username
        })
    
    abort(401, description='Invalid credentials')

# Portfolio Routes
@app.route('/api/portfolios', methods=['POST'])
@jwt_required()
def create_portfolio():
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    if not data or not data.get('name'):
        abort(400, description='Portfolio name is required')
    
    portfolio = Portfolio(
        name=data['name'],
        description=data.get('description', ''),
        user_id=current_user_id
    )
    
    db.session.add(portfolio)
    db.session.commit()
    
    return jsonify({
        'message': 'Portfolio created successfully',
        'portfolio_id': portfolio.id
    }), 201

@app.route('/api/portfolios', methods=['GET'])
@jwt_required()
def get_portfolios():
    current_user_id = get_jwt_identity()
    portfolios = Portfolio.query.filter_by(user_id=current_user_id).all()
    
    return jsonify([{
        'id': p.id,
        'name': p.name,
        'description': p.description,
        'created_at': p.created_at.isoformat(),
        'updated_at': p.updated_at.isoformat(),
        'holdings_count': len(p.holdings)
    } for p in portfolios])

@app.route('/api/portfolios/<int:portfolio_id>', methods=['GET'])
@jwt_required()
def get_portfolio(portfolio_id):
    current_user_id = get_jwt_identity()
    portfolio = Portfolio.query.filter_by(id=portfolio_id, user_id=current_user_id).first()
    
    if not portfolio:
        abort(404, description='Portfolio not found')
    
    return jsonify({
        'id': portfolio.id,
        'name': portfolio.name,
        'description': portfolio.description,
        'holdings': [{
            'id': h.id,
            'symbol': h.symbol,
            'quantity': h.quantity,
            'average_price': h.average_price,
            'sector': h.sector,
            'added_date': h.added_date.isoformat()
        } for h in portfolio.holdings]
    })

@app.route('/api/portfolios/<int:portfolio_id>', methods=['PUT'])
@jwt_required()
def update_portfolio(portfolio_id):
    current_user_id = get_jwt_identity()
    portfolio = Portfolio.query.filter_by(id=portfolio_id, user_id=current_user_id).first()
    
    if not portfolio:
        abort(404, description='Portfolio not found')
    
    data = request.get_json()
    if data.get('name'):
        portfolio.name = data['name']
    if data.get('description'):
        portfolio.description = data['description']
    
    db.session.commit()
    
    return jsonify({'message': 'Portfolio updated successfully'})

@app.route('/api/portfolios/<int:portfolio_id>', methods=['DELETE'])
@jwt_required()
def delete_portfolio(portfolio_id):
    current_user_id = get_jwt_identity()
    portfolio = Portfolio.query.filter_by(id=portfolio_id, user_id=current_user_id).first()
    
    if not portfolio:
        abort(404, description='Portfolio not found')
    
    db.session.delete(portfolio)
    db.session.commit()
    
    return jsonify({'message': 'Portfolio deleted successfully'})

# Holdings Routes
@app.route('/api/portfolios/<int:portfolio_id>/holdings', methods=['POST'])
@jwt_required()
def add_holding(portfolio_id):
    current_user_id = get_jwt_identity()
    portfolio = Portfolio.query.filter_by(id=portfolio_id, user_id=current_user_id).first()
    
    if not portfolio:
        abort(404, description='Portfolio not found')
    
    data = request.get_json()
    required_fields = ['symbol', 'quantity', 'average_price']
    if not all(field in data for field in required_fields):
        abort(400, description='Missing required fields: symbol, quantity, average_price')
    
    holding = Holding(
        portfolio_id=portfolio_id,
        symbol=data['symbol'],
        quantity=data['quantity'],
        average_price=data['average_price'],
        sector=data.get('sector')
    )
    
    db.session.add(holding)
    db.session.commit()
    
    return jsonify({
        'message': 'Holding added successfully',
        'holding_id': holding.id
    }), 201

@app.route('/api/holdings/<int:holding_id>', methods=['PUT'])
@jwt_required()
def update_holding(holding_id):
    current_user_id = get_jwt_identity()
    holding = Holding.query.join(Portfolio).filter(
        Holding.id == holding_id,
        Portfolio.user_id == current_user_id
    ).first()
    
    if not holding:
        abort(404, description='Holding not found')
    
    data = request.get_json()
    if data.get('quantity'):
        holding.quantity = data['quantity']
    if data.get('average_price'):
        holding.average_price = data['average_price']
    if data.get('sector'):
        holding.sector = data['sector']
    
    db.session.commit()
    
    return jsonify({'message': 'Holding updated successfully'})

@app.route('/api/holdings/<int:holding_id>', methods=['DELETE'])
@jwt_required()
def delete_holding(holding_id):
    current_user_id = get_jwt_identity()
    holding = Holding.query.join(Portfolio).filter(
        Holding.id == holding_id,
        Portfolio.user_id == current_user_id
    ).first()
    
    if not holding:
        abort(404, description='Holding not found')
    
    db.session.delete(holding)
    db.session.commit()
    
    return jsonify({'message': 'Holding delete
# Code truncated at 10000 characters