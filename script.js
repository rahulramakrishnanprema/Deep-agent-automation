// script.js - Frontend JavaScript for Portfolio Management System
// Handles UI interactions, API calls, and data display for the portfolio management application

document.addEventListener('DOMContentLoaded', function() {
    // Initialize the application
    initApp();
});

/**
 * Initialize the application
 */
function initApp() {
    loadPortfolioData();
    setupEventListeners();
    checkUserRole();
}

/**
 * Set up event listeners for UI interactions
 */
function setupEventListeners() {
    // Portfolio form submission
    const portfolioForm = document.getElementById('portfolioForm');
    if (portfolioForm) {
        portfolioForm.addEventListener('submit', handlePortfolioSubmit);
    }

    // Refresh button
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', loadPortfolioData);
    }

    // Advisor dashboard toggle
    const advisorToggle = document.getElementById('advisorToggle');
    if (advisorToggle) {
        advisorToggle.addEventListener('change', toggleAdvisorView);
    }
}

/**
 * Load portfolio data from backend API
 */
async function loadPortfolioData() {
    try {
        showLoading(true);
        
        const response = await fetch('/api/portfolio', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${getAuthToken()}`
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const portfolioData = await response.json();
        displayPortfolioData(portfolioData);
        
        // Load advisory signals if user is advisor
        if (isAdvisorUser()) {
            await loadAdvisorySignals(portfolioData);
        }

    } catch (error) {
        console.error('Error loading portfolio data:', error);
        showError('Failed to load portfolio data. Please try again.');
    } finally {
        showLoading(false);
    }
}

/**
 * Handle portfolio form submission
 * @param {Event} event - Form submit event
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
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${getAuthToken()}`
            },
            body: JSON.stringify(portfolioData)
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = await response.json();
        showSuccess('Portfolio item added successfully!');
        loadPortfolioData();
        event.target.reset();

    } catch (error) {
        console.error('Error adding portfolio item:', error);
        showError('Failed to add portfolio item. Please try again.');
    }
}

/**
 * Display portfolio data in the UI
 * @param {Array} portfolioData - Array of portfolio items
 */
function displayPortfolioData(portfolioData) {
    const portfolioTable = document.getElementById('portfolioTable');
    const portfolioBody = document.getElementById('portfolioBody');
    
    if (!portfolioBody) return;

    portfolioBody.innerHTML = '';

    portfolioData.forEach(item => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${item.stock_symbol}</td>
            <td>${item.quantity}</td>
            <td>₹${item.purchase_price.toFixed(2)}</td>
            <td>₹${(item.quantity * item.purchase_price).toFixed(2)}</td>
            <td>${item.sector}</td>
            <td class="signal-${item.advisory_signal?.toLowerCase() || 'hold'}">
                ${item.advisory_signal || 'N/A'}
            </td>
        `;
        portfolioBody.appendChild(row);
    });

    // Show table if hidden
    if (portfolioTable && portfolioTable.classList.contains('d-none')) {
        portfolioTable.classList.remove('d-none');
    }
}

/**
 * Load advisory signals for portfolio items
 * @param {Array} portfolioData - Array of portfolio items
 */
async function loadAdvisorySignals(portfolioData) {
    try {
        const stockSymbols = portfolioData.map(item => item.stock_symbol);
        
        const response = await fetch('/api/advisory/signals', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${getAuthToken()}`
            },
            body: JSON.stringify({ stocks: stockSymbols })
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const signals = await response.json();
        updatePortfolioWithSignals(signals);

    } catch (error) {
        console.error('Error loading advisory signals:', error);
    }
}

/**
 * Update portfolio display with advisory signals
 * @param {Object} signals - Advisory signals data
 */
function updatePortfolioWithSignals(signals) {
    const portfolioBody = document.getElementById('portfolioBody');
    if (!portfolioBody) return;

    const rows = portfolioBody.querySelectorAll('tr');
    rows.forEach(row => {
        const symbol = row.querySelector('td:first-child').textContent;
        const signalCell = row.querySelector('td:nth-child(6)');
        
        if (signals[symbol]) {
            signalCell.textContent = signals[symbol].signal;
            signalCell.className = `signal-${signals[symbol].signal.toLowerCase()}`;
            
            // Add tooltip for signal details
            signalCell.title = `Confidence: ${signals[symbol].confidence}% | Reason: ${signals[symbol].reason}`;
        }
    });
}

