// script.js - Frontend JavaScript for Portfolio Management Dashboard

// DOM Elements
const loginForm = document.getElementById('loginForm');
const portfolioForm = document.getElementById('portfolioForm');
const advisorDashboard = document.getElementById('advisorDashboard');
const clientDashboard = document.getElementById('clientDashboard');
const portfolioList = document.getElementById('portfolioList');
const signalList = document.getElementById('signalList');
const performanceChart = document.getElementById('performanceChart');
const sectorChart = document.getElementById('sectorChart');

// Global State
let currentUser = null;
let portfolios = [];
let advisorySignals = [];

// Initialize Application
document.addEventListener('DOMContentLoaded', function() {
    initializeEventListeners();
    checkAuthenticationStatus();
    loadDummyData();
});

// Event Listeners
function initializeEventListeners() {
    // Login Form
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }

    // Portfolio Form
    if (portfolioForm) {
        portfolioForm.addEventListener('submit', handlePortfolioSubmit);
    }

    // Navigation
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', handleNavigation);
    });

    // Refresh Data Button
    const refreshBtn = document.getElementById('refreshData');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', refreshData);
    }
}

// Authentication Functions
async function handleLogin(e) {
    e.preventDefault();
    
    const formData = new FormData(loginForm);
    const username = formData.get('username');
    const password = formData.get('password');

    try {
        const response = await fetch('/api/auth/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });

        if (response.ok) {
            const userData = await response.json();
            currentUser = userData;
            localStorage.setItem('authToken', userData.token);
            updateUIAfterLogin(userData);
        } else {
            showNotification('Invalid credentials', 'error');
        }
    } catch (error) {
        console.error('Login error:', error);
        showNotification('Login failed', 'error');
    }
}

function checkAuthenticationStatus() {
    const token = localStorage.getItem('authToken');
    if (token) {
        // Verify token and get user data
        fetch('/api/auth/verify', {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        })
        .then(response => {
            if (response.ok) {
                return response.json();
            }
            throw new Error('Invalid token');
        })
        .then(userData => {
            currentUser = userData;
            updateUIAfterLogin(userData);
        })
        .catch(() => {
            localStorage.removeItem('authToken');
            showLoginScreen();
        });
    } else {
        showLoginScreen();
    }
}

function logout() {
    localStorage.removeItem('authToken');
    currentUser = null;
    showLoginScreen();
    showNotification('Logged out successfully', 'success');
}

// Portfolio Management
async function handlePortfolioSubmit(e) {
    e.preventDefault();
    
    const formData = new FormData(portfolioForm);
    const portfolioData = {
        name: formData.get('portfolioName'),
        stocks: Array.from(formData.getAll('stocks')).map(stock => ({
            symbol: stock,
            quantity: parseInt(formData.get(`quantity_${stock}`)),
            purchasePrice: parseFloat(formData.get(`price_${stock}`))
        })),
        clientId: formData.get('clientId') || currentUser.id
    };

    try {
        const response = await fetch('/api/portfolios', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            },
            body: JSON.stringify(portfolioData)
        });

        if (response.ok) {
            const newPortfolio = await response.json();
            portfolios.push(newPortfolio);
            renderPortfolios();
            showNotification('Portfolio created successfully', 'success');
            portfolioForm.reset();
        } else {
            showNotification('Failed to create portfolio', 'error');
        }
    } catch (error) {
        console.error('Portfolio creation error:', error);
        showNotification('Network error', 'error');
    }
}

async function fetchPortfolios() {
    try {
        const response = await fetch('/api/portfolios', {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });

        if (response.ok) {
            portfolios = await response.json();
            renderPortfolios();
        }
    } catch (error) {
        console.error('Error fetching portfolios:', error);
        // Fallback to dummy data
        loadDummyData();
    }
}

