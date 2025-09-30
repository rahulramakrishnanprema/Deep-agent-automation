// script.js - Frontend JavaScript for Portfolio Management MVP

// Global variables
let currentUser = null;
let portfolios = [];
let advisorySignals = [];

// DOM Ready
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

// Initialize the application
function initializeApp() {
    checkAuthentication();
    setupEventListeners();
    loadDummyData();
}

// Check if user is authenticated
function checkAuthentication() {
    // For MVP, use dummy authentication
    const userRole = localStorage.getItem('userRole') || 'client';
    currentUser = {
        id: 1,
        name: 'Demo User',
        role: userRole,
        email: 'demo@example.com'
    };
    
    updateUIForUserRole();
}

// Update UI based on user role
function updateUIForUserRole() {
    const advisorSections = document.querySelectorAll('.advisor-only');
    advisorSections.forEach(section => {
        section.style.display = currentUser.role === 'advisor' ? 'block' : 'none';
    });
}

// Setup event listeners
function setupEventListeners() {
    // Portfolio form submission
    document.getElementById('portfolioForm')?.addEventListener('submit', handlePortfolioSubmit);
    
    // Refresh signals button
    document.getElementById('refreshSignals')?.addEventListener('click', generateAdvisorySignals);
    
    // View reports button (advisor only)
    document.getElementById('viewReports')?.addEventListener('click', loadAdvisorReports);
    
    // Role switcher for demo purposes
    document.getElementById('switchRole')?.addEventListener('click', switchUserRole);
}

// Load dummy data for MVP
function loadDummyData() {
    // Dummy portfolios for Indian equity market
    portfolios = [
        {
            id: 1,
            name: 'Conservative Portfolio',
            value: 1250000,
            stocks: [
                { symbol: 'RELIANCE', name: 'Reliance Industries', quantity: 50, avgPrice: 2450, currentPrice: 2580 },
                { symbol: 'HDFCBANK', name: 'HDFC Bank', quantity: 75, avgPrice: 1450, currentPrice: 1520 },
                { symbol: 'INFY', name: 'Infosys', quantity: 100, avgPrice: 1450, currentPrice: 1525 }
            ],
            performance: { ytd: 12.5, oneYear: 18.2, threeYear: 45.8 }
        },
        {
            id: 2,
            name: 'Growth Portfolio',
            value: 850000,
            stocks: [
                { symbol: 'TCS', name: 'Tata Consultancy Services', quantity: 30, avgPrice: 3200, currentPrice: 3350 },
                { symbol: 'HINDUNILVR', name: 'Hindustan Unilever', quantity: 40, avgPrice: 2450, currentPrice: 2520 },
                { symbol: 'ICICIBANK', name: 'ICICI Bank', quantity: 60, avgPrice: 850, currentPrice: 920 }
            ],
            performance: { ytd: 15.8, oneYear: 22.4, threeYear: 52.1 }
        }
    ];
    
    renderPortfolios();
    generateAdvisorySignals();
}

