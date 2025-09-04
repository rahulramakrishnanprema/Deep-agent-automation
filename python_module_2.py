"""
Role-Based Access Control (RBAC) and Basic User Profile API
"""

from flask import Flask, request, jsonify, make_response
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, jwt_required, get_jwt_identity
from flask_migrate import Migrate
from fastapi import FastAPI, HTTPException, Depends
from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

import os
from datetime import timedelta

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///rbac.db'
app.config['JWT_SECRET_KEY'] = 'your-secret-key'
app.config['JWT_TOKEN_EXPIRATION_MINUTES'] = 300

db = SQLAlchemy(app)
jwt = JWTManager(app)
migrate = Migrate(app, db)

Base = declarative_base()
engine = create_engine(app.config['SQLALCHEMY_DATABASE_URI'])
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

roles = db.Table(
    'roles',
    db.Column('user_id', db.Integer, db.ForeignKey('user.id'), primary_key=True),
    db.Column('role_id', db.Integer, db.ForeignKey('role.id'), primary_key=True)
)

users = db.Table(
    'users',
    db.Column('id', db.Integer, primary_key=True),
    db.Column('username', db.String(80), unique=True, nullable=False),
    db.Column('password', db.String(120), nullable=False)
)

roles_users = db.Table(
    'roles_users',
    db.Column('role_id', db.Integer, db.ForeignKey('role.id'), primary_key=True),
    db.Column('user_id', db.Integer, db.ForeignKey('user.id'), primary_key=True)
)

roles = db.Table(
    'roles',
    db.Column('id', db.Integer, primary_key=True),
    db.Column('name', db.String(50), unique=True, nullable=False)
)

class Role(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), nullable=False)
    users = db.relationship('User', secondary=roles, backref=db.backref('roles', lazy=True))

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)
    roles = db.relationship('Role', secondary=roles_users, backref=db.backref('users', lazy=True))

@jwt.token_in_blocklist_loader
def check_if_token_in_blacklist(jwt_header, jwt_data):
    jti = jwt_data['jti']
    return jti in get_blacklisted_jwt()

@app.before_first_request
def setup_db():
    db.create_all()

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    if not data or not data.get('username') or not data.get('password'):
        return make_response(jsonify({'error': 'Invalid data'}), 400)

    user = User.query.filter_by(username=data['username']).first()
    if user:
        return make_response(jsonify({'error': 'User already exists'}), 400)

    new_user = User(username=data['username'], password=data['password'])
    db.session.add(new_user)
    db.session.commit()

    return make_response(jsonify({'message': 'User created'}), 201)

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if not data or not data.get('username') or not data.get('password'):
        return make_response(jsonify({'error': 'Invalid data'}), 400)

    user = User.query.filter_by(username=data['username']).first()
    if user and user.password == data['password']:
        access_token = create_access_token(identity=user.id)
        return jsonify(access_token=access_token)

    return make_response(jsonify({'error': 'Invalid credentials'}), 401)

@jwt.token_loaded_handler
def handle_token_loaded(token):
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    return user

def create_access_token(identity):
    to_encode = {
        'sub': str(identity),
        'exp': int(time.time()) + app.config['JWT_TOKEN_EXPIRATION_MINUTES'] * 60
    }
    return jwt.encode(to_encode)

def get_blacklisted_jwt():
    return set(jwt_data['jti'] for jwt_data in jwt_manager.blacklisted_tokens)

Base.metadata.create_all(bind=engine)

class UserInDB(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    role = Column(String, index=True)

    items = relationship("Item", back_populates="user")

app.include_router(FastAPIRouter())

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/profile", response_model=UserOut)
def read_user_profile(db: Session = Depends(get_db), user_id: Optional[int] = None):
    if not user_id:
        user_id = int(os.getenv("USER_ID"))

    user = db.query(UserInDB).filter(UserInDB.id == user_id).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return user

@app.post("/profile", response_model=UserOut)
def create_user_profile(user: UserCreate, db: Session = Depends(get_db)):
    new_user = UserInDB(**user.dict())
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

if __name__ == '__main__':
    main()