async function deletePortfolio(portfolioId) {
    try {
        const response = await fetch(`/api/portfolios/${portfolioId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });

        if (response.ok) {
            portfolios = portfolios.filter(p => p.id !== portfolioId);
            renderPortfolios();
            showNotification('Portfolio deleted', 'success');
        }
    } catch (error) {
        console.error('Error deleting portfolio:', error);
        showNotification('Delete failed', 'error');
    }
}

// Advisory Signals
async function fetchAdvisorySignals() {
    try {
        const response = await fetch('/api/signals', {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });

        if (response.ok) {
            advisorySignals = await response.json();
            renderAdvisorySignals();
            renderCharts();
        }
    } catch (error) {
        console.error('Error fetching signals:', error);
        // Fallback to dummy data
        generateDummySignals();
    }
}

function generateAdvisorySignal(stock) {
    // Simple signal generation logic (would be more complex in production)
    const factors = {
        historicalPerformance: Math.random() > 0.3 ? 'good' : 'poor',
        technicalIndicators: Math.random() > 0.4 ? 'bullish' : 'bearish',
        sectorPotential: Math.random() > 0.5 ? 'high' : 'low',
        marketBuzz: Math.random() > 0.6 ? 'positive' : 'negative'
    };

    let signal = 'HOLD';
    let confidence = 0.5;

    const positiveFactors = Object.values(factors).filter(f => 
        ['good', 'bullish', 'high', 'positive'].includes(f)
    ).length;

    if (positiveFactors >= 3) {
        signal = 'BUY';
        confidence = 0.7 + (Math.random() * 0.3);
    } else if (positiveFactors <= 1) {
        signal = 'SELL';
        confidence = 0.6 + (Math.random() * 0.3);
    }

    return {
        stock: stock.symbol,
        signal,
        confidence: Math.round(confidence * 100),
        factors,
        timestamp: new Date().toISOString()
    };
}

// Visualization and Charts
function renderCharts() {
    if (!performanceChart || !sectorChart) return;

    // Performance Chart (using Chart.js)
    const performanceCtx = performanceChart.getContext('2d');
    new Chart(performanceCtx, {
        type: 'line',
        data: {
            labels: portfolios.map(p => p.name),
            datasets: [{
                label: 'Portfolio Performance (%)',
                data: portfolios.map(() => Math.random() * 30 - 10), // Dummy data
                borderColor: '#007bff',
                tension: 0.1
            }]
        }
    });

    // Sector Chart
    const sectorCtx = sectorChart.getContext('2d');
    const sectors = ['IT', 'Banking', 'Pharma', 'Auto', 'FMCG'];
    new Chart(sectorCtx, {
        type: 'bar',
        data: {
            labels: sectors,
            datasets: [{
                label: 'Sector Performance',
                data: sectors.map(() => Math.random() * 20 - 5), // Dummy data
                backgroundColor: '#28a745'
            }]
        }
    });
}

// UI Update Functions
function updateUIAfterLogin(userData) {
    document.getElementById('loginScreen').classList.add('d-none');
    
    if (userData.role === 'advisor') {
        document.getElementById('advisorDashboard').classList.remove('d-none');
        fetchPortfolios();
        fetchAdvisorySignals();
    } else {
        document.getElementById('clientDashboard').classList.remove('d-none');
        fetchPortfolios();
    }

    // Update user info
    const userInfoElements = document.querySelectorAll('.user-info');
    userInfoElements.forEach(el => {
        el.textContent = `${userData.name} (${userData.role})`;
    });
}

function showLoginScreen() {
    document.getElementById('loginScreen').classList.remove('d-none');
    document.getElementById('advisorDashboard').classList.add('d-none');
    document.getElementById('clientDashboard').classList.add('d-none');
}

function renderPortfolios() {
    if (!portfolioList) return;

    portfolioList.innerHTML = portfolios.map(portfolio => `
        <div class="col-md-6 mb-3">
            <div class="card">
                <div class="card-header d-flex justify-content-between align-items-center">
                    <h5>${portfolio.name}</h5>
                    <button class="btn btn-sm btn-danger" onclick="deletePortfolio(${portfolio.id})">
                        <i class="bi bi-trash"></i>
                    </button>
                </div>
                <div class="card-body">
                    <h6>Stocks:</h6>
                    <ul class="list-group">
                        ${portfolio.stocks.map(stock => `
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                ${stock.symbol}
                                <span class="badge bg-primary rounded-pill">
                                    ${stock.quantity} shares
                                </span>
                            </li>
                        `).join('')}
                    </ul>
                </div>
            </div>
        </div>
    `).join('');
}

function renderAdvisorySignals() {
    if (!signalList || currentUser?.role !== 'advisor') return;

    signalList.innerHTML = advisorySignals.map(signal => `
        <div class="col-md-4 mb-3">
            <div class="card signal-card ${getSignalClass(signal.signal)}">
                <div class="card-header">
                    <h6>${signal.stock}</h6>
                    <span class="badge ${getSignalBadgeClass(signal.signal)}">
                        ${signal.signal}
                    </span>
                </div>
                <div class="card-body">
                    <p>Confidence: ${signal.confidence}%</p>
                    <small class="text-muted">
                        ${new Date(signal.timestamp).toLocaleDateString()}
                    </small>
                </div>
            </div>
        </div>
    `).join('');
}

function getSignalClass(signal) {
    const classes = {
        'BUY': 'border-success',
        'SELL': 'border-danger',
        'HOLD': 'border-warning'
    };
    return classes[signal] || '';
}

function getSignalBadgeClass(signal) {
    const classes = {
        'BUY': 'bg-success',
        'SELL': 'bg-danger',
        'HOLD': 'bg-warning'
    };
    return classes[signal] || '';
}

// Dummy Data Implementation
function loadDummyData() {
    // Dummy portfolios for MVP
    portfolios = [
        {
            id: 1,
            name: 'Tech Growth Portfolio',
            stocks: [
                { symbol: 'INFY', quantity: 50, purchasePrice: 1500 },
                { symbol: 'TCS', quantity: 30, purchasePrice: 3200 },
                { symbol: 'HCLTECH', quantity: 40, purchasePrice: 1100 }
            ]
        },
        {
            id: 2,
            name: 'Banking Dividend Portfolio',
            stocks: [
                { symbol: 'HDFCBANK', quantity: 20, purchasePrice: 1400 },
                { symbol: 'ICICIBANK', quantity: 25, purchasePrice: 900 },
                { symbol: 'SBIN', quantity: 35, purchasePrice: 600 }
            ]
        }
    ];

    generateDummySignals();
    renderPortfolios();
    renderAdvisorySignals();
    renderCharts();
}

function generateDummySignals() {
    const allStocks = [...new Set(portfolios.flatMap(p => p.stocks.map(s => s.symbol)))];
    advisorySignals = allStocks.map(stock => generateAdvisorySignal({ symbol: stock }));
}

// Utility Functions
function showNotification(message, type = 'info') {
    // Create Bootstrap toast notification
    const toastContainer = document.getElementById('toastContainer');
    const toastId = 'toast-' + Date.now();
    
    const toastHTML = `
        <div class="toast align-items-center text-white bg-${type} border-0" role="alert" id="${toastId}">
            <div class="d-flex">
                <div class="toast-body">${message}</div>
                <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
            </div>
        </div>
    `;
    
    toastContainer.innerHTML += toastHTML;
    const toast = new bootstrap.Toast(document.getElementById(toastId));
    toast.show();
}

function handleNavigation(e) {
    e.preventDefault();
    const target = e.target.getAttribute('data-target');
    
    // Hide all sections
    document.querySelectorAll('.content-section').forEach(section => {
        section.classList.add('d-none');
    });
    
    // Show target section
    document.getElementById(target).classList.remove('d-none');
}

async function refreshData() {
    showNotification('Refreshing data...', 'info');
    await fetchPortfolios();
    await fetchAdvisorySignals();
    showNotification('Data refreshed', 'success');
}

// Export functions for global access
window.deletePortfolio = deletePortfolio;
window.logout = logout;