// Render portfolios to the UI
function renderPortfolios() {
    const portfolioList = document.getElementById('portfolioList');
    if (!portfolioList) return;
    
    portfolioList.innerHTML = portfolios.map(portfolio => `
        <div class="col-md-6 mb-4">
            <div class="card portfolio-card">
                <div class="card-header bg-primary text-white">
                    <h5 class="mb-0">${portfolio.name}</h5>
                </div>
                <div class="card-body">
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <span class="h4 text-success">₹${formatCurrency(portfolio.value)}</span>
                        <span class="badge bg-success">${portfolio.performance.ytd}% YTD</span>
                    </div>
                    
                    <h6>Holdings:</h6>
                    <div class="table-responsive">
                        <table class="table table-sm">
                            <thead>
                                <tr>
                                    <th>Stock</th>
                                    <th>Qty</th>
                                    <th>Price</th>
                                    <th>Value</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${portfolio.stocks.map(stock => `
                                    <tr>
                                        <td>${stock.name}<br><small class="text-muted">${stock.symbol}</small></td>
                                        <td>${stock.quantity}</td>
                                        <td>₹${formatCurrency(stock.currentPrice)}</td>
                                        <td>₹${formatCurrency(stock.quantity * stock.currentPrice)}</td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    `).join('');
}

// Handle portfolio form submission
function handlePortfolioSubmit(e) {
    e.preventDefault();
    
    const formData = new FormData(e.target);
    const portfolioData = {
        name: formData.get('portfolioName'),
        description: formData.get('portfolioDescription')
    };
    
    // For MVP, just add to local array
    const newPortfolio = {
        id: portfolios.length + 1,
        ...portfolioData,
        value: 0,
        stocks: [],
        performance: { ytd: 0, oneYear: 0, threeYear: 0 }
    };
    
    portfolios.push(newPortfolio);
    renderPortfolios();
    
    // Show success message
    showAlert('Portfolio created successfully!', 'success');
    e.target.reset();
}

// Generate advisory signals
function generateAdvisorySignals() {
    // For MVP, generate dummy signals based on Indian market data
    advisorySignals = portfolios.flatMap(portfolio => 
        portfolio.stocks.map(stock => {
            const signal = calculateSignal(stock);
            return {
                portfolioId: portfolio.id,
                stockSymbol: stock.symbol,
                stockName: stock.name,
                currentPrice: stock.currentPrice,
                signal: signal,
                confidence: Math.random() * 0.3 + 0.7, // 70-100% confidence
                reasons: generateSignalReasons(stock, signal)
            };
        })
    );
    
    renderAdvisorySignals();
}

// Calculate signal for a stock
function calculateSignal(stock) {
    const priceChange = ((stock.currentPrice - stock.avgPrice) / stock.avgPrice) * 100;
    
    // Simple algorithm for MVP
    if (priceChange > 20) return 'Sell';
    if (priceChange < -10) return 'Buy';
    return 'Hold';
}

// Generate signal reasons
function generateSignalReasons(stock, signal) {
    const reasons = [];
    
    // Historical performance reason
    const performance = ((stock.currentPrice - stock.avgPrice) / stock.avgPrice) * 100;
    reasons.push(`Historical performance: ${performance.toFixed(1)}%`);
    
    // Technical indicator reasons (dummy)
    reasons.push('RSI: Neutral');
    reasons.push('Moving Average: Bullish crossover');
    
    // Sector potential (dummy)
    const sectors = {
        'RELIANCE': 'Energy & Petrochemicals',
        'HDFCBANK': 'Banking & Finance',
        'INFY': 'IT Services',
        'TCS': 'IT Services',
        'HINDUNILVR': 'FMCG',
        'ICICIBANK': 'Banking & Finance'
    };
    
    reasons.push(`Sector: ${sectors[stock.symbol] || 'General'} - Positive outlook`);
    
    // Market buzz (dummy)
    reasons.push('Market sentiment: Positive news flow');
    
    return reasons;
}

// Render advisory signals
function renderAdvisorySignals() {
    const signalsContainer = document.getElementById('advisorySignals');
    if (!signalsContainer) return;
    
    signalsContainer.innerHTML = advisorySignals.map(signal => `
        <div class="card mb-3">
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <h5 class="card-title">${signal.stockName} (${signal.stockSymbol})</h5>
                        <h6 class="card-subtitle mb-2 text-muted">Current: ₹${formatCurrency(signal.currentPrice)}</h6>
                    </div>
                    <span class="badge ${getSignalBadgeClass(signal.signal)} fs-6">
                        ${signal.signal} (${Math.round(signal.confidence * 100)}%)
                    </span>
                </div>
                
                <ul class="mt-3">
                    ${signal.reasons.map(reason => `<li>${reason}</li>`).join('')}
                </ul>
            </div>
        </div>
    `).join('');
}

// Get CSS class for signal badge
function getSignalBadgeClass(signal) {
    switch(signal) {
        case 'Buy': return 'bg-success';
        case 'Sell': return 'bg-danger';
        case 'Hold': return 'bg-warning text-dark';
        default: return 'bg-secondary';
    }
}

// Load advisor reports
function loadAdvisorReports() {
    if (currentUser.role !== 'advisor') {
        showAlert('Access denied. Advisor privileges required.', 'danger');
        return;
    }
    
    // For MVP, show simple charts using Chart.js
    renderPerformanceCharts();
    renderSectorAllocation();
}

// Render performance charts
function renderPerformanceCharts() {
    const ctx = document.getElementById('performanceChart')?.getContext('2d');
    if (!ctx) return;
    
    new Chart(ctx, {
        type: 'line',
        data: {
            labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
            datasets: portfolios.map((portfolio, index) => ({
                label: portfolio.name,
                data: Array(12).fill().map((_, i) => 
                    portfolio.value * (1 + (i * portfolio.performance.ytd / 1200))
                ),
                borderColor: index === 0 ? '#007bff' : '#28a745',
                tension: 0.1
            }))
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Portfolio Performance (YTD)'
                }
            }
        }
    });
}

// Render sector allocation
function renderSectorAllocation() {
    const ctx = document.getElementById('sectorChart')?.getContext('2d');
    if (!ctx) return;
    
    // Calculate sector allocation from all portfolios
    const sectorData = {};
    portfolios.forEach(portfolio => {
        portfolio.stocks.forEach(stock => {
            const sector = getSectorForStock(stock.symbol);
            const value = stock.quantity * stock.currentPrice;
            sectorData[sector] = (sectorData[sector] || 0) + value;
        });
    });
    
    new Chart(ctx, {
        type: 'pie',
        data: {
            labels: Object.keys(sectorData),
            datasets: [{
                data: Object.values(sectorData),
                backgroundColor: ['#007bff', '#28a745', '#dc3545', '#ffc107', '#17a2b8']
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

// Get sector for stock symbol
function getSectorForStock(symbol) {
    const sectors = {
        'RELIANCE': 'Energy',
        'HDFCBANK': 'Financial',
        'INFY': 'IT',
        'TCS': 'IT',
        'HINDUNILVR': 'FMCG',
        'ICICIBANK': 'Financial'
    };
    return sectors[symbol] || 'Other';
}

// Switch user role for demo purposes
function switchUserRole() {
    const newRole = currentUser.role === 'advisor' ? 'client' : 'advisor';
    localStorage.setItem('userRole', newRole);
    currentUser.role = newRole;
    updateUIForUserRole();
    showAlert(`Switched to ${newRole} view`, 'info');
}

// Utility function to format currency
function formatCurrency(amount) {
    return new Intl.NumberFormat('en-IN').format(amount);
}

// Show alert message
function showAlert(message, type) {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    const container = document.querySelector('.container');
    container.insertBefore(alertDiv, container.firstChild);
    
    // Auto dismiss after 3 seconds
    setTimeout(() => {
        if (alertDiv.parentNode) {
            alertDiv.classList.remove('show');
            setTimeout(() => alertDiv.remove(), 150);
        }
    }, 3000);
}

// API Integration Functions (for future implementation)

async function fetchPortfolios() {
    try {
        const response = await fetch('/api/portfolios');
        if (!response.ok) throw new Error('Failed to fetch portfolios');
        return await response.json();
    } catch (error) {
        console.error('Error fetching portfolios:', error);
        showAlert('Failed to load portfolios', 'danger');
        return [];
    }
}

async function fetchAdvisorySignals(portfolioId) {
    try {
        const response = await fetch(`/api/portfolios/${portfolioId}/signals`);
        if (!response.ok) throw new Error('Failed to fetch signals');
        return await response.json();
    } catch (error) {
        console.error('Error fetching signals:', error);
        return [];
    }
}

async function createPortfolio(portfolioData) {
    try {
        const response = await fetch('/api/portfolios', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(portfolioData)
        });
        
        if (!response.ok) throw new Error('Failed to create portfolio');
        return await response.json();
    } catch (error) {
        console.error('Error creating portfolio:', error);
        showAlert('Failed to create portfolio', 'danger');
        throw error;
    }
}