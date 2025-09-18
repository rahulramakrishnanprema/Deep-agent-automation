# Issue: AEP-123
# Generated: 2025-09-18T17:27:22.334220
# Thread: 8de2f38c
# Enhanced: LangChain structured generation
# AI Model: None
# Max Length: 25000 characters

import uvicorn
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from typing import List
import psycopg2
import jwt
import logging

# Initialize FastAPI app
app = FastAPI()

# Database connection
conn = psycopg2.connect("dbname=aep_db user=aep_user password=aep_password")
cur = conn.cursor()

# JWT authentication
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Structured logging configuration
logging.basicConfig(format='%(asctime)s - %(levelname)s - %(message)s', level=logging.INFO)

# Models
class Item(BaseModel):
    name: str
    description: str

# Routes
@app.post("/items/", response_model=Item)
async def create_item(item: Item, token: str = Depends(oauth2_scheme)):
    try:
        # Decode and verify JWT token
        payload = jwt.decode(token, "secret_key", algorithms=["HS256"])
        logging.info(f"User {payload['username']} is creating item {item.name}")
        
        # Insert item into database
        cur.execute("INSERT INTO items (name, description) VALUES (%s, %s)", (item.name, item.description))
        conn.commit()
        
        return item
    except jwt.ExpiredSignatureError:
        logging.error("Token has expired")
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        logging.error("Invalid token")
        raise HTTPException(status_code=401, detail="Invalid token")
    except Exception as e:
        logging.error(f"An error occurred: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/items/", response_model=List[Item])
async def read_items(token: str = Depends(oauth2_scheme)):
    try:
        # Decode and verify JWT token
        payload = jwt.decode(token, "secret_key", algorithms=["HS256"])
        logging.info(f"User {payload['username']} is reading items")
        
        # Retrieve items from database
        cur.execute("SELECT name, description FROM items")
        items = [Item(name=row[0], description=row[1]) for row in cur.fetchall()]
        
        return items
    except jwt.ExpiredSignatureError:
        logging.error("Token has expired")
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        logging.error("Invalid token")
        raise HTTPException(status_code=401, detail="Invalid token")
    except Exception as e:
        logging.error(f"An error occurred: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)