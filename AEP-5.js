import React, { useState, useEffect } from 'react';
import { getUserProfile } from '../services/apiService';
import { logger } from '../utils/logger';
import './AEP-5.css';

/**
 * AEP-5: Basic User Dashboard Component
 * Displays user profile information including name, email, and role
 * Integrates with user profile API and applies company theme styling
 */
const AEP5Dashboard = () => {
  const [userProfile, setUserProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchUserProfile();
  }, []);

  /**
   * Fetches user profile data from the API
   * Handles loading states and error scenarios
   */
  const fetchUserProfile = async () => {
    try {
      setLoading(true);
      setError(null);
      
      logger.info('AEP-5: Fetching user profile data');
      const profileData = await getUserProfile();
      
      if (profileData && profileData.success) {
        setUserProfile(profileData.data);
        logger.info('AEP-5: User profile data fetched successfully');
      } else {
        throw new Error(profileData?.message || 'Failed to fetch user profile');
      }
    } catch (err) {
      const errorMessage = err.response?.data?.message || err.message || 'Unknown error occurred';
      setError(errorMessage);
      logger.error('AEP-5: Error fetching user profile', { error: errorMessage });
    } finally {
      setLoading(false);
    }
  };

  /**
   * Renders loading state UI
   */
  const renderLoadingState = () => (
    <div className="aep5-loading-container" data-testid="aep5-loading">
      <div className="aep5-loading-spinner"></div>
      <p className="aep5-loading-text">Loading your dashboard...</p>
    </div>
  );

  /**
   * Renders error state UI
   */
  const renderErrorState = () => (
    <div className="aep5-error-container" data-testid="aep5-error">
      <div className="aep5-error-icon">⚠️</div>
      <h3 className="aep5-error-title">Oops! Something went wrong</h3>
      <p className="aep5-error-message">{error}</p>
      <button 
        className="aep5-retry-button"
        onClick={fetchUserProfile}
        aria-label="Retry loading dashboard"
      >
        Try Again
      </button>
    </div>
  );

  /**
   * Renders user profile information
   */
  const renderProfileInfo = () => (
    <div className="aep5-profile-container" data-testid="aep5-profile">
      <header className="aep5-profile-header">
        <h1 className="aep5-welcome-title">Welcome to Your Dashboard</h1>
        <p className="aep5-welcome-subtitle">Here's your profile information</p>
      </header>
      
      <div className="aep5-profile-card">
        <div className="aep5-profile-avatar">
          {userProfile?.name?.charAt(0)?.toUpperCase() || 'U'}
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
            <span className="aep5-detail-value">{userProfile?.role || 'Not specified'}</span>
          </div>
        </div>
      </div>
      
      <footer className="aep5-profile-footer">
        <p className="aep5-footer-text">
          Last updated: {new Date().toLocaleDateString()}
        </p>
      </footer>
    </div>
  );

  return (
    <div className="aep5-dashboard-container">
      <div className="aep5-content-wrapper">
        {loading && renderLoadingState()}
        {error && !loading && renderErrorState()}
        {!loading && !error && userProfile && renderProfileInfo()}
      </div>
    </div>
  );
};

export default AEP5Dashboard;