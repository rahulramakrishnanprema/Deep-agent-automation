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
DATABASE = []

# AEP-123: JWT authentication
SECRET_KEY = "secret"
ALGORITHM = "HS256"
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# AEP-123: User model
class User(BaseModel):
    username: str
    password: str

# AEP-123: Token model
class Token(BaseModel):
    access_token: str
    token_type: str

# AEP-123: Authenticate user
def authenticate_user(username: str, password: str):
    user = next((user for user in DATABASE if user["username"] == username), None)
    if not user or not pwd_context.verify(password, user["password"]):
        return False
    return user

# AEP-123: Create access token
def create_access_token(data: dict):
    to_encode = data.copy()
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# AEP-123: Dependency for authentication
def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid credentials")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return username

# AEP-123: REST API endpoints
@app.post("/token", response_model=Token)
def login_for_access_token(user: User):
    authenticated_user = authenticate_user(user.username, user.password)
    if not authenticated_user:
        raise HTTPException(status_code=401, detail="Incorrect username or password")
    access_token = create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me")
def read_users_me(current_user: str = Depends(get_current_user)):
    return {"username": current_user}