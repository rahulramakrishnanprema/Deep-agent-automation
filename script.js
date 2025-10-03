// script.js - Frontend JavaScript for Portfolio Management Application
// This file handles the frontend functionality for the MVP web application for managing client stock portfolios in Indian equity markets

// Global variables
let currentPortfolio = [];
let advisorySignals = [];
let isAdvisor = false;

// DOM Content Loaded Event
document.addEventListener('DOMContentLoaded', function() {
    initializeApplication();
    setupEventListeners();
    checkUserRole();
});

// Initialize application
function initializeApplication() {
    loadPortfolioData();
    loadAdvisorySignals();
    updateDashboard();
}

// Setup event listeners
function setupEventListeners() {
    // Portfolio management
    document.getElementById('addStockForm')?.addEventListener('submit', handleAddStock);
    document.getElementById('removeStockBtn')?.addEventListener('click', handleRemoveStock);
    document.getElementById('refreshPortfolioBtn')?.addEventListener('click', refreshPortfolio);
    
    // Navigation
    document.getElementById('portfolioTab')?.addEventListener('click', showPortfolioView);
    document.getElementById('analyticsTab')?.addEventListener('click', showAnalyticsView);
    
    // Responsive menu
    document.getElementById('mobileMenuBtn')?.addEventListener('click', toggleMobileMenu);
}

// Check user role and adjust UI accordingly
function checkUserRole() {
    // Simulate role check - in real app, this would come from authentication
    const userRole = localStorage.getItem('userRole') || 'client';
    isAdvisor = userRole === 'advisor';
    
    if (isAdvisor) {
        document.getElementById('analyticsTab').style.display = 'block';
        initializeAdvisorDashboard();
    } else {
        document.getElementById('analyticsTab').style.display = 'none';
    }
}

// Portfolio Management Functions
async function loadPortfolioData() {
    try {
        const response = await fetch('/api/portfolio', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            currentPortfolio = data.portfolio || [];
            renderPortfolioTable();
        } else {
            console.error('Failed to load portfolio data');
            // Fallback to dummy data for demo
            loadDummyPortfolioData();
        }
    } catch (error) {
        console.error('Error loading portfolio:', error);
        loadDummyPortfolioData();
    }
}

function loadDummyPortfolioData() {
    // Dummy data for Indian equity markets
    currentPortfolio = [
        { id: 1, symbol: 'RELIANCE', name: 'Reliance Industries', quantity: 10, avgPrice: 2450, currentPrice: 2680 },
        { id: 2, symbol: 'TCS', name: 'Tata Consultancy Services', quantity: 5, avgPrice: 3200, currentPrice: 3350 },
        { id: 3, symbol: 'HDFCBANK', name: 'HDFC Bank', quantity: 8, avgPrice: 1400, currentPrice: 1520 },
        { id: 4, symbol: 'INFY', name: 'Infosys', quantity: 12, avgPrice: 1500, currentPrice: 1620 }
    ];
    renderPortfolioTable();
}

async function loadAdvisorySignals() {
    try {
        const response = await fetch('/api/advisory-signals', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            advisorySignals = data.signals || [];
            renderAdvisorySignals();
        } else {
            console.error('Failed to load advisory signals');
            loadDummyAdvisorySignals();
        }
    } catch (error) {
        console.error('Error loading advisory signals:', error);
        loadDummyAdvisorySignals();
    }
}

function loadDummyAdvisorySignals() {
    // Dummy advisory signals for Indian stocks
    advisorySignals = [
        { symbol: 'RELIANCE', signal: 'BUY', confidence: 85, reason: 'Strong sector growth and positive technical indicators' },
        { symbol: 'TCS', signal: 'HOLD', confidence: 70, reason: 'Stable performance, wait for better entry point' },
        { symbol: 'HDFCBANK', signal: 'BUY', confidence: 90, reason: 'Undervalued with strong fundamentals' },
        { symbol: 'INFY', signal: 'SELL', confidence: 65, reason: 'Technical indicators showing weakness' }
    ];
    renderAdvisorySignals();
}

