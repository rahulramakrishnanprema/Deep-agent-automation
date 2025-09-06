import os
import logging
from datetime import datetime, timedelta
from functools import wraps
from typing import Dict, Optional

from flask import Flask, request, jsonify, make_response
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from pydantic import BaseModel, EmailStr, constr, ValidationError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask application
app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'your-secret-key-here-change-in-production')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get(
    'DATABASE_URL', 
    'sqlite:///aep2_auth.db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=1)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = timedelta(days=7)

# Initialize database
db = SQLAlchemy(app)

# Pydantic models for request validation
class UserRegistration(BaseModel):
    """AEP-2 User registration request model"""
    username: constr(min_length=3, max_length=50)
    email: EmailStr
    password: constr(min_length=8)

class UserLogin(BaseModel):
    """AEP-2 User login request model"""
    email: EmailStr
    password: str

# Database models
class User(db.Model):
    """AEP-2 User model for authentication"""
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime, nullable=True)
    is_active = db.Column(db.Boolean, default=True)
    
    def set_password(self, password: str) -> None:
        """Hash and set user password"""
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password: str) -> bool:
        """Check if password matches hash"""
        return check_password_hash(self.password_hash, password)
    
    def generate_token(self, token_type: str = 'access') -> str:
        """Generate JWT token for user"""
        expires_delta = app.config[f'JWT_{token_type.upper()}_TOKEN_EXPIRES']
        payload = {
            'user_id': self.id,
            'email': self.email,
            'username': self.username,
            'exp': datetime.utcnow() + expires_delta,
            'type': token_type
        }
        return jwt.encode(payload, app.config['SECRET_KEY'], algorithm='HS256')
    
    def update_last_login(self) -> None:
        """Update user's last login timestamp"""
        self.last_login = datetime.utcnow()
        db.session.commit()

class BlacklistedToken(db.Model):
    """AEP-2 Blacklisted token model"""
    __tablename__ = 'blacklisted_tokens'
    
    id = db.Column(db.Integer, primary_key=True)
    token = db.Column(db.String(500), unique=True, nullable=False)
    blacklisted_at = db.Column(db.DateTime, default=datetime.utcnow)
    expires_at = db.Column(db.DateTime, nullable=False)

