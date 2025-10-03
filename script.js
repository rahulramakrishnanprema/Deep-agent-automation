// script.js - Frontend JavaScript for Portfolio Management Application
// This file handles frontend logic including API calls, dynamic UI updates, and user interactions

// Global variables
let currentUser = null;
let portfolioData = [];
let advisorySignals = [];

// DOM Content Loaded Event Listener
document.addEventListener('DOMContentLoaded', function() {
    initializeApplication();
});

// Initialize the application
function initializeApplication() {
    checkAuthenticationStatus();
    setupEventListeners();
    loadInitialData();
}

// Check if user is authenticated
async function checkAuthenticationStatus() {
    try {
        const response = await fetch('/api/auth/status', {
            credentials: 'include'
        });
        
        if (response.ok) {
            const userData = await response.json();
            currentUser = userData;
            updateUIForUserRole(userData.role);
        } else {
            redirectToLogin();
        }
    } catch (error) {
        console.error('Authentication check failed:', error);
        redirectToLogin();
    }
}

// Setup event listeners
function setupEventListeners() {
    // Login form submission
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }

    // Logout button
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', handleLogout);
    }

    // Portfolio refresh button
    const refreshBtn = document.getElementById('refreshPortfolio');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', loadPortfolioData);
    }

    // Advisor dashboard toggle
    const advisorToggle = document.getElementById('advisorDashboardToggle');
    if (advisorToggle) {
        advisorToggle.addEventListener('click', toggleAdvisorDashboard);
    }
}

// Handle user login
async function handleLogin(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const credentials = {
        email: formData.get('email'),
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
            const userData = await response.json();
            currentUser = userData;
            updateUIForUserRole(userData.role);
            window.location.href = '/dashboard';
        } else {
            showNotification('Login failed. Please check your credentials.', 'error');
        }
    } catch (error) {
        console.error('Login error:', error);
        showNotification('Login failed. Please try again.', 'error');
    }
}

// Handle user logout
async function handleLogout() {
    try {
        await fetch('/api/auth/logout', {
            method: 'POST',
            credentials: 'include'
        });
        
        currentUser = null;
        redirectToLogin();
    } catch (error) {
        console.error('Logout error:', error);
    }
}

// Load initial data based on user role
async function loadInitialData() {
    if (currentUser) {
        await loadPortfolioData();
        
        if (currentUser.role === 'advisor') {
            await loadAdvisorySignals();
            await loadVisualReports();
        }
    }
}

// Load portfolio data from backend
async function loadPortfolioData() {
    try {
        showLoading('portfolioSection');
        
        const response = await fetch('/api/portfolio', {
            credentials: 'include'
        });
        
        if (response.ok) {
            portfolioData = await response.json();
            renderPortfolioData(portfolioData);
        } else {
            throw new Error('Failed to load portfolio data');
        }
    } catch (error) {
        console.error('Error loading portfolio:', error);
        showNotification('Failed to load portfolio data', 'error');
        renderPortfolioData(getDummyPortfolioData());
    } finally {
        hideLoading('portfolioSection');
    }
}

// Load advisory signals
async function loadAdvisorySignals() {
    if (currentUser?.role !== 'advisor') return;

    try {
        showLoading('advisorySection');
        
        const response = await fetch('/api/advisory/signals', {
            credentials: 'include'
        });
        
        if (response.ok) {
            advisorySignals = await response.json();
            renderAdvisorySignals(advisorySignals);
        } else {
            throw new Error('Failed to load advisory signals');
        }
    } catch (error) {
        console.error('Error loading advisory signals:', error);
        showNotification('Failed to load advisory signals', 'error');
        renderAdvisorySignals(getDummyAdvisorySignals());
    } finally {
        hideLoading('advisorySection');
    }
}

// Load visual reports for advisors
async function loadVisualReports() {
    if (currentUser?.role !== 'advisor') return;

    try {
        showLoading('reportsSection');
        
        const response = await fetch('/api/reports/analytics', {
            credentials: 'include'
        });
        
        if (response.ok) {
            const reportsData = await response.json();
            renderVisualReports(reportsData);
        } else {
            throw new Error('Failed to load visual reports');
        }
    } catch (error) {
        console.error('Error loading reports:', error);
        showNotification('Failed to load visual reports', 'error');
    } finally {
        hideLoading('reportsSection');
    }
}

