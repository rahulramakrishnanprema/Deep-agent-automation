# AEP-2: Implement Authentication APIs

import jwt
import logging

# Sample user data for demonstration purposes
users = {
    "user1": {
        "username": "user1",
        "password": "password1"
    },
    "user2": {
        "username": "user2",
        "password": "password2"
    }
}

# Secret key for JWT token
SECRET_KEY = "secret"

# Logging configuration
logging.basicConfig(level=logging.INFO)

def login(username, password):
    if username in users and users[username]["password"] == password:
        token = jwt.encode({"username": username}, SECRET_KEY, algorithm="HS256")
        logging.info(f"User {username} logged in successfully")
        return {"token": token}
    else:
        logging.error("Invalid login attempt")
        return {"error": "Invalid credentials"}

def register(username, password):
    if username in users:
        return {"error": "Username already exists"}
    else:
        users[username] = {"username": username, "password": password}
        logging.info(f"User {username} registered successfully")
        return {"message": "Registration successful"}

# Sample test cases
def test_login():
    assert login("user1", "password1") == {"token": jwt.encode({"username": "user1"}, SECRET_KEY, algorithm="HS256")}
    assert login("user1", "wrongpassword") == {"error": "Invalid credentials"}

def test_register():
    assert register("user3", "password3") == {"message": "Registration successful"}
    assert register("user1", "password1") == {"error": "Username already exists"}

if __name__ == "__main__":
    test_login()
    test_register()