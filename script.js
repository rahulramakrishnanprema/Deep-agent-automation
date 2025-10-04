// script.js - Frontend JavaScript for Portfolio Management Application
// This file handles UI interactions, API calls, and dashboard functionality

document.addEventListener('DOMContentLoaded', function() {
    // Initialize application
    initApp();
});

// Global variables
let currentUserRole = 'client'; // Default role
let portfolioData = [];
let advisorySignals = [];

// Initialize the application
function initApp() {
    checkUserRole();
    loadPortfolioData();
    setupEventListeners();
    
    // If user is advisor, load dashboard
    if (currentUserRole === 'advisor') {
        loadAdvisorDashboard();
    }
}

// Check user role (simulated for demo purposes)
function checkUserRole() {
    // In real implementation, this would come from authentication
    const urlParams = new URLSearchParams(window.location.search);
    const role = urlParams.get('role') || 'client';
    currentUserRole = role;
    
    // Update UI based on role
    updateUIBasedOnRole();
}

// Update UI elements based on user role
function updateUIBasedOnRole() {
    const advisorElements = document.querySelectorAll('.advisor-only');
    const clientElements = document.querySelectorAll('.client-only');
    
    if (currentUserRole === 'advisor') {
        advisorElements.forEach(el => el.style.display = 'block');
        clientElements.forEach(el => el.style.display = 'none');
    } else {
        advisorElements.forEach(el => el.style.display = 'none');
        clientElements.forEach(el => el.style.display = 'block');
    }
}

// Load portfolio data from backend API
async function loadPortfolioData() {
    try {
        const response = await fetch('/api/portfolio', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                // In real implementation, include authentication token
            }
        });
        
        if (!response.ok) {
            throw new Error('Failed to fetch portfolio data');
        }
        
        portfolioData = await response.json();
        displayPortfolioData(portfolioData);
        
    } catch (error) {
        console.error('Error loading portfolio data:', error);
        // Fallback to dummy data
        loadDummyPortfolioData();
    }
}

// Load dummy portfolio data (fallback)
function loadDummyPortfolioData() {
    portfolioData = [
        {
            id: 1,
            stockName: 'Reliance Industries',
            symbol: 'RELIANCE',
            quantity: 10,
            purchasePrice: 2400,
            currentPrice: 2600,
            sector: 'Energy'
        },
        {
            id: 2,
            stockName: 'Infosys',
            symbol: 'INFY',
            quantity: 15,
            purchasePrice: 1500,
            currentPrice: 1650,
            sector: 'IT'
        },
        {
            id: 3,
            stockName: 'HDFC Bank',
            symbol: 'HDFCBANK',
            quantity: 8,
            purchasePrice: 1400,
            currentPrice: 1450,
            sector: 'Banking'
        }
    ];
    
    displayPortfolioData(portfolioData);
}

// Display portfolio data in the UI
function displayPortfolioData(data) {
    const portfolioTable = document.getElementById('portfolio-table');
    const portfolioBody = portfolioTable.querySelector('tbody');
    
    // Clear existing data
    portfolioBody.innerHTML = '';
    
    data.forEach(stock => {
        const row = document.createElement('tr');
        const profitLoss = (stock.currentPrice - stock.purchasePrice) * stock.quantity;
        const profitLossPercent = ((stock.currentPrice - stock.purchasePrice) / stock.purchasePrice * 100).toFixed(2);
        
        row.innerHTML = `
            <td>${stock.stockName}</td>
            <td>${stock.symbol}</td>
            <td>${stock.quantity}</td>
            <td>₹${stock.purchasePrice.toLocaleString()}</td>
            <td>₹${stock.currentPrice.toLocaleString()}</td>
            <td class="${profitLoss >= 0 ? 'text-success' : 'text-danger'}">
                ₹${Math.abs(profitLoss).toLocaleString()} (${profitLossPercent}%)
            </td>
            <td>${stock.sector}</td>
        `;
        
        portfolioBody.appendChild(row);
    });
    
    // Update summary statistics
    updatePortfolioSummary(data);
}

