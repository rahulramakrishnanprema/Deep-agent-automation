"""
AEP-2 Authentication API Implementation
Backend authentication API service that handles user login and registration with JWT token-based authentication
"""

import os
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, Any

from flask import Flask, request, jsonify, make_response
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.exc import IntegrityError
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from functools import wraps
from pydantic import BaseModel, EmailStr, constr, ValidationError
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("aep2_auth.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("AEP-2")

# Initialize Flask app
app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-here-change-in-production')
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv(
    'DATABASE_URL', 
    'sqlite:///aep2_auth.db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=1)

# Initialize database
db = SQLAlchemy(app)

# Pydantic models for request validation
class UserRegistration(BaseModel):
    username: constr(min_length=3, max_length=50)
    email: EmailStr
    password: constr(min_length=8)

class UserLogin(BaseModel):
    email: EmailStr
    password: str

# Database models
class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime, nullable=True)
    is_active = db.Column(db.Boolean, default=True)
    
    def set_password(self, password: str) -> None:
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password: str) -> bool:
        return check_password_hash(self.password_hash, password)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'created_at': self.created_at.isoformat(),
            'last_login': self.last_login.isoformat() if self.last_login else None,
            'is_active': self.is_active
        }

# JWT token decorator
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        # Check for token in Authorization header
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            logger.warning("Access attempt without token")
            return jsonify({'message': 'Token is missing'}), 401
        
        try:
            # Decode the token
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = User.query.get(data['user_id'])
            
            if not current_user or not current_user.is_active:
                logger.warning(f"Invalid token for user_id: {data.get('user_id')}")
                return jsonify({'message': 'Invalid token'}), 401
                
        except jwt.ExpiredSignatureError:
            logger.warning("Expired token attempt")
            return jsonify({'message': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            logger.warning("Invalid token attempt")
            return jsonify({'message': 'Token is invalid'}), 401
        
        return f(current_user, *args, **kwargs)
    
    return decorated

# Utility functions
def generate_jwt_token(user: User) -> str:
    """Generate JWT token for authenticated user"""
    payload = {
        'user_id': user.id,
        'username': user.username,
        'email': user.email,
        'exp': datetime.utcnow() + app.config['JWT_ACCESS_TOKEN_EXPIRES']
    }
    return jwt.encode(payload, app.config['SECRET_KEY'], algorithm='HS256')

# API Routes
@app.route('/api/aep2/register', methods=['POST'])
def register():
    """User registration endpoint"""
    try:
        # Validate request data
        registration_data = UserRegistration(**request.get_json())
        
        # Check if user already exists
        if User.query.filter_by(email=registration_data.email).first():
            logger.warning(f"Registration attempt with existing email: {registration_data.email}")
            return jsonify({
                'message': 'User with this email already exists'
            }), 409
        
        if User.query.filter_by(username=registration_data.username).first():
            logger.warning(f"Registration attempt with existing username: {registration_data.username}")
            return jsonify({
                'message': 'User with this username already exists'
            }), 409
        
        # Create new user
        new_user = User(
            username=registration_data.username,
            email=registration_data.email
        )
        new_user.set_password(registration_data.password)
        
        db.session.add(new_user)
        db.session.commit()
        
        logger.info(f"New user registered: {registration_data.email}")
        
        # Generate token
        token = generate_jwt_token(new_user)
        
        return jsonify({
            'message': 'User registered successfully',
            'token': token,
            'user': new_user.to_dict()
        }), 201
        
    except ValidationError as e:
        logger.warning(f"Invalid registration data: {e}")
        return jsonify({
            'message': 'Invalid input data',
            'errors': e.errors()
        }), 400
        
    except IntegrityError:
        db.session.rollback()
        logger.error("Database integrity error during registration")
        return jsonify({
            'message': 'Registration failed due to database error'
        }), 500
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Unexpected error during registration: {e}")
        return jsonify({
            'message': 'Internal server error'
        }), 500

@app.route('/api/aep2/login', methods=['POST'])
def login():
    """User login endpoint"""
    try:
        # Validate request data
        login_data = UserLogin(**request.get_json())
        
        # Find user by email
        user = User.query.filter_by(email=login_data.email).first()
        
        # Check if user exists and password is correct
        if not user or not user.check_password(login_data.password):
            logger.warning(f"Failed login attempt for email: {login_data.email}")
            return jsonify({
                'message': 'Invalid email or password'
            }), 401
        
        # Check if user is active
        if not user.is_active:
            logger.warning(f"Login attempt for inactive user: {login_data.email}")
            return jsonify({
                'message': 'Account is deactivated'
            }), 401
        
        # Update last login
        user.last_login = datetime.utcnow()
        db.session.commit()
        
        # Generate token
        token = generate_jwt_token(user)
        
        logger.info(f"User logged in successfully: {login_data.email}")
        
        return jsonify({
            'message': 'Login successful',
            'token': token,
            'user': user.to_dict()
        }), 200
        
    except ValidationError as e:
        logger.warning(f"Invalid login data: {e}")
        return jsonify({
            'message': 'Invalid input data',
            'errors': e.errors()
        }), 400
        
    except Exception as e:
        logger.error(f"Unexpected error during login: {e}")
        return jsonify({
            'message': 'Internal server error'
        }), 500

@app.route('/api/aep2/profile', methods=['GET'])
@token_required
def get_profile(current_user):
    """Get user profile endpoint (protected)"""
    try:
        return jsonify({
            'message': 'Profile retrieved successfully',
            'user': current_user.to_dict()
        }), 200
        
    except Exception as e:
        logger.error(f"Error retrieving profile: {e}")
        return jsonify({
            'message': 'Internal server error'
        }), 500

@app.route('/api/aep2/validate-token', methods=['GET'])
@token_required
def validate_token(current_user):
    """Validate JWT token endpoint"""
    return jsonify({
        'message': 'Token is valid',
        'user': current_user.to_dict()
    }), 200

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'message': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return jsonify({'message': 'Internal server error'}), 500

# Health check endpoint
@app.route('/api/aep2/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        # Test database connection
        db.session.execute('SELECT 1')
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'service': 'AEP-2 Authentication API'
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500

# Initialize database
def init_db():
    """Initialize database with required tables"""
    with app.app_context():
        db.create_all()
        logger.info("Database initialized successfully")

if __name__ == '__main__':
    # Initialize database
    init_db()
    
    # Run Flask app
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Starting AEP-2 Authentication API on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)