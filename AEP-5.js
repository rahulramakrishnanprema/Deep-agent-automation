import { apiClient } from './api-client.js';
import { logger } from './logger.js';
import { theme } from './theme.js';

/**
 * AEP-5: Basic User Dashboard Component
 * Displays user profile information with company styling and API integration
 */
class AEP5Dashboard {
    constructor(containerSelector = '#dashboard-container') {
        this.container = document.querySelector(containerSelector);
        this.userData = null;
        this.isLoading = false;
        
        if (!this.container) {
            logger.error('AEP-5: Dashboard container not found');
            throw new Error('Dashboard container element not found');
        }
        
        this.init();
    }
    
    /**
     * Initialize the dashboard component
     */
    init() {
        this.renderLoadingState();
        this.loadUserProfile();
        this.setupEventListeners();
    }
    
    /**
     * Set up event listeners for the dashboard
     */
    setupEventListeners() {
        // Refresh button functionality
        this.container.addEventListener('click', (e) => {
            if (e.target.classList.contains('aep5-refresh-btn')) {
                this.refreshData();
            }
        });
        
        // Error retry functionality
        this.container.addEventListener('click', (e) => {
            if (e.target.classList.contains('aep5-retry-btn')) {
                this.loadUserProfile();
            }
        });
    }
    
    /**
     * Load user profile data from API
     */
    async loadUserProfile() {
        if (this.isLoading) return;
        
        this.isLoading = true;
        this.renderLoadingState();
        
        try {
            const response = await apiClient.get('/api/user/profile');
            
            if (response.success && response.data) {
                this.userData = response.data;
                this.renderDashboard();
                logger.info('AEP-5: User profile loaded successfully');
            } else {
                throw new Error(response.message || 'Failed to load user profile');
            }
        } catch (error) {
            logger.error('AEP-5: Error loading user profile', error);
            this.renderErrorState(error.message);
        } finally {
            this.isLoading = false;
        }
    }
    
    /**
     * Refresh dashboard data
     */
    async refreshData() {
        await this.loadUserProfile();
    }
    
    /**
     * Render loading state UI
     */
    renderLoadingState() {
        this.container.innerHTML = `
            <div class="aep5-dashboard-loading">
                <div class="aep5-spinner"></div>
                <p>Loading your dashboard...</p>
            </div>
        `;
        
        this.applyStyles();
    }
    
    /**
     * Render error state UI
     * @param {string} errorMessage - The error message to display
     */
    renderErrorState(errorMessage) {
        this.container.innerHTML = `
            <div class="aep5-dashboard-error">
                <div class="aep5-error-icon">⚠️</div>
                <h3>Something went wrong</h3>
                <p>${errorMessage || 'Unable to load dashboard data'}</p>
                <button class="aep5-retry-btn ${theme.buttons.primary}">Try Again</button>
            </div>
        `;
        
        this.applyStyles();
    }
    
    /**
     * Render the main dashboard UI
     */
    renderDashboard() {
        if (!this.userData) {
            this.renderErrorState('No user data available');
            return;
        }
        
        const { name, email, role } = this.userData;
        
        this.container.innerHTML = `
            <div class="aep5-dashboard">
                <div class="aep5-dashboard-header">
                    <h2>User Dashboard</h2>
                    <button class="aep5-refresh-btn ${theme.buttons.secondary}">
                        ↻ Refresh
                    </button>
                </div>
                
                <div class="aep5-profile-card">
                    <div class="aep5-profile-header">
                        <div class="aep5-avatar">${this.getInitials(name)}</div>
                        <h3>Profile Information</h3>
                    </div>
                    
                    <div class="aep5-profile-details">
                        <div class="aep5-detail-row">
                            <span class="aep5-detail-label">Name:</span>
                            <span class="aep5-detail-value">${this.escapeHtml(name)}</span>
                        </div>
                        
                        <div class="aep5-detail-row">
                            <span class="aep5-detail-label">Email:</span>
                            <span class="aep5-detail-value">${this.escapeHtml(email)}</span>
                        </div>
                        
                        <div class="aep5-detail-row">
                            <span class="aep5-detail-label">Role:</span>
                            <span class="aep5-detail-value aep5-role-badge">${this.escapeHtml(role)}</span>
                        </div>
                    </div>
                </div>
                
                <div class="aep5-dashboard-footer">
                    <p>Last updated: ${new Date().toLocaleString()}</p>
                </div>
            </div>
        `;
        
        this.applyStyles();
    }
    
    /**
     * Get user initials from name
     * @param {string} name - The user's full name
     * @returns {string} Initials
     */
    getInitials(name) {
        if (!name) return '??';
        
        return name
            .split(' ')
            .map(part => part.charAt(0).toUpperCase())
            .slice(0, 2)
            .join('');
    }
    
