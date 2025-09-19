# Issue: AEP-201
# Generated: 2025-09-19T15:19:38.448532
# Thread: 302f2370
# Enhanced: LangChain structured generation
# AI Model: deepseek/deepseek-chat-v3.1:free
# Max Length: 25000 characters

import os
import re
import logging
import datetime
import secrets
import string
from typing import Optional, Dict, Any, Tuple
from functools import wraps

import jwt
import bcrypt
import redis
from pydantic import BaseModel, EmailStr, validator, constr
from fastapi import FastAPI, HTTPException, Depends, status, Request, Header
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Boolean, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.exc import SQLAlchemyError, IntegrityError
from jose import JWTError
from redis.exceptions import RedisError
from email_validator import validate_email, EmailNotValidError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./aep.db")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
SECRET_KEY = os.getenv("SECRET_KEY", secrets.token_urlsafe(32))
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))
EMAIL_VERIFICATION_EXPIRE_HOURS = int(os.getenv("EMAIL_VERIFICATION_EXPIRE_HOURS", "24"))
PASSWORD_RESET_EXPIRE_MINUTES = int(os.getenv("PASSWORD_RESET_EXPIRE_MINUTES", "30"))

# Database setup
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Redis setup
redis_client = redis.Redis.from_url(REDIS_URL, decode_responses=True)

# FastAPI app
app = FastAPI(title="AEP Authentication Service", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

# Password validation
def validate_password_strength(password: str) -> bool:
    if len(password) < 8:
        return False
    if not re.search(r"[A-Z]", password):
        return False
    if not re.search(r"[a-z]", password):
        return False
    if not re.search(r"[0-9]", password):
        return False
    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        return False
    return True

# Database models
class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String, nullable=False)
    is_active = Column(Boolean, default=False)
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

class UserSession(Base):
    __tablename__ = "user_sessions"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    token = Column(String, unique=True, index=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

# Pydantic models
class UserBase(BaseModel):
    email: EmailStr
    full_name: constr(min_length=1, max_length=100)

class UserCreate(UserBase):
    password: str
    
    @validator('password')
    def password_strength(cls, v):
        if not validate_password_strength(v):
            raise ValueError('Password must be at least 8 characters long and contain uppercase, lowercase, numbers, and special characters')
        return v

class UserResponse(UserBase):
    id: int
    is_active: bool
    is_verified: bool
    created_at: datetime.datetime
    
    class Config:
        orm_mode = True

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str

class TokenData(BaseModel):
    user_id: Optional[int] = None

class PasswordResetRequest(BaseModel):
    email: EmailStr

class PasswordReset(BaseModel):
    token: str
    new_password: str
    
    @validator('new_password')
    def password_strength(cls, v):
        if not validate_password_strength(v):
            raise ValueError('Password must be at least 8 characters long and contain uppercase, lowercase, numbers, and special characters')
        return v

class EmailVerificationRequest(BaseModel):
    token: str

# Database dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Redis dependency
def get_redis():
    return redis_client

# Utility functions
def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def create_tokens(user_id: int, db: Session, redis_client: redis.Redis) -> Tuple[str, str]:
    access_token_expires = datetime.datetime.utcnow() + datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    refresh_token_expires = datetime.datetime.utcnow() + datetime.timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    
    access_payload = {"sub": str(user_id), "type": "access", "exp": access_token_expires}
    refresh_payload = {"sub": str(user_id), "type": "refresh", "exp": refresh_token_expires}
    
    access_token = jwt.encode(access_payload, SECRET_KEY, algorithm=ALGORITHM)
    refresh_token = jwt.encode(refresh_payload, SECRET_KEY, algorithm=ALGORITHM)
    
    # Store refresh token in database
    session = UserSession(user_id=user_id, token=refresh_token, expires_at=refresh_token_expires)
    db.add(session)
    db.commit()
    
    # Store refresh token in Redis for quick validation
    redis_client.setex(f"refresh_token:{refresh_token}", REFRESH_TOKEN_EXPIRE_DAYS * 86400, user_id)
    
    return access_token, refresh_token

def verify_token(token: str, token_type: str = "access") -> Optional[int]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != token_type:
            return None
        user_id = int(payload.get("sub"))
        return user_id
    except (JWTError, ValueError):
        return None

def generate_random_token(length: int = 32) -> str:
    return ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(length))

