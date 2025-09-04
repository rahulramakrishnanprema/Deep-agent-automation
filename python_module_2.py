import os
from flask import Flask, render_template, jsonify
from flask_cors import CORS
import requests
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')
API_BASE_URL = os.getenv('API_BASE_URL', 'http://localhost:5001/api')

class APIError(Exception):
    """Custom exception for API errors"""
    pass

def fetch_user_profile():
    """
    Fetch user profile from API with error handling
    """
    try:
        response = requests.get(
            f"{API_BASE_URL}/user/profile",
            timeout=10,
            headers={'Content-Type': 'application/json'}
        )
        
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 401:
            raise APIError("Authentication failed. Please log in again.")
        elif response.status_code == 404:
            raise APIError("User profile not found.")
        else:
            response.raise_for_status()
            
    except requests.exceptions.Timeout:
        raise APIError("Request timed out. Please try again.")
    except requests.exceptions.ConnectionError:
        raise APIError("Unable to connect to the server. Please check your connection.")
    except requests.exceptions.RequestException as e:
        raise APIError(f"An error occurred: {str(e)}")

@app.route('/')
def dashboard():
    """
    Main dashboard route
    """
    try:
        user_data = fetch_user_profile()
        return render_template('dashboard.html', user=user_data)
    except APIError as e:
        return render_template('error.html', error_message=str(e)), 500
    except Exception as e:
        app.logger.error(f"Unexpected error in dashboard: {str(e)}")
        return render_template('error.html', error_message="An unexpected error occurred."), 500

@app.route('/health')
def health_check():
    """
    Health check endpoint
    """
    return jsonify({"status": "healthy", "service": "user-dashboard"})

@app.errorhandler(404)
def not_found(error):
    return render_template('error.html', error_message="Page not found."), 404

@app.errorhandler(500)
def internal_error(error):
    return render_template('error.html', error_message="Internal server error."), 500

def main():
    """Main function to run the Flask application"""
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)

if __name__ == '__main__':
    main()