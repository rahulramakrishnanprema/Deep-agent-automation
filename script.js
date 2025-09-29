// script.js - Frontend JavaScript for Portfolio Management Application
// Handles UI interactions, API calls, and data visualization for the portfolio management system

// Global variables
let currentUserRole = 'user'; // Default role, will be updated after login
let portfolioData = [];
let advisorySignals = [];

// DOM Ready Event
document.addEventListener('DOMContentLoaded', function() {
    initializeApplication();
    setupEventListeners();
});

/**
 * Initialize the application
 */
function initializeApplication() {
    checkAuthentication();
    loadPortfolioData();
    setupRoleBasedUI();
}

/**
 * Check if user is authenticated and set role
 */
function checkAuthentication() {
    // In a real application, this would check cookies/localStorage
    const userRole = localStorage.getItem('userRole');
    if (userRole) {
        currentUserRole = userRole;
        updateUIForRole();
    }
}

/**
 * Setup event listeners for UI interactions
 */
function setupEventListeners() {
    // Portfolio form submission
    const portfolioForm = document.getElementById('portfolioForm');
    if (portfolioForm) {
        portfolioForm.addEventListener('submit', handlePortfolioSubmit);
    }

    // Refresh data button
    const refreshBtn = document.getElementById('refreshData');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', loadPortfolioData);
    }

    // Advisor report toggle
    const reportToggle = document.getElementById('advisorReportsToggle');
    if (reportToggle) {
        reportToggle.addEventListener('click', toggleAdvisorReports);
    }

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
}

/**
 * Setup role-based UI elements
 */
function setupRoleBasedUI() {
    const advisorElements = document.querySelectorAll('.advisor-only');
    advisorElements.forEach(element => {
        if (currentUserRole === 'advisor') {
            element.style.display = 'block';
        } else {
            element.style.display = 'none';
        }
    });
}

/**
 * Update UI based on user role
 */
function updateUIForRole() {
    const advisorSections = document.querySelectorAll('.advisor-section');
    const userSections = document.querySelectorAll('.user-section');
    
    if (currentUserRole === 'advisor') {
        advisorSections.forEach(section => section.style.display = 'block');
        userSections.forEach(section => section.style.display = 'none');
        loadAdvisoryReports();
    } else {
        advisorSections.forEach(section => section.style.display = 'none');
        userSections.forEach(section => section.style.display = 'block');
    }
}

/**
 * Load portfolio data from backend API
 */
