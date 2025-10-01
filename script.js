// script.js - Frontend JavaScript for Indian Equity Portfolio Management Dashboard
// This file handles frontend interactions, API calls, and dynamic content rendering

document.addEventListener('DOMContentLoaded', function() {
    // Initialize the application
    initApp();
});

/**
 * Initialize the application
 */
function initApp() {
    checkAuthentication();
    setupEventListeners();
    loadDashboardData();
}

/**
 * Check if user is authenticated and handle access control
 */
function checkAuthentication() {
    const token = localStorage.getItem('advisor_token');
    if (!token) {
        redirectToLogin();
        return;
    }
    
    // Verify token validity with backend
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
    // Portfolio management
    document.getElementById('addPortfolioBtn')?.addEventListener('click', showAddPortfolioModal);
    document.getElementById('portfolioForm')?.addEventListener('submit', handlePortfolioSubmit);
    
    // Navigation
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', handleNavigation);
    });
    
    // Logout
    document.getElementById('logoutBtn')?.addEventListener('click', handleLogout);
    
    // Refresh data
    document.getElementById('refreshBtn')?.addEventListener('click', refreshData);
}

/**
 * Load dashboard data from backend
 */
async function loadDashboardData() {
    try {
        showLoadingState();
        
        const [portfolioData, signalsData, reportsData] = await Promise.all([
            fetchPortfolios(),
            fetchAdvisorySignals(),
            fetchVisualReports()
        ]);
        
        renderPortfolioTable(portfolioData);
        renderAdvisorySignals(signalsData);
        renderVisualReports(reportsData);
        
        hideLoadingState();
    } catch (error) {
        console.error('Failed to load dashboard data:', error);
        showError('Failed to load data. Please try again.');
        hideLoadingState();
    }
}

/**
 * Fetch portfolios from backend
 */
async function fetchPortfolios() {
    const token = localStorage.getItem('advisor_token');
    const response = await fetch('/api/portfolios', {
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        }
    });
    
    if (!response.ok) {
        throw new Error('Failed to fetch portfolios');
    }
    
    return await response.json();
}

/**
 * Fetch advisory signals from backend
 */
async function fetchAdvisorySignals() {
    const token = localStorage.getItem('advisor_token');
    const response = await fetch('/api/advisory/signals', {
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        }
    });
    
    if (!response.ok) {
        throw new Error('Failed to fetch advisory signals');
    }
    
    return await response.json();
}

/**
 * Fetch visual reports from backend
 */
async function fetchVisualReports() {
    const token = localStorage.getItem('advisor_token');
    const response = await fetch('/api/reports/dashboard', {
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        }
    });
    
    if (!response.ok) {
        throw new Error('Failed to fetch reports');
    }
    
    return await response.json();
}

/**
 * Render portfolio table with data
 */
function renderPortfolioTable(portfolios) {
    const tableBody = document.getElementById('portfolioTableBody');
    if (!tableBody) return;
    
    tableBody.innerHTML = '';
    
    portfolios.forEach(portfolio => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${portfolio.client_name}</td>
            <td>${portfolio.equity_symbol}</td>
            <td>${portfolio.quantity}</td>
            <td>₹${portfolio.average_price.toLocaleString()}</td>
            <td>₹${portfolio.current_value.toLocaleString()}</td>
            <td><span class="badge ${getSignalBadgeClass(portfolio.signal)}">${portfolio.signal}</span></td>
            <td>
                <button class="btn btn-sm btn-outline-primary" onclick="editPortfolio(${portfolio.id})">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deletePortfolio(${portfolio.id})">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        `;
        tableBody.appendChild(row);
    });
}

/**
 * Render advisory signals
 */
function renderAdvisorySignals(signals) {
    const signalsContainer = document.getElementById('advisorySignals');
    if (!signalsContainer) return;
    
    signalsContainer.innerHTML = '';
    
    signals.forEach(signal => {
        const card = document.createElement('div');
        card.className = 'col-md-6 col-lg-4 mb-3';
        card.innerHTML = `
            <div class="card h-100 signal-card ${getSignalCardClass(signal.recommendation)}">
                <div class="card-body">
                    <h5 class="card-title">${signal.equity_symbol}</h5>
                    <h6 class="card-subtitle mb-2 ${getSignalTextClass(signal.recommendation)}">
                        ${signal.recommendation}
                    </h6>
                    <p class="card-text">${signal.reasoning}</p>
                    <small class="text-muted">Generated: ${new Date(signal.generated_at).toLocaleString()}</small>
                </div>
            </div>
        `;
        signalsContainer.appendChild(card);
    });
}

/**
 * Render visual reports using Chart.js
 */
function renderVisualReports(reports) {
    renderPortfolioValueChart(reports.portfolio_value_trend);
    renderSectorAllocationChart(reports.sector_allocation);
    renderPerformanceMetrics(reports.performance_metrics);
}

/**
 * Render portfolio value trend chart
 */
function renderPortfolioValueChart(data) {
    const ctx = document.getElementById('portfolioValueChart');
    if (!ctx) return;
    
    new Chart(ctx, {
        type: 'line',
        data: {
            labels: data.labels,
            datasets: [{
                label: 'Portfolio Value (₹)',
                data: data.values,
                borderColor: 'rgb(75, 192, 192)',
                tension: 0.1,
                fill: true
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Portfolio Value Trend'
                }
            }
        }
    });
}