// Update portfolio summary statistics
function updatePortfolioSummary(data) {
    const totalInvestment = data.reduce((sum, stock) => sum + (stock.purchasePrice * stock.quantity), 0);
    const currentValue = data.reduce((sum, stock) => sum + (stock.currentPrice * stock.quantity), 0);
    const totalProfitLoss = currentValue - totalInvestment;
    const profitLossPercent = ((totalProfitLoss / totalInvestment) * 100).toFixed(2);
    
    document.getElementById('total-investment').textContent = `₹${totalInvestment.toLocaleString()}`;
    document.getElementById('current-value').textContent = `₹${currentValue.toLocaleString()}`;
    document.getElementById('total-pl').textContent = `₹${Math.abs(totalProfitLoss).toLocaleString()}`;
    document.getElementById('pl-percent').textContent = `${profitLossPercent}%`;
    
    const plElement = document.getElementById('total-pl');
    plElement.className = totalProfitLoss >= 0 ? 'text-success' : 'text-danger';
}

// Setup event listeners for UI interactions
function setupEventListeners() {
    // Add stock form submission
    const addStockForm = document.getElementById('add-stock-form');
    if (addStockForm) {
        addStockForm.addEventListener('submit', handleAddStock);
    }
    
    // Refresh portfolio button
    const refreshBtn = document.getElementById('refresh-portfolio');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', loadPortfolioData);
    }
    
    // Generate advisory signals button
    const generateSignalsBtn = document.getElementById('generate-signals');
    if (generateSignalsBtn) {
        generateSignalsBtn.addEventListener('click', generateAdvisorySignals);
    }
}

// Handle add stock form submission
async function handleAddStock(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const stockData = {
        stockName: formData.get('stockName'),
        symbol: formData.get('symbol'),
        quantity: parseInt(formData.get('quantity')),
        purchasePrice: parseFloat(formData.get('purchasePrice')),
        sector: formData.get('sector')
    };
    
    try {
        const response = await fetch('/api/portfolio', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(stockData)
        });
        
        if (!response.ok) {
            throw new Error('Failed to add stock');
        }
        
        // Refresh portfolio data
        await loadPortfolioData();
        event.target.reset();
        
        // Show success message
        showAlert('Stock added successfully!', 'success');
        
    } catch (error) {
        console.error('Error adding stock:', error);
        showAlert('Error adding stock. Please try again.', 'danger');
    }
}

// Generate advisory signals
async function generateAdvisorySignals() {
    if (currentUserRole !== 'advisor') {
        showAlert('Access denied. Advisor role required.', 'warning');
        return;
    }
    
    try {
        const response = await fetch('/api/advisory/signals', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ portfolio: portfolioData })
        });
        
        if (!response.ok) {
            throw new Error('Failed to generate advisory signals');
        }
        
        advisorySignals = await response.json();
        displayAdvisorySignals(advisorySignals);
        showAlert('Advisory signals generated successfully!', 'success');
        
    } catch (error) {
        console.error('Error generating advisory signals:', error);
        // Fallback to dummy signals
        generateDummyAdvisorySignals();
    }
}

// Generate dummy advisory signals (fallback)
function generateDummyAdvisorySignals() {
    advisorySignals = portfolioData.map(stock => {
        const signals = ['BUY', 'HOLD', 'SELL'];
        const randomSignal = signals[Math.floor(Math.random() * signals.length)];
        const reasons = [
            'Strong historical performance',
            'Positive technical indicators',
            'Sector growth potential',
            'Positive market sentiment'
        ];
        
        return {
            symbol: stock.symbol,
            stockName: stock.stockName,
            signal: randomSignal,
            confidence: Math.random() * 100,
            reasons: reasons.slice(0, Math.floor(Math.random() * reasons.length) + 1),
            timestamp: new Date().toISOString()
        };
    });
    
    displayAdvisorySignals(advisorySignals);
}

// Display advisory signals in the UI
function displayAdvisorySignals(signals) {
    const signalsContainer = document.getElementById('advisory-signals');
    signalsContainer.innerHTML = '';
    
    signals.forEach(signal => {
        const card = document.createElement('div');
        card.className = 'card mb-3';
        
        let badgeClass = '';
        switch (signal.signal) {
            case 'BUY': badgeClass = 'bg-success'; break;
            case 'HOLD': badgeClass = 'bg-warning'; break;
            case 'SELL': badgeClass = 'bg-danger'; break;
        }
        
        card.innerHTML = `
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-center">
                    <h5 class="card-title">${signal.stockName} (${signal.symbol})</h5>
                    <span class="badge ${badgeClass}">${signal.signal}</span>
                </div>
                <p class="card-text">
                    <strong>Confidence:</strong> ${signal.confidence.toFixed(1)}%<br>
                    <strong>Reasons:</strong><br>
                    <ul>
                        ${signal.reasons.map(reason => `<li>${reason}</li>`).join('')}
                    </ul>
                </p>
                <small class="text-muted">Generated: ${new Date(signal.timestamp).toLocaleString()}</small>
            </div>
        `;
        
        signalsContainer.appendChild(card);
    });
}