async function loadPortfolioData() {
    try {
        showLoading('portfolioData');
        
        const response = await fetch('/api/portfolio', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        portfolioData = data.portfolios || [];
        
        renderPortfolioTable(portfolioData);
        loadAdvisorySignals();
        
    } catch (error) {
        console.error('Error loading portfolio data:', error);
        showError('Failed to load portfolio data. Please try again.');
    } finally {
        hideLoading('portfolioData');
    }
}

/**
 * Load advisory signals from backend API
 */
async function loadAdvisorySignals() {
    try {
        const response = await fetch('/api/advisory/signals', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        advisorySignals = data.signals || [];
        
        renderAdvisorySignals(advisorySignals);
        
    } catch (error) {
        console.error('Error loading advisory signals:', error);
        showError('Failed to load advisory signals.');
    }
}

/**
 * Load advisor reports (for advisors only)
 */
async function loadAdvisoryReports() {
    if (currentUserRole !== 'advisor') return;
    
    try {
        showLoading('advisorReports');
        
        const response = await fetch('/api/advisory/reports', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const reports = await response.json();
        renderAdvisoryReports(reports);
        
    } catch (error) {
        console.error('Error loading advisory reports:', error);
        showError('Failed to load advisor reports.');
    } finally {
        hideLoading('advisorReports');
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
        purchase_date: formData.get('purchase_date'),
        sector: formData.get('sector')
    };

    try {
        const response = await fetch('/api/portfolio', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            },
            body: JSON.stringify(portfolioData)
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = await response.json();
        showSuccess('Portfolio item added successfully!');
        event.target.reset();
        loadPortfolioData();
        
    } catch (error) {
        console.error('Error adding portfolio item:', error);
        showError('Failed to add portfolio item. Please try again.');
    }
}

/**
 * Handle login form submission
 * @param {Event} event - Form submit event
 */
async function handleLogin(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const loginData = {
        username: formData.get('username'),
        password: formData.get('password')
    };

    try {
        const response = await fetch('/api/auth/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(loginData)
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = await response.json();
        
        // Store authentication data
        localStorage.setItem('authToken', result.token);
        localStorage.setItem('userRole', result.role);
        localStorage.setItem('userId', result.user_id);
        
        currentUserRole = result.role;
        updateUIForRole();
        
        showSuccess('Login successful!');
        $('#loginModal').modal('hide');
        
    } catch (error) {
        console.error('Login error:', error);
        showError('Login failed. Please check your credentials.');
    }
}

/**
 * Handle logout
 */
async function handleLogout() {
    try {
        await fetch('/api/auth/logout', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });
    } catch (error) {
        console.error('Logout error:', error);
    } finally {
        // Clear local storage and reset UI
        localStorage.removeItem('authToken');
        localStorage.removeItem('userRole');
        localStorage.removeItem('userId');
        
        currentUserRole = 'user';
        updateUIForRole();
        
        showSuccess('Logged out successfully!');
    }
}

/**
 * Render portfolio data in table
 * @param {Array} data - Portfolio data array
 */
function renderPortfolioTable(data) {
    const tableBody = document.getElementById('portfolioTableBody');
    if (!tableBody) return;

    tableBody.innerHTML = '';

    data.forEach((item, index) => {
        const row = document.createElement('tr');
        
        const currentPrice = calculateCurrentPrice(item.purchase_price);
        const gainLoss = calculateGainLoss(item.quantity, item.purchase_price, currentPrice);
        const gainLossClass = gainLoss >= 0 ? 'text-success' : 'text-danger';
        const gainLossIcon = gainLoss >= 0 ? '▲' : '▼';

        row.innerHTML = `
            <td>${item.stock_symbol}</td>
            <td>${item.quantity}</td>
            <td>₹${item.purchase_price.toFixed(2)}</td>
            <td>₹${currentPrice.toFixed(2)}</td>
            <td class="${gainLossClass}">${gainLossIcon} ₹${Math.abs(gainLoss).toFixed(2)}</td>
            <td>${item.sector}</td>
            <td>${formatDate(item.purchase_date)}</td>
            <td>
                <button class="btn btn-sm btn-outline-danger" onclick="deletePortfolioItem(${item.id})">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        `;
        
        tableBody.appendChild(row);
    });

    updatePortfolioSummary(data);
}

/**
 * Render advisory signals
 * @param {Array} signals - Advisory signals array
 */
function renderAdvisorySignals(signals) {
    const container = document.getElementById('advisorySignals');
    if (!container) return;

    container.innerHTML = '';

    signals.forEach(signal => {
        const card = document.createElement('div');
        card.className = `col-md-4 mb-3`;
        
        let badgeClass = '';
        switch(signal.recommendation.toLowerCase()) {
            case 'buy': badgeClass = 'bg-success'; break;
            case 'sell': badgeClass = 'bg-danger'; break;
            case 'hold': badgeClass = 'bg-warning'; break;
            default: badgeClass = 'bg-secondary';
        }

        card.innerHTML = `
            <div class="card h-100">
                <div class="card-body">
                    <h5 class="card-title">${signal.stock_symbol}</h5>
                    <span class="badge ${badgeClass}">${signal.recommendation}</span>
                    <p class="card-text mt-2">${signal.reason}</p>
                    <small class="text-muted">Confidence: ${signal.confidence_score}%</small>
                </div>
                <div class="card-footer">
                    <small>Updated: ${formatDate(signal.generated_at)}</small>
                </div>
            </div>
        `;
        
        container.appendChild(card);
    });
}

/**
 * Render advisor reports with charts
 * @param {Object} reports - Reports data object
 */
function renderAdvisoryReports(reports) {
    if (!reports) return;

    renderPerformanceChart(reports.performance_data);
    renderSectorAnalysis(reports.sector_analysis);
    renderTechnicalIndicators(reports.technical_indicators);
}

/**
 * Render performance chart using Chart.js
 * @param {Array} performanceData - Performance data array
 */
function renderPerformanceChart(performanceData) {
    const ctx = document.getElementById('performanceChart');
    if (!ctx || !performanceData) return;

    const labels = performanceData.map(item => item.date);
    const values = performanceData.map(item => item.value);

    new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Portfolio Performance',
                data: values,
                borderColor: 'rgb(75, 192, 192)',
                tension: 0.1,
                fill: true,
                backgroundColor: 'rgba(75, 192, 192, 0.2)'
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Portfolio Performance Over Time'
                }
            }
        }
    });
}

/**
 * Render sector analysis
 * @param {Array} sectorData - Sector analysis data
 */
