// script.js - Frontend JavaScript for Investment Portfolio Management MVP

// Global state management
let currentUser = null;
let userPortfolios = [];
let advisorySignals = [];
let marketData = [];

// DOM Content Loaded Event Listener
document.addEventListener('DOMContentLoaded', function() {
    initializeApplication();
    setupEventListeners();
    loadInitialData();
});

// Initialize application
function initializeApplication() {
    checkAuthenticationStatus();
    setupNavigation();
    initializeCharts();
}

// Check if user is authenticated
function checkAuthenticationStatus() {
    const token = localStorage.getItem('authToken');
    if (token) {
        currentUser = JSON.parse(localStorage.getItem('userData'));
        updateUIForAuthenticatedUser();
    } else {
        showLoginView();
    }
}

// Setup event listeners
function setupEventListeners() {
    // Authentication events
    document.getElementById('loginForm')?.addEventListener('submit', handleLogin);
    document.getElementById('registerForm')?.addEventListener('submit', handleRegister);
    document.getElementById('logoutBtn')?.addEventListener('click', handleLogout);

    // Portfolio management events
    document.getElementById('createPortfolioForm')?.addEventListener('submit', handleCreatePortfolio);
    document.getElementById('refreshPortfolioBtn')?.addEventListener('click', refreshPortfolios);

    // Navigation events
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', handleNavigation);
    });
}

// API Service Functions
const apiService = {
    // Authentication endpoints
    async login(credentials) {
        const response = await fetch('/api/auth/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(credentials)
        });
        return handleResponse(response);
    },

    async register(userData) {
        const response = await fetch('/api/auth/register', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(userData)
        });
        return handleResponse(response);
    },

    // Portfolio endpoints
    async getPortfolios() {
        const response = await fetch('/api/portfolios', {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });
        return handleResponse(response);
    },

    async createPortfolio(portfolioData) {
        const response = await fetch('/api/portfolios', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            },
            body: JSON.stringify(portfolioData)
        });
        return handleResponse(response);
    },

    async updatePortfolio(portfolioId, portfolioData) {
        const response = await fetch(`/api/portfolios/${portfolioId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            },
            body: JSON.stringify(portfolioData)
        });
        return handleResponse(response);
    },

    async deletePortfolio(portfolioId) {
        const response = await fetch(`/api/portfolios/${portfolioId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });
        return handleResponse(response);
    },

    // Market data endpoints
    async getMarketData() {
        const response = await fetch('/api/market/data');
        return handleResponse(response);
    },

    async getAdvisorySignals() {
        const response = await fetch('/api/advisory/signals', {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });
        return handleResponse(response);
    },

    async getSectorAnalysis() {
        const response = await fetch('/api/market/sector-analysis', {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });
        return handleResponse(response);
    }
};

// Response handler
async function handleResponse(response) {
    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.message || 'Network response was not ok');
    }
    return response.json();
}

// Authentication handlers
async function handleLogin(event) {
    event.preventDefault();
    const formData = new FormData(event.target);
    const credentials = {
        email: formData.get('email'),
        password: formData.get('password')
    };

    try {
        const data = await apiService.login(credentials);
        localStorage.setItem('authToken', data.token);
        localStorage.setItem('userData', JSON.stringify(data.user));
        currentUser = data.user;
        updateUIForAuthenticatedUser();
        showNotification('Login successful!', 'success');
    } catch (error) {
        showNotification(error.message, 'error');
    }
}

async function handleRegister(event) {
    event.preventDefault();
    const formData = new FormData(event.target);
    const userData = {
        name: formData.get('name'),
        email: formData.get('email'),
        password: formData.get('password'),
        role: formData.get('role') || 'investor'
    };

    try {
        const data = await apiService.register(userData);
        showNotification('Registration successful! Please login.', 'success');
        switchToLoginView();
    } catch (error) {
        showNotification(error.message, 'error');
    }
}

function handleLogout() {
    localStorage.removeItem('authToken');
    localStorage.removeItem('userData');
    currentUser = null;
    userPortfolios = [];
    showLoginView();
    showNotification('Logged out successfully', 'info');
}

// Portfolio management handlers
async function handleCreatePortfolio(event) {
    event.preventDefault();
    const formData = new FormData(event.target);
    const portfolioData = {
        name: formData.get('portfolioName'),
        description: formData.get('portfolioDescription'),
        initialInvestment: parseFloat(formData.get('initialInvestment'))
    };

    try {
        await apiService.createPortfolio(portfolioData);
        await refreshPortfolios();
        event.target.reset();
        showNotification('Portfolio created successfully!', 'success');
    } catch (error) {
        showNotification(error.message, 'error');
    }
}

async function refreshPortfolios() {
    try {
        userPortfolios = await apiService.getPortfolios();
        renderPortfolios();
        updatePortfolioPerformanceCharts();
    } catch (error) {
        showNotification('Failed to load portfolios', 'error');
    }
}

