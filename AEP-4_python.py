# AEP-4: Basic User Profile API

import logging
import psycopg2

# Database connection details
DB_HOST = "localhost"
DB_NAME = "user_profiles"
DB_USER = "admin"
DB_PASSWORD = "password"

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
        logging.error(f"Error connecting to database: {e}")
        return None

# Unit tests
def test_get_user_profile():
    user_id = 1
    profile_data = get_user_profile(user_id)
    
    assert profile_data is not None
    assert len(profile_data) == 3
    assert isinstance(profile_data[0], str)
    assert isinstance(profile_data[1], str)
    assert isinstance(profile_data[2], str)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    test_get_user_profile()