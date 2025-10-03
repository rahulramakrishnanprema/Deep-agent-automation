// script.js - Main JavaScript file for Indian Equity Portfolio Management Dashboard
// Handles frontend functionality including API calls, UI updates, and chart rendering

// Global variables
let currentPortfolioId = null;
let advisorySignals = [];
let portfolioData = [];

// DOM Content Loaded Event Listener
document.addEventListener('DOMContentLoaded', function() {
    initializeDashboard();
    setupEventListeners();
});

/**
 * Initialize dashboard components
 */
function initializeDashboard() {
    checkAuthentication();
    loadPortfolioList();
    setupResponsiveDesign();
}

/**
 * Check user authentication status
 */
function checkAuthentication() {
    const token = localStorage.getItem('authToken');
    if (!token) {
        redirectToLogin();
        return;
    }
    
    // Verify token validity
    fetch('/api/auth/verify', {
        method: 'GET',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        }
    })
    .then(response => {
        if (!response.ok) {
            redirectToLogin();
        }
    })
    .catch(error => {
        console.error('Auth verification failed:', error);
        redirectToLogin();
    });
}

/**
 * Redirect to login page
 */
function redirectToLogin() {
    window.location.href = '/login.html';
}

/**
 * Set up event listeners for UI interactions
 */
function setupEventListeners() {
    // Portfolio selection
    document.getElementById('portfolio-select').addEventListener('change', handlePortfolioSelect);
    
    // Refresh button
    document.getElementById('refresh-btn').addEventListener('click', refreshDashboard);
    
    // Logout button
    document.getElementById('logout-btn').addEventListener('click', handleLogout);
    
    // Responsive design listeners
    window.addEventListener('resize', handleResize);
}

/**
 * Handle window resize for responsive design
 */
function handleResize() {
    updateChartSizes();
    adjustLayout();
}

/**
 * Adjust layout based on screen size
 */
function adjustLayout() {
    const screenWidth = window.innerWidth;
    const dashboard = document.getElementById('dashboard');
    
    if (screenWidth < 768) {
        dashboard.classList.add('mobile-view');
        document.getElementById('sidebar').classList.add('collapsed');
    } else {
        dashboard.classList.remove('mobile-view');
        document.getElementById('sidebar').classList.remove('collapsed');
    }
}

/**
 * Load portfolio list for the authenticated advisor
 */
function loadPortfolioList() {
    fetch('/api/portfolios', {
        method: 'GET',
        headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`,
            'Content-Type': 'application/json'
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to load portfolios');
        }
        return response.json();
    })
    .then(portfolios => {
        populatePortfolioDropdown(portfolios);
        if (portfolios.length > 0) {
            loadPortfolioDetails(portfolios[0].id);
        }
    })
    .catch(error => {
        console.error('Error loading portfolios:', error);
        showError('Failed to load portfolios');
    });
}

/**
 * Populate portfolio dropdown
 * @param {Array} portfolios - Array of portfolio objects
 */
function populatePortfolioDropdown(portfolios) {
    const select = document.getElementById('portfolio-select');
    select.innerHTML = '';
    
    portfolios.forEach(portfolio => {
        const option = document.createElement('option');
        option.value = portfolio.id;
        option.textContent = `${portfolio.client_name} - ${portfolio.portfolio_name}`;
        select.appendChild(option);
    });
}

/**
 * Handle portfolio selection change
 * @param {Event} event - Change event
 */
function handlePortfolioSelect(event) {
    const portfolioId = event.target.value;
    loadPortfolioDetails(portfolioId);
}

/**
 * Load detailed portfolio information
 * @param {number} portfolioId - Portfolio ID
 */
function loadPortfolioDetails(portfolioId) {
    currentPortfolioId = portfolioId;
    
    Promise.all([
        fetchPortfolioHoldings(portfolioId),
        fetchPortfolioPerformance(portfolioId),
        fetchAdvisorySignals(portfolioId)
    ])
    .then(([holdings, performance, signals]) => {
        updatePortfolioSummary(holdings, performance);
        renderHoldingsTable(holdings);
        renderPerformanceCharts(performance);
        renderAdvisorySignals(signals);
    })
    .catch(error => {
        console.error('Error loading portfolio details:', error);
        showError('Failed to load portfolio details');
    });
}

/**
 * Fetch portfolio holdings from API
 * @param {number} portfolioId - Portfolio ID
 * @returns {Promise} Promise resolving to holdings data
 */
function fetchPortfolioHoldings(portfolioId) {
    return fetch(`/api/portfolios/${portfolioId}/holdings`, {
        headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`,
            'Content-Type': 'application/json'
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to fetch holdings');
        }
        return response.json();
    });
}

/**
 * Fetch portfolio performance data
 * @param {number} portfolioId - Portfolio ID
 * @returns {Promise} Promise resolving to performance data
 */