/**
 * Render sector allocation chart
 */
function renderSectorAllocationChart(data) {
    const ctx = document.getElementById('sectorAllocationChart');
    if (!ctx) return;
    
    new Chart(ctx, {
        type: 'pie',
        data: {
            labels: data.sectors,
            datasets: [{
                data: data.percentages,
                backgroundColor: [
                    'rgb(255, 99, 132)',
                    'rgb(54, 162, 235)',
                    'rgb(255, 205, 86)',
                    'rgb(75, 192, 192)',
                    'rgb(153, 102, 255)'
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
 * Render performance metrics
 */
function renderPerformanceMetrics(metrics) {
    document.getElementById('totalValue').textContent = `₹${metrics.total_value.toLocaleString()}`;
    document.getElementById('totalGain').textContent = `₹${metrics.total_gain.toLocaleString()}`;
    document.getElementById('gainPercentage').textContent = `${metrics.gain_percentage}%`;
    document.getElementById('totalStocks').textContent = metrics.total_stocks;
}

/**
 * Show add portfolio modal
 */
function showAddPortfolioModal() {
    const modal = new bootstrap.Modal(document.getElementById('addPortfolioModal'));
    modal.show();
}

/**
 * Handle portfolio form submission
 */
async function handlePortfolioSubmit(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const portfolioData = {
        client_name: formData.get('client_name'),
        equity_symbol: formData.get('equity_symbol'),
        quantity: parseInt(formData.get('quantity')),
        average_price: parseFloat(formData.get('average_price'))
    };
    
    try {
        const token = localStorage.getItem('advisor_token');
        const response = await fetch('/api/portfolios', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(portfolioData)
        });
        
        if (response.ok) {
            const modal = bootstrap.Modal.getInstance(document.getElementById('addPortfolioModal'));
            modal.hide();
            event.target.reset();
            refreshData();
            showSuccess('Portfolio added successfully!');
        } else {
            throw new Error('Failed to add portfolio');
        }
    } catch (error) {
        console.error('Error adding portfolio:', error);
        showError('Failed to add portfolio. Please try again.');
    }
}

/**
 * Edit portfolio
 */
async function editPortfolio(portfolioId) {
    // Implementation for editing portfolio
    console.log('Edit portfolio:', portfolioId);
}

/**
 * Delete portfolio
 */
async function deletePortfolio(portfolioId) {
    if (!confirm('Are you sure you want to delete this portfolio?')) {
        return;
    }
    
    try {
        const token = localStorage.getItem('advisor_token');
        const response = await fetch(`/api/portfolios/${portfolioId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        
        if (response.ok) {
            refreshData();
            showSuccess('Portfolio deleted successfully!');
        } else {
            throw new Error('Failed to delete portfolio');
        }
    } catch (error) {
        console.error('Error deleting portfolio:', error);
        showError('Failed to delete portfolio. Please try again.');
    }
}

/**
 * Handle navigation
 */
function handleNavigation(event) {
    event.preventDefault();
    const target = event.target.getAttribute('data-target');
    
    // Hide all sections
    document.querySelectorAll('.content-section').forEach(section => {
        section.classList.add('d-none');
    });
    
    // Show target section
    document.getElementById(target)?.classList.remove('d-none');
    
    // Load specific data if needed
    if (target === 'portfolios') {
        loadPortfolioData();
    } else if (target === 'reports') {
        loadReportsData();
    }
}

/**
 * Handle logout
 */
function handleLogout() {
    localStorage.removeItem('advisor_token');
    redirectToLogin();
}

/**
 * Refresh all data
 */
function refreshData() {
    loadDashboardData();
}

/**
 * Show loading state
 */
function showLoadingState() {
    document.getElementById('loadingSpinner').classList.remove('d-none');
    document.getElementById('contentArea').classList.add('d-none');
}

/**
 * Hide loading state
 */
function hideLoadingState() {
    document.getElementById('loadingSpinner').classList.add('d-none');
    document.getElementById('contentArea').classList.remove('d-none');
}

/**
 * Show success message
 */
function showSuccess(message) {
    showAlert(message, 'success');
}

/**
 * Show error message
 */
function showError(message) {
    showAlert(message, 'danger');
}

/**
 * Show alert message
 */
function showAlert(message, type) {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    const container = document.getElementById('alertsContainer');
    container.appendChild(alertDiv);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
        alertDiv.remove();
    }, 5000);
}

/**
 * Get CSS class for signal badge
 */
function getSignalBadgeClass(signal) {
    const signalMap = {
        'BUY': 'bg-success',
        'HOLD': 'bg-warning',
        'SELL': 'bg-danger'
    };
    return signalMap[signal] || 'bg-secondary';
}

/**
 * Get CSS class for signal card
 */
function getSignalCardClass(recommendation) {
    const signalMap = {
        'BUY': 'border-success',
        'HOLD': 'border-warning',
        'SELL': 'border-danger'
    };
    return signalMap[recommendation] || '';
}

/**
 * Get CSS class for signal text
 */
function getSignalTextClass(recommendation) {
    const signalMap = {
        'BUY': 'text-success',
        'HOLD': 'text-warning',
        'SELL': 'text-danger'
    };
    return signalMap[recommendation] || 'text-muted';
}

// Export functions for global access (if needed)
window.editPortfolio = editPortfolio;
window.deletePortfolio = deletePortfolio;