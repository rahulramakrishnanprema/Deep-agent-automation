import os
import json
import logging
import secrets
import string
import threading
from datetime import datetime, timedelta
from functools import wraps
from typing import Dict, Optional, Tuple

# Third-party imports
try:
    import bcrypt
    import jwt
    from flask import Flask, request, jsonify, make_response
    from flask_limiter import Limiter
    from flask_limiter.util import get_remote_address
except ImportError as e:
    print(f"Missing required dependency: {e}")
    print("Please install with: pip install bcrypt pyjwt flask flask-limiter")
    raise

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('aep2_auth_service.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('AEP-2_Auth_Service')

# Initialize Flask application
app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', secrets.token_hex(32))
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', secrets.token_hex(32))
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=1)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = timedelta(days=7)
app.config['MAX_LOGIN_ATTEMPTS'] = int(os.environ.get('MAX_LOGIN_ATTEMPTS', 5))
app.config['LOCKOUT_TIME'] = int(os.environ.get('LOCKOUT_TIME', 300))  # 5 minutes in seconds

# Rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

# Thread-safe user storage (in production, use a proper database)
class ThreadSafeUserStorage:
    """Thread-safe in-memory user storage for demonstration purposes."""
    
    def __init__(self):
        self.users = {}
        self.failed_attempts = {}
        self.lockouts = {}
        self.lock = threading.RLock()
    
    def add_user(self, username: str, hashed_password: str, email: str) -> bool:
        """Add a new user to storage."""
        with self.lock:
            if username in self.users:
                return False
            self.users[username] = {
                'hashed_password': hashed_password,
                'email': email,
                'created_at': datetime.utcnow().isoformat(),
                'is_active': True
            }
            return True
    
    def get_user(self, username: str) -> Optional[Dict]:
        """Retrieve user data."""
        with self.lock:
            return self.users.get(username)
    
    def record_failed_attempt(self, username: str) -> int:
        """Record a failed login attempt and return current count."""
        with self.lock:
            if username not in self.failed_attempts:
                self.failed_attempts[username] = 0
            self.failed_attempts[username] += 1
            return self.failed_attempts[username]
    
    def reset_failed_attempts(self, username: str):
        """Reset failed login attempts for a user."""
        with self.lock:
            if username in self.failed_attempts:
                del self.failed_attempts[username]
            if username in self.lockouts:
                del self.lockouts[username]
    
    def is_locked_out(self, username: str) -> bool:
        """Check if user is currently locked out."""
        with self.lock:
            if username in self.lockouts:
                lockout_time = self.lockouts[username]
                if datetime.utcnow() < lockout_time:
                    return True
                else:
                    del self.lockouts[username]
                    del self.failed_attempts[username]
            return False
    
    def lockout_user(self, username: str):
        """Lock out a user for the configured lockout time."""
        with self.lock:
            lockout_until = datetime.utcnow() + timedelta(seconds=app.config['LOCKOUT_TIME'])
            self.lockouts[username] = lockout_until

# Initialize thread-safe storage
user_storage = ThreadSafeUserStorage()

def generate_password(length: int = 12) -> str:
    """Generate a secure random password."""
    characters = string.ascii_letters + string.digits + string.punctuation
    return ''.join(secrets.choice(characters) for _ in range(length))