# Utility functions
def token_required(f):
    """AEP-2 JWT token authentication decorator"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        # Get token from Authorization header
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
        
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        
        try:
            # Verify token
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            
            # Check if token is blacklisted
            blacklisted = BlacklistedToken.query.filter_by(token=token).first()
            if blacklisted:
                return jsonify({'error': 'Token has been revoked'}), 401
            
            current_user = User.query.get(data['user_id'])
            if not current_user or not current_user.is_active:
                return jsonify({'error': 'User not found or inactive'}), 401
                
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(current_user, *args, **kwargs)
    
    return decorated

def validate_request_data(model):
    """Validate request data against Pydantic model"""
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            try:
                data = model(**request.get_json())
                return f(data, *args, **kwargs)
            except ValidationError as e:
                return jsonify({'error': 'Invalid input data', 'details': e.errors()}), 400
        return decorated
    return decorator

# API Routes
@app.route('/api/aep2/register', methods=['POST'])
@validate_request_data(UserRegistration)
def register_user(data: UserRegistration):
    """AEP-2 User registration endpoint"""
    try:
        # Check if user already exists
        existing_user = User.query.filter(
            (User.email == data.email) | (User.username == data.username)
        ).first()
        
        if existing_user:
            if existing_user.email == data.email:
                return jsonify({'error': 'Email already registered'}), 409
            else:
                return jsonify({'error': 'Username already taken'}), 409
        
        # Create new user
        new_user = User(
            username=data.username,
            email=data.email
        )
        new_user.set_password(data.password)
        
        db.session.add(new_user)
        db.session.commit()
        
        # Generate tokens
        access_token = new_user.generate_token('access')
        refresh_token = new_user.generate_token('refresh')
        
        logger.info(f"User registered successfully: {data.email}")
        
        return jsonify({
            'message': 'User registered successfully',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': {
                'id': new_user.id,
                'username': new_user.username,
                'email': new_user.email
            }
        }), 201
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Registration error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/aep2/login', methods=['POST'])
@validate_request_data(UserLogin)
def login_user(data: UserLogin):
    """AEP-2 User login endpoint"""
    try:
        # Find user by email
        user = User.query.filter_by(email=data.email, is_active=True).first()
        
        if not user or not user.check_password(data.password):
            logger.warning(f"Failed login attempt for email: {data.email}")
            return jsonify({'error': 'Invalid email or password'}), 401
        
        # Update last login and generate tokens
        user.update_last_login()
        access_token = user.generate_token('access')
        refresh_token = user.generate_token('refresh')
        
        logger.info(f"User logged in successfully: {data.email}")
        
        return jsonify({
            'message': 'Login successful',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email
            }
        }), 200
        
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/aep2/refresh', methods=['POST'])
def refresh_token():
    """AEP-2 Token refresh endpoint"""
    try:
        refresh_token = request.get_json().get('refresh_token')
        
        if not refresh_token:
            return jsonify({'error': 'Refresh token is required'}), 400
        
        try:
            # Verify refresh token
            data = jwt.decode(refresh_token, app.config['SECRET_KEY'], algorithms=['HS256'])
            
            if data.get('type') != 'refresh':
                return jsonify({'error': 'Invalid token type'}), 401
            
            # Check if token is blacklisted
            blacklisted = BlacklistedToken.query.filter_by(token=refresh_token).first()
            if blacklisted:
                return jsonify({'error': 'Token has been revoked'}), 401
            
            user = User.query.get(data['user_id'])
            if not user or not user.is_active:
                return jsonify({'error': 'User not found or inactive'}), 401
            
            # Generate new access token
            new_access_token = user.generate_token('access')
            
            return jsonify({
                'access_token': new_access_token
            }), 200
            
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Refresh token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid refresh token'}), 401
            
    except Exception as e:
        logger.error(f"Token refresh error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/aep2/logout', methods=['POST'])
@token_required
def logout_user(current_user):
    """AEP-2 User logout endpoint"""
    try:
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            
            # Decode token to get expiration time
            try:
                data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
                expires_at = datetime.utcfromtimestamp(data['exp'])
                
                # Add token to blacklist
                blacklisted_token = BlacklistedToken(
                    token=token,
                    expires_at=expires_at
                )
                db.session.add(blacklisted_token)
                db.session.commit()
                
                logger.info(f"User logged out successfully: {current_user.email}")
                return jsonify({'message': 'Logout successful'}), 200
                
            except jwt.InvalidTokenError:
                return jsonify({'error': 'Invalid token'}), 401
        
        return jsonify({'error': 'Token is missing'}), 401
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Logout error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/aep2/profile', methods=['GET'])
@token_required
def get_user_profile(current_user):
    """AEP-2 Get user profile endpoint"""
    return jsonify({
        'user': {
            'id': current_user.id,
            'username': current_user.username,
            'email': current_user.email,
            'created_at': current_user.created_at.isoformat(),
            'last_login': current_user.last_login.isoformat() if current_user.last_login else None
        }
    }), 200

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {str(error)}")
    return jsonify({'error': 'Internal server error'}), 500

# Health check endpoint
@app.route('/api/aep2/health', methods=['GET'])
def health_check():
    """AEP-2 Health check endpoint"""
    return jsonify({'status': 'healthy', 'service': 'AEP-2 Authentication API'}), 200

# Initialize database
def init_db():
    """Initialize database with required tables"""
    with app.app_context():
        db.create_all()
        logger.info("Database initialized successfully")

if __name__ == '__main__':
    init_db()
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=os.environ.get('FLASK_DEBUG', 'False').lower() == 'true')