function fetchPortfolioPerformance(portfolioId) {
    return fetch(`/api/portfolios/${portfolioId}/performance`, {
        headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`,
            'Content-Type': 'application/json'
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to fetch performance data');
        }
        return response.json();
    });
}

/**
 * Fetch advisory signals for portfolio
 * @param {number} portfolioId - Portfolio ID
 * @returns {Promise} Promise resolving to signals data
 */
function fetchAdvisorySignals(portfolioId) {
    return fetch(`/api/portfolios/${portfolioId}/signals`, {
        headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`,
            'Content-Type': 'application/json'
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to fetch advisory signals');
        }
        return response.json();
    });
}

/**
 * Update portfolio summary section
 * @param {Object} holdings - Portfolio holdings data
 * @param {Object} performance - Portfolio performance data
 */
function updatePortfolioSummary(holdings, performance) {
    const totalValue = holdings.reduce((sum, holding) => sum + (holding.quantity * holding.current_price), 0);
    const totalInvested = holdings.reduce((sum, holding) => sum + (holding.quantity * holding.average_cost), 0);
    const totalGainLoss = totalValue - totalInvested;
    const gainLossPercent = (totalGainLoss / totalInvested) * 100;
    
    document.getElementById('total-value').textContent = formatCurrency(totalValue);
    document.getElementById('total-invested').textContent = formatCurrency(totalInvested);
    document.getElementById('total-gain-loss').textContent = formatCurrency(totalGainLoss);
    document.getElementById('gain-loss-percent').textContent = gainLossPercent.toFixed(2) + '%';
    
    // Set color based on gain/loss
    const gainLossElement = document.getElementById('total-gain-loss');
    const percentElement = document.getElementById('gain-loss-percent');
    
    if (totalGainLoss >= 0) {
        gainLossElement.classList.add('positive');
        gainLossElement.classList.remove('negative');
        percentElement.classList.add('positive');
        percentElement.classList.remove('negative');
    } else {
        gainLossElement.classList.add('negative');
        gainLossElement.classList.remove('positive');
        percentElement.classList.add('negative');
        percentElement.classList.remove('positive');
    }
}

/**
 * Render holdings table
 * @param {Array} holdings - Array of holding objects
 */
function renderHoldingsTable(holdings) {
    const tableBody = document.getElementById('holdings-table-body');
    tableBody.innerHTML = '';
    
    holdings.forEach(holding => {
        const row = document.createElement('tr');
        const currentValue = holding.quantity * holding.current_price;
        const investedValue = holding.quantity * holding.average_cost;
        const gainLoss = currentValue - investedValue;
        const gainLossPercent = (gainLoss / investedValue) * 100;
        
        row.innerHTML = `
            <td>${holding.symbol}</td>
            <td>${holding.name}</td>
            <td>${holding.quantity}</td>
            <td>${formatCurrency(holding.average_cost)}</td>
            <td>${formatCurrency(holding.current_price)}</td>
            <td>${formatCurrency(currentValue)}</td>
            <td class="${gainLoss >= 0 ? 'positive' : 'negative'}">${formatCurrency(gainLoss)}</td>
            <td class="${gainLoss >= 0 ? 'positive' : 'negative'}">${gainLossPercent.toFixed(2)}%</td>
        `;
        
        tableBody.appendChild(row);
    });
}

/**
 * Render performance charts using Chart.js
 * @param {Object} performance - Performance data object
 */
function renderPerformanceCharts(performance) {
    renderReturnsChart(performance.historical_returns);
    renderSectorAllocationChart(performance.sector_allocation);
    renderTopHoldingsChart(performance.top_holdings);
}

/**
 * Render historical returns chart
 * @param {Array} returnsData - Historical returns data
 */