function renderSectorAnalysis(sectorData) {
    const container = document.getElementById('sectorAnalysis');
    if (!container || !sectorData) return;

    container.innerHTML = '';

    sectorData.forEach(sector => {
        const progressBar = document.createElement('div');
        progressBar.className = 'mb-2';
        
        progressBar.innerHTML = `
            <div class="d-flex justify-content-between">
                <span>${sector.sector}</span>
                <span>${sector.percentage}%</span>
            </div>
            <div class="progress">
                <div class="progress-bar" role="progressbar" 
                     style="width: ${sector.percentage}%; background-color: ${getSectorColor(sector.sector)}"
                     aria-valuenow="${sector.percentage}" aria-valuemin="0" aria-valuemax="100">
                </div>
            </div>
        `;
        
        container.appendChild(progressBar);
    });
}

/**
 * Render technical indicators
 * @param {Array} indicators - Technical indicators data
 */
function renderTechnicalIndicators(indicators) {
    const container = document.getElementById('technicalIndicators');
    if (!container || !indicators) return;

    container.innerHTML = '';

    indicators.forEach(indicator => {
        const card = document.createElement('div');
        card.className = 'col-md-6 mb-3';
        
        card.innerHTML = `
            <div class="card">
                <div class="card-body">
                    <h6 class="card-title">${indicator.stock_symbol}</h6>
                    <div class="row">
                        <div class="col-6">
                            <small>RSI: ${indicator.rsi || 'N/A'}</small>
                        </div>
                        <div class="col-6">
                            <small>MACD: ${indicator.macd || 'N/A'}</small>
                        </div>
                    </div>
                    <div class="row mt-2">
                        <div class="col-6">
                            <small>Moving Avg: ${indicator.moving_average || 'N/A'}</small>
                        </div>
                        <div class="col-6">
                            <small>Volatility: ${indicator.volatility || 'N/A'}</small>
                        </div>
                    </div>
                </div>
            </div>
        `;
        
        container.appendChild(card);
    });
}

/**
 * Delete portfolio item
 * @param {number} itemId - Portfolio item ID
 */
async function deletePortfolioItem(itemId) {
    if (!confirm('Are you sure you want to delete this portfolio item?')) {
        return;
    }

    try {
        const response = await fetch(`/api/portfolio/${itemId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        showSuccess('Portfolio item deleted successfully!');
        loadPortfolioData();
        
    } catch (error) {
        console.error('Error deleting portfolio item:', error);
        showError('Failed to delete portfolio item.');
    }
}

/**
 * Toggle advisor reports visibility
 */
function toggleAdvisorReports() {
    const reportsSection = document.getElementById('advisorReportsSection');
    if (reportsSection) {
        reportsSection.style.display = reportsSection.style.display === 'none' ? 'block' : 'none';
    }
}

/**
 * Calculate current price (mock function - would use real market data)
 * @param {number} purchasePrice - Original purchase price
 * @returns {number} - Current price
 */
function calculateCurrentPrice(purchasePrice) {
    // Mock price fluctuation between -10% to +20%
    const fluctuation = 0.9 + (Math.random() * 0.3);
    return purchasePrice * fluctuation;
}

/**
 * Calculate gain/loss
 * @param {number} quantity - Quantity of stocks
 * @param {number} purchasePrice - Purchase price
 * @param {number} currentPrice - Current price
 * @returns {number} - Gain/loss amount
 */
function calculateGainLoss(quantity, purchasePrice, currentPrice) {
    return (currentPrice - purchasePrice) * quantity;
}

/**
 * Update portfolio summary
 * @param {Array} data - Portfolio data
 */
function updatePortfolioSummary(data) {
    const totalInvested = data.reduce((sum, item) => sum + (item.quantity * item.purchase_price), 0);
    const totalCurrent = data.reduce((sum, item) => {
        const currentPrice = calculateCurrentPrice(item.purchase_price);
        return sum + (item.quantity * currentPrice);
    }, 0);
    const totalGainLoss = totalCurrent - totalInvested;
    const gainLossPercent = totalInvested > 0 ? (totalGainLoss / totalInvested) * 100 : 0;

    document.getElementById('totalInvested').textContent = `₹${totalInvested.toFixed(2)}`;
    document.getElementById('totalCurrent').textContent = `₹${totalCurrent.toFixed(2)}`;
    document.getElementById('totalGainLoss').textContent = `₹${totalGainLoss.toFixed(2)}`;
    document.getElementById('gainLossPercent').textContent = `${gainLossPercent.toFixed(2)}%`;
    
    const gainLossElement = document.getElementById('totalGainLoss');
    gainLossElement.className = totalGainLoss >= 0 ? 'text-success fw-bold' : 'text-danger fw-bold';
}

/**
 * Format date for display
 * @param {string} dateString - Date string
 * @returns {string} - Formatted date
 */
function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('en-IN', {
        year: 'numeric',
        month