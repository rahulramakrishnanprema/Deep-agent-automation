// ipm_55_main.js - Main JavaScript file for IPM Portfolio Management System
// Handles frontend functionality including API calls, UI interactions, and dashboard rendering

// Global variables
let currentPortfolio = null;
let advisorySignals = [];
let marketData = [];

// DOM Ready event
document.addEventListener('DOMContentLoaded', function() {
    initializeApplication();
    setupEventListeners();
    
    // Check authentication status
    checkAuthStatus();
});

/**
 * Initialize the application
 */
function initializeApplication() {
    console.log('IPM Portfolio Management System initialized');
    
    // Load initial data if authenticated
    if (isAuthenticated()) {
        loadDashboardData();
    }
}

/**
 * Set up event listeners for UI interactions
 */
function setupEventListeners() {
    // Login form submission
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }

    // Portfolio form submission
    const portfolioForm = document.getElementById('portfolioForm');
    if (portfolioForm) {
        portfolioForm.addEventListener('submit', handlePortfolioSubmit);
    }

    // Logout button
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', handleLogout);
    }

    // Refresh data button
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', loadDashboardData);
    }
}

/**
 * Check authentication status and update UI accordingly
 */
async function checkAuthStatus() {
    try {
        const response = await fetch('/api/auth/status', {
            method: 'GET',
            credentials: 'include'
        });

        if (response.ok) {
            const data = await response.json();
            updateUIBasedOnAuth(data.authenticated, data.userRole);
        } else {
            updateUIBasedOnAuth(false, 'guest');
        }
    } catch (error) {
        console.error('Auth status check failed:', error);
        updateUIBasedOnAuth(false, 'guest');
    }
}

/**
 * Update UI based on authentication status
 */
function updateUIBasedOnAuth(isAuthenticated, userRole) {
    const authElements = document.querySelectorAll('.auth-only');
    const guestElements = document.querySelectorAll('.guest-only');
    const advisorElements = document.querySelectorAll('.advisor-only');

    if (isAuthenticated) {
        authElements.forEach(el => el.style.display = 'block');
        guestElements.forEach(el => el.style.display = 'none');
        
        if (userRole === 'advisor') {
            advisorElements.forEach(el => el.style.display = 'block');
            loadDashboardData();
        } else {
            advisorElements.forEach(el => el.style.display = 'none');
        }
    } else {
        authElements.forEach(el => el.style.display = 'none');
        guestElements.forEach(el => el.style.display = 'block');
        advisorElements.forEach(el => el.style.display = 'none');
    }
}

/**
 * Check if user is authenticated
 */
function isAuthenticated() {
    // This is a simplified check - in production, use proper session management
    return document.cookie.includes('session_id');
}

/**
 * Handle login form submission
 */
async function handleLogin(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const credentials = {
        username: formData.get('username'),
        password: formData.get('password')
    };

    try {
        const response = await fetch('/api/auth/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(credentials),
            credentials: 'include'
        });

        if (response.ok) {
            const data = await response.json();
            showNotification('Login successful!', 'success');
            updateUIBasedOnAuth(true, data.role);
        } else {
            showNotification('Login failed. Please check your credentials.', 'error');
        }
    } catch (error) {
        console.error('Login error:', error);
        showNotification('Login failed. Please try again.', 'error');
    }
}

/**
 * Handle logout
 */
async function handleLogout() {
    try {
        await fetch('/api/auth/logout', {
            method: 'POST',
            credentials: 'include'
        });
        
        showNotification('Logged out successfully', 'success');
        updateUIBasedOnAuth(false, 'guest');
    } catch (error) {
        console.error('Logout error:', error);
        showNotification('Logout failed', 'error');
    }
}

/**
 * Load dashboard data for authenticated users
 */
async function loadDashboardData() {
    if (!isAuthenticated()) return;

    try {
        showLoadingState(true);
        
        // Load portfolio data
        const portfolioResponse = await fetch('/api/portfolio', {
            credentials: 'include'
        });
        
        if (portfolioResponse.ok) {
            const portfolioData = await portfolioResponse.json();
            currentPortfolio = portfolioData;
            renderPortfolio(portfolioData);
        }

        // Load advisory signals
        const signalsResponse = await fetch('/api/advisory/signals', {
            credentials: 'include'
        });
        
        if (signalsResponse.ok) {
            const signalsData = await signalsResponse.json();
            advisorySignals = signalsData;
            renderAdvisorySignals(signalsData);
        }

        // Load market data
        const marketResponse = await fetch('/api/market/data', {
            credentials: 'include'
        });
        
        if (marketResponse.ok) {
            const marketDataResponse = await marketResponse.json();
            marketData = marketDataResponse;
            renderMarketData(marketDataResponse);
        }

        // Load technical indicators
        await loadTechnicalIndicators();

    } catch (error) {
        console.error('Failed to load dashboard data:', error);
        showNotification('Failed to load dashboard data', 'error');
    } finally {
        showLoadingState(false);
    }
}

/**
 * Handle portfolio form submission
 */
async function handlePortfolioSubmit(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const portfolioData = {
        stock_symbol: formData.get('stock_symbol'),
        quantity: parseInt(formData.get('quantity')),
        purchase_price: parseFloat(formData.get('purchase_price')),
        sector: formData.get('sector')
    };

    try {
        const response = await fetch('/api/portfolio', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(portfolioData),
            credentials: 'include'
        });

        if (response.ok) {
            showNotification('Portfolio updated successfully', 'success');
            event.target.reset();
            loadDashboardData(); // Refresh data
        } else {
            showNotification('Failed to update portfolio', 'error');
        }
    } catch (error) {
        console.error('Portfolio update error:', error);
        showNotification('Failed to update portfolio', 'error');
    }
}

