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
    loadDashboardData();
}

// Check Authentication Status
async function checkAuthentication() {
    try {
        const response = await fetch('/api/auth/status', {
            credentials: 'include'
        });
        
        if (response.ok) {
            const data = await response.json();
            currentUser = data.user;
            updateUIForAuthenticatedUser();
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
    // Login Form
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }

    // Logout Button
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', handleLogout);
    }

    // Portfolio Management
    const addStockForm = document.getElementById('addStockForm');
    if (addStockForm) {
        addStockForm.addEventListener('submit', handleAddStock);
    }

    // Refresh Data Button
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', loadDashboardData);
    }

    // Responsive Menu Toggle
    const menuToggle = document.getElementById('menuToggle');
    if (menuToggle) {
        menuToggle.addEventListener('click', toggleMobileMenu);
    }
}

// Handle Login
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
            const data = await response.json();
            currentUser = data.user;
            window.location.href = '/dashboard.html';
        } else {
            showNotification('Login failed. Please check your credentials.', 'error');
        }
    } catch (error) {
        console.error('Login error:', error);
        showNotification('Network error. Please try again.', 'error');
    }
}

// Handle Logout
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

// Load Dashboard Data
async function loadDashboardData() {
    try {
        showLoadingState(true);
        
        // Load portfolio data
        const portfolioResponse = await fetch('/api/portfolio', {
            credentials: 'include'
        });
        
        if (portfolioResponse.ok) {
            portfolioData = await portfolioResponse.json();
            renderPortfolioTable(portfolioData);
        }

        // Load advisory signals
        const signalsResponse = await fetch('/api/advisory/signals', {
            credentials: 'include'
        });
        
        if (signalsResponse.ok) {
            advisorySignals = await signalsResponse.json();
            renderAdvisorySignals(advisorySignals);
        }

        // Load dashboard charts
        await loadCharts();

    } catch (error) {
        console.error('Failed to load dashboard data:', error);
        showNotification('Failed to load data. Please try again.', 'error');
    } finally {
        showLoadingState(false);
    }
}

// Handle Add Stock to Portfolio
async function handleAddStock(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const stockData = {
        symbol: formData.get('symbol'),
        quantity: parseInt(formData.get('quantity')),
        purchase_price: parseFloat(formData.get('purchase_price')),
        purchase_date: formData.get('purchase_date')
    };

    try {
        const response = await fetch('/api/portfolio', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(stockData),
            credentials: 'include'
        });

        if (response.ok) {
            const newStock = await response.json();
            portfolioData.push(newStock);
            renderPortfolioTable(portfolioData);
            event.target.reset();
            showNotification('Stock added successfully!', 'success');
            
            // Refresh advisory signals
            await loadAdvisorySignals();
        } else {
            showNotification('Failed to add stock. Please try again.', 'error');
        }
    } catch (error) {
        console.error('Add stock error:', error);
        showNotification('Network error. Please try again.', 'error');
    }
}

// Render Portfolio Table
function renderPortfolioTable(data) {
    const tableBody = document.getElementById('portfolioTableBody');
    if (!tableBody) return;

    tableBody.innerHTML = '';
    
    data.forEach(stock => {
        const row = document.createElement('tr');
        
        row.innerHTML = `
            <td>${stock.symbol}</td>
            <td>${stock.quantity}</td>
            <td>₹${stock.purchase_price.toFixed(2)}</td>
            <td>₹${stock.current_price.toFixed(2)}</td>
            <td>${calculateProfitLoss(stock)}</td>
            <td>${getSignalBadge(stock.advisory_signal)}</td>
            <td>
                <button class="btn btn-sm btn-danger" onclick="deleteStock(${stock.id})">
                    Delete
                </button>
            </td>
        `;
        
        tableBody.appendChild(row);
    });
}

// Render Advisory Signals
function renderAdvisorySignals(signals) {
    const container = document.getElementById('advisorySignalsContainer');
    if (!container) return;

    container.innerHTML = '';
    
    signals.forEach(signal => {
        const card = document.createElement('div');
        card.className = 'col-md-6 col-lg-4 mb-3';
        
        card.innerHTML = `
            <div class="card signal-card ${getSignalClass(signal.signal)}">
                <div class="card-body">
                    <h5 class="card-title">${signal.symbol}</h5>
                    <span class="signal-badge ${getSignalClass(signal.signal)}">
                        ${signal.signal}
                    </span>
                    <p class="card-text mt-2">${signal.reason}</p>
                    <small class="text-muted">Updated: ${new Date(signal.updated_at).toLocaleDateString()}</small>
                </div>
            </div>
        `;
        
        container.appendChild(card);
    });
}

