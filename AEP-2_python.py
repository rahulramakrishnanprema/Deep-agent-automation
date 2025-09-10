# AEP-2: Implement Authentication APIs

import jwt
from flask import Flask, request, jsonify

app = Flask(__name__)

# Dummy user data for demonstration purposes
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

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Username and password are required"}), 400

    user = users.get(username)
    if not user or user['password'] != password:
        return jsonify({"error": "Invalid username or password"}), 401

    token = jwt.encode({'username': username}, SECRET_KEY, algorithm='HS256')
    return jsonify({"token": token.decode('utf-8')}), 200

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Username and password are required"}), 400

    if username in users:
        return jsonify({"error": "Username already exists"}), 409

    users[username] = {"username": username, "password": password}
    return jsonify({"message": "User registered successfully"}), 201

if __name__ == '__main__':
    app.run(debug=True)