# Authentication dependencies
async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    user_id = verify_token(token, "access")
    if user_id is None:
        raise credentials_exception
    
    user = db.query(User).filter(User.id == user_id, User.is_active == True).first()
    if user is None:
        raise credentials_exception
    
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

# Rate limiting decorator
def rate_limit(requests_per_minute: int = 10):
    def decorator(func):
        @wraps(func)
        async def wrapper(request: Request, *args, **kwargs):
            client_ip = request.client.host
            key = f"rate_limit:{func.__name__}:{client_ip}"
            
            current = int(redis_client.get(key) or 0)
            if current >= requests_per_minute:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Rate limit exceeded"
                )
            
            redis_client.incr(key)
            redis_client.expire(key, 60)
            
            return await func(request, *args, **kwargs)
        return wrapper
    return decorator

# API endpoints
@app.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
@rate_limit(requests_per_minute=5)
async def register(user: UserCreate, db: Session = Depends(get_db), redis_client: redis.Redis = Depends(get_redis)):
    try:
        # Check if user already exists
        existing_user = db.query(User).filter(User.email == user.email).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User with this email already exists"
            )
        
        # Create new user
        hashed_password = hash_password(user.password)
        db_user = User(
            email=user.email,
            hashed_password=hashed_password,
            full_name=user.full_name
        )
        
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        
        # Generate email verification token
        verification_token = generate_random_token()
        redis_key = f"email_verify:{verification_token}"
        redis_client.setex(redis_key, EMAIL_VERIFICATION_EXPIRE_HOURS * 3600, db_user.id)
        
        # In production, send email with verification link
        logger.info(f"Email verification token for {user.email}: {verification_token}")
        
        return db_user
        
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists"
        )
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Database error during registration: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@app.post("/login", response_model=Token)
@rate_limit(requests_per_minute=5)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db), redis_client: redis.Redis = Depends(get_redis)):
    user = db.query(User).filter(User.email == form_data.username, User.is_active == True).first()
    
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email not verified",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token, refresh_token = create_tokens(user.id, db, redis_client)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }

@app.post("/refresh", response_model=Token)
async def refresh_token(refresh_token: str = Header(...), db: Session = Depends(get_db), redis_client: redis.Redis = Depends(get_redis)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate refresh token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    # Check Redis for valid refresh token
    user_id = redis_client.get(f"refresh_token:{refresh_token}")
    if not user_id:
        raise credentials_exception
    
    user_id = int(user_id)
    user = db.query(User).filter(User.id == user_id, User.is_active == True).first()
    if not user:
        raise credentials_exception
    
    # Verify JWT token
    if verify_token(refresh_token, "refresh") != user_id:
        raise credentials_exception
    
    # Remove old refresh token
    redis_client.delete(f"refresh_token:{refresh_token}")
    db.query(UserSession).filter(UserSession.token == refresh_token).delete()
    db.commit()
    
    # Create new tokens
    access_token, new_refresh_token = create_tokens(user.id, db, redis_client)
    
    return {
        "access_token": access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer"
    }

@app.post("/logout")
async def logout(refresh_token: str = Header(...), db: Session = Depends(get_db), redis_client: redis.Redis = Depends(get_redis)):
    # Remove refresh token from Redis and database
    redis_client.delete(f"refresh_token:{refresh_token}")
    db.query(UserSession).filter(UserSession.token == refresh_token).delete()
    db.commit()
    
    return {"message": "Successfully logged out"}

@app.post("/verify-email")
async def verify_email(request: EmailVerificationRequest, db: Session = Depends(get_db), redis_client: redis.Redis = Depends(get_redis)):
    redis_key = f"email_verify:{request.token}"
    user_id = redis_client.get(redis_key)
    
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification token"
        )
    
    user_id = int(user_id)
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User not found"
        )
    
    if user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already verified"
        )
    
    user.is_verified = True
    db.commit()
    
    redis_client.delete(redis_key)
    
    return {"message": "Email successfully verified"}

