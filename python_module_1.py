# Project: Setup Database Schema and Implement Authentication APIs

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
from schemas import Token, UserCreate, UserLogin

load_dotenv()
DB_URL = os.getenv("DB_URL")
SECRET_KEY = "your_secret_key"
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def create_tables():
    # ... (same as in the original main.py from AEP-1)

def insert_sample_data():
    # ... (same as in the original main.py from AEP-1)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: timedelta = None):
    # ... (same as in the original main.py from AEP-2)

def authenticate_user(fake_db, username: str, password: str):
    # ... (same as in the original main.py from AEP-2)

@app.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    # ... (same as in the original main.py from AEP-2)

@app.post("/register")
async def register(user: UserCreate, db: Session = Depends(db.get_db)):
    # ... (same as in the original main.py from AEP-2)

def main():
    create_tables()
    insert_sample_data()

    # Run FastAPI app
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

if __name__ == "__main__":
    main()