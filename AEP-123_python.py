from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel
from typing import List
import logging

# AEP-123: Initialize FastAPI app
app = FastAPI()

# AEP-123: Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# AEP-123: Database integration
class Database:
    def __init__(self):
        self.users = []

db = Database()

# AEP-123: Authentication
SECRET_KEY = "secret"
ALGORITHM = "HS256"
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# AEP-123: User model
class User(BaseModel):
    username: str
    email: str
    password: str

# AEP-123: Create user endpoint
@app.post("/users/", response_model=User)
def create_user(user: User):
    hashed_password = pwd_context.hash(user.password)
    db.users.append({"username": user.username, "email": user.email, "password": hashed_password})
    return user

# AEP-123: Get all users endpoint
@app.get("/users/", response_model=List[User])
def get_users(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    return db.users

# AEP-123: Error handling
@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    logging.error(f"HTTPException: {exc.detail}")
    return JSONResponse(status_code=exc.status_code, content={"message": exc.detail})

# AEP-123: Unit tests
def test_create_user():
    user = User(username="testuser", email="test@example.com", password="password")
    assert create_user(user) == user

def test_get_users():
    assert get_users("valid_token") == db.users