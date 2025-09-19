# Issue: AEP-201
# Generated: 2025-09-19T15:13:43.187854
# Thread: 70190300
# Enhanced: LangChain structured generation
# AI Model: deepseek/deepseek-chat-v3.1:free
# Max Length: 25000 characters

import os
import re
import logging
import secrets
import string
import time
import jwt
import bcrypt
import redis
import smtplib
from email.mime.text import MIMEText
from datetime import datetime, timedelta, timezone
from functools import wraps
from typing import Optional, Dict, Any, Tuple, List
from pydantic import BaseModel, EmailStr, validator, constr
from fastapi import FastAPI, HTTPException, Depends, status, Request, BackgroundTasks
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Boolean, DateTime, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.exc import SQLAlchemyError, IntegrityError
from contextlib import contextmanager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost/aep_db")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", secrets.token_urlsafe(32))
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))
SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USERNAME = os.getenv("SMTP_USERNAME", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:3000")

# Database setup
engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_size=20, max_overflow=10)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Redis setup for token blacklisting and rate limiting
redis_client = redis.from_url(REDIS_URL, decode_responses=True)

# FastAPI app
app = FastAPI(title="AEP Authentication Service", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[FRONTEND_URL],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security scheme
security = HTTPBearer()

# Password validation regex
PASSWORD_REGEX = re.compile(r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$")

# Database models
class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    token = Column(String(100), unique=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class RefreshToken(Base):
    __tablename__ = "refresh_tokens"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    token = Column(String(255), unique=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    revoked = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

# Pydantic models
class UserBase(BaseModel):
    email: EmailStr
    first_name: constr(min_length=1, max_length=100)
    last_name: constr(min_length=1, max_length=100)

class UserCreate(UserBase):
    password: constr(min_length=8)
    
    @validator('password')
    def validate_password(cls, v):
        if not PASSWORD_REGEX.match(v):
            raise ValueError('Password must be at least 8 characters long and contain at least one uppercase letter, one lowercase letter, one number, and one special character')
        return v

class UserResponse(UserBase):
    id: int
    is_active: bool
    is_verified: bool
    created_at: datetime
    
    class Config:
        orm_mode = True

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class PasswordResetRequest(BaseModel):
    email: EmailStr

class PasswordResetConfirm(BaseModel):
    token: str
    new_password: constr(min_length=8)
    
    @validator('new_password')
    def validate_password(cls, v):
        if not PASSWORD_REGEX.match(v):
            raise ValueError('Password must be at least 8 characters long and contain at least one uppercase letter, one lowercase letter, one number, and one special character')
        return v

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: constr(min_length=8)
    
    @validator('new_password')
    def validate_password(cls, v):
        if not PASSWORD_REGEX.match(v):
            raise ValueError('Password must be at least 8 characters long and contain at least one uppercase letter, one lowercase letter, one number, and one special character')
        return v

# Database dependency
@contextmanager
def get_db():
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception as e:
        db.rollback()
        raise e
    finally:
        db.close()

# Utility functions
def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def generate_reset_token() -> str:
    return secrets.token_urlsafe(32)

def generate_jwt_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)

def decode_jwt_token(token: str) -> Dict[str, Any]:
    try:
        return jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
    except jwt.PyJWTError as e:
        logger.error(f"JWT decoding error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )

def create_access_token(user_id: int) -> str:
    expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return generate_jwt_token({"sub": str(user_id), "type": "access"}, expires)

def create_refresh_token(user_id: int) -> Tuple[str, datetime]:
    expires_delta = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    expires = datetime.now(timezone.utc) + expires_delta
    token = generate_jwt_token({"sub": str(user_id), "type": "refresh"}, expires_delta)
    return token, expires

def is_token_blacklisted(token: str) -> bool:
    return redis_client.exists(f"blacklist:{token}") > 0

def blacklist_token(token: str, expires_at: datetime) -> None:
    expires_in = expires_at - datetime.now(timezone.utc)
    redis_client.setex(f"blacklist:{token}", int(expires_in.total_seconds()), "1")

def check_rate_limit(key: str, limit: int, period: int) -> bool:
    current = int(time.time())
    window = current // period
    redis_key = f"ratelimit:{key}:{window}"
    count = redis_client.incr(redis_key)
    redis_client.expire(redis_key, period * 2)
    return count <= limit

def send_email(to_email: str, subject: str, body: str) -> None:
    try:
        msg = MIMEText(body)
        msg['Subject'] = subject
        msg['From'] = SMTP_USERNAME
        msg['To'] = to_email
        
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)
    except Exception as e:
        logger.error(f"Failed to send email: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send email"
        )

# Authentication dependencies
def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security), db: Session = Depends(get_db)) -> User:
    token = credentials.credentials
    if is_token_blacklisted(token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    try:
        payload = decode_jwt_token(token)
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")
        
        if user_id is None or token_type != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user = db.query(User).filter(User.id == int(user_id), User.is_active == True).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return user

def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

# Rate limiting middleware
@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    client_ip = request.client.host
    path = request.url.path
    
    # Different rate limits for different endpoints
    if path == "/auth/register" or path == "/auth/login":
        limit_key = f"{client_ip}:{path}"
        if not check_rate_limit(limit_key, 5, 60):  # 5 requests per minute
            raise HTTPException(status_code=429, detail="Too many requests")
    elif path.startswith("/auth/password-reset"):
        limit_key = f"{client_ip}:password-reset"
        if not check_rate_limit(limit_key, 3, 300):  # 3 requests per 5 minutes
            raise HTTPException(status_code=429, detail="Too many requests")
    
    return await call_next(request)

# API endpoints
@app.post("/auth/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register_user(user: UserCreate, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
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
            password_hash=hashed_password,
            first_name=user.first_name,
            last_name=user.last_name
        )
        
        db.add(db_user)
        db.flush()  # Flush to get the user ID
        
        # Send verification email in background
        verification_token = generate_jwt_token({"sub": str(db_user.id), "type": "verify"})
        verification_url = f"{FRONTEND_URL}/verify-email?token={verification_token}"
        email_body = f"""Hello {user.first_name},
        
Please verify your email address by clicking the link below:
{verification_url}

If you did not create an account, please ignore this email.
"""
        background_tasks.add_task(send_email, user.email, "Verify your AEP account", email_body)
        
        return db_user
        
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists"
        )
    except SQLAlchemyError as e:
        logger.error(f"Database error during registration: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create user"
        )

@app.post("/auth/login", response_model=TokenResponse)
def login(login_data: LoginRequest, db: Session = Depends(get_db)):
    try:
        user = db.query(User).filter(User.email == login_data.email, User.is_active == True).first()
        if not user or not verify_password(login_data.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        access_token = create_access_token(user.id)
        refresh_token, expires_at = create_refresh_token(user.id)
        
        # Store refresh token in database
        db_refresh_token = RefreshToken(
            user_id=user.id,
            token=refresh_token,
            expires_at=expires_at
        )
        db.add(db_refresh_token)
        
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer"
        }
        
    except SQLAlchemyError as e:
        logger.error(f"Database error during login: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to login"
        )

@app.post("/auth/refresh", response_model=TokenResponse)
def refresh_token(refresh_token: str, db: Session = Depends(get_db)):
    try:
        # Verify refresh token
        payload = decode_jwt_token(refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type"
            )
        
        user_id = int(payload.get("sub"))
        
        # Check if refresh token exists and is not revoked
        db_token = db.query(RefreshToken).filter(
            RefreshToken.token == refresh_token,
            RefreshToken.user_id == user_id,
            RefreshToken.revoked == False,
            RefreshToken.expires_at > datetime.utcnow()
        ).first()
        
        if not db_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired refresh token"
            )
        
        # Revoke the used refresh token
        db_token.revoked = True
        
        # Create new tokens
        access_token = create_access_token(user_id)
        new_refresh_token, expires_at = create_refresh_token(user_id)
        
        # Store new refresh token
        new_db_token = RefreshToken(
            user_id=user_id,
            token=new_refresh_token,
            expires_at=expires_at
        )
        db.add(new_db_token)
        
        return {
            "access_token": access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer"
        }
        
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    except SQLAlchemyError as e:
        logger.error(f"Database error during token refresh: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to refresh token"
        )

