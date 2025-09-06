import os
import logging
import datetime
import jwt
import bcrypt
from functools import wraps
from flask import Flask, request, jsonify, make_response
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.exc import IntegrityError
from marshmallow import Schema, fields, ValidationError
from werkzeug.security import generate_password_hash, check_password_hash

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask application
app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'aep-2-development-secret-key-2024')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get(
    'DATABASE_URL', 
    'sqlite:///aep2_auth.db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = datetime.timedelta(hours=1)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = datetime.timedelta(days=7)

# Initialize database
db = SQLAlchemy(app)

# Database Models
class User(db.Model):
    """User model for AEP-2 authentication system"""
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)
    failed_login_attempts = db.Column(db.Integer, default=0)
    last_login_attempt = db.Column(db.DateTime, nullable=True)
    
    def set_password(self, password):
        """Hash and set user password"""
        salt = bcrypt.gensalt()
        self.password_hash = bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')
    
    def check_password(self, password):
        """Verify password against hash"""
        return bcrypt.checkpw(password.encode('utf-8'), self.password_hash.encode('utf-8'))
    
    def generate_jwt_token(self, token_type='access'):
        """Generate JWT token for user"""
        expiration = datetime.datetime.utcnow() + (
            app.config['JWT_ACCESS_TOKEN_EXPIRES'] if token_type == 'access' 
            else app.config['JWT_REFRESH_TOKEN_EXPIRES']
        )
        
        payload = {
            'user_id': self.id,
            'email': self.email,
            'type': token_type,
            'exp': expiration,
            'iat': datetime.datetime.utcnow()
        }
        
        return jwt.encode(
            payload, 
            app.config['SECRET_KEY'], 
            algorithm='HS256'
        )

# Marshmallow Schemas for validation
class UserRegistrationSchema(Schema):
    """Schema for user registration validation"""
    email = fields.Email(required=True)
    password = fields.Str(required=True, validate=lambda p: len(p) >= 8)
    confirm_password = fields.Str(required=True)

class UserLoginSchema(Schema):
    """Schema for user login validation"""
    email = fields.Email(required=True)
    password = fields.Str(required=True)

