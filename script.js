// script.js - Frontend JavaScript for Portfolio Management Dashboard
// This file handles UI interactions, API calls, and data visualization for the portfolio management system

document.addEventListener('DOMContentLoaded', function() {
    // Initialize the application
    initApp();
});

/**
 * Initialize the application
 */
function initApp() {
    // Check user authentication status
    checkAuthStatus();
    
    // Load portfolio data
    loadPortfolioData();
    
    // Set up event listeners
    setupEventListeners();
}

/**
 * Check user authentication status and handle UI accordingly
 */
async function checkAuthStatus() {
    try {
        const response = await fetch('/api/auth/status', {
            credentials: 'include'
        });
        
        if (response.ok) {
            const data = await response.json();
            updateUIForUserRole(data.user);
        } else {
            // Redirect to login if not authenticated
            window.location.href = '/login';
        }
    } catch (error) {
        console.error('Auth status check failed:', error);
        showNotification('Authentication check failed', 'error');
    }
}

/**
 * Update UI based on user role (advisor vs client)
 */
function updateUIForUserRole(user) {
    const advisorSections = document.querySelectorAll('.advisor-only');
    const clientSections = document.querySelectorAll('.client-only');
    
    if (user.role === 'advisor') {
        advisorSections.forEach(section => section.style.display = 'block');
        clientSections.forEach(section => section.style.display = 'none');
        loadAdvisorySignals();
        loadAdvisorReports();
    } else {
        advisorSections.forEach(section => section.style.display = 'none');
        clientSections.forEach(section => section.style.display = 'block');
    }
    
    // Update user info in navbar
    const userInfoElement = document.getElementById('user-info');
    if (userInfoElement) {
        userInfoElement.textContent = `${user.name} (${user.role})`;
    }
}

/**
 * Load portfolio data from backend API
 */
async function loadPortfolioData() {
    try {
        showLoading('portfolio-container');
        
        const response = await fetch('/api/portfolio', {
            credentials: 'include'
        });
        
        if (response.ok) {
            const portfolioData = await response.json();
            renderPortfolioTable(portfolioData);
            renderPortfolioSummary(portfolioData);
        } else {
            throw new Error('Failed to fetch portfolio data');
        }
    } catch (error) {
        console.error('Error loading portfolio:', error);
        showNotification('Failed to load portfolio data', 'error');
    } finally {
        hideLoading('portfolio-container');
    }
}

/**
 * Render portfolio data in table format
 */
