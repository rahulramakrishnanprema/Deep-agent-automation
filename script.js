// script.js - Frontend JavaScript for Portfolio Management Application

// DOM Elements
let portfolioTable;
let performanceChart;
let advisorySignals;
let marketBuzzContainer;

// Initialize application when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

/**
 * Initialize the application
 */
function initializeApp() {
    // Get DOM elements
    portfolioTable = document.getElementById('portfolio-table');
    performanceChart = document.getElementById('performance-chart');
    advisorySignals = document.getElementById('advisory-signals');
    marketBuzzContainer = document.getElementById('market-buzz');
    
    // Load initial data
    loadPortfolioData();
    loadPerformanceData();
    loadAdvisorySignals();
    loadMarketBuzz();
    
    // Set up event listeners
    setupEventListeners();
}

/**
 * Set up event listeners for UI interactions
 */
function setupEventListeners() {
    // Refresh button
    const refreshBtn = document.getElementById('refresh-btn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', function() {
            refreshAllData();
        });
    }
    
    // Portfolio filter
    const portfolioFilter = document.getElementById('portfolio-filter');
    if (portfolioFilter) {
        portfolioFilter.addEventListener('change', function() {
            filterPortfolio(this.value);
        });
    }
}

/**
 * Load portfolio data from backend API
 */
async function loadPortfolioData() {
    try {
        const response = await fetch('/api/portfolio');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const portfolioData = await response.json();
        renderPortfolioTable(portfolioData);
    } catch (error) {
        console.error('Error loading portfolio data:', error);
        showError('Failed to load portfolio data');
        // Fallback to dummy data
        renderPortfolioTable(getDummyPortfolioData());
    }
}

/**
 * Load performance data and render chart
 */
async function loadPerformanceData() {
    try {
        const response = await fetch('/api/performance');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const performanceData = await response.json();
        renderPerformanceChart(performanceData);
    } catch (error) {
        console.error('Error loading performance data:', error);
        showError('Failed to load performance data');
    }
}

/**
 * Load advisory signals
 */
async function loadAdvisorySignals() {
    try {
        const response = await fetch('/api/advisory-signals');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const signals = await response.json();
        renderAdvisorySignals(signals);
    } catch (error) {
        console.error('Error loading advisory signals:', error);
        showError('Failed to load advisory signals');
        // Fallback to dummy signals
        renderAdvisorySignals(generateDummySignals());
    }
}

/**
 * Load market buzz data
 */
async function loadMarketBuzz() {
    try {
        const response = await fetch('/api/market-buzz');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const buzzData = await response.json();
        renderMarketBuzz(buzzData);
    } catch (error) {
        console.error('Error loading market buzz:', error);
        showError('Failed to load market buzz');
        // Fallback to dummy buzz
        renderMarketBuzz(generateDummyMarketBuzz());
    }
}

/**
 * Render portfolio table with data
 * @param {Array} data - Portfolio data array
 */