// Navigation handler
function handleNavigation(event) {
    event.preventDefault();
    const target = event.target.getAttribute('data-target');
    showView(target);
}

// View management
function showView(viewName) {
    // Hide all views
    document.querySelectorAll('.view').forEach(view => {
        view.classList.add('d-none');
    });

    // Show requested view
    const targetView = document.getElementById(`${viewName}View`);
    if (targetView) {
        targetView.classList.remove('d-none');
        
        // Load view-specific data
        switch(viewName) {
            case 'dashboard':
                loadDashboardData();
                break;
            case 'portfolios':
                refreshPortfolios();
                break;
            case 'advisory':
                loadAdvisorySignals();
                break;
            case 'reports':
                if (currentUser?.role === 'advisor') {
                    loadAdvisorReports();
                }
                break;
        }
    }
}

function showLoginView() {
    showView('login');
    document.getElementById('userMenu').classList.add('d-none');
}

function updateUIForAuthenticatedUser() {
    document.getElementById('userMenu').classList.remove('d-none');
    document.getElementById('userName').textContent = currentUser.name;
    
    if (currentUser.role === 'advisor') {
        document.getElementById('reportsNav').classList.remove('d-none');
    } else {
        document.getElementById('reportsNav').classList.add('d-none');
    }
    
    showView('dashboard');
}

function switchToLoginView() {
    showView('login');
}

// Data loading functions
async function loadInitialData() {
    try {
        marketData = await apiService.getMarketData();
        if (currentUser) {
            await refreshPortfolios();
            await loadAdvisorySignals();
        }
    } catch (error) {
        console.error('Failed to load initial data:', error);
    }
}

async function loadDashboardData() {
    try {
        const [signals, sectorAnalysis] = await Promise.all([
            apiService.getAdvisorySignals(),
            apiService.getSectorAnalysis()
        ]);
        
        updateDashboardCharts(signals, sectorAnalysis);
        renderMarketOverview(marketData);
    } catch (error) {
        showNotification('Failed to load dashboard data', 'error');
    }
}

async function loadAdvisorySignals() {
    try {
        advisorySignals = await apiService.getAdvisorySignals();
        renderAdvisorySignals();
    } catch (error) {
        showNotification('Failed to load advisory signals', 'error');
    }
}

async function loadAdvisorReports() {
    try {
        const reportsData = await Promise.all([
            apiService.getPortfolios(),
            apiService.getSectorAnalysis(),
            apiService.getAdvisorySignals()
        ]);
        
        renderAdvisorReports(...reportsData);
    } catch (error) {
        showNotification('Failed to load advisor reports', 'error');
    }
}

// Rendering functions
function renderPortfolios() {
    const container = document.getElementById('portfoliosContainer');
    if (!container) return;

    container.innerHTML = userPortfolios.length > 0 ? '' : '<div class="col-12"><p class="text-center">No portfolios found</p></div>';

    userPortfolios.forEach(portfolio => {
        const portfolioCard = createPortfolioCard(portfolio);
        container.appendChild(portfolioCard);
    });
}

function createPortfolioCard(portfolio) {
    const col = document.createElement('div');
    col.className = 'col-md-6 col-lg-4 mb-4';
    
    const performanceChange = portfolio.performance?.change || 0;
    const changeClass = performanceChange >= 0 ? 'text-success' : 'text-danger';
    const changeIcon = performanceChange >= 0 ? '▲' : '▼';

    col.innerHTML = `
        <div class="card h-100 portfolio-card">
            <div class="card-body">
                <h5 class="card-title">${portfolio.name}</h5>
                <p class="card-text">${portfolio.description || 'No description'}</p>
                <div class="d-flex justify-content-between align-items-center">
                    <span class="h6">₹${portfolio.currentValue?.toLocaleString() || '0'}</span>
                    <span class="${changeClass}">
                        ${changeIcon} ${Math.abs(performanceChange)}%
                    </span>
                </div>
            </div>
            <div class="card-footer">
                <button class="btn btn-sm btn-outline-primary me-2" onclick="viewPortfolioDetails(${portfolio.id})">
                    View Details
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deletePortfolio(${portfolio.id})">
                    Delete
                </button>
            </div>
        </div>
    `;
    
    return col;
}

function renderAdvisorySignals() {
    const container = document.getElementById('advisorySignalsContainer');
    if (!container) return;

    container.innerHTML = advisorySignals.length > 0 ? '' : '<div class="col-12"><p class="text-center">No advisory signals available</p></div>';

    advisorySignals.forEach(signal => {
        const signalCard = createSignalCard(signal);
        container.appendChild(signalCard);
    });
}

