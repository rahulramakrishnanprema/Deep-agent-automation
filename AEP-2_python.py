# AEP-2: Implement Authentication APIs

import jwt
import logging

# Function to handle user login
def login(username, password):
    # Validate username and password
    if username == "admin" and password == "password":
        # Generate JWT token
        token = jwt.encode({'username': username}, 'secret_key', algorithm='HS256')
        return token
    else:
        logging.error("Invalid login attempt")
        return "Invalid username or password"

# Function to handle user registration
def register(username, password):
    # Implement registration logic here
    return "User registered successfully"

# Main function to test the APIs
if __name__ == "__main__":
    # Test login API
    print(login("admin", "password"))
    print(login("user", "password123"))

    # Test registration API
    print(register("new_user", "new_password"))