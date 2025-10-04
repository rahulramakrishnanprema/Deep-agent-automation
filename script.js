// script.js - Frontend JavaScript for Portfolio Management Dashboard

// Global variables
let currentUser = null;
let portfolioData = [];
let advisorySignals = [];

// DOM Content Loaded Event
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

// Initialize Application
function initializeApp() {
    checkAuthentication();
    setupEventListeners();
    loadInitialData();
}

// Check User Authentication
async function checkAuthentication() {
    try {
        const response = await fetch('/api/auth/status', {
            credentials: 'include'
        });
        
        if (response.ok) {
            const userData = await response.json();
            currentUser = userData;
            updateUIForUserRole();
        } else {
            redirectToLogin();
        }
    } catch (error) {
        console.error('Authentication check failed:', error);
        redirectToLogin();
    }
}

// Setup Event Listeners
function setupEventListeners() {
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

    // Advisor reports toggle
    const reportsToggle = document.getElementById('reportsToggle');
    if (reportsToggle) {
        reportsToggle.addEventListener('click', toggleAdvisorReports);
    }

    // Refresh data button
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', refreshData);
    }
}

// Load Initial Data
async function loadInitialData() {
    try {
        await Promise.all([
            loadPortfolioData(),
            loadAdvisorySignals()
        ]);
        
        updateDashboard();
    } catch (error) {
        showError('Failed to load initial data');
        console.error('Data loading error:', error);
    }
}

// Load Portfolio Data from Backend
async function loadPortfolioData() {
    try {
        const response = await fetch('/api/portfolio', {
            credentials: 'include'
        });
        
        if (!response.ok) {
            throw new Error('Failed to fetch portfolio data');
        }
        
        portfolioData = await response.json();
        return portfolioData;
    } catch (error) {
        console.error('Portfolio data loading error:', error);
        throw error;
    }
}

// Load Advisory Signals from Backend
async function loadAdvisorySignals() {
    try {
        const response = await fetch('/api/advisory/signals', {
            credentials: 'include'
        });
        
        if (!response.ok) {
            throw new Error('Failed to fetch advisory signals');
        }
        
        advisorySignals = await response.json();
        return advisorySignals;
    } catch (error) {
        console.error('Advisory signals loading error:', error);
        throw error;
    }
}

// Handle Portfolio Form Submission
async function handlePortfolioSubmit(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const portfolioItem = {
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
            credentials: 'include',
            body: JSON.stringify(portfolioItem)
        });
        
        if (response.ok) {
            await loadPortfolioData();
            await loadAdvisorySignals();
            updateDashboard();
            event.target.reset();
            showSuccess('Portfolio item added successfully');
        } else {
            throw new Error('Failed to add portfolio item');
        }
    } catch (error) {
        showError('Failed to add portfolio item');
        console.error('Portfolio submission error:', error);
    }
}

// Update Dashboard UI
function updateDashboard() {
    updatePortfolioTable();
    updatePerformanceSummary();
    updateAdvisorySignals();
    
    if (currentUser && currentUser.role === 'advisor') {
        loadAdvisorReports();
    }
}

// Update Portfolio Table
function updatePortfolioTable() {
    const tableBody = document.getElementById('portfolioTableBody');
    if (!tableBody) return;
    
    tableBody.innerHTML = '';
    
    portfolioData.forEach(item => {
        const row = document.createElement('tr');
        
        row.innerHTML = `
            <td>${item.stock_symbol}</td>
            <td>${item.quantity}</td>
            <td>₹${item.purchase_price.toFixed(2)}</td>
            <td>₹${item.current_price?.toFixed(2) || 'N/A'}</td>
            <td>${item.sector}</td>
            <td>
                <button class="btn btn-sm btn-danger" onclick="deletePortfolioItem(${item.id})">
                    Delete
                </button>
            </td>
        `;
        
        tableBody.appendChild(row);
    });
}

// Update Performance Summary
function updatePerformanceSummary() {
    const summaryElement = document.getElementById('performanceSummary');
    if (!summaryElement) return;
    
    const totalValue = portfolioData.reduce((sum, item) => {
        return sum + (item.current_price * item.quantity);
    }, 0);
    
    const totalInvestment = portfolioData.reduce((sum, item) => {
        return sum + (item.purchase_price * item.quantity);
    }, 0);
    
    const profitLoss = totalValue - totalInvestment;
    const profitLossPercent = totalInvestment > 0 ? (profitLoss / totalInvestment * 100) : 0;
    
    summaryElement.innerHTML = `
        <div class="card">
            <div class="card-body">
                <h5 class="card-title">Portfolio Summary</h5>
                <p>Total Value: ₹${totalValue.toFixed(2)}</p>
                <p>Total Investment: ₹${totalInvestment.toFixed(2)}</p>
                <p class="${profitLoss >= 0 ? 'text-success' : 'text-danger'}">
                    P&L: ₹${profitLoss.toFixed(2)} (${profitLossPercent.toFixed(2)}%)
                </p>
            </div>
        </div>
    `;
}

