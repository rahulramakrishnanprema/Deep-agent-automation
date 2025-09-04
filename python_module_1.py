import os
from datetime import datetime, timedelta
from typing import Optional
from functools import wraps

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from dotenv import load_dotenv

load_dotenv()

# Database setup
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./test.db")
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Models
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    role = Column(String)
    password = Column(String)

# Pydantic models
class UserProfileResponse(BaseModel):
    name: str
    email: str
    role: str

    class Config:
        orm_mode = True

class UserRegister(BaseModel):
    username: str
    email: str
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class TokenRefresh(BaseModel):
    refresh_token: str

# Database dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# FastAPI app setup
fastapi_app = FastAPI(title="User Profile API", version="1.0.0")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Flask app setup
flask_app = Flask(__name__)
CORS(flask_app, supports_credentials=True)
flask_app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'your-secret-key-here')
flask_app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=1)
flask_app.config['JWT_REFRESH_TOKEN_EXPIRES'] = timedelta(days=7)

# Authentication utilities
def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == token).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        
        try:
            data = jwt.decode(token, flask_app.config['SECRET_KEY'], algorithms=['HS256'])
            db = next(get_db())
            current_user = db.query(User).filter(User.id == data['user_id']).first()
            
            if not current_user:
                return jsonify({'error': 'Invalid token'}), 401
                
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(current_user, *args, **kwargs)
    
    return decorated

# FastAPI routes
@fastapi_app.get("/api/user/profile", response_model=UserProfileResponse)
def get_user_profile(current_user: User = Depends(get_current_user)):
    try:
        return UserProfileResponse.from_orm(current_user)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error retrieving user profile"
        )

@fastapi_app.on_event("startup")
def startup_event():
    Base.metadata.create_all(bind=engine)

# Flask routes
@flask_app.route('/api/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        
        if not data or not data.get('username') or not data.get('password') or not data.get('email'):
            return jsonify({'error': 'Username, email and password are required'}), 400
        
        username = data['username'].strip()
        email = data['email'].strip().lower()
        password = data['password']
        
        if len(password) < 6:
            return jsonify({'error': 'Password must be at least 6 characters'}), 400
        
        db = next(get_db())
        
        # Check if user already exists
        existing_user = db.query(User).filter(
            (User.username == username) | (User.email == email)
        ).first()
        
        if existing_user:
            return jsonify({'error': 'Username or email already exists'}), 409
        
        # Create new user
        hashed_password = generate_password_hash(password)
        new_user = User(
            username=username,
            email=email,
            password=hashed_password,
            name=username,
            role="user"
        )
        db.add(new_user)
        db.commit()
        
        return jsonify({'message': 'User registered successfully'}), 201
        
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500

@flask_app.route('/api/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        
        if not data or not data.get('username') or not data.get('password'):
            return jsonify({'error': 'Username and password are required'}), 400
        
        username = data['username'].strip()
        password = data['password']
        
        db = next(get_db())
        user = db.query(User).filter(
            (User.username == username) | (User.email == username)
        ).first()
        
        if not user or not check_password_hash(user.password, password):
            return jsonify({'error': 'Invalid username or password'}), 401
        
        # Generate tokens
        access_token = jwt.encode({
            'user_id': user.id,
            'exp': datetime.utcnow() + flask_app.config['JWT_ACCESS_TOKEN_EXPIRES']
        }, flask_app.config['SECRET_KEY'])
        
        refresh_token = jwt.encode({
            'user_id': user.id,
            'exp': datetime.utcnow() + flask_app.config['JWT_REFRESH_TOKEN_EXPIRES']
        }, flask_app.config['SECRET_KEY'])
        
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
        return jsonify({'error': 'Internal server error'}), 500

@flask_app.route('/api/refresh', methods=['POST'])
def refresh_token():
    try:
        data = request.get_json()
        
        if not data or not data.get('refresh_token'):
            return jsonify({'error': 'Refresh token is required'}), 400
        
        refresh_token = data['refresh_token']
        
        try:
            payload = jwt.decode(refresh_token, flask_app.config['SECRET_KEY'], algorithms=['HS256'])
            user_id = payload['user_id']
            
            db = next(get_db())
            user = db.query(User).filter(User.id == user_id).first()
            
            if not user:
                return jsonify({'error': 'Invalid refresh token'}), 401
            
            # Generate new access token
            access_token = jwt.encode({
                'user_id': user.id,
                'exp': datetime.utcnow() + flask_app.config['JWT_ACCESS_TOKEN_EXPIRES']
            }, flask_app.config['SECRET_KEY'])
            
            return jsonify({
                'access_token': access_token,
                'user': {
                    'id': user.id,
                    'username': user.username,
                    'email': user.email
                }
            }), 200
            
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Refresh token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid refresh token'}), 401
            
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500

@flask_app.route('/api/profile', methods=['GET'])
@token_required
def get_profile(current_user):
    return jsonify({
        'user': {
            'id': current_user.id,
            'username': current_user.username,
            'email': current_user.email
        }
    }), 200

@flask_app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'}), 200

@flask_app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@flask_app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

def main():
    """Main function to run both FastAPI and Flask applications"""
    import threading
    import uvicorn
    
    # Start FastAPI server in a separate thread
    def run_fastapi():
        uvicorn.run(fastapi_app, host="0.0.0.0", port=8000)
    
    fastapi_thread = threading.Thread(target=run_fastapi)
    fastapi_thread.daemon = True
    fastapi_thread.start()
    
    # Start Flask server in the main thread
    port = int(os.environ.get('PORT', 5000))
    flask_app.run(host='0.0.0.0', port=port, debug=os.environ.get('FLASK_DEBUG', 'False').lower() == 'true')

if __name__ == '__main__':
    Base.metadata.create_all(bind=engine)
    main()