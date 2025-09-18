# Issue: DEEP-123
# Generated: 2025-09-18T18:34:31.245119
# Thread: e82b8897
# Enhanced: LangChain structured generation
# AI Model: None
# Max Length: 25000 characters

from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from passlib.context import CryptContext
import jwt
import logging
import psycopg2

# Initialize FastAPI app
app = FastAPI()

# Initialize logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database connection
conn = psycopg2.connect("dbname=deep_project user=postgres password=123456")
cur = conn.cursor()

# JWT settings
SECRET_KEY = "secret"
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Models
class User(BaseModel):
    username: str
    password: str

# Authentication
def authenticate_user(username: str, password: str):
    cur.execute("SELECT * FROM users WHERE username=%s", (username,))
    user = cur.fetchone()
    if not user:
        return False
    if not pwd_context.verify(password, user[1]):
        return False
    return user

# Create token
def create_access_token(data: dict):
    encoded_jwt = jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# API endpoints
@app.post("/token")
def login_for_access_token(user: User):
    db_user = authenticate_user(user.username, user.password)
    if not db_user:
        raise HTTPException(status_code=401, detail="Incorrect username or password")
    access_token = create_access_token({"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer"}

# Error handling
@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    logger.error(f"HTTP Exception: {exc}")
    return JSONResponse(status_code=exc.status_code, content={"message": exc.detail})

# Unit tests
def test_login_for_access_token():
    test_user = User(username="testuser", password="testpassword")
    response = login_for_access_token(test_user)
    assert response["token_type"] == "bearer"

# Run app
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)