# Decorators
def token_required(f):
    """Decorator to require valid JWT token"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        # Check for token in Authorization header
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        
        try:
            # Decode and verify token
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = User.query.get(data['user_id'])
            
            if not current_user or not current_user.is_active:
                return jsonify({'error': 'Invalid token or user not active'}), 401
                
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(current_user, *args, **kwargs)
    
    return decorated

# Utility Functions
def validate_request_data(schema_class):
    """Decorator to validate request data against schema"""
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            try:
                data = request.get_json()
                if not data:
                    return jsonify({'error': 'No input data provided'}), 400
                
                schema = schema_class()
                errors = schema.validate(data)
                if errors:
                    return jsonify({'error': 'Validation failed', 'details': errors}), 400
                
                return f(data, *args, **kwargs)
            except Exception as e:
                logger.error(f"Validation error: {str(e)}")
                return jsonify({'error': 'Invalid JSON data'}), 400
        return decorated
    return decorator

# API Routes
@app.route('/api/aep2/auth/register', methods=['POST'])
@validate_request_data(UserRegistrationSchema)
def register_user(data):
    """User registration endpoint for AEP-2"""
    try:
        # Check if passwords match
        if data['password'] != data['confirm_password']:
            return jsonify({'error': 'Passwords do not match'}), 400
        
        # Check if user already exists
        existing_user = User.query.filter_by(email=data['email']).first()
        if existing_user:
            return jsonify({'error': 'User already exists'}), 409
        
        # Create new user
        new_user = User(email=data['email'])
        new_user.set_password(data['password'])
        
        db.session.add(new_user)
        db.session.commit()
        
        # Generate tokens
        access_token = new_user.generate_jwt_token('access')
        refresh_token = new_user.generate_jwt_token('refresh')
        
        logger.info(f"New user registered: {data['email']}")
        
        return jsonify({
            'message': 'User registered successfully',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user_id': new_user.id,
            'email': new_user.email
        }), 201
        
    except IntegrityError:
        db.session.rollback()
        return jsonify({'error': 'User already exists'}), 409
    except Exception as e:
        db.session.rollback()
        logger.error(f"Registration error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/aep2/auth/login', methods=['POST'])
@validate_request_data(UserLoginSchema)
def login_user(data):
    """User login endpoint for AEP-2"""
    try:
        user = User.query.filter_by(email=data['email']).first()
        
        # Check if user exists and is active
        if not user or not user.is_active:
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # Check if account is locked due to too many failed attempts
        if user.failed_login_attempts >= 5 and user.last_login_attempt:
            lock_time = datetime.datetime.utcnow() - user.last_login_attempt
            if lock_time.total_seconds() < 300:  # 5 minutes lock
                return jsonify({
                    'error': 'Account temporarily locked. Try again later.'
                }), 429
        
        # Verify password
        if not user.check_password(data['password']):
            # Update failed login attempts
            user.failed_login_attempts += 1
            user.last_login_attempt = datetime.datetime.utcnow()
            db.session.commit()
            
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # Reset failed attempts on successful login
        user.failed_login_attempts = 0
        user.last_login_attempt = datetime.datetime.utcnow()
        db.session.commit()
        
        # Generate tokens
        access_token = user.generate_jwt_token('access')
        refresh_token = user.generate_jwt_token('refresh')
        
        logger.info(f"User logged in: {data['email']}")
        
        return jsonify({
            'message': 'Login successful',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user_id': user.id,
            'email': user.email
        }), 200
        
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/aep2/auth/refresh', methods=['POST'])
def refresh_token():
    """Refresh JWT token endpoint"""
    try:
        refresh_token = request.json.get('refresh_token')
        
        if not refresh_token:
            return jsonify({'error': 'Refresh token is required'}), 400
        
        try:
            # Verify refresh token
            payload = jwt.decode(refresh_token, app.config['SECRET_KEY'], algorithms=['HS256'])
            
            if payload['type'] != 'refresh':
                return jsonify({'error': 'Invalid token type'}), 401
            
            user = User.query.get(payload['user_id'])
            if not user or not user.is_active:
                return jsonify({'error': 'Invalid user'}), 401
            
            # Generate new access token
            new_access_token = user.generate_jwt_token('access')
            
            return jsonify({
                'access_token': new_access_token
            }), 200
            
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Refresh token expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid refresh token'}), 401
            
    except Exception as e:
        logger.error(f"Token refresh error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/aep2/auth/profile', methods=['GET'])
@token_required
def get_user_profile(current_user):
    """Get user profile endpoint"""
    return jsonify({
        'user_id': current_user.id,
        'email': current_user.email,
        'created_at': current_user.created_at.isoformat(),
        'is_active': current_user.is_active
    }), 200

@app.route('/api/aep2/auth/logout', methods=['POST'])
@token_required
def logout_user(current_user):
    """User logout endpoint"""
    # In a production environment, you might want to blacklist the token
    # For now, we'll just return success
    logger.info(f"User logged out: {current_user.email}")
    return jsonify({'message': 'Logout successful'}), 200

# Error Handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {str(error)}")
    return jsonify({'error': 'Internal server error'}), 500

# Health Check Endpoint
@app.route('/api/aep2/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'AEP-2 Authentication API',
        'timestamp': datetime.datetime.utcnow().isoformat()
    }), 200

# Initialize database
def init_db():
    """Initialize database with required tables"""
    with app.app_context():
        db.create_all()
        logger.info("Database initialized successfully")

# Main entry point
if __name__ == '__main__':
    # Initialize database
    init_db()
    
    # Run Flask application
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Starting AEP-2 Authentication API on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)