    /**
     * Escape HTML to prevent XSS
     * @param {string} text - Text to escape
     * @returns {string} Escaped text
     */
    escapeHtml(text) {
        if (!text) return '';
        
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    /**
     * Apply company theme styles
     */
    applyStyles() {
        const styleId = 'aep5-dashboard-styles';
        let styleElement = document.getElementById(styleId);
        
        if (!styleElement) {
            styleElement = document.createElement('style');
            styleElement.id = styleId;
            document.head.appendChild(styleElement);
        }
        
        styleElement.textContent = `
            .aep5-dashboard {
                max-width: 600px;
                margin: 0 auto;
                padding: ${theme.spacing.lg};
                font-family: ${theme.fonts.primary};
            }
            
            .aep5-dashboard-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: ${theme.spacing.xl};
            }
            
            .aep5-dashboard-header h2 {
                color: ${theme.colors.primary};
                margin: 0;
                font-size: ${theme.fontSizes.xl};
            }
            
            .aep5-profile-card {
                background: ${theme.colors.background};
                border-radius: ${theme.borderRadius.md};
                padding: ${theme.spacing.xl};
                box-shadow: ${theme.shadows.md};
                border: 1px solid ${theme.colors.border};
            }
            
            .aep5-profile-header {
                display: flex;
                align-items: center;
                margin-bottom: ${theme.spacing.lg};
            }
            
            .aep5-avatar {
                width: 60px;
                height: 60px;
                border-radius: 50%;
                background: ${theme.colors.primary};
                color: white;
                display: flex;
                align-items: center;
                justify-content: center;
                font-weight: bold;
                font-size: ${theme.fontSizes.lg};
                margin-right: ${theme.spacing.md};
            }
            
            .aep5-profile-header h3 {
                margin: 0;
                color: ${theme.colors.textPrimary};
                font-size: ${theme.fontSizes.lg};
            }
            
            .aep5-profile-details {
                display: flex;
                flex-direction: column;
                gap: ${theme.spacing.md};
            }
            
            .aep5-detail-row {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: ${theme.spacing.sm} 0;
                border-bottom: 1px solid ${theme.colors.borderLight};
            }
            
            .aep5-detail-row:last-child {
                border-bottom: none;
            }
            
            .aep5-detail-label {
                font-weight: 600;
                color: ${theme.colors.textSecondary};
            }
            
            .aep5-detail-value {
                color: ${theme.colors.textPrimary};
            }
            
            .aep5-role-badge {
                background: ${theme.colors.accent};
                color: white;
                padding: ${theme.spacing.xs} ${theme.spacing.md};
                border-radius: ${theme.borderRadius.full};
                font-size: ${theme.fontSizes.sm};
                font-weight: 500;
            }
            
            .aep5-dashboard-footer {
                margin-top: ${theme.spacing.lg};
                text-align: center;
                color: ${theme.colors.textMuted};
                font-size: ${theme.fontSizes.sm};
            }
            
            .aep5-dashboard-loading,
            .aep5-dashboard-error {
                text-align: center;
                padding: ${theme.spacing.xl};
                color: ${theme.colors.textPrimary};
            }
            
            .aep5-spinner {
                width: 40px;
                height: 40px;
                border: 3px solid ${theme.colors.borderLight};
                border-top: 3px solid ${theme.colors.primary};
                border-radius: 50%;
                animation: aep5-spin 1s linear infinite;
                margin: 0 auto ${theme.spacing.md};
            }
            
            .aep5-error-icon {
                font-size: ${theme.fontSizes.xl};
                margin-bottom: ${theme.spacing.md};
            }
            
            @keyframes aep5-spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
            
            /* Cross-browser compatibility */
            .aep5-dashboard * {
                box-sizing: border-box;
            }
            
            @media (max-width: 768px) {
                .aep5-dashboard {
                    padding: ${theme.spacing.md};
                }
                
                .aep5-dashboard-header {
                    flex-direction: column;
                    gap: ${theme.spacing.md};
                    text-align: center;
                }
                
                .aep5-profile-header {
                    flex-direction: column;
                    text-align: center;
                    gap: ${theme.spacing.md};
                }
                
                .aep5-avatar {
                    margin-right: 0;
                }
                
                .aep5-detail-row {
                    flex-direction: column;
                    align-items: flex-start;
                    gap: ${theme.spacing.xs};
                }
            }
            
            /* IE11 fallbacks */
            @media all and (-ms-high-contrast: none), (-ms-high-contrast: active) {
                .aep5-dashboard {
                    display: block;
                }
                
                .aep5-profile-header {
                    display: block;
                }
                
                .aep5-profile-details {
                    display: block;
                }
                
                .aep5-detail-row {
                    display: block;
                }
            }
        `;
    }
    
    /**
     * Get current user data
     * @returns {Object|null} User data object
     */
    getUserData() {
        return this.userData;
    }
    
    /**
     * Destroy the dashboard component and clean up
     */
    destroy() {
        this.container.innerHTML = '';
        const styleElement = document.getElementById('aep5-dashboard-styles');
        if (styleElement) {
            styleElement.remove();
        }
        
        logger.info('AEP-5: Dashboard component destroyed');
    }
}

// Export for use in other modules
export { AEP5Dashboard };

// Auto-initialize if script is loaded directly (for non-module environments)
if (typeof window !== 'undefined' && !window.AEP5_DASHBOARD_INITIALIZED) {
    window.AEP5_DASHBOARD_INITIALIZED = true;
    
    document.addEventListener('DOMContentLoaded', () => {
        try {
            window.aep5Dashboard = new AEP5Dashboard();
            logger.info('AEP-5: Dashboard auto-initialized');
        } catch (error) {
            logger.error('AEP-5: Failed to auto-initialize dashboard', error);
        }
    });
}