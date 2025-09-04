"""Role-Based Access Control (RBAC) using FastAPI and SQLAlchemy"""

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import List
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey
from sqlalchemy.orm import sessionmaker, relationship
from sqlalchemy.ext.declarative import declarative_base
from passlib.hash import bcrypt

# Database models
Base = declarative_base()

class Role(Base):
    __tablename__ = 'roles'
    id = Column(Integer, primary_key=True)
    name = Column(String(30), unique=True)

class User(Base):
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True)
    username = Column(String(30), unique=True, index=True)
    password = Column(String(128))
    role_id = Column(Integer, ForeignKey('roles.id'))
    role = relationship("Role")

DATABASE_URL = "sqlite:///./app.db"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

app = FastAPI()
security = OAuth2PasswordBearer(tokenUrl="token")

def verify_password(plain_password, hashed_password):
    return bcrypt.verify(plain_password, hashed_password)

def get_hashed_password(plain_password):
    return bcrypt.hash(plain_password)

def authenticate_user(username: str, password: str):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        return False
    if not verify_password(password, user.password):
        return False
    return user

async def get_current_user(token: str = Depends(oauth2_scheme)):
    user = authenticate_user(token.username, token.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user

@app.post("/token")
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        return {"access_token": "", "token_type": ""}
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.id}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

# ... (Add your endpoints here with proper role checks using get_current_user())

if __name__ == "__main__":
    main()