function renderPortfolioTable(data) {
    if (!portfolioTable) return;
    
    const tbody = portfolioTable.querySelector('tbody');
    if (!tbody) return;
    
    tbody.innerHTML = '';
    
    data.forEach(stock => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${stock.symbol}</td>
            <td>${stock.name}</td>
            <td>${stock.quantity}</td>
            <td>₹${stock.averagePrice.toFixed(2)}</td>
            <td>₹${stock.currentPrice.toFixed(2)}</td>
            <td class="${getProfitLossClass(stock.profitLoss)}">
                ${formatProfitLoss(stock.profitLoss)}
            </td>
            <td>${stock.sector}</td>
            <td><span class="badge ${getSignalBadgeClass(stock.signal)}">${stock.signal}</span></td>
        `;
        tbody.appendChild(row);
    });
}

/**
 * Render performance chart
 * @param {Object} data - Performance data
 */
function renderPerformanceChart(data) {
    if (!performanceChart) return;
    
    // Using Chart.js for performance visualization
    const ctx = performanceChart.getContext('2d');
    new Chart(ctx, {
        type: 'line',
        data: {
            labels: data.labels,
            datasets: [{
                label: 'Portfolio Value',
                data: data.values,
                borderColor: '#007bff',
                backgroundColor: 'rgba(0, 123, 255, 0.1)',
                fill: true
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Portfolio Performance'
                }
            },
            scales: {
                y: {
                    beginAtZero: false
                }
            }
        }
    });
}

/**
 * Render advisory signals
 * @param {Array} signals - Array of signal objects
 */
function renderAdvisorySignals(signals) {
    if (!advisorySignals) return;
    
    advisorySignals.innerHTML = '';
    
    signals.forEach(signal => {
        const card = document.createElement('div');
        card.className = 'card mb-3';
        card.innerHTML = `
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-center">
                    <h5 class="card-title mb-0">${signal.symbol}</h5>
                    <span class="badge ${getSignalBadgeClass(signal.recommendation)}">
                        ${signal.recommendation}
                    </span>
                </div>
                <p class="card-text mt-2">${signal.reason}</p>
                <div class="text-muted small">
                    Target: ₹${signal.targetPrice} | Stop Loss: ₹${signal.stopLoss}
                </div>
            </div>
        `;
        advisorySignals.appendChild(card);
    });
}

/**
 * Render market buzz
 * @param {Array} buzzData - Market buzz data
 */
function renderMarketBuzz(buzzData) {
    if (!marketBuzzContainer) return;
    
    marketBuzzContainer.innerHTML = '';
    
    buzzData.forEach(item => {
        const buzzItem = document.createElement('div');
        buzzItem.className = 'market-buzz-item';
        buzzItem.innerHTML = `
            <div class="d-flex justify-content-between align-items-start">
                <div>
                    <h6 class="mb-1">${item.title}</h6>
                    <p class="mb-1 text-muted small">${item.source} • ${formatDate(item.timestamp)}</p>
                </div>
                <span class="badge ${getSentimentBadgeClass(item.sentiment)}">
                    ${item.sentiment}
                </span>
            </div>
            <p class="mb-0 mt-2 small">${item.summary}</p>
        `;
        marketBuzzContainer.appendChild(buzzItem);
    });
}

/**
 * Filter portfolio by sector
 * @param {string} sector - Sector to filter by
 */
function filterPortfolio(sector) {
    // This would typically call a filtered API endpoint
    console.log(`Filtering portfolio by sector: ${sector}`);
    // For now, we'll just reload all data
    loadPortfolioData();
}

/**
 * Refresh all data
 */
function refreshAllData() {
    loadPortfolioData();
    loadPerformanceData();
    loadAdvisorySignals();
    loadMarketBuzz();
}

/**
 * Get CSS class for profit/loss display
 * @param {number} profitLoss - Profit/loss amount
 * @returns {string} CSS class
 */
function getProfitLossClass(profitLoss) {
    return profitLoss >= 0 ? 'text-success' : 'text-danger';
}

/**
 * Get CSS class for signal badge
 * @param {string} signal - Signal type
 * @returns {string} CSS class
 */
function getSignalBadgeClass(signal) {
    const classes = {
        'Buy': 'bg-success',
        'Hold': 'bg-warning',
        'Sell': 'bg-danger'
    };
    return classes[signal] || 'bg-secondary';
}

/**
 * Get CSS class for sentiment badge
 * @param {string} sentiment - Sentiment type
 * @returns {string} CSS class
 */
function getSentimentBadgeClass(sentiment) {
    const classes = {
        'Positive': 'bg-success',
        'Neutral': 'bg-warning',
        'Negative': 'bg-danger'
    };
    return classes[sentiment] || 'bg-secondary';
}

/**
 * Format profit/loss for display
 * @param {number} profitLoss - Profit/loss amount
 * @returns {string} Formatted string
 */
function formatProfitLoss(profitLoss) {
    const sign = profitLoss >= 0 ? '+' : '';
    return `${sign}₹${Math.abs(profitLoss).toFixed(2)}`;
}

/**
 * Format date for display
 * @param {string} dateString - Date string
 * @returns {string} Formatted date
 */
function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('en-IN', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

/**
 * Show error message
 * @param {string} message - Error message
 */
function showError(message) {
    // Create or show error toast/notification
    console.error('Error:', message);
    // You could implement a toast notification system here
}

// Dummy data functions for fallback
function getDummyPortfolioData() {
    return [
        {
            symbol: 'RELIANCE',
            name: 'Reliance Industries',
            quantity: 100,
            averagePrice: 2400,
            currentPrice: 2600,
            profitLoss: 20000,
            sector: 'Energy',
            signal: 'Buy'
        },
        {
            symbol: 'TCS',
            name: 'Tata Consultancy Services',
            quantity: 50,
            averagePrice: 3200,
            currentPrice: 3400,
            profitLoss: 10000,
            sector: 'IT',
            signal: 'Hold'
        },
        {
            symbol: 'HDFCBANK',
            name: 'HDFC Bank',
            quantity: 75,
            averagePrice: 1400,
            currentPrice: 1350,
            profitLoss: -3750,
            sector: 'Banking',
            signal: 'Sell'
        }
    ];
}

function generateDummySignals() {
    return [
        {
            symbol: 'RELIANCE',
            recommendation: 'Buy',
            reason: 'Strong technical breakout above resistance',
            targetPrice: 2800,
            stopLoss: 2500
        },
        {
            symbol: 'TCS',
            recommendation: 'Hold',
            reason: 'Consolidating near support levels',
            targetPrice: 3500,
            stopLoss: 3300
        },
        {
            symbol: 'HDFCBANK',
            recommendation: 'Sell',
            reason: 'Breaking below key support level',
            targetPrice: 1300,
            stopLoss: 1400
        }
    ];
}

function generateDummyMarketBuzz() {
    return [
        {
            title: 'RBI Maintains Interest Rates',
            source: 'Economic Times',
            timestamp: new Date().toISOString(),
            sentiment: 'Neutral',
            summary: 'RBI keeps repo rate unchanged at 6.5% as expected by market participants.'
        },
        {
            title: 'IT Sector Shows Strong Q4 Results',
            source: 'Business Standard',
            timestamp: new Date().toISOString(),
            sentiment: 'Positive',
            summary: 'Major IT companies report better-than-expected quarterly earnings.'
        },
        {
            title: 'Banking Sector Under Pressure',
            source: 'Financial Express',
            timestamp: new Date().toISOString(),
            sentiment: 'Negative',
            summary: 'Rising NPAs and margin pressures affecting banking stocks.'
        }
    ];
}

// Export functions for testing (if needed)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        initializeApp,
        loadPortfolioData,
        loadPerformanceData,
        loadAdvisorySignals,
        loadMarketBuzz,
        renderPortfolioTable,
        renderPerformanceChart,
        renderAdvisorySignals,
        renderMarketBuzz,
        getProfitLossClass,
        getSignalBadgeClass,
        getSentimentBadgeClass,
        formatProfitLoss,
        formatDate,
        getDummyPortfolioData,
        generateDummySignals,
        generateDummyMarketBuzz
    };
}