function renderPortfolioTable(portfolioData) {
    const tableBody = document.getElementById('portfolio-table-body');
    if (!tableBody) return;
    
    tableBody.innerHTML = '';
    
    portfolioData.holdings.forEach(holding => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${holding.symbol}</td>
            <td>${holding.name}</td>
            <td>${holding.quantity}</td>
            <td>₹${holding.average_price.toFixed(2)}</td>
            <td>₹${holding.current_price.toFixed(2)}</td>
            <td>₹${(holding.current_price * holding.quantity).toFixed(2)}</td>
            <td class="${getProfitLossClass(holding.profit_loss_percentage)}">
                ${holding.profit_loss_percentage}%
            </td>
            <td>
                <span class="badge ${getSignalBadgeClass(holding.signal)}">
                    ${holding.signal}
                </span>
            </td>
        `;
        tableBody.appendChild(row);
    });
}

/**
 * Render portfolio summary information
 */
function renderPortfolioSummary(portfolioData) {
    const summaryElement = document.getElementById('portfolio-summary');
    if (!summaryElement) return;
    
    summaryElement.innerHTML = `
        <div class="row">
            <div class="col-md-3">
                <div class="card bg-primary text-white">
                    <div class="card-body">
                        <h6>Total Investment</h6>
                        <h4>₹${portfolioData.total_investment.toFixed(2)}</h4>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card bg-info text-white">
                    <div class="card-body">
                        <h6>Current Value</h6>
                        <h4>₹${portfolioData.current_value.toFixed(2)}</h4>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card ${getProfitLossCardClass(portfolioData.total_profit_loss_percentage)}">
                    <div class="card-body">
                        <h6>Total P&L</h6>
                        <h4>${portfolioData.total_profit_loss_percentage}%</h4>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card bg-secondary text-white">
                    <div class="card-body">
                        <h6>Holdings</h6>
                        <h4>${portfolioData.holdings_count}</h4>
                    </div>
                </div>
            </div>
        </div>
    `;
}

/**
 * Load advisory signals for advisor view
 */
async function loadAdvisorySignals() {
    try {
        showLoading('signals-container');
        
        const response = await fetch('/api/advisory/signals', {
            credentials: 'include'
        });
        
        if (response.ok) {
            const signals = await response.json();
            renderAdvisorySignals(signals);
        }
    } catch (error) {
        console.error('Error loading signals:', error);
        showNotification('Failed to load advisory signals', 'error');
    } finally {
        hideLoading('signals-container');
    }
}

/**
 * Render advisory signals table
 */
function renderAdvisorySignals(signals) {
    const container = document.getElementById('signals-container');
    if (!container) return;
    
    let html = `
        <div class="table-responsive">
            <table class="table table-striped">
                <thead>
                    <tr>
                        <th>Symbol</th>
                        <th>Name</th>
                        <th>Signal</th>
                        <th>Confidence</th>
                        <th>Historical</th>
                        <th>Technical</th>
                        <th>Sector</th>
                        <th>Market Buzz</th>
                        <th>Last Updated</th>
                    </tr>
                </thead>
                <tbody>
    `;
    
    signals.forEach(signal => {
        html += `
            <tr>
                <td>${signal.symbol}</td>
                <td>${signal.name}</td>
                <td><span class="badge ${getSignalBadgeClass(signal.signal)}">${signal.signal}</span></td>
                <td>${signal.confidence_score}%</td>
                <td>${signal.historical_score}</td>
                <td>${signal.technical_score}</td>
                <td>${signal.sector_score}</td>
                <td>${signal.market_buzz_score}</td>
                <td>${new Date(signal.last_updated).toLocaleDateString()}</td>
            </tr>
        `;
    });
    
    html += `
                </tbody>
            </table>
        </div>
    `;
    
    container.innerHTML = html;
}

/**
 * Load advisor reports and visualizations
 */
async function loadAdvisorReports() {
    try {
        showLoading('reports-container');
        
        const response = await fetch('/api/advisory/reports', {
            credentials: 'include'
        });
        
        if (response.ok) {
            const reports = await response.json();
            renderReportsVisualizations(reports);
        }
    } catch (error) {
        console.error('Error loading reports:', error);
        showNotification('Failed to load reports', 'error');
    } finally {
        hideLoading('reports-container');
    }
}

/**
 * Render reports and visualizations for advisors
 */
function renderReportsVisualizations(reports) {
    const container = document.getElementById('reports-container');
    if (!container) return;
    
    // Render sector allocation chart
    renderSectorAllocationChart(reports.sector_allocation);
    
    // Render performance chart
    renderPerformanceChart(reports.performance_data);
    
    // Render signal distribution
    renderSignalDistribution(reports.signal_distribution);
}

/**
 * Render sector allocation pie chart
 */
function renderSectorAllocationChart(sectorData) {
    const ctx = document.getElementById('sector-allocation-chart');
    if (!ctx) return;
    
    // Using Chart.js for visualization
    new Chart(ctx, {
        type: 'pie',
        data: {
            labels: sectorData.map(s => s.sector),
            datasets: [{
                data: sectorData.map(s => s.percentage),
                backgroundColor: [
                    '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0',
                    '#9966FF', '#FF9F40', '#FF6384', '#C9CBCF'
                ]
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Sector Allocation'
                }
            }
        }
    });
}

/**
 * Render performance line chart
 */
function renderPerformanceChart(performanceData) {
    const ctx = document.getElementById('performance-chart');
    if (!ctx) return;
    
    new Chart(ctx, {
        type: 'line',
        data: {
            labels: performanceData.dates,
            datasets: [{
                label: 'Portfolio Value',
                data: performanceData.values,
                borderColor: '#36A2EB',
                tension: 0.1
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Portfolio Performance'
                }
            },
            scales: {
                y: {
                    beginAtZero: false
                }
            }
        }
    });
}

/**
 * Render signal distribution chart
 */
function renderSignalDistribution(signalData) {
    const ctx = document.getElementById('signal-distribution-chart');
    if (!ctx) return;
    
    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['Buy', 'Hold', 'Sell'],
            datasets: [{
                label: 'Number of Stocks',
                data: [
                    signalData.buy,
                    signalData.hold,
                    signalData.sell
                ],
                backgroundColor: [
                    '#28a745', '#ffc107', '#dc3545'
                ]
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Signal Distribution'
                }
            }
        }
    });
}

/**
 * Set up event listeners for UI interactions
 */
function setupEventListeners() {
    // Refresh button
    const refreshBtn = document.getElementById('refresh-btn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
            loadPortfolioData();
            if (document.querySelector('.advisor-only').style.display === 'block') {
                loadAdvisorySignals();
                loadAdvisorReports();
            }
        });
    }
    
    // Logout button
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', handleLogout);
    }
    
    // Responsive layout adjustments
    window.addEventListener('resize', handleResize);
}

/**
 * Handle logout action
 */
async function handleLogout() {
    try {
        const response = await fetch('/api/auth/logout', {
            method: 'POST',
            credentials: 'include'
        });
        
        if (response.ok) {
            window.location.href = '/login';
        }
    } catch (error) {
        console.error('Logout failed:', error);
        showNotification('Logout failed', 'error');
    }
}

/**
 * Handle window resize for responsive adjustments
 */
function handleResize() {
    // Re-render charts if they exist
    const advisorSections = document.querySelectorAll('.advisor-only');
    if (advisorSections[0]?.style.display === 'block') {
        loadAdvisorReports();
    }
}

/**
 * Show loading indicator
 */
function showLoading(containerId) {
    const container = document.getElementById(containerId);
    if (container) {
        container.innerHTML = `
            <div class="text-center py-4">
                <div class="spinner-border" role="status">
                    <span class="visually-hidden">Loading...</span>
                </div>
                <p class="mt-2">Loading...</p>
            </div>
        `;
    }
}

/**
 * Hide loading indicator
 */
function hideLoading(containerId) {
    const container = document.getElementById(containerId);
    if (container && container.querySelector('.spinner-border')) {
        // Loading will be replaced by actual content
    }
}

/**
 * Show notification to user
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
    
    document.body.appendChild(notification);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
        if (notification.parentNode) {
            notification.parentNode.removeChild(notification);
        }
    }, 5000);
}

/**
 * Get CSS class for profit/loss display based on value
 */
function getProfitLossClass(value) {
    if (value > 0) return 'text-success';
    if (value < 0) return 'text-danger';
    return 'text-muted';
}

/**
 * Get CSS class for profit/loss card based on value
 */
function getProfitLossCardClass(value) {
    if (value > 0) return 'bg-success text-white';
    if (value < 0) return 'bg-danger text-white';
    return 'bg-secondary text-white';
}

/**
 * Get CSS class for signal badges
 */
function getSignalBadgeClass(signal) {
    switch (signal.toLowerCase()) {
        case 'buy': return 'bg-success';
        case 'hold': return 'bg-warning';
        case 'sell': return 'bg-danger';
        default: return 'bg-secondary';
    }
}

// Error handling for fetch requests
const originalFetch = window.fetch;
window.fetch = async function(...args) {
    try {
        const response = await originalFetch.apply(this, args);
        
        if (!response.ok) {
            const error = new Error(`HTTP error! status: ${response.status}`);
            error.response = response;
            throw error;
        }
        
        return response;
    } catch (error) {
        console.error('Fetch error:', error);
        
        if (error.response?.status === 401) {
            // Unauthorized - redirect to login
            window.location.href = '/login';
        } else if (error.response?.status === 403) {
            // Forbidden - show access denied
            showNotification('Access denied. Insufficient permissions.', 'error');
        } else if (error.response?.status >= 500) {
            // Server error
            showNotification('Server error. Please try again later.', 'error');
        } else {
            // Other errors
            showNotification('Network error. Please check your connection.', 'error');
        }
        
        throw error;
    }
};