// UI Rendering Functions
function renderPortfolioTable() {
    const tableBody = document.getElementById('portfolioTableBody');
    if (!tableBody) return;
    
    tableBody.innerHTML = '';
    
    currentPortfolio.forEach(stock => {
        const row = document.createElement('tr');
        const profitLoss = (stock.currentPrice - stock.avgPrice) * stock.quantity;
        const profitLossClass = profitLoss >= 0 ? 'profit' : 'loss';
        
        row.innerHTML = `
            <td><input type="checkbox" class="stock-checkbox" data-id="${stock.id}"></td>
            <td>${stock.symbol}</td>
            <td>${stock.name}</td>
            <td>${stock.quantity}</td>
            <td>₹${stock.avgPrice.toLocaleString()}</td>
            <td>₹${stock.currentPrice.toLocaleString()}</td>
            <td class="${profitLossClass}">₹${profitLoss.toLocaleString()}</td>
        `;
        tableBody.appendChild(row);
    });
    
    updatePortfolioSummary();
}

function renderAdvisorySignals() {
    const container = document.getElementById('advisorySignalsContainer');
    if (!container) return;
    
    container.innerHTML = '';
    
    advisorySignals.forEach(signal => {
        const signalCard = document.createElement('div');
        signalCard.className = `signal-card ${signal.signal.toLowerCase()}`;
        
        signalCard.innerHTML = `
            <h4>${signal.symbol}</h4>
            <div class="signal ${signal.signal.toLowerCase()}">${signal.signal}</div>
            <div class="confidence">Confidence: ${signal.confidence}%</div>
            <p>${signal.reason}</p>
        `;
        container.appendChild(signalCard);
    });
}

function updatePortfolioSummary() {
    const totalInvested = currentPortfolio.reduce((sum, stock) => sum + (stock.avgPrice * stock.quantity), 0);
    const currentValue = currentPortfolio.reduce((sum, stock) => sum + (stock.currentPrice * stock.quantity), 0);
    const totalGainLoss = currentValue - totalInvested;
    const gainLossPercent = totalInvested > 0 ? (totalGainLoss / totalInvested * 100) : 0;
    
    document.getElementById('totalInvested').textContent = `₹${totalInvested.toLocaleString()}`;
    document.getElementById('currentValue').textContent = `₹${currentValue.toLocaleString()}`;
    document.getElementById('totalGainLoss').textContent = `₹${totalGainLoss.toLocaleString()}`;
    document.getElementById('gainLossPercent').textContent = `${gainLossPercent.toFixed(2)}%`;
    
    const gainLossElement = document.getElementById('totalGainLoss');
    gainLossElement.className = totalGainLoss >= 0 ? 'profit' : 'loss';
}

// Event Handlers
async function handleAddStock(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const stockData = {
        symbol: formData.get('symbol'),
        name: formData.get('name'),
        quantity: parseInt(formData.get('quantity')),
        avgPrice: parseFloat(formData.get('avgPrice'))
    };
    
    try {
        const response = await fetch('/api/portfolio/add', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            },
            body: JSON.stringify(stockData)
        });
        
        if (response.ok) {
            event.target.reset();
            await loadPortfolioData();
            showNotification('Stock added successfully!', 'success');
        } else {
            throw new Error('Failed to add stock');
        }
    } catch (error) {
        console.error('Error adding stock:', error);
        // Fallback: Add to local array for demo
        stockData.id = Date.now();
        stockData.currentPrice = stockData.avgPrice; // For demo purposes
        currentPortfolio.push(stockData);
        renderPortfolioTable();
        showNotification('Stock added (demo mode)', 'info');
    }
}

async function handleRemoveStock() {
    const selectedStocks = Array.from(document.querySelectorAll('.stock-checkbox:checked'))
        .map(checkbox => parseInt(checkbox.dataset.id));
    
    if (selectedStocks.length === 0) {
        showNotification('Please select stocks to remove', 'warning');
        return;
    }
    
    try {
        const response = await fetch('/api/portfolio/remove', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            },
            body: JSON.stringify({ stockIds: selectedStocks })
        });
        
        if (response.ok) {
            await loadPortfolioData();
            showNotification('Stocks removed successfully!', 'success');
        } else {
            throw new Error('Failed to remove stocks');
        }
    } catch (error) {
        console.error('Error removing stocks:', error);
        // Fallback: Remove from local array for demo
        currentPortfolio = currentPortfolio.filter(stock => !selectedStocks.includes(stock.id));
        renderPortfolioTable();
        showNotification('Stocks removed (demo mode)', 'info');
    }
}

