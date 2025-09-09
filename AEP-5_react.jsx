// AEP-5: Basic User Dashboard UI
import React, { useState, useEffect } from 'react';
import './AEP-5_styles.css';

const UserDashboard = () => {
  const [userData, setUserData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchUserProfile();
  }, []);

  const fetchUserProfile = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await fetch('/api/user/profile', {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('authToken')}`,
          'Content-Type': 'application/json',
        },
        credentials: 'include'
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      
      if (data.success) {
        setUserData(data.user);
      } else {
        throw new Error(data.message || 'Failed to fetch user profile');
      }
    } catch (err) {
      console.error('AEP-5 Error fetching user profile:', err);
      setError(err.message || 'An error occurred while loading your profile');
    } finally {
      setLoading(false);
    }
  };

  const handleRetry = () => {
    fetchUserProfile();
  };

  if (loading) {
    return (
      <div className="dashboard-container" data-testid="dashboard-loading">
        <div className="loading-spinner">
          <div className="spinner"></div>
          <p>Loading your profile...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="dashboard-container" data-testid="dashboard-error">
        <div className="error-state">
          <h2>Oops! Something went wrong</h2>
          <p>{error}</p>
          <button onClick={handleRetry} className="retry-button">
            Try Again
          </button>
        </div>
      </div>
    );
  }

  if (!userData) {
    return (
      <div className="dashboard-container" data-testid="dashboard-no-data">
        <div className="no-data">
          <h2>No profile data available</h2>
          <p>Please try refreshing the page or contact support.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="dashboard-container" data-testid="user-dashboard">
      <div className="dashboard-header">
        <h1>User Dashboard</h1>
        <p>Welcome to your personal dashboard</p>
      </div>
      
      <div className="profile-card">
        <div className="profile-header">
          <h2>Profile Information</h2>
        </div>
        
        <div className="profile-content">
          <div className="profile-item">
            <label>Name:</label>
            <span>{userData.name || 'Not provided'}</span>
          </div>
          
          <div className="profile-item">
            <label>Email:</label>
            <span>{userData.email || 'Not provided'}</span>
          </div>
          
          <div className="profile-item">
            <label>Role:</label>
            <span className={`role-badge role-${userData.role?.toLowerCase() || 'unknown'}`}>
              {userData.role || 'Unknown'}
            </span>
          </div>
        </div>
        
        <div className="profile-footer">
          <p className="last-updated">
            Last updated: {new Date().toLocaleDateString()}
          </p>
        </div>
      </div>
    </div>
  );
};

export default UserDashboard;