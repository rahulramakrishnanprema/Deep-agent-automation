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
        logger.error(f"Error fetching user profile: {e}")
        return None

# Unit tests
def test_get_user_profile():
    user_id = 1
    profile_data = get_user_profile(user_id)
    assert profile_data == ('John Doe', 'john.doe@example.com', 'user')

if __name__ == "__main__":
    user_id = 1
    profile_data = get_user_profile(user_id)
    if profile_data:
        print(f"User Profile Data: {profile_data}")
    else:
        print("Failed to fetch user profile data.")