// Load Charts
async function loadCharts() {
    try {
        // Load portfolio allocation chart
        const allocationResponse = await fetch('/api/portfolio/allocation', {
            credentials: 'include'
        });
        
        if (allocationResponse.ok) {
            const allocationData = await allocationResponse.json();
            renderAllocationChart(allocationData);
        }

        // Load performance chart
        const performanceResponse = await fetch('/api/portfolio/performance', {
            credentials: 'include'
        });
        
        if (performanceResponse.ok) {
            const performanceData = await performanceResponse.json();
            renderPerformanceChart(performanceData);
        }

    } catch (error) {
        console.error('Failed to load charts:', error);
    }
}

// Render Allocation Chart
function renderAllocationChart(data) {
    const ctx = document.getElementById('allocationChart');
    if (!ctx) return;

    // Using Chart.js (assumed to be included)
    new Chart(ctx, {
        type: 'pie',
        data: {
            labels: data.labels,
            datasets: [{
                data: data.values,
                backgroundColor: ['#4e73df', '#1cc88a', '#36b9cc', '#f6c23e', '#e74a3b']
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false
        }
    });
}

// Render Performance Chart
function renderPerformanceChart(data) {
    const ctx = document.getElementById('performanceChart');
    if (!ctx) return;

    new Chart(ctx, {
        type: 'line',
        data: {
            labels: data.dates,
            datasets: [{
                label: 'Portfolio Value',
                data: data.values,
                borderColor: '#4e73df',
                fill: false
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false
        }
    });
}

// Delete Stock
async function deleteStock(stockId) {
    if (!confirm('Are you sure you want to delete this stock?')) return;

    try {
        const response = await fetch(`/api/portfolio/${stockId}`, {
            method: 'DELETE',
            credentials: 'include'
        });

        if (response.ok) {
            portfolioData = portfolioData.filter(stock => stock.id !== stockId);
            renderPortfolioTable(portfolioData);
            showNotification('Stock deleted successfully!', 'success');
            
            // Refresh data
            await loadDashboardData();
        } else {
            showNotification('Failed to delete stock.', 'error');
        }
    } catch (error) {
        console.error('Delete stock error:', error);
        showNotification('Network error. Please try again.', 'error');
    }
}

// Helper Functions
function calculateProfitLoss(stock) {
    const profitLoss = (stock.current_price - stock.purchase_price) * stock.quantity;
    const percentage = ((stock.current_price - stock.purchase_price) / stock.purchase_price) * 100;
    
    const colorClass = profitLoss >= 0 ? 'text-success' : 'text-danger';
    return `
        <span class="${colorClass}">
            ₹${profitLoss.toFixed(2)} (${percentage.toFixed(2)}%)
        </span>
    `;
}

function getSignalBadge(signal) {
    const signalClass = getSignalClass(signal);
    return `<span class="badge ${signalClass}">${signal}</span>`;
}

function getSignalClass(signal) {
    switch (signal.toLowerCase()) {
        case 'buy': return 'bg-success';
        case 'hold': return 'bg-warning';
        case 'sell': return 'bg-danger';
        default: return 'bg-secondary';
    }
}

function showLoadingState(show) {
    const loadingElement = document.getElementById('loadingIndicator');
    const contentElement = document.getElementById('contentArea');
    
    if (loadingElement) loadingElement.style.display = show ? 'block' : 'none';
    if (contentElement) contentElement.style.display = show ? 'none' : 'block';
}

function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show`;
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;

    // Add to page
    const container = document.getElementById('notificationContainer') || document.body;
    container.appendChild(notification);

    // Auto remove after 5 seconds
    setTimeout(() => {
        notification.remove();
    }, 5000);
}

function updateUIForAuthenticatedUser() {
    const userElement = document.getElementById('userName');
    if (userElement && currentUser) {
        userElement.textContent = currentUser.name;
    }
    
    // Show/hide authenticated elements
    const authElements = document.querySelectorAll('.auth-only');
    authElements.forEach(el => el.style.display = 'block');
    
    const unauthElements = document.querySelectorAll('.unauth-only');
    unauthElements.forEach(el => el.style.display = 'none');
}

function redirectToLogin() {
    if (!window.location.pathname.includes('login.html')) {
        window.location.href = '/login.html';
    }
}

function toggleMobileMenu() {
    const sidebar = document.getElementById('sidebar');
    if (sidebar) {
        sidebar.classList.toggle('mobile-show');
    }
}

// Responsive event listeners
window.addEventListener('resize', function() {
    const sidebar = document.getElementById('sidebar');
    if (sidebar && window.innerWidth >= 768) {
        sidebar.classList.remove('mobile-show');
    }
});

// Export for global access (if needed)
window.PortfolioManager = {
    loadDashboardData,
    deleteStock,
    handleAddStock
};