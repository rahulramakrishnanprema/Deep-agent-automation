import os
from flask import Flask, render_template, jsonify, request, redirect, session
from flask_cors import CORS
from functools import wraps

def create_app():
    """Create and configure the Flask application"""
    app = Flask(__name__)
    app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key-2023')
    CORS(app)

    # Mock user data - In production, this would be a database
    USERS = {
        "user1@example.com": {
            "id": 1,
            "name": "John Doe",
            "email": "user1@example.com",
            "role": "admin",
            "password": "password123"  # In production, use hashed passwords
        },
        "user2@example.com": {
            "id": 2,
            "name": "Jane Smith",
            "email": "user2@example.com",
            "role": "user",
            "password": "password456"
        }
    }

    def login_required(f):
        """Decorator to require authentication for protected routes"""
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'user_id' not in session:
                return jsonify({'error': 'Authentication required'}), 401
            return f(*args, **kwargs)
        return decorated_function

    @app.route('/')
    def index():
        """Redirect root to dashboard"""
        return redirect('/dashboard')

    @app.route('/login', methods=['POST'])
    def login():
        """Handle user login authentication"""
        try:
            data = request.get_json()
            email = data.get('email')
            password = data.get('password')
            
            if not email or not password:
                return jsonify({'error': 'Email and password required'}), 400
            
            user = USERS.get(email)
            if user and user['password'] == password:
                session['user_id'] = user['id']
                session['user_email'] = user['email']
                return jsonify({
                    'message': 'Login successful',
                    'user': {
                        'id': user['id'],
                        'name': user['name'],
                        'email': user['email'],
                        'role': user['role']
                    }
                }), 200
            else:
                return jsonify({'error': 'Invalid credentials'}), 401
                
        except Exception as e:
            return jsonify({'error': 'Login failed', 'details': str(e)}), 500

    @app.route('/logout', methods=['POST'])
    def logout():
        """Handle user logout"""
        try:
            session.clear()
            return jsonify({'message': 'Logout successful'}), 200
        except Exception as e:
            return jsonify({'error': 'Logout failed', 'details': str(e)}), 500

    @app.route('/api/profile', methods=['GET'])
    @login_required
    def get_profile():
        """Get authenticated user's profile information"""
        try:
            user_email = session.get('user_email')
            user = USERS.get(user_email)
            
            if not user:
                return jsonify({'error': 'User not found'}), 404
                
            return jsonify({
                'id': user['id'],
                'name': user['name'],
                'email': user['email'],
                'role': user['role']
            }), 200
            
        except Exception as e:
            return jsonify({'error': 'Failed to fetch profile', 'details': str(e)}), 500

    @app.route('/dashboard')
    def dashboard():
        """Serve the main dashboard page"""
        return render_template('dashboard.html')

    @app.errorhandler(404)
    def not_found(error):
        """Handle 404 errors"""
        return jsonify({'error': 'Endpoint not found'}), 404

    @app.errorhandler(500)
    def internal_error(error):
        """Handle 500 errors"""
        return jsonify({'error': 'Internal server error'}), 500

    return app

def main():
    """Main function to run the Flask application"""
    app = create_app()
    debug_mode = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    app.run(host='0.0.0.0', port=5000, debug=debug_mode)

if __name__ == '__main__':
    main()