/**
 * Toggle advisor view based on user role and toggle state
 */
function toggleAdvisorView() {
    const advisorToggle = document.getElementById('advisorToggle');
    const advisorDashboard = document.getElementById('advisorDashboard');
    
    if (!advisorToggle || !advisorDashboard) return;

    if (advisorToggle.checked && isAdvisorUser()) {
        loadAdvisorDashboard();
        advisorDashboard.classList.remove('d-none');
    } else {
        advisorDashboard.classList.add('d-none');
    }
}

/**
 * Load advisor dashboard data
 */
async function loadAdvisorDashboard() {
    try {
        const response = await fetch('/api/advisory/dashboard', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${getAuthToken()}`
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const dashboardData = await response.json();
        renderAdvisorDashboard(dashboardData);

    } catch (error) {
        console.error('Error loading advisor dashboard:', error);
        showError('Failed to load advisor dashboard. Access may be restricted.');
    }
}

/**
 * Render advisor dashboard with visual reports
 * @param {Object} dashboardData - Dashboard data from backend
 */
function renderAdvisorDashboard(dashboardData) {
    // Implementation for charts and visual reports would go here
    // Using Chart.js or similar library for visualization
    
    console.log('Rendering advisor dashboard with data:', dashboardData);
    
    // Placeholder for chart rendering
    const chartsContainer = document.getElementById('advisorCharts');
    if (chartsContainer) {
        chartsContainer.innerHTML = `
            <div class="alert alert-info">
                Advisor dashboard visualization would be implemented here with Chart.js
                showing portfolio performance, sector analysis, and market trends.
            </div>
        `;
    }
}

/**
 * Check user role and adjust UI accordingly
 */
function checkUserRole() {
    const advisorSection = document.getElementById('advisorSection');
    const advisorToggle = document.getElementById('advisorToggle');
    
    if (isAdvisorUser()) {
        if (advisorSection) advisorSection.classList.remove('d-none');
        if (advisorToggle) advisorToggle.disabled = false;
    } else {
        if (advisorSection) advisorSection.classList.add('d-none');
        if (advisorToggle) advisorToggle.disabled = true;
    }
}

/**
 * Check if current user is an advisor
 * @returns {boolean} True if user is advisor
 */
function isAdvisorUser() {
    // In a real implementation, this would check JWT token or user session
    // For demo purposes, using a simple flag
    return localStorage.getItem('userRole') === 'advisor';
}

/**
 * Get authentication token from storage
 * @returns {string} Auth token
 */
function getAuthToken() {
    return localStorage.getItem('authToken') || 'demo-token';
}

/**
 * Show loading state
 * @param {boolean} show - Whether to show loading indicator
 */
function showLoading(show) {
    const loadingIndicator = document.getElementById('loadingIndicator');
    const mainContent = document.getElementById('mainContent');
    
    if (loadingIndicator && mainContent) {
        if (show) {
            loadingIndicator.classList.remove('d-none');
            mainContent.classList.add('d-none');
        } else {
            loadingIndicator.classList.add('d-none');
            mainContent.classList.remove('d-none');
        }
    }
}

/**
 * Show error message
 * @param {string} message - Error message to display
 */
function showError(message) {
    const errorAlert = document.getElementById('errorAlert');
    const errorMessage = document.getElementById('errorMessage');
    
    if (errorAlert && errorMessage) {
        errorMessage.textContent = message;
        errorAlert.classList.remove('d-none');
        
        // Auto-hide after 5 seconds
        setTimeout(() => {
            errorAlert.classList.add('d-none');
        }, 5000);
    }
}

/**
 * Show success message
 * @param {string} message - Success message to display
 */
function showSuccess(message) {
    const successAlert = document.getElementById('successAlert');
    const successMessage = document.getElementById('successMessage');
    
    if (successAlert && successMessage) {
        successMessage.textContent = message;
        successAlert.classList.remove('d-none');
        
        // Auto-hide after 3 seconds
        setTimeout(() => {
            successAlert.classList.add('d-none');
        }, 3000);
    }
}

// Utility function for formatting numbers
function formatCurrency(amount) {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR'
    }).format(amount);
}

// Export functions for testing purposes
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        initApp,
        loadPortfolioData,
        displayPortfolioData,
        isAdvisorUser,
        formatCurrency
    };
}