@app.post("/request-password-reset")
@rate_limit(requests_per_minute=3)
async def request_password_reset(request: PasswordResetRequest, db: Session = Depends(get_db), redis_client: redis.Redis = Depends(get_redis)):
    user = db.query(User).filter(User.email == request.email, User.is_active == True).first()
    
    if user:
        # Generate password reset token
        reset_token = generate_random_token()
        redis_key = f"password_reset:{reset_token}"
        redis_client.setex(redis_key, PASSWORD_RESET_EXPIRE_MINUTES * 60, user.id)
        
        # In production, send email with reset link
        logger.info(f"Password reset token for {request.email}: {reset_token}")
    
    return {"message": "If the email exists, a password reset link has been sent"}

@app.post("/reset-password")
async def reset_password(request: PasswordReset, db: Session = Depends(get_db), redis_client: redis.Redis = Depends(get_redis)):
    redis_key = f"password_reset:{request.token}"
    user_id = redis_client.get(redis_key)
    
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token"
        )
    
    user_id = int(user_id)
    user = db.query(User).filter(User.id == user_id, User.is_active == True).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User not found"
        )
    
    # Update password
    user.hashed_password = hash_password(request.new_password)
    db.commit()
    
    # Remove all active sessions
    db.query(UserSession).filter(UserSession.user_id == user_id).delete()
    db.commit()
    
    # Clean up Redis keys
    redis_client.delete(redis_key)
    for key in redis_client.scan_iter(f"refresh_token:*"):
        if redis_client.get(key) == user_id:
            redis_client.delete(key)
    
    return {"message": "Password successfully reset"}

@app.get("/me", response_model=UserResponse)
async def read_users_me(current_user: User = Depends(get_current_active_user)):
    return current_user

@app.put("/me", response_model=UserResponse)
async def update_user_profile(update_data: UserBase, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    current_user.full_name = update_data.full_name
    current_user.email = update_data.email
    
    try:
        db.commit()
        db.refresh(current_user)
        return current_user
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already in use"
        )

# Health check endpoint
@app.get("/health")
async def health_check(db: Session = Depends(get_db), redis_client: redis.Redis = Depends(get_redis)):
    try:
        # Check database connection
        db.execute("SELECT 1")
        
        # Check Redis connection
        redis_client.ping()
        
        return {"status": "healthy", "database": "connected", "redis": "connected"}
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service unavailable"
        )

# Create database tables
@app.on_event("startup")
async def startup_event():
    Base.metadata.create_all(bind=engine)
    
    # Test Redis connection
    try:
        redis_client.ping()
        logger.info("Redis connection established")
    except RedisError as e:
        logger.error(f"Redis connection failed: {str(e)}")
        raise

# Cleanup expired tokens
@app.on_event("startup")
async def schedule_cleanup():
    async def cleanup_task():
        while True:
            try:
                # Clean expired database sessions
                db = SessionLocal()
                db.query(UserSession).filter(UserSession.expires_at < datetime.datetime.utcnow()).delete()
                db.commit()
                db.close()
                
                # Clean expired Redis tokens
                for key in redis_client.scan_iter("email_verify:*"):
                    if redis_client.ttl(key) == -2:
                        redis_client.delete(key)
                
                for key in redis_client.scan_iter("password_reset:*"):
                    if redis_client.ttl(key) == -2:
                        redis_client.delete(key)
                
                await asyncio.sleep(3600)  # Run every hour
            except Exception as e:
                logger.error(f"Cleanup task failed: {str(e)}")
                await asyncio.sleep(300)  # Retry after 5 minutes
    
    asyncio.create_task(cleanup_task())

# Import asyncio for cleanup task
import asyncio