// Render portfolio data to UI
function renderPortfolioData(data) {
    const portfolioContainer = document.getElementById('portfolioContainer');
    if (!portfolioContainer) return;

    portfolioContainer.innerHTML = data.map(stock => `
        <div class="col-md-4 mb-4">
            <div class="card h-100">
                <div class="card-body">
                    <h5 class="card-title">${stock.symbol}</h5>
                    <h6 class="card-subtitle mb-2 text-muted">${stock.name}</h6>
                    <p class="card-text">
                        Quantity: ${stock.quantity}<br>
                        Avg Price: ₹${stock.average_price}<br>
                        Current Price: ₹${stock.current_price}<br>
                        P&L: <span class="${stock.pl_percentage >= 0 ? 'text-success' : 'text-danger'}">
                            ${stock.pl_percentage >= 0 ? '+' : ''}${stock.pl_percentage}%
                        </span>
                    </p>
                </div>
            </div>
        </div>
    `).join('');
}

// Render advisory signals
function renderAdvisorySignals(signals) {
    const signalsContainer = document.getElementById('advisorySignalsContainer');
    if (!signalsContainer) return;

    signalsContainer.innerHTML = signals.map(signal => {
        const signalClass = getSignalClass(signal.recommendation);
        return `
            <div class="col-md-6 mb-3">
                <div class="card">
                    <div class="card-header ${signalClass}">
                        <strong>${signal.symbol}</strong> - ${signal.recommendation}
                    </div>
                    <div class="card-body">
                        <p><strong>Reasoning:</strong> ${signal.reasoning}</p>
                        <p><strong>Confidence:</strong> ${signal.confidence}%</p>
                        <p><strong>Last Updated:</strong> ${new Date(signal.timestamp).toLocaleString()}</p>
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

// Render visual reports
function renderVisualReports(reportsData) {
    const reportsContainer = document.getElementById('visualReportsContainer');
    if (!reportsContainer) return;

    // This would typically involve chart rendering libraries like Chart.js
    // For now, we'll create a simple placeholder
    reportsContainer.innerHTML = `
        <div class="row">
            <div class="col-md-6 mb-4">
                <div class="card">
                    <div class="card-header">
                        <h5>Portfolio Performance</h5>
                    </div>
                    <div class="card-body">
                        <canvas id="performanceChart" width="400" height="200"></canvas>
                    </div>
                </div>
            </div>
            <div class="col-md-6 mb-4">
                <div class="card">
                    <div class="card-header">
                        <h5>Sector Allocation</h5>
                    </div>
                    <div class="card-body">
                        <canvas id="sectorChart" width="400" height="200"></canvas>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Initialize charts (would be implemented with Chart.js)
    initializeCharts();
}

// Get CSS class for signal recommendation
function getSignalClass(recommendation) {
    const classes = {
        'Buy': 'bg-success text-white',
        'Hold': 'bg-warning text-dark',
        'Sell': 'bg-danger text-white'
    };
    return classes[recommendation] || 'bg-secondary text-white';
}

// Update UI based on user role
function updateUIForUserRole(role) {
    // Show/hide advisor-specific elements
    const advisorElements = document.querySelectorAll('.advisor-only');
    advisorElements.forEach(element => {
        element.style.display = role === 'advisor' ? 'block' : 'none';
    });

    // Update user display
    const userDisplay = document.getElementById('userDisplay');
    if (userDisplay) {
        userDisplay.textContent = `Logged in as: ${currentUser?.email} (${role})`;
    }
}

// Toggle advisor dashboard
function toggleAdvisorDashboard() {
    const dashboard = document.getElementById('advisorDashboard');
    if (dashboard) {
        dashboard.classList.toggle('d-none');
    }
}

// Show loading indicator
function showLoading(sectionId) {
    const section = document.getElementById(sectionId);
    if (section) {
        const loadingElement = section.querySelector('.loading-spinner') || createLoadingElement();
        section.appendChild(loadingElement);
    }
}

// Hide loading indicator
function hideLoading(sectionId) {
    const section = document.getElementById(sectionId);
    if (section) {
        const loadingElement = section.querySelector('.loading-spinner');
        if (loadingElement) {
            loadingElement.remove();
        }
    }
}

// Create loading element
function createLoadingElement() {
    const div = document.createElement('div');
    div.className = 'loading-spinner text-center my-4';
    div.innerHTML = `
        <div class="spinner-border text-primary" role="status">
            <span class="visually-hidden">Loading...</span>
        </div>
        <p class="mt-2">Loading...</p>
    `;
    return div;
}

// Show notification
function showNotification(message, type = 'info') {
    // Create toast notification
    const toastContainer = document.getElementById('toastContainer') || createToastContainer();
    const toastId = 'toast-' + Date.now();
    
    const toastHtml = `
        <div class="toast align-items-center text-white bg-${type === 'error' ? 'danger' : type} border-0" 
             role="alert" aria-live="assertive" aria-atomic="true" id="${toastId}">
            <div class="d-flex">
                <div class="toast-body">
                    ${message}
                </div>
                <button type="button" class="btn-close btn-close-white me-2 m-auto" 
                        data-bs-dismiss="toast" aria-label="Close"></button>
            </div>
        </div>
    `;
    
    toastContainer.insertAdjacentHTML('beforeend', toastHtml);
    
    // Show the toast
    const toastElement = document.getElementById(toastId);
    const toast = new bootstrap.Toast(toastElement);
    toast.show();
    
    // Remove toast after it hides
    toastElement.addEventListener('hidden.bs.toast', () => {
        toastElement.remove();
    });
}

// Create toast container if it doesn't exist
function createToastContainer() {
    const container = document.createElement('div');
    container.id = 'toastContainer';
    container.className = 'toast-container position-fixed top-0 end-0 p-3';
    container.style.zIndex = '9999';
    document.body.appendChild(container);
    return container;
}

// Redirect to login page
function redirectToLogin() {
    if (!window.location.pathname.includes('login')) {
        window.location.href = '/login';
    }
}

// Dummy data fallbacks
function getDummyPortfolioData() {
    return [
        {
            symbol: 'RELIANCE',
            name: 'Reliance Industries Ltd.',
            quantity: 50,
            average_price: 2450.75,
            current_price: 2678.50,
            pl_percentage: 9.3
        },
        {
            symbol: 'INFY',
            name: 'Infosys Ltd.',
            quantity: 75,
            average_price: 1450.25,
            current_price: 1520.75,
            pl_percentage: 4.9
        },
        {
            symbol: 'HDFCBANK',
            name: 'HDFC Bank Ltd.',
            quantity: 30,
            average_price: 1567.80,
            current_price: 1489.25,
            pl_percentage: -5.0
        }
    ];
}

function getDummyAdvisorySignals() {
    return [
        {
            symbol: 'RELIANCE',
            recommendation: 'Buy',
            reasoning: 'Strong technical indicators and positive sector outlook',
            confidence: 85,
            timestamp: new Date().toISOString()
        },
        {
            symbol: 'INFY',
            recommendation: 'Hold',
            reasoning: 'Stable performance but limited upside potential',
            confidence: 70,
            timestamp: new Date().toISOString()
        },
        {
            symbol: 'HDFCBANK',
            recommendation: 'Sell',
            reasoning: 'Technical breakdown and sector headwinds',
            confidence: 78,
            timestamp: new Date().toISOString()
        }
    ];
}

// Initialize charts (placeholder for Chart.js integration)
function initializeCharts() {
    // This would be implemented with Chart.js in a real scenario
    console.log('Charts would be initialized here with Chart.js');
}

// Error handling for fetch requests
function handleFetchError(error, context) {
    console.error(`Error in ${context}:`, error);
    showNotification(`Failed to ${context}. Please try again.`, 'error');
}

// Export functions for testing (if needed)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        initializeApplication,
        handleLogin,
        handleLogout,
        loadPortfolioData,
        loadAdvisorySignals,
        renderPortfolioData,
        renderAdvisorySignals,
        getDummyPortfolioData,
        getDummyAdvisorySignals,
        getSignalClass
    };
}