async function refreshPortfolio() {
    try {
        const response = await fetch('/api/portfolio/refresh', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });
        
        if (response.ok) {
            await loadPortfolioData();
            showNotification('Portfolio refreshed!', 'success');
        } else {
            throw new Error('Failed to refresh portfolio');
        }
    } catch (error) {
        console.error('Error refreshing portfolio:', error);
        // Fallback: Simulate price changes for demo
        currentPortfolio.forEach(stock => {
            const changePercent = (Math.random() - 0.5) * 0.1; // ±5% change
            stock.currentPrice = Math.max(1, stock.currentPrice * (1 + changePercent));
        });
        renderPortfolioTable();
        showNotification('Portfolio refreshed (demo mode)', 'info');
    }
}

// View Management
function showPortfolioView() {
    document.getElementById('portfolioView').classList.remove('hidden');
    document.getElementById('analyticsView').classList.add('hidden');
    updateActiveTab('portfolioTab');
}

function showAnalyticsView() {
    if (!isAdvisor) {
        showNotification('Access denied. Advisor privileges required.', 'error');
        return;
    }
    
    document.getElementById('portfolioView').classList.add('hidden');
    document.getElementById('analyticsView').classList.remove('hidden');
    updateActiveTab('analyticsTab');
    initializeAdvisorDashboard();
}

function updateActiveTab(activeTabId) {
    document.querySelectorAll('.nav-tab').forEach(tab => tab.classList.remove('active'));
    document.getElementById(activeTabId).classList.add('active');
}

// Advisor Dashboard Functions
function initializeAdvisorDashboard() {
    if (!isAdvisor) return;
    
    loadAnalyticsData();
    setupAnalyticsCharts();
}

async function loadAnalyticsData() {
    try {
        const response = await fetch('/api/analytics', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            updateAnalyticsDashboard(data);
        } else {
            throw new Error('Failed to load analytics data');
        }
    } catch (error) {
        console.error('Error loading analytics:', error);
        loadDummyAnalyticsData();
    }
}

function loadDummyAnalyticsData() {
    const dummyData = {
        portfolioPerformance: {
            labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
            data: [100, 105, 110, 108, 115, 120]
        },
        sectorAllocation: [
            { sector: 'Technology', allocation: 35 },
            { sector: 'Financial', allocation: 25 },
            { sector: 'Energy', allocation: 20 },
            { sector: 'Healthcare', allocation: 15 },
            { sector: 'Other', allocation: 5 }
        ],
        riskMetrics: {
            sharpeRatio: 1.2,
            volatility: 0.15,
            maxDrawdown: -0.08
        }
    };
    updateAnalyticsDashboard(dummyData);
}

function updateAnalyticsDashboard(data) {
    // Update performance metrics
    document.getElementById('sharpeRatio').textContent = data.riskMetrics.sharpeRatio.toFixed(2);
    document.getElementById('volatility').textContent = `${(data.riskMetrics.volatility * 100).toFixed(1)}%`;
    document.getElementById('maxDrawdown').textContent = `${(data.riskMetrics.maxDrawdown * 100).toFixed(1)}%`;
}

function setupAnalyticsCharts() {
    // This would initialize actual charts using a library like Chart.js
    // For this demo, we'll just show placeholder messages
    console.log('Analytics charts would be initialized here with real data');
}

// Utility Functions
function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    // Add to page
    document.body.appendChild(notification);
    
    // Remove after delay
    setTimeout(() => {
        notification.classList.add('fade-out');
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

function toggleMobileMenu() {
    const nav = document.querySelector('nav');
    nav.classList.toggle('mobile-open');
}

function updateDashboard() {
    updatePortfolioSummary();
    renderAdvisorySignals();
}

// Error handling for fetch operations
function handleFetchError(error, context) {
    console.error(`Error in ${context}:`, error);
    showNotification(`Error: ${error.message}`, 'error');
}

// Export functions for testing (if needed)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        initializeApplication,
        loadPortfolioData,
        loadAdvisorySignals,
        renderPortfolioTable,
        renderAdvisorySignals,
        updatePortfolioSummary
    };
}