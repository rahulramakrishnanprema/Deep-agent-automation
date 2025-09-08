import os
import logging
import datetime
import jwt
import bcrypt
from functools import wraps
from flask import Flask, request, jsonify, make_response
from flask_sqlalchemy import SQLAlchemy
from marshmallow import Schema, fields, ValidationError, validates_schema
from werkzeug.security import generate_password_hash, check_password_hash
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Validate required environment variables
required_env_vars = ['SECRET_KEY', 'DATABASE_URL']
missing_vars = [var for var in required_env_vars if not os.getenv(var)]
if missing_vars:
    raise RuntimeError(f"Missing required environment variables: {', '.join(missing_vars)}")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('aep2_auth.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize Flask application
app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = datetime.timedelta(hours=1)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = datetime.timedelta(days=7)

# Security headers middleware
@app.after_request
def add_security_headers(response):
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    return response

# Initialize database
db = SQLAlchemy(app)

# Database Models
class User(db.Model):
    """User model for authentication system.
    
    Attributes:
        id (int): Primary key identifier
        username (str): Unique username
        email (str): Unique email address
        password_hash (str): Hashed password
        created_at (datetime): Account creation timestamp
        is_active (bool): Account active status
        failed_login_attempts (int): Count of failed login attempts
        last_login_attempt (datetime): Timestamp of last login attempt
        email_verified (bool): Email verification status
    """
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)
    failed_login_attempts = db.Column(db.Integer, default=0)
    last_login_attempt = db.Column(db.DateTime, nullable=True)
    email_verified = db.Column(db.Boolean, default=False)
    
    def set_password(self, password: str) -> None:
        """Hash and set user password using bcrypt.
        
        Args:
            password: Plain text password to hash
        """
        salt = bcrypt.gensalt()
        self.password_hash = bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')
    
    def check_password(self, password: str) -> bool:
        """Verify password against bcrypt hash.
        
        Args:
            password: Plain text password to verify
            
        Returns:
            bool: True if password matches hash, False otherwise
        """
        return bcrypt.checkpw(password.encode('utf-8'), self.password_hash.encode('utf-8'))
    
    def increment_failed_login(self) -> None:
        """Increment failed login attempts counter and update timestamp."""
        self.failed_login_attempts += 1
        self.last_login_attempt = datetime.datetime.utcnow()
        db.session.commit()
    
    def reset_failed_logins(self) -> None:
        """Reset failed login attempts counter."""
        self.failed_login_attempts = 0
        self.last_login_attempt = None
        db.session.commit()
    
    def to_dict(self) -> dict:
        """Convert user object to dictionary.
        
        Returns:
            dict: User data as dictionary
        """
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'created_at': self.created_at.isoformat(),
            'is_active': self.is_active,
            'email_verified': self.email_verified
        }

class BlacklistedToken(db.Model):
    """Model for storing blacklisted JWT tokens."""
    __tablename__ = 'blacklisted_tokens'
    
    id = db.Column(db.Integer, primary_key=True)
    token = db.Column(db.String(500), unique=True, nullable=False)
    blacklisted_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)
    expires_at = db.Column(db.DateTime, nullable=False)

# Marshmallow Schemas
class RegistrationSchema(Schema):
    """Schema for user registration validation."""
    username = fields.Str(required=True, validate=fields.validate.Length(min=3, max=80))
    email = fields.Email(required=True)
    password = fields.Str(required=True, validate=fields.validate.Length(min=8))
    confirm_password = fields.Str(required=True)
    
    @validates_schema
    def validate_passwords(self, data: dict, **kwargs) -> None:
        """Validate that password and confirm_password match.
        
        Args:
            data: Input data dictionary
            
        Raises:
            ValidationError: If passwords don't match
        """
        if data['password'] != data['confirm_password']:
            raise ValidationError("Passwords do not match", field_name="confirm_password")
    
    @validates_schema
    def validate_password_complexity(self, data: dict, **kwargs) -> None:
        """Validate password complexity requirements.
        
        Args:
            data: Input data dictionary
            
        Raises:
            ValidationError: If password doesn't meet complexity requirements
        """
        password = data['password']
        if (len(password) < 8 or 
            not any(char.isdigit() for char in password) or
            not any(char.isupper() for char in password) or
            not any(char.islower() for char in password)):
            raise ValidationError("Password must be at least 8 characters long and contain uppercase, lowercase letters and numbers", field_name="password")

class LoginSchema(Schema):
    """Schema for user login validation."""
    username = fields.Str(required=True)
    password = fields.Str(required=True)

class RefreshTokenSchema(Schema):
    """Schema for refresh token validation."""
    refresh_token = fields.Str(required=True)

