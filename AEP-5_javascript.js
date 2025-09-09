// AEP-5: Basic User Dashboard UI
// This file contains the JavaScript code for the user dashboard component

class UserDashboard {
    constructor(apiEndpoint = '/api/user/profile') {
        this.apiEndpoint = apiEndpoint;
        this.userData = null;
        this.init();
    }

    async init() {
        try {
            await this.loadUserProfile();
            this.renderDashboard();
            this.bindEvents();
        } catch (error) {
            this.handleError(error);
        }
    }

    async loadUserProfile() {
        try {
            const response = await fetch(this.apiEndpoint, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.getAuthToken()}`
                },
                credentials: 'include'
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            
            if (!data || typeof data !== 'object') {
                throw new Error('Invalid response format from API');
            }

            this.userData = {
                name: data.name || 'Not provided',
                email: data.email || 'Not provided',
                role: data.role || 'Not specified'
            };

            console.log('User profile loaded successfully:', this.userData);
            
        } catch (error) {
            console.error('Failed to load user profile:', error);
            throw new Error(`Unable to load profile: ${error.message}`);
        }
    }

    getAuthToken() {
        // Retrieve authentication token from cookies or localStorage
        return localStorage.getItem('authToken') || 
               document.cookie.replace(/(?:(?:^|.*;\s*)authToken\s*=\s*([^;]*).*$)|^.*$/, "$1");
    }

    renderDashboard() {
        const dashboardElement = document.getElementById('userDashboard');
        
        if (!dashboardElement) {
            throw new Error('Dashboard container element not found');
        }

        if (!this.userData) {
            dashboardElement.innerHTML = this.getLoadingTemplate();
            return;
        }

        dashboardElement.innerHTML = this.getDashboardTemplate();
    }

    getLoadingTemplate() {
        return `
            <div class="dashboard-loading">
                <div class="loading-spinner"></div>
                <p>Loading your profile...</p>
            </div>
        `;
    }

    getDashboardTemplate() {
        return `
            <div class="user-dashboard">
                <div class="dashboard-header">
                    <h2>User Dashboard</h2>
                </div>
                <div class="profile-card">
                    <div class="profile-header">
                        <div class="profile-avatar">
                            ${this.getInitials(this.userData.name)}
                        </div>
                        <h3>${this.escapeHTML(this.userData.name)}</h3>
                    </div>
                    <div class="profile-details">
                        <div class="detail-item">
                            <label>Email:</label>
                            <span>${this.escapeHTML(this.userData.email)}</span>
                        </div>
                        <div class="detail-item">
                            <label>Role:</label>
                            <span class="role-badge">${this.escapeHTML(this.userData.role)}</span>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    getInitials(fullName) {
        if (!fullName || fullName === 'Not provided') return 'U';
        return fullName
            .split(' ')
            .map(name => name[0])
            .join('')
            .toUpperCase()
            .substring(0, 2);
    }

    escapeHTML(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    bindEvents() {
        // Add event listeners for any interactive elements
        // Example: document.addEventListener('click', this.handleClick.bind(this));
    }

    handleError(error) {
        console.error('Dashboard error:', error);
        
        const dashboardElement = document.getElementById('userDashboard');
        if (dashboardElement) {
            dashboardElement.innerHTML = `
                <div class="dashboard-error">
                    <div class="error-icon">⚠️</div>
                    <h3>Something went wrong</h3>
                    <p>Unable to load your dashboard. Please try again later.</p>
                    <button onclick="window.location.reload()" class="retry-btn">
                        Retry
                    </button>
                </div>
            `;
        }

        // Optional: Send error to monitoring service
        this.reportError(error);
    }

    reportError(error) {
        // Implement error reporting to external service
        // Example: Sentry.captureException(error);
    }

    refresh() {
        this.userData = null;
        this.init();
    }

    // Public method to get current user data
    getUserData() {
        return this.userData;
    }
}

// Initialize dashboard when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    try {
        window.userDashboard = new UserDashboard();
    } catch (error) {
        console.error('Failed to initialize dashboard:', error);
    }
});

// Export for module usage if applicable
if (typeof module !== 'undefined' && module.exports) {
    module.exports = UserDashboard;
}