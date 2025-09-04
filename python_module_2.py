import os
import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Optional

import asyncpg
import requests
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends
from flask import Flask, render_template, jsonify
from flask_cors import CORS
from pydantic import BaseModel

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database configuration
DB_URL = os.getenv('DB_URL', "postgresql://admin:admin@localhost:5432/training_db")

# Flask app configuration
FLASK_SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key')
API_BASE_URL = os.getenv('API_BASE_URL', 'http://localhost:5001/api')

# Database connection pool
_pool: Optional[asyncpg.Pool] = None

# Flask app initialization
flask_app = Flask(__name__)
CORS(flask_app)
flask_app.config['SECRET_KEY'] = FLASK_SECRET_KEY

# FastAPI app initialization
fastapi_app = FastAPI()

# Pydantic models
class UserCreate(BaseModel):
    username: str
    email: str
    full_name: str
    role_id: int

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    full_name: str
    role_id: int

class TrainingNeedCreate(BaseModel):
    user_id: int
    skill_name: str
    priority: int
    status: str = "pending"

class CourseCreate(BaseModel):
    title: str
    description: str
    duration_hours: int
    instructor: str

class APIError(Exception):
    """Custom exception for API errors"""
    pass

# Database functions
async def run_migrations():
    """Run database migrations"""
    try:
        pool = await asyncpg.create_pool(DB_URL)
        async with pool.acquire() as conn:
            # Create tables
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS roles (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(50) NOT NULL UNIQUE,
                    description TEXT
                )
            """)
            
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    username VARCHAR(50) NOT NULL UNIQUE,
                    email VARCHAR(100) NOT NULL UNIQUE,
                    full_name VARCHAR(100) NOT NULL,
                    role_id INTEGER REFERENCES roles(id),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS training_needs (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER REFERENCES users(id),
                    skill_name VARCHAR(100) NOT NULL,
                    priority INTEGER DEFAULT 1,
                    status VARCHAR(20) DEFAULT 'pending',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS courses (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(200) NOT NULL,
                    description TEXT,
                    duration_hours INTEGER,
                    instructor VARCHAR(100),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Insert sample data
            await conn.execute("""
                INSERT INTO roles (name, description) VALUES
                ('admin', 'Administrator with full access'),
                ('manager', 'Manager with team management privileges'),
                ('employee', 'Regular employee')
                ON CONFLICT (name) DO NOTHING
            """)
            
            await conn.execute("""
                INSERT INTO users (username, email, full_name, role_id) VALUES
                ('admin_user', 'admin@company.com', 'Admin User', 1),
                ('manager_john', 'john.manager@company.com', 'John Manager', 2),
                ('employee_sarah', 'sarah.employee@company.com', 'Sarah Employee', 3)
                ON CONFLICT (username) DO NOTHING
            """)
            
            logger.info("Database migrations completed successfully")
    except Exception as e:
        logger.error(f"Migration failed: {e}")
        raise

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage database connection pool lifecycle"""
    global _pool
    try:
        _pool = await asyncpg.create_pool(DB_URL)
        logger.info("Database connection pool created successfully")
        yield
    except Exception as e:
        logger.error(f"Failed to create database pool: {e}")
        raise
    finally:
        if _pool:
            await _pool.close()
            logger.info("Database connection pool closed")

async def get_db_pool() -> asyncpg.Pool:
    """Dependency to get database pool"""
    if _pool is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    return _pool

# Flask routes and functions
def fetch_user_profile():
    """
    Fetch user profile from API with error handling
    """
    try:
        response = requests.get(
            f"{API_BASE_URL}/user/profile",
            timeout=10,
            headers={'Content-Type': 'application/json'}
        )
        
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 401:
            raise APIError("Authentication failed. Please log in again.")
        elif response.status_code == 404:
            raise APIError("User profile not found.")
        else:
            response.raise_for_status()
            
    except requests.exceptions.Timeout:
        raise APIError("Request timed out. Please try again.")
    except requests.exceptions.ConnectionError:
        raise APIError("Unable to connect to the server. Please check your connection.")
    except requests.exceptions.RequestException as e:
        raise APIError(f"An error occurred: {str(e)}")

