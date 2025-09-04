# Role-Based Access Control (RBAC) and Basic User Profile API
# Combined FastAPI application

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.security.oauth2 import OAuth2Password Bearer
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import create_engine, select
from sqlalchemy.ext.declarative import declarative_base
from pydantic import BaseModel

DB_URL = "postgresql://username:password@localhost/db_name"

Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String, nullable=False)
    email = db.Column(db.String, unique=True, nullable=False)
    role = db.Column(db.String)

engine = create_engine(DB_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

app = FastAPI()

models.Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_user(db: Session, user_id: int):
    return db.query(User).filter(User.id == user_id).first()

def authenticate_user(fake_db, username: str, password: str):
    user = get_user(fake_db, username=username)
    if not user:
        return False
    if not check_password_hash(user.password, password):
        return False
    return user

def get_current_user(token: str = Depends(oauth2_scheme)):
    # Implement token validation logic here
    return {"sub": "fake_user_id"}

class UserProfile(BaseModel):
    name: str
    email: str
    role: Optional[str] = None

def read_user_profile(user_id: int = None, db: Session = Depends(get_db)):
    if user_id:
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            return {
                "name": user.name,
                "email": user.email,
                "role": user.role
            }
        else:
            raise HTTPException(status_code=404, detail="User not found")
    else:
        raise HTTPException(status_code=400, detail="User ID is required")

@app.post("/token")
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    user = authenticate_user(fake_db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.id}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/roles", response_model=List[Role])
async def read_roles(db: Session = Depends(get_db)):
    return db.query(Role).all()

@app.get("/users/{user_id}", response_model=User)
async def read_user(user_id: int, db: Session = Depends(get_db)):
    user = get_user(db, user_id=user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user

@app.get("/profile", response_model=UserProfile)
async def read_protected_user(current_user: User = Depends(get_current_user)):
    # Check if the current user has the required role (e.g., admin)
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    return current_user._dict()

if __name__ == "__main__":
    main()