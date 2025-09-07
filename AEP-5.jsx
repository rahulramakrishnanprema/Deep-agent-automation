import React, { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import './AEP-5.css'; // Importing the associated CSS file

/**
 * AEP-5: User Dashboard Component
 * Displays user profile information (name, email, role) fetched from an API.
 * Styled with company theme and includes comprehensive error handling.
 */
const UserDashboard = ({ userId, apiEndpoint }) => {
  const [userProfile, setUserProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch user profile data from API
  useEffect(() => {
    const fetchUserProfile = async () => {
      try {
        setLoading(true);
        setError(null);
        
        const response = await fetch(`${apiEndpoint}/users/${userId}`, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`,
          },
        });

        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        setUserProfile(data);
      } catch (err) {
        console.error('AEP-5 Error fetching user profile:', err);
        setError('Failed to load user profile. Please try again later.');
      } finally {
        setLoading(false);
      }
    };

    fetchUserProfile();
  }, [userId, apiEndpoint]);

  // Loading state
  if (loading) {
    return (
      <div className="aep5-dashboard-container" data-testid="aep5-dashboard-loading">
        <div className="aep5-loading-spinner"></div>
        <p>Loading your dashboard...</p>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="aep5-dashboard-container" data-testid="aep5-dashboard-error">
        <div className="aep5-error-message">
          <h2>Oops! Something went wrong.</h2>
          <p>{error}</p>
          <button 
            className="aep5-retry-button"
            onClick={() => window.location.reload()}
          >
            Try Again
          </button>
        </div>
      </div>
    );
  }

  // Main dashboard content
  return (
    <div className="aep5-dashboard-container" data-testid="aep5-dashboard">
      <header className="aep5-dashboard-header">
        <h1>User Dashboard</h1>
        <p>Welcome to your personalized dashboard</p>
      </header>
      
      <div className="aep5-profile-card">
        <div className="aep5-profile-header">
          <h2>Profile Information</h2>
          <div className="aep5-profile-avatar">
            {userProfile?.name?.charAt(0) || 'U'}
          </div>
        </div>
        
        <div className="aep5-profile-details">
          <div className="aep5-detail-row">
            <span className="aep5-detail-label">Name:</span>
            <span className="aep5-detail-value">{userProfile?.name || 'Not provided'}</span>
          </div>
          
          <div className="aep5-detail-row">
            <span className="aep5-detail-label">Email:</span>
            <span className="aep5-detail-value">{userProfile?.email || 'Not provided'}</span>
          </div>
          
          <div className="aep5-detail-row">
            <span className="aep5-detail-label">Role:</span>
            <span className="aep5-detail-value aep5-role-badge">
              {userProfile?.role || 'User'}
            </span>
          </div>
        </div>
        
        <div className="aep5-profile-footer">
          <p className="aep5-last-updated">
            Last updated: {new Date().toLocaleDateString()}
          </p>
        </div>
      </div>
    </div>
  );
};

// PropTypes for type checking and documentation
UserDashboard.propTypes = {
  userId: PropTypes.oneOfType([PropTypes.string, PropTypes.number]).isRequired,
  apiEndpoint: PropTypes.string.isRequired,
};

// Default props for fallback values
UserDashboard.defaultProps = {
  apiEndpoint: process.env.REACT_APP_API_BASE_URL || 'https://api.example.com',
};

export default UserDashboard;