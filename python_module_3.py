import os
import logging
from logging.handlers import RotatingFileHandler
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
import datetime
from functools import wraps

# Initialize Flask app
app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'your-secret-key-here')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///rbac.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize database
db = SQLAlchemy(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
handler = RotatingFileHandler('app.log', maxBytes=10000, backupCount=3)
handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
app.logger.addHandler(handler)

# Database Models
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)
    role_id = db.Column(db.Integer, db.ForeignKey('roles.id'), nullable=False)
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'role_id': self.role_id
        }

class Role(db.Model):
    __tablename__ = 'roles'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), unique=True, nullable=False)
    permissions = db.Column(db.String(255), nullable=False)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'permissions': self.permissions.split(',')
        }

# Authentication and Authorization Decorators
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        
        try:
            if token.startswith('Bearer '):
                token = token[7:]
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = User.query.get(data['user_id'])
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        except Exception as e:
            app.logger.error(f"Token validation error: {str(e)}")
            return jsonify({'error': 'Token validation failed'}), 401
        
        return f(current_user, *args, **kwargs)
    return decorated

def role_required(required_permission):
    def decorator(f):
        @wraps(f)
        @token_required
        def decorated(current_user, *args, **kwargs):
            role = Role.query.get(current_user.role_id)
            if not role:
                return jsonify({'error': 'User role not found'}), 403
            
            permissions = role.permissions.split(',')
            if required_permission not in permissions:
                app.logger.warning(f"User {current_user.username} attempted to access {required_permission} without permission")
                return jsonify({'error': 'Insufficient permissions'}), 403
            
            return f(current_user, *args, **kwargs)
        return decorated
    return decorator

# Routes
@app.route('/api/auth/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        
        if not data or not data.get('username') or not data.get('email') or not data.get('password'):
            return jsonify({'error': 'Missing required fields'}), 400
        
        if User.query.filter_by(username=data['username']).first():
            return jsonify({'error': 'Username already exists'}), 409
        
        if User.query.filter_by(email=data['email']).first():
            return jsonify({'error': 'Email already exists'}), 409
        
        # Default role is employee
        default_role = Role.query.filter_by(name='employee').first()
        if not default_role:
            return jsonify({'error': 'Default role not found'}), 500
        
        user = User(
            username=data['username'],
            email=data['email'],
            role_id=default_role.id
        )
        user.set_password(data['password'])
        
        db.session.add(user)
        db.session.commit()
        
        app.logger.info(f"New user registered: {user.username}")
        return jsonify({'message': 'User created successfully', 'user': user.to_dict()}), 201
        
    except Exception as e:
        db.session.rollback()
        app.logger.error(f"Registration error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        
        if not data or not data.get('username') or not data.get('password'):
            return jsonify({'error': 'Missing username or password'}), 400
        
        user = User.query.filter_by(username=data['username']).first()
        
        if not user or not user.check_password(data['password']):
            return jsonify({'error': 'Invalid credentials'}), 401
        
        token = jwt.encode({
            'user_id': user.id,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
        }, app.config['SECRET_KEY'], algorithm='HS256')
        
        app.logger.info(f"User logged in: {user.username}")
        return jsonify({
            'token': token,
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        app.logger.error(f"Login error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/employee/dashboard', methods=['GET'])
@role_required('view_employee_dashboard')
def employee_dashboard(current_user):
    return jsonify({
        'message': 'Welcome to Employee Dashboard',
        'data': 'Employee-specific data here'
    }), 200

@app.route('/api/manager/dashboard', methods=['GET'])
@role_required('view_manager_dashboard')
def manager_dashboard(current_user):
    return jsonify({
        'message': 'Welcome to Manager Dashboard',
        'data': 'Manager-specific data here'
    }), 200

@app.route('/api/admin/dashboard', methods=['GET'])
@role_required('view_admin_dashboard')
def admin_dashboard(current_user):
    return jsonify({
        'message': 'Welcome to Admin Dashboard',
        'data': 'Admin-specific data here'
    }), 200

@app.route('/api/admin/users', methods=['GET'])
@role_required('manage_users')
def list_users(current_user):
    try:
        users = User.query.all()
        return jsonify({
            'users': [user.to_dict() for user in users]
        }), 200
    except Exception as e:
        app.logger.error(f"List users error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'}), 200

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    app.logger.error(f"Internal server error: {str(error)}")
    return jsonify({'error': 'Internal server error'}), 500

# Initialize database and create default roles
def init_db():
    with app.app_context():
        db.create_all()
        
        # Create default roles if they don't exist
        default_roles = [
            {'name': 'employee', 'permissions': 'view_employee_dashboard'},
            {'name': 'manager', 'permissions': 'view_employee_dashboard,view_manager_dashboard'},
            {'name': 'admin', 'permissions': 'view_employee_dashboard,view_manager_dashboard,view_admin_dashboard,manage_users'}
        ]
        
        for role_data in default_roles:
            if not Role.query.filter_by(name=role_data['name']).first():
                role = Role(name=role_data['name'], permissions=role_data['permissions'])
                db.session.add(role)
        
        db.session.commit()
        app.logger.info("Database initialized with default roles")

def main():
    """Main function to initialize and run the RBAC Flask application"""
    init_db()
    port = int(os.environ.get('PORT', 5000))
    debug_mode = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug_mode)

if __name__ == '__main__':
    main()