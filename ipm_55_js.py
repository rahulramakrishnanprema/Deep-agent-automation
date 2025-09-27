// IPM-55: Portfolio Management Dashboard JavaScript
// Main dashboard functionality for Indian Portfolio Management system

document.addEventListener('DOMContentLoaded', function() {
    // Initialize dashboard components
    initDashboard();
    setupEventListeners();
    loadPortfolioData();
    loadMarketData();
});

// Dashboard initialization
function initDashboard() {
    console.log('Initializing IPM Dashboard...');
    
    // Check authentication status
    checkAuthStatus();
    
    // Initialize charts and visualizations
    initCharts();
    
    // Set up real-time data updates
    setupRealTimeUpdates();
}

// Authentication status check
function checkAuthStatus() {
    const token = localStorage.getItem('authToken');
    if (!token) {
        window.location.href = '/login';
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
            localStorage.removeItem('authToken');
            window.location.href = '/login';
        }
    })
    .catch(error => {
        console.error('Auth verification failed:', error);
        window.location.href = '/login';
    });
}

// Portfolio data loading
function loadPortfolioData() {
    const token = localStorage.getItem('authToken');
    
    fetch('/api/portfolio', {
        method: 'GET',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to load portfolio data');
        }
        return response.json();
    })
    .then(data => {
        updatePortfolioDisplay(data);
        generateAdvisorySignals(data);
    })
    .catch(error => {
        console.error('Error loading portfolio:', error);
        showNotification('Failed to load portfolio data', 'error');
    });
}

// Market data integration
function loadMarketData() {
    fetch('/api/market/data', {
        method: 'GET',
        headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`,
            'Content-Type': 'application/json'
        }
    })
    .then(response => response.json())
    .then(data => {
        updateMarketWidgets(data);
        updateCharts(data);
    })
    .catch(error => {
        console.error('Error loading market data:', error);
    });
}

// Real-time data processing setup
function setupRealTimeUpdates() {
    // WebSocket connection for real-time updates
    const ws = new WebSocket('wss://your-api-domain.com/ws/market');
    
    ws.onopen = function() {
        console.log('WebSocket connection established');
        ws.send(JSON.stringify({
            type: 'subscribe',
            channels: ['nifty', 'sensex', 'portfolio_updates']
        }));
    };
    
    ws.onmessage = function(event) {
        const data = JSON.parse(event.data);
        handleRealTimeUpdate(data);
    };
    
    ws.onerror = function(error) {
        console.error('WebSocket error:', error);
    };
    
    ws.onclose = function() {
        console.log('WebSocket connection closed');
        // Attempt reconnection after delay
        setTimeout(setupRealTimeUpdates, 5000);
    };
}

// Handle real-time data updates
function handleRealTimeUpdate(data) {
    switch (data.channel) {
        case 'nifty':
        case 'sensex':
            updateIndexDisplay(data);
            break;
        case 'portfolio_updates':
            updatePortfolioValue(data);
            break;
        case 'news':
            updateNewsFeed(data);
            break;
    }
}

// Advisory signal generation
function generateAdvisorySignals(portfolioData) {
    fetch('/api/advisory/signals', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(portfolioData)
    })
    .then(response => response.json())
    .then(signals => {
        displayAdvisorySignals(signals);
    })
    .catch(error => {
        console.error('Error generating advisory signals:', error);
    });
}

// Display advisory signals with confidence scores
function displayAdvisorySignals(signals) {
    const signalsContainer = document.getElementById('advisory-signals');
    if (!signalsContainer) return;
    
    signalsContainer.innerHTML = '';
    
    signals.forEach(signal => {
        const signalElement = createSignalElement(signal);
        signalsContainer.appendChild(signalElement);
    });
}

// Create individual signal element
function createSignalElement(signal) {
    const div = document.createElement('div');
    div.className = `signal ${signal.recommendation.toLowerCase()}`;
    
    const confidenceClass = getConfidenceClass(signal.confidence);
    
    div.innerHTML = `
        <div class="signal-header">
            <span class="symbol">${signal.symbol}</span>
            <span class="recommendation ${signal.recommendation.toLowerCase()}">
                ${signal.recommendation}
            </span>
            <span class="confidence ${confidenceClass}">
                ${Math.round(signal.confidence * 100)}%
            </span>
        </div>
        <div class="signal-reasoning">
            ${signal.reasoning}
        </div>
        <div class="signal-metrics">
            <span>Target: ₹${signal.targetPrice}</span>
            <span>Stop Loss: ₹${signal.stopLoss}</span>
        </div>
    `;
    
    return div;
}

// Get CSS class based on confidence score
function getConfidenceClass(confidence) {
    if (confidence >= 0.8) return 'high-confidence';
    if (confidence >= 0.6) return 'medium-confidence';
    return 'low-confidence';
}

// Chart initialization
function initCharts() {
    // Initialize portfolio allocation chart
    const allocationCtx = document.getElementById('allocationChart');
    if (allocationCtx) {
        new Chart(allocationCtx, {
            type: 'pie',
            data: {
                labels: [],
                datasets: [{
                    data: [],
                    backgroundColor: [
                        '#4CAF50', '#2196F3', '#FFC107', '#E91E63', '#9C27B0'
                    ]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });
    }
    
    // Initialize performance chart
    const performanceCtx = document.getElementById('performanceChart');
    if (performanceCtx) {
        new Chart(performanceCtx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'Portfolio Value',
                    data: [],
                    borderColor: '#2196F3',
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });
    }
}

// Update charts with new data
function updateCharts(marketData) {
    // Implementation for updating charts with real-time data
    // This would interact with Chart.js instances
}

// Event listeners setup
function setupEventListeners() {
    // Portfolio management actions
    document.getElementById('refreshBtn')?.addEventListener('click', loadPortfolioData);
    document.getElementById('addStockBtn')?.addEventListener('click', showAddStockModal);
    document.getElementById('exportBtn')?.addEventListener('click', exportPortfolio);
    
    // Navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', handleNavigation);
    });
    
    // Search functionality
    const searchInput = document.getElementById('stockSearch');
    if (searchInput) {
        searchInput.addEventListener('input', debounce(handleStockSearch, 300));
    }
}

// Debounce function for search
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Stock search handler
function handleStockSearch(event) {
    const query = event.target.value.trim();
    if (query.length > 2) {
        searchStocks(query);
    }
}

// Search stocks API call
function searchStocks(query) {
    fetch(`/api/stocks/search?q=${encodeURIComponent(query)}`, {
        headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`
        }
    })
    .then(response => response.json())
    .then(results => {
        displaySearchResults(results);
    })
    .catch(error => {
        console.error('Search error:', error);
    });
}

// Utility functions
function showNotification(message, type = 'info') {
    // Implementation for showing notifications
    console.log(`${type}: ${message}`);
}

function formatCurrency(amount) {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR'
    }).format(amount);
}

function formatPercentage(value) {
    return `${(value * 100).toFixed(2)}%`;
}

// Export portfolio data
function exportPortfolio() {
    fetch('/api/portfolio/export', {
        headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`
        }
    })
    .then(response => response.blob())
    .then(blob => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'portfolio-export.csv';
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
    })
    .catch(error => {
        console.err
# Code truncated at 10000 characters