@app.post("/auth/logout")
def logout(token: HTTPAuthorizationCredentials = Depends(security), db: Session = Depends(get_db)):
    try:
        access_token = token.credentials
        payload = decode_jwt_token(access_token)
        
        # Blacklist the access token
        expires_at = datetime.fromtimestamp(payload['exp'], timezone.utc)
        blacklist_token(access_token, expires_at)
        
        return {"message": "Successfully logged out"}
        
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

@app.post("/auth/password-reset-request")
def password_reset_request(reset_request: PasswordResetRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    try:
        user = db.query(User).filter(User.email == reset_request.email, User.is_active == True).first()
        if user:
            # Generate reset token
            reset_token = generate_reset_token()
            expires_at = datetime.utcnow() + timedelta(hours=1)
            
            # Store reset token in database
            db_reset_token = PasswordResetToken(
                user_id=user.id,
                token=reset_token,
                expires_at=expires_at
            )
            db.add(db_reset_token)
            
            # Send reset email in background
            reset_url = f"{FRONTEND_URL}/reset-password?token={reset_token}"
            email_body = f"""Hello {user.first_name},
            
You requested to reset your password. Click the link below to reset it:
{reset_url}

This link will expire in 1 hour.

If you did not request a password reset, please ignore this email.
"""
            background_tasks.add_task(send_email, user.email, "Password Reset Request", email_body)
        
        # Always return success to prevent email enumeration
        return {"message": "If the email exists, a password reset link has been sent"}
        
    except SQLAlchemyError as e:
        logger.error(f"Database error during password reset request: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process password reset request"
        )

@app.post("/auth/password-reset-confirm")
def password_reset_confirm(reset_confirm: PasswordResetConfirm, db: Session = Depends(get_db)):
    try:
        # Find valid reset token
        reset_token = db.query(PasswordResetToken).filter(
            PasswordResetToken.token == reset_confirm.token,
            PasswordResetToken.used == False,
            PasswordResetToken.expires_at > datetime.utcnow()
        ).first()
        
        if not reset_token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired reset token"
            )
        
        # Get user and update password
        user = db.query(User).filter(User.id == reset_token.user_id, User.is_active == True).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User not found"
            )
        
        user.password_hash = hash_password(reset_confirm.new_password)
        reset_token.used = True
        
        # Revoke all refresh tokens for this user
        db.query(RefreshToken).filter(RefreshToken.user_id == user.id).update({"revoked": True})
        
        return {"message": "Password successfully reset"}
        
    except SQLAlchemyError as e:
        logger.error(f"Database error during password reset confirm: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to reset password"
        )