function renderReturnsChart(returnsData) {
    const ctx = document.getElementById('returns-chart').getContext('2d');
    
    if (window.returnsChart) {
        window.returnsChart.destroy();
    }
    
    window.returnsChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: returnsData.map(item => item.date),
            datasets: [{
                label: 'Portfolio Value',
                data: returnsData.map(item => item.value),
                borderColor: '#4CAF50',
                backgroundColor: 'rgba(76, 175, 80, 0.1)',
                fill: true,
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
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
 * Render sector allocation chart
 * @param {Array} sectorData - Sector allocation data
 */
function renderSectorAllocationChart(sectorData) {
    const ctx = document.getElementById('sector-chart').getContext('2d');
    
    if (window.sectorChart) {
        window.sectorChart.destroy();
    }
    
    window.sectorChart = new Chart(ctx, {
        type: 'pie',
        data: {
            labels: sectorData.map(item => item.sector),
            datasets: [{
                data: sectorData.map(item => item.percentage),
                backgroundColor: [
                    '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', 
                    '#9966FF', '#FF9F40', '#FF6384', '#C9CBCF'
                ]
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
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
 * Render top holdings chart
 * @param {Array} holdingsData - Top holdings data
 */
function renderTopHoldingsChart(holdingsData) {
    const ctx = document.getElementById('holdings-chart').getContext('2d');
    
    if (window.holdingsChart) {
        window.holdingsChart.destroy();
    }
    
    window.holdingsChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: holdingsData.map(item => item.symbol),
            datasets: [{
                label: 'Portfolio Weight (%)',
                data: holdingsData.map(item => item.weight),
                backgroundColor: '#2196F3'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                title: {
                    display: true,
                    text: 'Top Holdings'
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    max: 100
                }
            }
        }
    });
}

/**
 * Render advisory signals
 * @param {Array} signals - Array of signal objects
 */
function renderAdvisorySignals(signals) {
    const container = document.getElementById('advisory-signals');
    container.innerHTML = '';
    
    advisorySignals = signals;
    
    signals.forEach(signal => {
        const signalElement = document.createElement('div');
        signalElement.className = `signal-card ${signal.signal.toLowerCase()}`;
        
        signalElement.innerHTML = `
            <div class="signal-header">
                <span class="symbol">${signal.symbol}</span>
                <span class="signal ${signal.signal.toLowerCase()}">${signal.signal}</span>
            </div>
            <div class="signal-body">
                <p>${signal.reasoning}</p>
                <div class="signal-details">
                    <span>Strength: ${signal.confidence}/10</span>
                    <span>Target: ${formatCurrency(signal.target_price)}</span>
                    <span>Current: ${formatCurrency(signal.current_price)}</span>
                </div>
            </div>
            <div class="signal-footer">
                <span>${new Date(signal.generated_at).toLocaleDateString()}</span>
                <button class="action-btn" onclick="executeSignal('${signal.symbol}', '${signal.signal}')">
                    Execute
                </button>
            </div>
        `;
        
        container.appendChild(signalElement);
    });
}

/**
 * Update chart sizes for responsive design
 */
function updateChartSizes() {
    const charts = [window.returnsChart, window.sectorChart, window.holdingsChart];
    charts.forEach(chart => {
        if (chart) {
            chart.resize();
        }
    });
}

/**
 * Refresh dashboard data
 */
function refreshDashboard() {
    if (currentPortfolioId) {
        loadPortfolioDetails(currentPortfolioId);
    }
}

/**
 * Execute trading signal
 * @param {string} symbol - Stock symbol
 * @param {string} signal - Signal type (BUY/SELL/HOLD)
 */
function executeSignal(symbol, signal) {
    if (!confirm(`Execute ${signal} signal for ${symbol}?`)) {
        return;
    }
    
    fetch('/api/trades/execute', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            portfolio_id: currentPortfolioId,
            symbol: symbol,
            signal: signal
        })
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to execute trade');
        }
        return response.json();
    })
    .then(result => {
        showSuccess(`Trade executed successfully for ${symbol}`);
        refreshDashboard();
    })
    .catch(error => {
        console.error('Error executing trade:', error);
        showError('Failed to execute trade');
    });
}

/**
 * Handle user logout
 */
function handleLogout() {
    localStorage.removeItem('authToken');
    redirectToLogin();
}

/**
 * Format currency amount
 * @param {number} amount - Amount to format
 * @returns {string} Formatted currency string
 */
function formatCurrency(amount) {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    }).format(amount);
}

/**
 * Show success message
 * @param {string} message - Success message
 */
function showSuccess(message) {
    showNotification(message, 'success');
}

/**
 * Show error message
 * @param {string} message - Error message
 */
function showError(message) {
    showNotification(message, 'error');
}

/**
 * Show notification
 * @param {string} message - Notification message
 * @param {string} type - Notification type (success/error)
 */
function showNotification(message, type) {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.remove();
    }, 3000);
}

/**
 * Set up responsive design features
 */
function setupResponsiveDesign() {
    // Add touch event listeners for mobile
    if ('ontouchstart' in window) {
        document.addEventListener('touchstart', handleTouchStart, false);
        document.addEventListener('touchmove', handleTouchMove, false);
    }
    
    // Initialize layout
    adjustLayout();
}

// Touch event handlers for mobile swipe support
let touchStartX = 0;
let touchStartY = 0;

function handleTouchStart(event) {
    touchStartX = event.touches[0].clientX;
    touchStartY = event.touches[0].clientY;
}

function handleTouchMove(event) {
    if (!touchStartX || !touchStartY) {
        return;
    }
    
    const touchEndX = event.touches[0].clientX;
    const touchEndY = event.touches[0].clientY;
    
    const diffX = touchStartX - touchEndX;
    const diffY = touchStartY - touchEndY;
    
    // Swipe left to show sidebar
    if (Math.abs(diffX) > Math.abs(diffY) && diffX > 50) {
        document.getElementById('sidebar').classList.add('show');
    }
    
    touchStartX = 0;
    touchStartY = 0;
}

// Export functions for testing purposes
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        formatCurrency,
        updatePortfolioSummary,
        renderAdvisorySignals
    };
}