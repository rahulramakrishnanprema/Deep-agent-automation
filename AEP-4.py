import os
import logging
from typing import Dict, Any, Optional
from datetime import datetime
from contextlib import contextmanager

from flask import Flask, jsonify, request, g
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.exc import SQLAlchemyError
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from functools import wraps

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask application
app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get(
    'DATABASE_URL', 
    'sqlite:///aep4_user_profiles.db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize database
db = SQLAlchemy(app)

class AEP4UserProfile(db.Model):
    """
    Database model for AEP-4 User Profile functionality.
    Stores basic user profile information including name, email, and role.
    """
    __tablename__ = 'aep4_user_profiles'
    
    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    email = Column(String(120), unique=True, nullable=False)
    password_hash = Column(String(128), nullable=False)
    role = Column(String(50), nullable=False, default='user')
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def set_password(self, password: str) -> None:
        """Hash and set the user's password."""
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password: str) -> bool:
        """Check if the provided password matches the stored hash."""
        return check_password_hash(self.password_hash, password)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert user profile to dictionary for JSON serialization."""
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'role': self.role,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }

def token_required(f):
    """
    Decorator to require valid JWT token for protected routes.
    Validates token and sets current user in Flask's g object.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        # Check for token in Authorization header
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            logger.warning('AEP-4: Missing authentication token')
            return jsonify({'message': 'Token is missing'}), 401
        
        try:
            # Decode and validate token
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = AEP4UserProfile.query.get(data['user_id'])
            
            if not current_user:
                logger.warning(f'AEP-4: User not found for token: {data["user_id"]}')
                return jsonify({'message': 'User not found'}), 401
            
            # Set current user in Flask's g object
            g.current_user = current_user
            
        except jwt.ExpiredSignatureError:
            logger.warning('AEP-4: Token has expired')
            return jsonify({'message': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            logger.warning('AEP-4: Invalid token')
            return jsonify({'message': 'Token is invalid'}), 401
        except Exception as e:
            logger.error(f'AEP-4: Token validation error: {str(e)}')
            return jsonify({'message': 'Token validation failed'}), 401
        
        return f(*args, **kwargs)
    
    return decorated

@contextmanager
def database_session():
    """
    Context manager for database operations with proper error handling.
    Ensures proper session management and rollback on errors.
    """
    try:
        yield db.session
        db.session.commit()
    except SQLAlchemyError as e:
        db.session.rollback()
        logger.error(f'AEP-4: Database error: {str(e)}')
        raise
    except Exception as e:
        db.session.rollback()
        logger.error(f'AEP-4: Unexpected error: {str(e)}')
        raise

@app.route('/api/aep4/profile', methods=['GET'])
@token_required
def get_user_profile():
    """
    AEP-4 User Profile API endpoint.
    Returns basic user profile information for authenticated users.
    
    Returns:
        JSON response with user profile data or error message
    """
    try:
        current_user = g.current_user
        
        logger.info(f'AEP-4: Retrieving profile for user: {current_user.email}')
        
        # Return user profile data
        return jsonify({
            'success': True,
            'data': {
                'profile': current_user.to_dict()
            },
            'message': 'User profile retrieved successfully'
        }), 200
        
    except SQLAlchemyError as e:
        logger.error(f'AEP-4: Database error while retrieving profile: {str(e)}')
        return jsonify({
            'success': False,
            'error': 'Database error occurred',
            'message': 'Failed to retrieve user profile'
        }), 500
        
    except Exception as e:
        logger.error(f'AEP-4: Unexpected error while retrieving profile: {str(e)}')
        return jsonify({
            'success': False,
            'error': 'Internal server error',
            'message': 'Failed to retrieve user profile'
        }), 500

@app.route('/api/aep4/health', methods=['GET'])
def health_check():
    """
    Health check endpoint for AEP-4 functionality.
    Verifies database connectivity and basic functionality.
    """
    try:
        # Test database connection
        db.session.execute('SELECT 1')
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'service': 'AEP-4 User Profile API'
        }), 200
        
    except Exception as e:
        logger.error(f'AEP-4: Health check failed: {str(e)}')
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat(),
            'service': 'AEP-4 User Profile API'
        }), 500

def create_test_user():
    """Create a test user for development and testing purposes."""
    try:
        with database_session():
            # Check if test user already exists
            test_user = AEP4UserProfile.query.filter_by(email='test@example.com').first()
            
            if not test_user:
                test_user = AEP4UserProfile(
                    name='Test User',
                    email='test@example.com',
                    role='admin'
                )
                test_user.set_password('testpassword')
                db.session.add(test_user)
                logger.info('AEP-4: Created test user')
            else:
                logger.info('AEP-4: Test user already exists')
                
    except Exception as e:
        logger.error(f'AEP-4: Failed to create test user: {str(e)}')

def initialize_database():
    """Initialize database and create tables."""
    try:
        with app.app_context():
            db.create_all()
            create_test_user()
            logger.info('AEP-4: Database initialized successfully')
    except Exception as e:
        logger.error(f'AEP-4: Database initialization failed: {str(e)}')
        raise

if __name__ == '__main__':
    # Initialize database and start application
    initialize_database()
    
    # Run Flask development server
    app.run(
        host=os.environ.get('HOST', '0.0.0.0'),
        port=int(os.environ.get('PORT', 5000)),
        debug=os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    )