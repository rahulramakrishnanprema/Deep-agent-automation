# python_module_3.py

"""
Project: Basic User Dashboard UI and DevOps & Environment Setup (Infra Story)

This module combines the functionality from two separate Python files, merging the basic Flask application and the database connection using psycopg2.
"""

import os
import sys
import psycopg2
from dotenv import dotenv_values
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS

# Load environment variables from .env file
env_config = dotenv_values(".env")

DB_HOST = env_config["DB_HOST"]
DB_PORT = env_config["DB_PORT"]
DB_NAME = env_config["DB_NAME"]
DB_USER = env_config["DB_USER"]
DB_PASSWORD = env_config["DB_PASSWORD"]

app = Flask(__name__)
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///user_dashboard.db'
db = SQLAlchemy(app)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100))
    email = db.Column(db.String(100))
    role = db.Column(db.String(50))

def connect_to_db():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        return conn
    except psycopg2.Error as e:
        print(f"Error connecting to database: {e}")
        sys.exit(1)

def get_profile():
    user_id = request.args.get('user_id')
    user = User.query.get(user_id)

    if not user:
        return jsonify({'error': 'User not found'}), 404

    return jsonify({
        'name': user.name,
        'email': user.email,
        'role': user.role
    })

def main():
    db.create_all()
    app.run(debug=True)

    # Add your application logic here
    # Example query:
    # conn = connect_to_db()
    # cursor = conn.cursor()
    # cursor.execute("SELECT * FROM your_table")
    # results = cursor.fetchall()
    # print(results)

    # Close the database connection
    # conn.close()

if __name__ == "__main__":
    main()