/**
 * Render portfolio data
 */
function renderPortfolio(portfolioData) {
    const portfolioContainer = document.getElementById('portfolioContainer');
    if (!portfolioContainer) return;

    if (portfolioData && portfolioData.length > 0) {
        const html = portfolioData.map(stock => `
            <div class="col-md-4 mb-3">
                <div class="card h-100">
                    <div class="card-body">
                        <h5 class="card-title">${stock.stock_symbol}</h5>
                        <p class="card-text">
                            Quantity: ${stock.quantity}<br>
                            Purchase Price: ₹${stock.purchase_price.toFixed(2)}<br>
                            Sector: ${stock.sector}<br>
                            Current Value: ₹${(stock.current_price * stock.quantity).toFixed(2)}
                        </p>
                    </div>
                </div>
            </div>
        `).join('');

        portfolioContainer.innerHTML = html;
    } else {
        portfolioContainer.innerHTML = `
            <div class="col-12">
                <div class="alert alert-info">
                    No portfolio data available. Add some stocks to get started.
                </div>
            </div>
        `;
    }
}

/**
 * Render advisory signals
 */
function renderAdvisorySignals(signalsData) {
    const signalsContainer = document.getElementById('signalsContainer');
    if (!signalsContainer) return;

    if (signalsData && signalsData.length > 0) {
        const html = signalsData.map(signal => {
            const badgeClass = signal.signal === 'Buy' ? 'success' : 
                             signal.signal === 'Sell' ? 'danger' : 'warning';
            
            return `
                <div class="col-md-6 mb-3">
                    <div class="card h-100">
                        <div class="card-body">
                            <h5 class="card-title">${signal.stock_symbol}</h5>
                            <span class="badge bg-${badgeClass}">${signal.signal}</span>
                            <p class="card-text mt-2">
                                Confidence: ${signal.confidence}%<br>
                                Reason: ${signal.reason}<br>
                                Last Updated: ${new Date(signal.timestamp).toLocaleDateString()}
                            </p>
                        </div>
                    </div>
                </div>
            `;
        }).join('');

        signalsContainer.innerHTML = html;
    } else {
        signalsContainer.innerHTML = `
            <div class="col-12">
                <div class="alert alert-info">
                    No advisory signals available.
                </div>
            </div>
        `;
    }
}

/**
 * Render market data
 */
function renderMarketData(marketData) {
    const marketContainer = document.getElementById('marketContainer');
    if (!marketContainer) return;

    if (marketData && marketData.length > 0) {
        const html = marketData.map(data => `
            <tr>
                <td>${data.sector}</td>
                <td>${data.growth_score}</td>
                <td>${data.sentiment}</td>
                <td>${data.news_count}</td>
                <td>${new Date(data.last_updated).toLocaleDateString()}</td>
            </tr>
        `).join('');

        marketContainer.innerHTML = html;
    } else {
        marketContainer.innerHTML = `
            <tr>
                <td colspan="5" class="text-center">No market data available</td>
            </tr>
        `;
    }
}

/**
 * Load technical indicators
 */
async function loadTechnicalIndicators() {
    try {
        const response = await fetch('/api/technical/indicators', {
            credentials: 'include'
        });

        if (response.ok) {
            const indicators = await response.json();
            renderTechnicalIndicators(indicators);
        }
    } catch (error) {
        console.error('Failed to load technical indicators:', error);
    }
}

/**
 * Render technical indicators
 */
function renderTechnicalIndicators(indicators) {
    const indicatorsContainer = document.getElementById('indicatorsContainer');
    if (!indicatorsContainer) return;

    if (indicators && indicators.length > 0) {
        const html = indicators.map(indicator => `
            <div class="col-md-4 mb-3">
                <div class="card">
                    <div class="card-body">
                        <h6 class="card-title">${indicator.stock_symbol}</h6>
                        <p class="mb-1">SMA: ${indicator.sma}</p>
                        <p class="mb-1">RSI: ${indicator.rsi}</p>
                        <p class="mb-0">Trend: ${indicator.trend}</p>
                    </div>
                </div>
            </div>
        `).join('');

        indicatorsContainer.innerHTML = html;
    }
}

/**
 * Show loading state
 */
function showLoadingState(show) {
    const loadingElement = document.getElementById('loadingIndicator');
    const contentElement = document.getElementById('contentArea');
    
    if (loadingElement && contentElement) {
        loadingElement.style.display = show ? 'block' : 'none';
        contentElement.style.display = show ? 'none' : 'block';
    }
}

/**
 * Show notification
 */
function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show`;
    notification.style.position = 'fixed';
    notification.style.top = '20px';
    notification.style.right = '20px';
    notification.style.zIndex = '1050';
    notification.style.minWidth = '300px';
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;

    // Add to document
    document.body.appendChild(notification);

    // Auto remove after 5 seconds
    setTimeout(() => {
        if (notification.parentNode) {
            notification.parentNode.removeChild(notification);
        }
    }, 5000);
}

/**
 * Format currency
 */
function formatCurrency(amount) {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR'
    }).format(amount);
}

/**
 * Format percentage
 */
function formatPercentage(value) {
    return `${value.toFixed(2)}%`;
}

// Export functions for testing (if needed)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        initializeApplication,
        handleLogin,
        handlePortfolioSubmit,
        formatCurrency,
        formatPercentage
    };
}