// Update Advisory Signals
function updateAdvisorySignals() {
    const signalsContainer = document.getElementById('advisorySignals');
    if (!signalsContainer) return;
    
    signalsContainer.innerHTML = '';
    
    advisorySignals.forEach(signal => {
        const badgeClass = getSignalBadgeClass(signal.signal);
        const card = document.createElement('div');
        card.className = 'card mb-2';
        
        card.innerHTML = `
            <div class="card-body">
                <h6 class="card-title">${signal.stock_symbol}</h6>
                <span class="badge ${badgeClass}">${signal.signal}</span>
                <p class="card-text mt-2">${signal.reason}</p>
                <small class="text-muted">Confidence: ${signal.confidence}%</small>
            </div>
        `;
        
        signalsContainer.appendChild(card);
    });
}

// Get CSS Class for Signal Badge
function getSignalBadgeClass(signal) {
    switch (signal) {
        case 'BUY': return 'bg-success';
        case 'SELL': return 'bg-danger';
        case 'HOLD': return 'bg-warning';
        default: return 'bg-secondary';
    }
}

// Load Advisor Reports
async function loadAdvisorReports() {
    try {
        const response = await fetch('/api/advisory/reports', {
            credentials: 'include'
        });
        
        if (response.ok) {
            const reports = await response.json();
            renderAdvisorReports(reports);
        }
    } catch (error) {
        console.error('Failed to load advisor reports:', error);
    }
}

// Render Advisor Reports
function renderAdvisorReports(reports) {
    const reportsContainer = document.getElementById('advisorReports');
    if (!reportsContainer) return;
    
    reportsContainer.innerHTML = '';
    
    reports.forEach(report => {
        const reportCard = document.createElement('div');
        reportCard.className = 'card mb-3';
        
        reportCard.innerHTML = `
            <div class="card-header">
                <h5>${report.title}</h5>
            </div>
            <div class="card-body">
                <div id="chart-${report.id}" style="height: 300px;"></div>
                <p class="mt-3">${report.insights}</p>
            </div>
        `;
        
        reportsContainer.appendChild(reportCard);
        renderChart(`chart-${report.id}`, report.chartData);
    });
}

// Render Chart (Placeholder - would integrate with Chart.js)
function renderChart(containerId, chartData) {
    const container = document.getElementById(containerId);
    if (!container) return;
    
    // Placeholder for chart rendering
    container.innerHTML = `
        <div class="text-center text-muted p-5">
            <i class="fas fa-chart-line fa-3x mb-3"></i>
            <p>Chart visualization would be implemented here</p>
            <small>Using Chart.js or similar library</small>
        </div>
    `;
}

// Toggle Advisor Reports Visibility
function toggleAdvisorReports() {
    const reportsSection = document.getElementById('advisorReportsSection');
    if (reportsSection) {
        reportsSection.classList.toggle('d-none');
    }
}

// Delete Portfolio Item
async function deletePortfolioItem(itemId) {
    if (!confirm('Are you sure you want to delete this portfolio item?')) {
        return;
    }
    
    try {
        const response = await fetch(`/api/portfolio/${itemId}`, {
            method: 'DELETE',
            credentials: 'include'
        });
        
        if (response.ok) {
            await loadPortfolioData();
            await loadAdvisorySignals();
            updateDashboard();
            showSuccess('Portfolio item deleted successfully');
        } else {
            throw new Error('Failed to delete portfolio item');
        }
    } catch (error) {
        showError('Failed to delete portfolio item');
        console.error('Delete error:', error);
    }
}

// Refresh Data
async function refreshData() {
    try {
        await loadInitialData();
        showSuccess('Data refreshed successfully');
    } catch (error) {
        showError('Failed to refresh data');
    }
}

// Handle Logout
async function handleLogout() {
    try {
        await fetch('/api/auth/logout', {
            method: 'POST',
            credentials: 'include'
        });
        
        redirectToLogin();
    } catch (error) {
        console.error('Logout error:', error);
        redirectToLogin();
    }
}

// Update UI Based on User Role
function updateUIForUserRole() {
    const advisorElements = document.querySelectorAll('.advisor-only');
    const clientElements = document.querySelectorAll('.client-only');
    
    if (currentUser && currentUser.role === 'advisor') {
        advisorElements.forEach(el => el.classList.remove('d-none'));
        clientElements.forEach(el => el.classList.add('d-none'));
    } else {
        advisorElements.forEach(el => el.classList.add('d-none'));
        clientElements.forEach(el => el.classList.remove('d-none'));
    }
    
    // Update user display
    const userDisplay = document.getElementById('userDisplay');
    if (userDisplay && currentUser) {
        userDisplay.textContent = `Welcome, ${currentUser.name} (${currentUser.role})`;
    }
}

// Redirect to Login Page
function redirectToLogin() {
    window.location.href = '/login.html';
}

// Show Success Message
function showSuccess(message) {
    showAlert(message, 'success');
}

// Show Error Message
function showError(message) {
    showAlert(message, 'danger');
}

// Show Alert Message
function showAlert(message, type) {
    const alertContainer = document.getElementById('alertContainer');
    if (!alertContainer) return;
    
    const alert = document.createElement('div');
    alert.className = `alert alert-${type} alert-dismissible fade show`;
    alert.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    alertContainer.appendChild(alert);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
        alert.remove();
    }, 5000);
}

// Export functions for global access (if needed)
window.deletePortfolioItem = deletePortfolioItem;
window.refreshData = refreshData;