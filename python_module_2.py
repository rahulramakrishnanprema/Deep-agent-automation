#!/usr/bin/env python3
'''
python_module_2.py
Integrated module from 2 source files
Part of larger python project - designed for cross-module compatibility
'''

# Imports (add any needed imports here)
import os
import sys
from typing import List, Dict, Any
from flask import Flask, request, jsonify, make_response
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, jwt_required, get_jwt_identity
from flask_migrate import Migrate
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.engine.url import URL

# Constants
DB_URL = "sqlite+aiosqlite:///./user_profiles.db"

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///roles.db'
app.config['JWT_SECRET_KEY'] = 'your-secret-key'

db = SQLAlchemy(app)
jwt = JWTManager(app)
migrate = Migrate(app, db)

Base = declarative_base()

# Modified from main.py - AEP-3 - Role-Based Access Control (RBAC)
roles_table = db.Table('roles',
    db.Column('user_id', db.Integer, db.ForeignKey('user.id'), primary_key=True),
    db.Column('role_id', db.Integer, db.ForeignKey('role.id'), primary_key=True)
)

roles = db.Table('roles',
    db.Column('role_id', db.Integer, primary_key=True),
    db.Column('name', db.String(50), unique=True)
)

users = db.Table('users',
    db.Column('id', db.Integer, primary_key=True),
    db.Column('username', db.String(80), unique=True),
    db.Column('password', db.String(120)),
    db.Column('active', db.Boolean(), default=True)
)

roles_users = db.Table('roles_users',
    db.Column('user_id', db.Integer, db.ForeignKey('users.id'), primary_key=True),
    db.Column('role_id', db.Integer, db.ForeignKey('roles.id'), primary_key=True)
)

class Role(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True)
    users = db.relationship('User', secondary=roles_users, backref=db.backref('roles', lazy='dynamic'))

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True)
    password = db.Column(db.String(120))
    active = db.Column(db.Boolean(), default=True)
    roles = db.relationship('Role', secondary=roles, backref=db.backref('users', lazy='dynamic'))

@jwt.token_in_blocklist_loader
def check_if_token_in_blacklist(jwt_header, jwt_payload):
    jti = jwt_payload["jti"]
    return jti in current_app.config["JWT_BLACKLISTED_TOKENS"]

@jwt.user_identity_loader
def user_identity_lookup(user):
    return user.id

@jwt.user_lookup_loader
def user_lookup_callback(jwt_header, jwt_payload):
    user_id = int(jwt_payload["identity"])
    return User.query.get(user_id)

@jwt.user_identity_loader
def user_identity_lookup(user):
    return user.id

@jwt.user_lookup_loader
def user_lookup_callback(jwt_header, jwt_payload):
    user_id = int(jwt_payload["identity"])
    return User.query.get(user_id)

@app.before_request
def before_request():
    if not current_user.is_authenticated:
        return jsonify({"error": "Unauthorized"}), 401

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    if not data or not data['username'] or not data['password']:
        return jsonify({"error": "Invalid data"}), 400

    user = User.query.filter_by(username=data['username']).first()
    if user is not None:
        return jsonify({"error": "Username already exists"}), 400

    new_user = User(username=data['username'], password=data['password'])
    db.session.add(new_user)
    db.session.commit()

    return jsonify({"message": "User created"}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if not data or not data['username'] or not data['password']:
        return jsonify({"error": "Invalid data"}), 400

    user = User.query.filter_by(username=data['username']).first()
    if user is None or not user.password == data['password']:
        return jsonify({"error": "Invalid credentials"}), 401

    access_token = create_access_token(identity=user.id)
    return jsonify({"access_token": access_token}), 200

# Modified from main.py - AEP-4 - Basic User Profile API
engine = create_engine(DB_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

class UserProfile(Base):
    __tablename__ = "user_profiles"

    id = column(Integer, primary_key=True, index=True)
    name = column(String, index=True)
    email = column(String, unique=True, index=True)
    role = column(String)

@app.get("/profile", response_model=UserProfileResponse)
def read_user_profile():
    db = SessionLocal()
    user = db.query(UserProfile).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "role": user.role
    }

@app.on_event("startup")
def setup_db():
    Base.metadata.create_all(bind=engine)

@app.on_event("shutdown")
def shutdown_db():
    db = SessionLocal()
    db.close()

class UserProfileResponse(BaseModel):
    id: Optional[int] = None
    name: str
    email: str
    role: Optional[str] = None

def main():
    '''Main function callable from main runner'''
    from sqlalchemy import create_engine, reflect

    # Initialize the Flask app
    app.run(debug=True)

    # Create a SQLAlchemy engine for the user_profiles database
    user_profiles_engine = create_engine(DB_URL)

    # Reflect the UserProfile table from the user_profiles database
    Base.metadata.reflect(bind=user_profiles_engine)

if __name__ == "__main__":
    main()