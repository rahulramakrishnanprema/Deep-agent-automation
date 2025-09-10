# AEP-4: Basic User Profile API

import logging
import psycopg2

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database connection details
DB_HOST = 'localhost'
DB_NAME = 'user_profiles'
DB_USER = 'admin'
DB_PASSWORD = 'password'

def get_user_profile(user_id):
    try:
        conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASSWORD)
        cursor = conn.cursor()
        
        query = "SELECT name, email, role FROM users WHERE id = %s"
        cursor.execute(query, (user_id,))
        
        profile_data = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        return profile_data
    except psycopg2.Error as e:
        logger.error(f"Error connecting to database: {e}")
        return None

if __name__ == "__main__":
    user_id = 1
    profile_data = get_user_profile(user_id)
    
    if profile_data:
        name, email, role = profile_data
        print(f"Name: {name}, Email: {email}, Role: {role}")
    else:
        print("Error retrieving user profile data.")