@flask_app.route('/')
def dashboard():
    """
    Main dashboard route
    """
    try:
        user_data = fetch_user_profile()
        return render_template('dashboard.html', user=user_data)
    except APIError as e:
        return render_template('error.html', error_message=str(e)), 500
    except Exception as e:
        flask_app.logger.error(f"Unexpected error in dashboard: {str(e)}")
        return render_template('error.html', error_message="An unexpected error occurred."), 500

@flask_app.route('/health')
def health_check():
    """
    Health check endpoint
    """
    return jsonify({"status": "healthy", "service": "user-dashboard"})

@flask_app.errorhandler(404)
def not_found(error):
    return render_template('error.html', error_message="Page not found."), 404

@flask_app.errorhandler(500)
def internal_error(error):
    return render_template('error.html', error_message="Internal server error."), 500

# FastAPI routes
@fastapi_app.get("/health")
async def fastapi_health_check():
    """Health check endpoint"""
    return {"status": "healthy", "database": "connected" if _pool else "disconnected"}

@fastapi_app.post("/users", response_model=UserResponse)
async def create_user(user: UserCreate, pool: asyncpg.Pool = Depends(get_db_pool)):
    """Create a new user"""
    try:
        async with pool.acquire() as conn:
            result = await conn.fetchrow(
                "INSERT INTO users (username, email, full_name, role_id) VALUES ($1, $2, $3, $4) RETURNING *",
                user.username, user.email, user.full_name, user.role_id
            )
            return dict(result)
    except asyncpg.exceptions.UniqueViolationError:
        raise HTTPException(status_code=400, detail="Username or email already exists")
    except Exception as e:
        logger.error(f"Error creating user: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@fastapi_app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int, pool: asyncpg.Pool = Depends(get_db_pool)):
    """Get user by ID"""
    try:
        async with pool.acquire() as conn:
            result = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)
            if not result:
                raise HTTPException(status_code=404, detail="User not found")
            return dict(result)
    except Exception as e:
        logger.error(f"Error fetching user: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@fastapi_app.post("/training-needs")
async def create_training_need(need: TrainingNeedCreate, pool: asyncpg.Pool = Depends(get_db_pool)):
    """Create a new training need"""
    try:
        async with pool.acquire() as conn:
            result = await conn.fetchrow(
                "INSERT INTO training_needs (user_id, skill_name, priority, status) VALUES ($1, $2, $3, $4) RETURNING *",
                need.user_id, need.skill_name, need.priority, need.status
            )
            return dict(result)
    except Exception as e:
        logger.error(f"Error creating training need: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@fastapi_app.post("/courses")
async def create_course(course: CourseCreate, pool: asyncpg.Pool = Depends(get_db_pool)):
    """Create a new course"""
    try:
        async with pool.acquire() as conn:
            result = await conn.fetchrow(
                "INSERT INTO courses (title, description, duration_hours, instructor) VALUES ($1, $2, $3, $4) RETURNING *",
                course.title, course.description, course.duration_hours, course.instructor
            )
            return dict(result)
    except Exception as e:
        logger.error(f"Error creating course: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

def main():
    """Main function to run all merged functionality"""
    # Run database migrations
    asyncio.run(run_migrations())
    
    # Start Flask app in a separate thread
    import threading
    
    def run_flask():
        port = int(os.getenv('FLASK_PORT', 5000))
        debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
        flask_app.run(host='0.0.0.0', port=port, debug=debug, use_reloader=False)
    
    flask_thread = threading.Thread(target=run_flask)
    flask_thread.daemon = True
    flask_thread.start()
    
    # Start FastAPI app
    import uvicorn
    fastapi_port = int(os.getenv('FASTAPI_PORT', 8000))
    uvicorn.run(fastapi_app, host="0.0.0.0", port=fastapi_port)

if __name__ == "__main__":
    main()