function createSignalCard(signal) {
    const col = document.createElement('div');
    col.className = 'col-md-6 col-lg-4 mb-4';
    
    const signalClass = {
        'Buy': 'success',
        'Hold': 'warning',
        'Sell': 'danger'
    }[signal.recommendation] || 'secondary';

    col.innerHTML = `
        <div class="card h-100">
            <div class="card-header bg-${signalClass} text-white">
                <h6 class="mb-0">${signal.equitySymbol} - ${signal.recommendation}</h6>
            </div>
            <div class="card-body">
                <p><strong>Current Price:</strong> ₹${signal.currentPrice}</p>
                <p><strong>Target Price:</strong> ₹${signal.targetPrice}</p>
                <p><strong>Confidence:</strong> ${signal.confidence}%</p>
                <p><strong>Reason:</strong> ${signal.reason}</p>
            </div>
        </div>
    `;
    
    return col;
}

function renderMarketOverview(data) {
    const container = document.getElementById('marketOverview');
    if (!container) return;

    container.innerHTML = `
        <div class="row">
            <div class="col-md-3">
                <div class="card text-center">
                    <div class="card-body">
                        <h5>NIFTY 50</h5>
                        <h3 class="${data.nifty.change >= 0 ? 'text-success' : 'text-danger'}">
                            ${data.nifty.value} ${data.nifty.change >= 0 ? '▲' : '▼'} ${Math.abs(data.nifty.change)}%
                        </h3>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card text-center">
                    <div class="card-body">
                        <h5>SENSEX</h5>
                        <h3 class="${data.sensex.change >= 0 ? 'text-success' : 'text-danger'}">
                            ${data.sensex.value} ${data.sensex.change >= 0 ? '▲' : '▼'} ${Math.abs(data.sensex.change)}%
                        </h3>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card text-center">
                    <div class="card-body">
                        <h5>Advancers</h5>
                        <h3 class="text-success">${data.advancers}</h3>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card text-center">
                    <div class="card-body">
                        <h5>Decliners</h5>
                        <h3 class="text-danger">${data.decliners}</h3>
                    </div>
                </div>
            </div>
        </div>
    `;
}

// Chart initialization and update functions
function initializeCharts() {
    // Initialize Chart.js instances for dashboard
    const performanceCtx = document.getElementById('performanceChart')?.getContext('2d');
    const sectorCtx = document.getElementById('sectorChart')?.getContext('2d');
    
    if (performanceCtx) {
        window.performanceChart = new Chart(performanceCtx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'Portfolio Performance',
                    data: [],
                    borderColor: '#007bff',
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'top',
                    }
                }
            }
        });
    }

    if (sectorCtx) {
        window.sectorChart = new Chart(sectorCtx, {
            type: 'bar',
            data: {
                labels: [],
                datasets: [{
                    label: 'Sector Performance',
                    data: [],
                    backgroundColor: '#28a745'
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'top',
                    }
                }
            }
        });
    }
}

function updateDashboardCharts(signals, sectorAnalysis) {
    if (window.performanceChart) {
        window.performanceChart.data.labels = signals.map(s => s.equitySymbol);
        window.performanceChart.data.datasets[0].data = signals.map(s => s.confidence);
        window.performanceChart.update();
    }

    if (window.sectorChart && sectorAnalysis) {
        window.sectorChart.data.labels = sectorAnalysis.map(s => s.sector);
        window.sectorChart.data.datasets[0].data = sectorAnalysis.map(s => s.performance);
        window.sectorChart.update();
    }
}

function updatePortfolioPerformanceCharts() {
    // Update portfolio-specific charts
    userPortfolios.forEach(portfolio => {
        if (portfolio.performanceData) {
            renderPortfolioPerformanceChart(portfolio.id, portfolio.performanceData);
        }
    });
}

function renderPortfolioPerformanceChart(portfolioId, performanceData) {
    const ctx = document.getElementById(`chart-${portfolioId}`)?.getContext('2d');
    if (ctx) {
        new Chart(ctx, {
            type: 'line',
            data: {
                labels: performanceData.dates,
                datasets: [{
                    label: 'Portfolio Value',
                    data: performanceData.values,
                    borderColor: '#007bff',
                    fill: false
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: false
                    }
                }
            }
        });
    }
}

// Utility functions
function showNotification(message, type = 'info') {
    // Create Bootstrap toast notification
    const toastContainer = document.getElementById('toastContainer');
    const toastId = 'toast-' + Date.now();
    
    const toast = document.createElement('div');
    toast.className = `toast align-items-center text-white bg-${type === 'error' ? 'danger' : type}`;
    toast.setAttribute('role', 'alert');
    toast.setAttribute('aria-live', 'assertive');
    toast.setAttribute('aria-atomic', 'true');
    toast.id = toastId;
    
    toast.innerHTML = `
        <div class="d-flex">
            <div class="toast-body">
                ${message}
            </div>
            <button type="button" class="btn-close me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
        </div>
    `;
    
    toastContainer.appendChild(toast);
    
