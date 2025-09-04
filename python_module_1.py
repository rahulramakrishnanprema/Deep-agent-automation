import os
import logging
import sqlite3
import jwt
from typing import Optional
from contextlib import contextmanager
from datetime import datetime, timedelta

import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from passlib.context import CryptContext
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database configuration
DB_URL = os.getenv("DB_URL", "postgresql://admin:admin@localhost:5432/training_db")
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
DATABASE_URL = "users.db"

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Security configurations
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

# Pydantic models
class UserCreate(BaseModel):
    username: str
    email: str
    password: str

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    created_at: datetime

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

class DatabaseManager:
    def __init__(self, db_url: str = DB_URL):
        self.db_url = db_url
        self._connection = None
    
    @contextmanager
    def get_connection(self):
        """Context manager for database connections"""
        conn = None
        try:
            conn = psycopg2.connect(self.db_url)
            yield conn
        except psycopg2.Error as e:
            logger.error(f"Database connection error: {e}")
            raise
        finally:
            if conn:
                conn.close()
    
    @contextmanager
    def get_cursor(self):
        """Context manager for database cursors"""
        with self.get_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            try:
                yield cursor
                conn.commit()
            except Exception as e:
                conn.rollback()
                logger.error(f"Database operation failed: {e}")
                raise
            finally:
                cursor.close()
    
    def execute_query(self, query: str, params: Optional[tuple] = None) -> list:
        """Execute a query and return results"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute(query, params)
                if cursor.description:
                    return cursor.fetchall()
                return []
        except psycopg2.Error as e:
            logger.error(f"Query execution failed: {e}")
            raise
    
    def execute_script(self, script_path: str):
        """Execute a SQL script file"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                with open(script_path, 'r') as file:
                    sql_script = file.read()
                cursor.execute(sql_script)
                conn.commit()
                logger.info(f"Successfully executed script: {script_path}")
        except (psycopg2.Error, FileNotFoundError) as e:
            logger.error(f"Script execution failed: {e}")
            raise

def setup_database():
    """Main function to setup the database schema"""
    db_manager = DatabaseManager()
    
    try:
        # Create tables
        logger.info("Creating database tables...")
        db_manager.execute_script("migrations/create_tables.sql")
        
        # Insert sample data
        logger.info("Inserting sample data...")
        db_manager.execute_script("migrations/insert_sample_data.sql")
        
        # Validate schema
        logger.info("Validating schema...")
        validate_schema(db_manager)
        
        logger.info("Database setup completed successfully!")
        
    except Exception as e:
        logger.error(f"Database setup failed: {e}")
        raise

def validate_schema(db_manager: DatabaseManager):
    """Validate that the schema was created correctly"""
    validation_queries = [
        "SELECT COUNT(*) as count FROM users",
        "SELECT COUNT(*) as count FROM roles",
        "SELECT COUNT(*) as count FROM training_needs",
        "SELECT COUNT(*) as count FROM courses"
    ]
    
    for query in validation_queries:
        try:
            result = db_manager.execute_query(query)
            logger.info(f"Validation query '{query}' returned: {result[0]['count']}")
        except Exception as e:
            logger.error(f"Validation failed for query '{query}': {e}")
            raise

def get_user_training_needs(user_id: int, db_manager: DatabaseManager) -> list:
    """Get training needs for a specific user"""
    query = """
    SELECT tn.*, c.course_name, c.course_description
    FROM training_needs tn
    JOIN courses c ON tn.course_id = c.id
    WHERE tn.user_id = %s
    """
    return db_manager.execute_query(query, (user_id,))

def get_all_users(db_manager: DatabaseManager) -> list:
    """Get all users with their roles"""
    query = """
    SELECT u.*, r.role_name
    FROM users u
    JOIN roles r ON u.role_id = r.id
    """
    return db_manager.execute_query(query)

def init_db():
    """Initialize database with users table"""
    conn = sqlite3.connect(DATABASE_URL)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            hashed_password TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            is_active BOOLEAN DEFAULT TRUE
        )
    ''')
    conn.commit()
    conn.close()

def get_db():
    conn = sqlite3.connect(DATABASE_URL)
    try:
        yield conn
    finally:
        conn.close()

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_user_by_username(username: str, conn):
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE username = ? AND is_active = TRUE", (username,))
    user = cursor.fetchone()
    return user

def authenticate_user(username: str, password: str, conn):
    user = get_user_by_username(username, conn)
    if not user:
        return False
    if not verify_password(password, user[3]):
        return False
    return user

async def get_current_user(token: str = Depends(oauth2_scheme), conn = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except jwt.PyJWTError:
        raise credentials_exception
    
    user = get_user_by_username(token_data.username, conn)
    if user is None:
        raise credentials_exception
    return user

app = FastAPI(title="Authentication API", version="1.0.0")

@app.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register_user(user: UserCreate, conn = Depends(get_db)):
    cursor = conn.cursor()
    
    cursor.execute("SELECT id FROM users WHERE username = ?", (user.username,))
    if cursor.fetchone():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )
    
    cursor.execute("SELECT id FROM users WHERE email = ?", (user.email,))
    if cursor.fetchone():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    hashed_password = get_password_hash(user.password)
    cursor.execute(
        "INSERT INTO users (username, email, hashed_password) VALUES (?, ?, ?)",
        (user.username, user.email, hashed_password)
    )
    conn.commit()
    
    cursor.execute("SELECT id, username, email, created_at FROM users WHERE id = ?", (cursor.lastrowid,))
    new_user = cursor.fetchone()
    
    return {
        "id": new_user[0],
        "username": new_user[1],
        "email": new_user[2],
        "created_at": new_user[3]
    }

@app.post("/login", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), conn = Depends(get_db)):
    user = authenticate_user(form_data.username, form_data.password, conn)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user[1]},
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=UserResponse)
async def read_users_me(current_user: tuple = Depends(get_current_user)):
    return {
        "id": current_user[0],
        "username": current_user[1],
        "email": current_user[2],
        "created_at": current_user[4]
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.utcnow()}

@app.on_event("startup")
async def startup_event():
    init_db()

def main():
    """Main function that runs all merged functionality"""
    try:
        # Setup PostgreSQL database schema
        setup_database()
        
        # Test the connection and some queries
        db_manager = DatabaseManager()
        
        # Display all users
        users = get_all_users(db_manager)
        logger.info(f"Found {len(users)} users in the database")
        
        # Display training needs for first user (if any)
        if users:
            training_needs = get_user_training_needs(users[0]['id'], db_manager)
            logger.info(f"User {users[0]['username']} has {len(training_needs)} training needs")
        
        # Initialize SQLite database for authentication
        init_db()
        logger.info("SQLite authentication database initialized")
        
        logger.info("All functionality initialized successfully!")
        
    except Exception as e:
        logger.error(f"Application failed: {e}")
        exit(1)

if __name__ == "__main__":
    main()