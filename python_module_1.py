# python_module_1.py

import os
import psycopg2
from psycopg2 import sql
from dotenv import load_dotenv
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime, timedelta
from models import User, db
from schemas import TokenData, UserCreate, UserLogin

load_dotenv()
DB_URL = os.getenv("DB_URL")
SECRET_KEY = "your-secret-key"
ALGORITHM = "HS256"

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def create_db_tables():
    conn = psycopg2.connect(DB_URL)
    cursor = conn.cursor()

    create_users_table_query = """
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role VARCHAR(255) NOT NULL
    );
    """
    cursor.execute(create_users_table_query)

    create_roles_table_query = """
    CREATE TABLE IF NOT EXISTS roles (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) UNIQUE NOT NULL
    );
    """
    cursor.execute(create_roles_table_query)

    create_training_needs_table_query = """
    CREATE TABLE IF NOT EXISTS training_needs (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        skill_id INTEGER REFERENCES skills(id),
        status VARCHAR(255) NOT NULL
    );
    """
    cursor.execute(create_training_needs_table_query)

    create_courses_table_query = """
    CREATE TABLE IF NOT EXISTS courses (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) UNIQUE NOT NULL,
        description TEXT,
        skill_id INTEGER REFERENCES skills(id)
    );
    """
    cursor.execute(create_courses_table_query)

    create_skills_table_query = """
    CREATE TABLE IF NOT EXISTS skills (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) UNIQUE NOT NULL
    );
    """
    cursor.execute(create_skills_table_query)

    create_roles_table_query = """
    INSERT INTO roles (name) VALUES
        ('admin'),
        ('user');
    """
    cursor.execute(create_roles_table_query)

    conn.commit()
    conn.close()

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def authenticate_user(db, username: str, password: str):
    user = db.query(User).filter(User.username == username).first()
    if not user or not verify_password(password, user.password):
        return False
    return user

def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def register(user: UserCreate, db: Session = Depends(db.get_db)):
    hashed_password = get_password_hash(user.password)
    user.password = hashed_password
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(db.get_db)):
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=30)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

def main():
    create_db_tables()
    app = FastAPI()
    app.post("/register", response_model=User, dependencies=[db])(register)
    app.post("/login", response_model=TokenData)(login)

if __name__ == "__main__":
    main()