@app.post("/auth/change-password")
def change_password(change_data: ChangePasswordRequest, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    try:
        # Verify current password
        if not verify_password(change_data.current_password, current_user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Current password is incorrect"
            )
        
        # Update password
        current_user.password_hash = hash_password(change_data.new_password)
        
        # Revoke all refresh tokens
        db.query(RefreshToken).filter(RefreshToken.user_id == current_user.id).update({"revoked": True})
        
        return {"message": "Password successfully changed"}
        
    except SQLAlchemyError as e:
        logger.error(f"Database error during password change: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to change password"
        )

@app.get("/auth/verify-email")
def verify_email(token: str, db: Session = Depends(get_db)):
    try:
        payload = decode_jwt_token(token)
        if payload.get("type") != "verify":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid verification token"
            )
        
        user_id = int(payload.get("sub"))
        user = db.query(User).filter(User.id == user_id).first()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User not found"
            )
        
        if user.is_verified:
            return {"message": "Email already verified"}
        
        user.is_verified = True
        return {"message": "Email successfully verified"}
        
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification token"
        )
    except SQLAlchemyError as e:
        logger.error(f"Database error during email verification: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to verify email"
        )

@app.get("/auth/me", response_model=UserResponse)
def get_current_user_profile(current_user: User = Depends(get_current_active_user)):
    return current_user

# Health check endpoint
@app.get("/health")
def health_check():
    return {"status": "healthy"}

# Create database tables
def create_tables():
    Base.metadata.create_all(bind=engine)

# Initialize application
@app.on_event("startup")
async def startup_event():
    create_tables()
    logger.info("Authentication service started")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)