def hash_password(password: str) -> str:
    """Hash a password using bcrypt."""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def verify_password(password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return bcrypt.checkpw(password.encode('utf-8'), hashed_password.encode('utf-8'))

def generate_jwt_token(payload: Dict, token_type: str = 'access') -> str:
    """Generate a JWT token."""
    expires_delta = app.config['JWT_ACCESS_TOKEN_EXPIRES'] if token_type == 'access' else app.config['JWT_REFRESH_TOKEN_EXPIRES']
    payload.update({
        'exp': datetime.utcnow() + expires_delta,
        'iat': datetime.utcnow(),
        'type': token_type
    })
    return jwt.encode(payload, app.config['JWT_SECRET_KEY'], algorithm='HS256')

def verify_jwt_token(token: str) -> Optional[Dict]:
    """Verify and decode a JWT token."""
    try:
        payload = jwt.decode(token, app.config['JWT_SECRET_KEY'], algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning("JWT token expired")
        return None
    except jwt.InvalidTokenError:
        logger.warning("Invalid JWT token")
        return None

def token_required(f):
    """Decorator to require valid JWT token for protected routes."""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        
        payload = verify_jwt_token(token)
        if not payload or payload.get('type') != 'access':
            return jsonify({'error': 'Invalid or expired token'}), 401
        
        request.user = payload
        return f(*args, **kwargs)
    
    return decorated

@app.route('/api/v1/register', methods=['POST'])
@limiter.limit("10 per minute")
def register():
    """
    AEP-2 Registration API
    Register a new user with username, email, and password.
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        username = data.get('username')
        email = data.get('email')
        password = data.get('password')
        
        # Validation
        if not all([username, email, password]):
            return jsonify({'error': 'Username, email, and password are required'}), 400
        
        if len(password) < 8:
            return jsonify({'error': 'Password must be at least 8 characters long'}), 400
        
        if len(username) < 3:
            return jsonify({'error': 'Username must be at least 3 characters long'}), 400
        
        # Check if user already exists
        if user_storage.get_user(username):
            return jsonify({'error': 'Username already exists'}), 409
        
        # Hash password and create user
        hashed_password = hash_password(password)
        
        if not user_storage.add_user(username, hashed_password, email):
            return jsonify({'error': 'Failed to create user'}), 500
        
        logger.info(f"User registered successfully: {username}")
        return jsonify({
            'message': 'User registered successfully',
            'username': username,
            'email': email
        }), 201
        
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/v1/login', methods=['POST'])
@limiter.limit("5 per minute")
def login():
    """
    AEP-2 Login API
    Authenticate user and return JWT tokens.
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        username = data.get('username')
        password = data.get('password')
        
        if not all([username, password]):
            return jsonify({'error': 'Username and password are required'}), 400
        
        # Check for lockout
        if user_storage.is_locked_out(username):
            return jsonify({'error': 'Account temporarily locked due to too many failed attempts'}), 429
        
        # Get user from storage
        user = user_storage.get_user(username)
        if not user or not user['is_active']:
            user_storage.record_failed_attempt(username)
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # Verify password
        if not verify_password(password, user['hashed_password']):
            attempts = user_storage.record_failed_attempt(username)
            
            if attempts >= app.config['MAX_LOGIN_ATTEMPTS']:
                user_storage.lockout_user(username)
                return jsonify({
                    'error': 'Too many failed attempts. Account temporarily locked.'
                }), 429
            
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # Reset failed attempts on successful login
        user_storage.reset_failed_attempts(username)
        
        # Generate tokens
        payload = {
            'sub': username,
            'email': user['email'],
            'created_at': user['created_at']
        }
        
        access_token = generate_jwt_token(payload, 'access')
        refresh_token = generate_jwt_token(payload, 'refresh')
        
        logger.info(f"User logged in successfully: {username}")
        
        response = make_response(jsonify({
            'message': 'Login successful',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'token_type': 'Bearer',
            'expires_in': int(app.config['JWT_ACCESS_TOKEN_EXPIRES'].total_seconds())
        }))
        
        # Set HTTP-only cookies for additional security
        response.set_cookie(
            'refresh_token',
            refresh_token,
            httponly=True,
            secure=True,  # Set to True in production with HTTPS
            samesite='Strict',
            max_age=int(app.config['JWT_REFRESH_TOKEN_EXPIRES'].total_seconds())
        )
        
        return response, 200
        
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/v1/refresh', methods=['POST'])
def refresh_token():
    """
    AEP-2 Token Refresh API
    Refresh access token using refresh token.
    """
    try:
        refresh_token = request.cookies.get('refresh_token') or request.json.get('refresh_token')
        
        if not refresh_token:
            return jsonify({'error': 'Refresh token required'}), 400
        
        payload = verify_jwt_token(refresh_token)
        if not payload or payload.get('type') != 'refresh':
            return jsonify({'error': 'Invalid or expired refresh token'}), 401
        
        # Generate new access token
        new_payload = {
            'sub': payload['sub'],
            'email': payload['email'],
            'created_at': payload['created_at']
        }
        
        access_token = generate_jwt_token(new_payload, 'access')
        
        logger.info(f"Token refreshed for user: {payload['sub']}")
        
        return jsonify({
            'access_token': access_token,
            'token_type': 'Bearer',
            'expires_in': int(app.config['JWT_ACCESS_TOKEN_EXPIRES'].total_seconds())
        }), 200
        
    except Exception as e:
        logger.error(f"Token refresh error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/v1/profile', methods=['GET'])
@token_required
def get_profile():
    """
    AEP-2 Protected Profile API
    Get user profile information (requires valid JWT).
    """
    try:
        username = request.user['sub']
        user = user_storage.get_user(username)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify({
            'username': username,
            'email': user['email'],
            'created_at': user['created_at'],
            'is_active': user['is_active']
        }), 200
        
    except Exception as e:
        logger.error(f"Profile retrieval error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/v1/logout', methods=['POST'])
def logout():
    """
    AEP-2 Logout API
    Invalidate refresh token by clearing cookie.
    """
    response = make_response(jsonify({'message': 'Logout successful'}))
    response.set_cookie('refresh_token