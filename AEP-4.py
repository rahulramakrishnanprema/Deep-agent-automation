import os
import logging
from typing import Optional, Dict, Any
from datetime import datetime
from contextlib import contextmanager

# Database imports
import sqlite3
from sqlite3 import Error

# Web framework imports
from flask import Flask, request, jsonify, g
from flask_httpauth import HTTPBasicAuth
from werkzeug.security import generate_password_hash, check_password_hash

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("aep4_user_profile.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("AEP-4-UserProfileAPI")

class AEP4DatabaseManager:
    """Database manager for AEP-4 User Profile API"""
    
    def __init__(self, db_path: str = "aep4_users.db"):
        self.db_path = db_path
        self._initialize_database()
    
    def _initialize_database(self):
        """Initialize database with required tables"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                # Create users table if it doesn't exist
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS users (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        username TEXT UNIQUE NOT NULL,
                        password_hash TEXT NOT NULL,
                        email TEXT UNIQUE NOT NULL,
                        full_name TEXT NOT NULL,
                        role TEXT NOT NULL DEFAULT 'user',
                        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # Create index for faster lookups
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_username ON users(username)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_email ON users(email)')
                
                conn.commit()
                logger.info("Database initialized successfully")
                
        except Error as e:
            logger.error(f"Database initialization failed: {e}")
            raise
    
    @contextmanager
    def _get_connection(self):
        """Context manager for database connections"""
        conn = None
        try:
            conn = sqlite3.connect(self.db_path)
            conn.row_factory = sqlite3.Row
            yield conn
        except Error as e:
            logger.error(f"Database connection error: {e}")
            raise
        finally:
            if conn:
                conn.close()
    
    def create_user(self, username: str, password: str, email: str, full_name: str, role: str = "user") -> bool:
        """Create a new user in the database"""
        try:
            password_hash = generate_password_hash(password)
            
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    INSERT INTO users (username, password_hash, email, full_name, role)
                    VALUES (?, ?, ?, ?, ?)
                ''', (username, password_hash, email, full_name, role))
                
                conn.commit()
                logger.info(f"User '{username}' created successfully")
                return True
                
        except Error as e:
            logger.error(f"Failed to create user '{username}': {e}")
            return False
    
    def get_user_by_username(self, username: str) -> Optional[Dict[str, Any]]:
        """Get user by username"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('SELECT * FROM users WHERE username = ?', (username,))
                user = cursor.fetchone()
                
                if user:
                    return dict(user)
                return None
                
        except Error as e:
            logger.error(f"Failed to get user '{username}': {e}")
            return None
    
    def get_user_profile(self, username: str) -> Optional[Dict[str, Any]]:
        """Get user profile information (name, email, role)"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    SELECT username, email, full_name as name, role, created_at, updated_at
                    FROM users WHERE username = ?
                ''', (username,))
                
                user = cursor.fetchone()
                if user:
                    profile = dict(user)
                    # Convert datetime objects to strings for JSON serialization
                    profile['created_at'] = profile['created_at']
                    profile['updated_at'] = profile['updated_at']
                    return profile
                return None
                
        except Error as e:
            logger.error(f"Failed to get profile for user '{username}': {e}")
            return None

class AEP4UserProfileService:
    """Service layer for AEP-4 User Profile operations"""
    
    def __init__(self, db_manager: AEP4DatabaseManager):
        self.db_manager = db_manager
    
    def get_user_profile(self, username: str) -> Dict[str, Any]:
        """Get user profile with proper error handling"""
        try:
            profile = self.db_manager.get_user_profile(username)
            
            if not profile:
                logger.warning(f"Profile not found for user: {username}")
                return {
                    "error": "User profile not found",
                    "status": "error"
                }
            
            # Remove sensitive information and format response
            response = {
                "status": "success",
                "data": {
                    "username": profile.get("username"),
                    "name": profile.get("name"),
                    "email": profile.get("email"),
                    "role": profile.get("role"),
                    "created_at": profile.get("created_at"),
                    "updated_at": profile.get("updated_at")
                }
            }
            
            logger.info(f"Profile retrieved successfully for user: {username}")
            return response
            
        except Exception as e:
            logger.error(f"Error retrieving profile for user '{username}': {e}")
            return {
                "error": "Internal server error",
                "status": "error"
            }

# Flask application setup
app = Flask(__name__)
auth = HTTPBasicAuth()

# Initialize database manager
db_manager = AEP4DatabaseManager()
user_service = AEP4UserProfileService(db_manager)

@auth.verify_password
def verify_password(username: str, password: str) -> Optional[str]:
    """Verify username and password for basic authentication"""
    try:
        user = db_manager.get_user_by_username(username)
        if user and check_password_hash(user['password_hash'], password):
            logger.info(f"User authenticated: {username}")
            return username
        logger.warning(f"Authentication failed for user: {username}")
        return None
    except Exception as e:
        logger.error(f"Authentication error for user '{username}': {e}")
        return None

@auth.error_handler
def auth_error(status: int) -> Dict[str, Any]:
    """Handle authentication errors"""
    logger.warning(f"Authentication error occurred, status: {status}")
    return jsonify({
        "error": "Authentication required",
        "status": "error"
    }), status

@app.route('/api/v1/profile', methods=['GET'])
@auth.login_required
def get_profile():
    """
    AEP-4: Basic User Profile API Endpoint
    
    Returns the authenticated user's profile information including:
    - name
    - email 
    - role
    - timestamps
    
    Requires Basic Authentication with valid username and password.
    """
    try:
        current_user = auth.current_user()
        logger.info(f"Profile request received for user: {current_user}")
        
        profile_data = user_service.get_user_profile(current_user)
        
        if profile_data.get("status") == "error":
            return jsonify(profile_data), 404
        
        return jsonify(profile_data), 200
        
    except Exception as e:
        logger.error(f"Unexpected error in profile endpoint: {e}")
        return jsonify({
            "error": "Internal server error",
            "status": "error"
        }), 500

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    logger.warning(f"404 error: {request.path}")
    return jsonify({
        "error": "Endpoint not found",
        "status": "error"
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"500 error: {error}")
    return jsonify({
        "error": "Internal server error",
        "status": "error"
    }), 500

def initialize_sample_data():
    """Initialize sample user data for testing"""
    sample_users = [
        ("john_doe", "password123", "john.doe@example.com", "John Doe", "user"),
        ("jane_smith", "securepass", "jane.smith@example.com", "Jane Smith", "admin"),
        ("bob_wilson", "testpass", "bob.wilson@example.com", "Bob Wilson", "user")
    ]
    
    for username, password, email, full_name, role in sample_users:
        existing_user = db_manager.get_user_by_username(username)
        if not existing_user:
            db_manager.create_user(username, password, email, full_name, role)
            logger.info(f"Sample user '{username}' created")

if __name__ == '__main__':
    # Initialize sample data
    initialize_sample_data()
    
    # Start the Flask application
    logger.info("Starting AEP-4 User Profile API server...")
    app.run(
        host=os.environ.get('FLASK_HOST', '0.0.0.0'),
        port=int(os.environ.get('FLASK_PORT', 5000)),
        debug=os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    )