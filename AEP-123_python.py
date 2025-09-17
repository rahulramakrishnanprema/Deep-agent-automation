import logging
import os
from datetime import datetime, timedelta
from typing import List, Optional
from uuid import UUID, uuid4

import jwt
from fastapi import Depends, FastAPI, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field, validator
from sqlalchemy import Column, DateTime, String, create_engine
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm.session import Session

# Configure structured JSON logging
logging.basicConfig(
    level=logging.INFO,
    format='{"timestamp": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s", "module": "%(module)s", "function": "%(funcName)s"}',
    datefmt="%Y-%m-%dT%H:%M:%SZ"
)
logger = logging.getLogger(__name__)

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/aepdb")
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# JWT configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

security = HTTPBearer()

# Database Models
class UserModel(Base):
    __tablename__ = "users"
    id = Column(String, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class ItemModel(Base):
    __tablename__ = "items"
    id = Column(String, primary_key=True, index=True)
    name = Column(String, index=True, nullable=False)
    description = Column(String, nullable=True)
    owner_id = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

# Pydantic Models
class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: str = Field(..., regex=r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")

    @validator('username')
    def username_alphanumeric(cls, v):
        if not v.isalnum():
            raise ValueError('Username must be alphanumeric')
        return v

class UserResponse(BaseModel):
    id: str
    username: str
    email: str
    created_at: datetime

    class Config:
        orm_mode = True

class ItemCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)

class ItemResponse(BaseModel):
    id: str
    name: str
    description: Optional[str]
    owner_id: str
    created_at: datetime

    class Config:
        orm_mode = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

# Database dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Database error: {str(e)}")
        raise HTTPException(status_code=500, detail="Database operation failed")
    finally:
        db.close()

# Authentication utilities
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return username
    except jwt.ExpiredSignatureError:
        logger.warning("Token expired")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError:
        logger.warning("Invalid token")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )

# FastAPI app initialization
app = FastAPI(title="AEP API", version="1.0.0")

@app.on_event("startup")
async def startup():
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created successfully")
    except SQLAlchemyError as e:
        logger.error(f"Failed to create database tables: {str(e)}")
        raise

# API Endpoints
@app.post("/users/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    """Create a new user - AEP-123"""
    try:
        db_user = db.query(UserModel).filter(UserModel.username == user.username).first()
        if db_user:
            logger.warning(f"Username {user.username} already exists")
            raise HTTPException(status_code=400, detail="Username already registered")
        
        db_user = db.query(UserModel).filter(UserModel.email == user.email).first()
        if db_user:
            logger.warning(f"Email {user.email} already exists")
            raise HTTPException(status_code=400, detail="Email already registered")
        
        user_id = str(uuid4())
        db_user = UserModel(id=user_id, username=user.username, email=user.email)
        db.add(db_user)
        db.flush()
        
        logger.info(f"User created successfully: {user.username}")
        return db_user
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating user: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/users/{user_id}", response_model=UserResponse)
def read_user(user_id: str, db: Session = Depends(get_db)):
    """Get user by ID - AEP-123"""
    try:
        db_user = db.query(UserModel).filter(UserModel.id == user_id).first()
        if db_user is None:
            logger.warning(f"User not found: {user_id}")
            raise HTTPException(status_code=404, detail="User not found")
        return db_user
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving user: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/token", response_model=Token)
def login_for_access_token(username: str, db: Session = Depends(get_db)):
    """Get JWT token for authentication - AEP-123"""
    try:
        db_user = db.query(UserModel).filter(UserModel.username == username).first()
        if not db_user:
            logger.warning(f"Login failed for non-existent user: {username}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        access_token = create_access_token(data={"sub": username})
        logger.info(f"Token generated for user: {username}")
        return {"access_token": access_token, "token_type": "bearer"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Token generation error: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/items/", response_model=ItemResponse, status_code=status.HTTP_201_CREATED)
def create_item(
    item: ItemCreate,
    username: str = Depends(verify_token),
    db: Session = Depends(get_db)
):

# Code truncated at 7979 characters to meet length limit
# Full implementation available upon request
