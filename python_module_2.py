#!/usr/bin/env python3
'''
python_module_2.py
Integrated module from 2 source files
Part of larger python project - designed for cross-module compatibility
'''

# Imports (add any needed imports here)
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import databases
import sqlalchemy
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, Table
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship, Session
import os
from dotenv import load_dotenv
import uuid
from logging import getLogger
from logging.config import dictConfig
from log_config import LogConfig

# Load environment variables
load_dotenv()

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./test.db")
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
ALGORITHM = os.getenv("ALGORITHM", "HS256")

logger = getLogger(__name__)

database = databases.Database(DATABASE_URL)
metadata = sqlalchemy.MetaData()
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Security
security = HTTPBearer()

# Database Models
user_role_association = Table(
    'user_role_association',
    Base.metadata,
    Column('user_id', Integer, ForeignKey('users.id')),
    Column('role_id', Integer, ForeignKey('roles.id'))
)

class Role(Base):
    __tablename__ = "roles"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    permissions = Column(String)  # Comma-separated permissions

    users = relationship("User", secondary=user_role_association, back_populates="roles")

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)

    roles = relationship("Role", secondary=user_role_association, back_populates="users")

# Pydantic Models
class RoleCreate(BaseModel):
    name: str
    permissions: str

class UserCreate(BaseModel):
    username: str
    email: str
    password: str
    role_ids: List[int]

class TokenData(BaseModel):
    username: Optional[str] = None
    roles: List[str] = []

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    roles: List[str]

# Create tables
Base.metadata.create_all(bind=engine)

# Utility functions
def verify_password(plain_password, hashed_password):
    # In production, use proper password hashing like bcrypt
    return plain_password == hashed_password

def get_password_hash(password):
    # In production, use proper password hashing
    return password

def create_access_token(data: Dict[str, Any]):
    to_encode = data.copy()
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username, roles=payload.get("roles", []))
    except JWTError:
        raise credentials_exception

    user = db.query(User).filter(User.username == token_data.username).first()
    if user is None:
        raise credentials_exception
    return user

def has_permission(user: User, required_permission: str):
    user_permissions = set()
    for role in user.roles:
        if role.permissions:
            user_permissions.update(role.permissions.split(','))
    return required_permission in user_permissions

def role_required(required_role: str):
    def role_checker(user: User = Depends(get_current_user)):
        user_roles = [role.name for role in user.roles]
        if required_role not in user_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires {required_role} role"
            )
        return user
    return role_checker

def permission_required(required_permission: str):
    def permission_checker(user: User = Depends(get_current_user)):
        if not has_permission(user, required_permission):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires {required_permission} permission"
            )
        return user
    return permission_checker

# Routes
def register_user(app: FastAPI, db: Session = Depends(get_db)):
    @app.post("/register", response_model=UserResponse)
    async def register_user(user: UserCreate, db: Session = Depends(get_db)):
        db_user = db.query(User).filter(User.username == user.username).first()
        if db_user:
            raise HTTPException(status_code=400, detail="Username already registered")

        roles = db.query(Role).filter(Role.id.in_(user.role_ids)).all()
        if len(roles) != len(user.role_ids):
            raise HTTPException(status_code=400, detail="One or more roles not found")

        hashed_password = get_password_hash(user.password)
        db_user = User(
            username=user.username,
            email=user.email,
            hashed_password=hashed_password,
            roles=roles
        )
        db.add(db_user)
        db.commit()
        db.refresh(db_user)

        return UserResponse(
            id=db_user.id,
            username=db_user.username,
            email=db_user.email,
            roles=[role.name for role in db_user.roles]
        )

def login(app: FastAPI, db: Session = Depends(get_db)):
    @app.post("/login")
    async def login(username: str, password: str, db: Session = Depends(get_db)):
        user = db.query(User).filter(User.username == username).first()
        if not user or not verify_password(password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password",
                headers={"WWW-Authenticate": "Bearer"},
            )

        access_token = create_access_token(
            data={
                "sub": user.username,
                "roles": [role.name for role in user.roles]
            }
        )
        return {"access_token": access_token, "token_type": "bearer"}

def create_role(app: FastAPI, db: Session = Depends(get_db)):
    @app.post("/roles", dependencies=[Depends(role_required("admin"))])
    async def create_role(role: RoleCreate, db: Session = Depends(get_db)):
        db_role = db.query(Role).filter(Role.name == role.name).first()
        if db_role:
            raise HTTPException(status_code=400, detail="Role already exists")

        db_role = Role(name=role.name, permissions=role.permissions)
        db.add(db_role)
        db.commit()
        db.refresh(db_role)
        return {"message": "Role created successfully", "role": db_role.name}

def employee_dashboard(app: FastAPI, db: Session = Depends(get_db)):
    @app.get("/employee/dashboard", dependencies=[Depends(permission_required("view_dashboard"))])
    async def employee_dashboard():
        return {"message": "Welcome to Employee Dashboard"}

def manager_dashboard(app: FastAPI, db: Session = Depends(get_db)):
    @app.get("/manager/dashboard", dependencies=[Depends(role_required("manager"))])
    async def manager_dashboard():
        return {"message": "Welcome to Manager Dashboard"}

def admin_dashboard(app: FastAPI, db: Session = Depends(get_db)):
    @app.get("/admin/dashboard", dependencies=[Depends(role_required("admin"))])
    async def admin_dashboard():
        return {"message": "Welcome to Admin Dashboard"}

def read_users_me(app: FastAPI, db: Session = Depends(get_db)):
    @app.get("/users/me", response_model=UserResponse)
    async def read_users_me(current_user: User = Depends(get_current_user)):
        return UserResponse(
            id=current_user.id,
            username=current_user.username,
            email=current_user.email,
            roles=[role.name for role in current_user.roles]
        )

def startup(app: FastAPI):
    @app.on_event("startup")
    async def startup():
        await database.connect()
        # Create default roles if they don't exist
        db = SessionLocal()
        try:
            default_roles = [
                {"name": "employee", "permissions": "view_dashboard,edit_profile"},
                {"name": "manager", "permissions": "view_dashboard,edit_profile,manage_team,view_reports"},
                {"name": "admin", "permissions": "view_dashboard,edit_profile,manage_team,view_reports,manage_users,manage_roles"}
            ]

            for role_data in default_roles:
                db_role = db.query(Role).filter(Role.name == role_data["name"]).first()
                if not db_role:
                    db_role = Role(name=role_data["name"], permissions=role_data["permissions"])
                    db.add(db_role)

            db.commit()
        finally:
            db.close()

def main():
    '''Main function callable from main runner'''
    from fastapi import FastAPI

    app = FastAPI(title="RBAC System", version="1.0.0")

    register_user(app)
    login(app)
    create_role(app)
    employee_dashboard(app)
    manager_dashboard(app)
    admin_dashboard(app)
    read_users_me(app)
    startup(app)

    if __name__ == "__main__":
        import uvicorn
        uvicorn.run(app, host="0.0.0.0", port=8000)

if __name__ == "__main__":
    main()