# JWT Token Management
def generate_jwt_tokens(user_id: int, username: str) -> tuple:
    """Generate access and refresh JWT tokens.
    
    Args:
        user_id: User identifier
        username: Username
        
    Returns:
        tuple: (access_token, refresh_token)
    """
    access_token_payload = {
        'user_id': user_id,
        'username': username,
        'exp': datetime.datetime.utcnow() + app.config['JWT_ACCESS_TOKEN_EXPIRES'],
        'iat': datetime.datetime.utcnow(),
        'type': 'access'
    }
    
    refresh_token_payload = {
        'user_id': user_id,
        'username': username,
        'exp': datetime.datetime.utcnow() + app.config['JWT_REFRESH_TOKEN_EXPIRES'],
        'iat': datetime.datetime.utcnow(),
        'type': 'refresh'
    }
    
    access_token = jwt.encode(
        access_token_payload, 
        app.config['SECRET_KEY'], 
        algorithm='HS256'
    )
    
    refresh_token = jwt.encode(
        refresh_token_payload, 
        app.config['SECRET_KEY'], 
        algorithm='HS256'
    )
    
    return access_token, refresh_token

def verify_jwt_token(token: str) -> dict:
    """Verify JWT token and return payload if valid.
    
    Args:
        token: JWT token to verify
        
    Returns:
        dict: Token payload if valid, None otherwise
    """
    try:
        # Check if token is blacklisted
        if BlacklistedToken.query.filter_by(token=token).first():
            logger.warning("Blacklisted token attempted use")
            return None
            
        payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning("JWT token expired")
        return None
    except jwt.InvalidTokenError:
        logger.warning("Invalid JWT token")
        return None

def blacklist_token(token: str, expires_at: datetime.datetime) -> None:
    """Add token to blacklist.
    
    Args:
        token: Token to blacklist
        expires_at: Token expiration time
    """
    blacklisted_token = BlacklistedToken(
        token=token,
        expires_at=expires_at
    )
    db.session.add(blacklisted_token)
    db.session.commit()

# Decorators
def token_required(f):
    """Decorator to require valid JWT token for protected routes."""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        # Check for token in Authorization header
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            logger.warning("Missing token in request")
            return jsonify({'error': 'Token is missing'}), 401
        
        # Verify token
        payload = verify_jwt_token(token)
        if not payload or payload.get('type') != 'access':
            logger.warning("Invalid or expired token")
            return jsonify({'error': 'Invalid or expired token'}), 401
        
        # Get user from database
        user = User.query.get(payload['user_id'])
        if not user or not user.is_active:
            logger.warning("User not found or inactive")
            return jsonify({'error': 'User not found or inactive'}), 401
        
        # Add user to request context
        request.current_user = user
        
        return f(*args, **kwargs)
    
    return decorated

# API Routes
@app.route('/api/aep2/register', methods=['POST'])
def register():
    """User registration endpoint."""
    try:
        # Validate input data
        schema = RegistrationSchema()
        data = schema.load(request.get_json())
        
        # Check if user already exists
        if User.query.filter_by(username=data['username']).first():
            logger.warning(f"Registration failed - username already exists: {data['username']}")
            return jsonify({'error': 'Username already exists'}), 409
        
        if User.query.filter_by(email=data['email']).first():
            logger.warning(f"Registration failed - email already exists: {data['email']}")
            return jsonify({'error': 'Email already exists'}), 409
        
        # Create new user
        new_user = User(
            username=data['username'],
            email=data['email']
        )
        new_user.set_password(data['password'])
        
        db.session.add(new_user)
        db.session.commit()
        
        logger.info(f"User registered successfully: {data['username']}")
        
        return jsonify({
            'message': 'User registered successfully',
            'user': new_user.to_dict()
        }), 201
        
    except ValidationError as err:
        logger.warning(f"Registration validation failed: {err.messages}")
        return jsonify({'error': 'Validation failed', 'details': err.messages}), 400
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/aep2/login', methods=['POST'])
def login():
    """User login endpoint."""
    try:
        # Validate input data
        schema = LoginSchema()
        data = schema.load(request.get_json())
        
        # Find user
        user = User.query.filter_by(username=data['username']).first()
        
        # Check if user exists and is active
        if not user or not user.is_active:
            logger.warning(f"Login failed - user not found or inactive: {data['username']}")
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # Check for too many failed attempts
        if (user.failed_login_attempts >= 5 and 
            user.last_login_attempt and 
            (datetime.datetime.utcnow() - user.last_login_attempt).total_seconds() < 300):
            logger.warning(f"Account temporarily locked: {data['username']}")
            return jsonify({'error': 'Account temporarily locked due to too many failed attempts'}), 429
        
        # Verify password
        if not user.check_password(data['password']):
            user.increment_failed_login()
            logger.warning(f"Login failed - invalid password: {data['username']}")
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # Reset failed login attempts on successful login
        user.reset_failed_logins()
        
        # Generate JWT tokens
        access_token, refresh_token = generate_jwt_tokens(user.id, user.username)
        
        logger.info(f"User logged in successfully: {data['username']}")