// Load advisor dashboard
async function loadAdvisorDashboard() {
    try {
        // Load dashboard data
        const [portfolioResponse, marketResponse] = await Promise.all([
            fetch('/api/portfolio/stats'),
            fetch('/api/market/data')
        ]);
        
        if (!portfolioResponse.ok || !marketResponse.ok) {
            throw new Error('Failed to load dashboard data');
        }
        
        const portfolioStats = await portfolioResponse.json();
        const marketData = await marketResponse.json();
        
        // Render charts
        renderPortfolioCharts(portfolioStats);
        renderMarketCharts(marketData);
        
    } catch (error) {
        console.error('Error loading dashboard:', error);
        // Fallback to dummy data
        loadDummyDashboardData();
    }
}

// Load dummy dashboard data (fallback)
function loadDummyDashboardData() {
    const portfolioStats = {
        totalValue: 1250000,
        sectorDistribution: [
            { sector: 'IT', value: 450000 },
            { sector: 'Banking', value: 350000 },
            { sector: 'Energy', value: 300000 },
            { sector: 'Healthcare', value: 150000 }
        ],
        performanceHistory: [
            { date: '2024-01', value: 1000000 },
            { date: '2024-02', value: 1100000 },
            { date: '2024-03', value: 1150000 },
            { date: '2024-04', value: 1250000 }
        ]
    };
    
    const marketData = {
        indices: [
            { name: 'Nifty 50', value: 22000, change: 1.5 },
            { name: 'Sensex', value: 73000, change: 1.2 },
            { name: 'Bank Nifty', value: 47000, change: 2.1 }
        ],
        sectorPerformance: [
            { sector: 'IT', performance: 8.5 },
            { sector: 'Banking', performance: 6.2 },
            { sector: 'Energy', performance: 4.8 },
            { sector: 'Healthcare', performance: 7.1 }
        ]
    };
    
    renderPortfolioCharts(portfolioStats);
    renderMarketCharts(marketData);
}

// Render portfolio charts
function renderPortfolioCharts(stats) {
    // Sector distribution pie chart
    const sectorCtx = document.getElementById('sector-distribution-chart');
    if (sectorCtx) {
        new Chart(sectorCtx, {
            type: 'pie',
            data: {
                labels: stats.sectorDistribution.map(item => item.sector),
                datasets: [{
                    data: stats.sectorDistribution.map(item => item.value),
                    backgroundColor: ['#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0']
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        });
    }
    
    // Performance history line chart
    const performanceCtx = document.getElementById('performance-chart');
    if (performanceCtx) {
        new Chart(performanceCtx, {
            type: 'line',
            data: {
                labels: stats.performanceHistory.map(item => item.date),
                datasets: [{
                    label: 'Portfolio Value',
                    data: stats.performanceHistory.map(item => item.value),
                    borderColor: '#36A2EB',
                    tension: 0.1
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

// Render market charts
function renderMarketCharts(marketData) {
    // Market indices bar chart
    const indicesCtx = document.getElementById('market-indices-chart');
    if (indicesCtx) {
        new Chart(indicesCtx, {
            type: 'bar',
            data: {
                labels: marketData.indices.map(item => item.name),
                datasets: [{
                    label: 'Change (%)',
                    data: marketData.indices.map(item => item.change),
                    backgroundColor: marketData.indices.map(item => 
                        item.change >= 0 ? '#4BC0C0' : '#FF6384'
                    )
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }
}

// Show alert message
function showAlert(message, type) {
    const alertContainer = document.getElementById('alert-container');
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

// Export functions for testing
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        initApp,
        loadPortfolioData,
        generateAdvisorySignals,
        displayPortfolioData,
        updatePortfolioSummary
    };
}