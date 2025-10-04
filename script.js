// script.js - Frontend JavaScript for Portfolio Management Dashboard
// MVP web application for managing client stock portfolios in Indian equity markets

// Global variables
let currentPortfolio = null;
let advisorMode = false;
const API_BASE_URL = 'http://localhost:5000/api';

// DOM Content Loaded Event
document.addEventListener('DOMContentLoaded', function() {
    initializeApplication();
    setupEventListeners();
    checkAuthenticationStatus();
});

// Initialize application
function initializeApplication() {
    console.log('Initializing Portfolio Management Application...');
    
    // Load initial data
    loadPortfolioList();
    loadMarketData();
    
    // Set up responsive design handlers
    setupResponsiveDesign();
}

// Setup event listeners
function setupEventListeners() {
    // Portfolio selection
    document.getElementById('portfolio-select').addEventListener('change', handlePortfolioSelect);
    
    // Advisor mode toggle
    document.getElementById('advisor-toggle').addEventListener('change', toggleAdvisorMode);
    
    // Refresh buttons
    document.getElementById('refresh-portfolio').addEventListener('click', refreshPortfolioData);
    document.getElementById('refresh-market').addEventListener('click', refreshMarketData);
    
    // Chart type toggle
    document.getElementById('chart-type').addEventListener('change', updateChartVisualization);
    
    // Login/logout
    document.getElementById('login-btn').addEventListener('click', handleLogin);
    document.getElementById('logout-btn').addEventListener('click', handleLogout);
}

// Authentication functions
function checkAuthenticationStatus() {
    const token = localStorage.getItem('advisor_token');
    if (token) {
        advisorMode = true;
        document.getElementById('advisor-toggle').checked = true;
        toggleAdvisorMode();
    }
}

function handleLogin() {
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    
    if (!username || !password) {
        showNotification('Please enter both username and password', 'error');
        return;
    }
    
    fetch(`${API_BASE_URL}/auth/login`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ username, password })
    })
    .then(response => {
        if (!response.ok) throw new Error('Login failed');
        return response.json();
    })
    .then(data => {
        localStorage.setItem('advisor_token', data.token);
        advisorMode = true;
        document.getElementById('advisor-toggle').checked = true;
        toggleAdvisorMode();
        showNotification('Login successful! Advisor mode activated', 'success');
        document.getElementById('login-modal').style.display = 'none';
    })
    .catch(error => {
        showNotification('Login failed: Invalid credentials', 'error');
    });
}

function handleLogout() {
    localStorage.removeItem('advisor_token');
    advisorMode = false;
    document.getElementById('advisor-toggle').checked = false;
    toggleAdvisorMode();
    showNotification('Logged out successfully', 'info');
}

function toggleAdvisorMode() {
    advisorMode = document.getElementById('advisor-toggle').checked;
    const advisorSections = document.querySelectorAll('.advisor-only');
    
    advisorSections.forEach(section => {
        section.style.display = advisorMode ? 'block' : 'none';
    });
    
    if (advisorMode && !localStorage.getItem('advisor_token')) {
        document.getElementById('login-modal').style.display = 'block';
    }
    
    if (currentPortfolio) {
        loadPortfolioDetails(currentPortfolio.id);
    }
}

// Portfolio Management Functions
async function loadPortfolioList() {
    try {
        const response = await fetch(`${API_BASE_URL}/portfolios`);
        if (!response.ok) throw new Error('Failed to load portfolios');
        
        const portfolios = await response.json();
        const select = document.getElementById('portfolio-select');
        select.innerHTML = '<option value="">Select Portfolio</option>';
        
        portfolios.forEach(portfolio => {
            const option = document.createElement('option');
            option.value = portfolio.id;
            option.textContent = `${portfolio.name} (${portfolio.client_name})`;
            select.appendChild(option);
        });
    } catch (error) {
        console.error('Error loading portfolios:', error);
        showNotification('Failed to load portfolios', 'error');
    }
}

async function handlePortfolioSelect(event) {
    const portfolioId = event.target.value;
    if (!portfolioId) return;
    
    try {
        const response = await fetch(`${API_BASE_URL}/portfolios/${portfolioId}`);
        if (!response.ok) throw new Error('Failed to load portfolio details');
        
        currentPortfolio = await response.json();
        displayPortfolioDetails(currentPortfolio);
        loadPortfolioPerformance(portfolioId);
        
        if (advisorMode) {
            generateAdvisorySignals(portfolioId);
            loadSectorAnalysis(portfolioId);
        }
    } catch (error) {
        console.error('Error loading portfolio details:', error);
        showNotification('Failed to load portfolio details', 'error');
    }
}

function displayPortfolioDetails(portfolio) {
    const detailsDiv = document.getElementById('portfolio-details');
    detailsDiv.innerHTML = `
        <h3>${portfolio.name}</h3>
        <p><strong>Client:</strong> ${portfolio.client_name}</p>
        <p><strong>Total Value:</strong> ₹${portfolio.total_value.toLocaleString()}</p>
        <p><strong>Last Updated:</strong> ${new Date(portfolio.last_updated).toLocaleString()}</p>
    `;
    
    displayHoldingsTable(portfolio.holdings);
}

function displayHoldingsTable(holdings) {
    const table = document.getElementById('holdings-table');
    const tbody = table.querySelector('tbody');
    tbody.innerHTML = '';
    
    holdings.forEach(holding => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${holding.stock_symbol}</td>
            <td>${holding.stock_name}</td>
            <td>${holding.quantity}</td>
            <td>₹${holding.avg_price.toLocaleString()}</td>
            <td>₹${holding.current_price.toLocaleString()}</td>
            <td>₹${(holding.quantity * holding.current_price).toLocaleString()}</td>
            <td class="${holding.gain_loss >= 0 ? 'positive' : 'negative'}">
                ${holding.gain_loss >= 0 ? '+' : ''}${holding.gain_loss}%
            </td>
        `;
        tbody.appendChild(row);
    });
}

// Performance and Analysis Functions
async function loadPortfolioPerformance(portfolioId) {
    try {
        const response = await fetch(`${API_BASE_URL}/portfolios/${portfolioId}/performance`);
        if (!response.ok) throw new Error('Failed to load performance data');
        
        const performanceData = await response.json();
        renderPerformanceCharts(performanceData);
    } catch (error) {
        console.error('Error loading performance data:', error);
        showNotification('Failed to load performance data', 'error');
    }
}

async function generateAdvisorySignals(portfolioId) {
    try {
        const token = localStorage.getItem('advisor_token');
        if (!token) throw new Error('Not authenticated');
        
        const response = await fetch(`${API_BASE_URL}/advisory/signals/${portfolioId}`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        
        if (!response.ok) throw new Error('Failed to generate advisory signals');
        
        const signals = await response.json();
        displayAdvisorySignals(signals);
    } catch (error) {
        console.error('Error generating advisory signals:', error);
        showNotification('Advisory signals unavailable', 'warning');
    }
}

function displayAdvisorySignals(signals) {
    const signalsDiv = document.getElementById('advisory-signals');
    signalsDiv.innerHTML = '<h4>Advisory Signals</h4>';
    
    signals.forEach(signal => {
        const signalCard = document.createElement('div');
        signalCard.className = `signal-card ${signal.recommendation.toLowerCase()}`;
        signalCard.innerHTML = `
            <h5>${signal.stock_symbol} - ${signal.stock_name}</h5>
            <p class="recommendation ${signal.recommendation.toLowerCase()}">${signal.recommendation}</p>
            <p><strong>Current Price:</strong> ₹${signal.current_price}</p>
            <p><strong>Target Price:</strong> ₹${signal.target_price}</p>
            <p><strong>Confidence:</strong> ${signal.confidence_level}%</p>
            <p><strong>Reason:</strong> ${signal.reasoning}</p>
            <p><small>Generated: ${new Date(signal.generated_at).toLocaleString()}</small></p>
        `;
        signalsDiv.appendChild(signalCard);
    });
}

async function loadSectorAnalysis(portfolioId) {
    try {
        const token = localStorage.getItem('advisor_token');
        if (!token) return;
        
        const response = await fetch(`${API_BASE_URL}/analysis/sector/${portfolioId}`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        
        if (!response.ok) throw new Error('Failed to load sector analysis');
        
        const sectorData = await response.json();
        renderSectorCharts(sectorData);
    } catch (error) {
        console.error('Error loading sector analysis:', error);
    }
}

// Market Data Functions
async function loadMarketData() {
    try {
        const response = await fetch(`${API_BASE_URL}/market/buzz`);
        if (!response.ok) throw new Error('Failed to load market data');
        
        const marketData = await response.json();
        displayMarketBuzz(marketData);
    } catch (error) {
        console.error('Error loading market data:', error);
        showNotification('Failed to load market data', 'error');
    }
}

function displayMarketBuzz(marketData) {
    const buzzDiv = document.getElementById('market-buzz');
    buzzDiv.innerHTML = '<h4>Market Buzz</h4>';
    
    marketData.news.slice(0, 5).forEach(news => {
        const newsItem = document.createElement('div');
        newsItem.className = 'news-item';
        newsItem.innerHTML = `
            <h5>${news.title}</h5>
            <p>${news.summary}</p>
            <p class="news-source">${news.source} - ${new Date(news.published_at).toLocaleDateString()}</p>
        `;
        buzzDiv.appendChild(newsItem);
    });
}

// Chart Rendering Functions
function renderPerformanceCharts(performanceData) {
    // Simple chart rendering using Chart.js (assumed to be included)
    const ctx = document.getElementById('performance-chart').getContext('2d');
    
    new Chart(ctx, {
        type: 'line',
        data: {
            labels: performanceData.dates,
            datasets: [{
                label: 'Portfolio Value (₹)',
                data: performanceData.values,
                borderColor: '#36a2eb',
                tension: 0.1
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Portfolio Performance'
                }
            }
        }
    });
}

function renderSectorCharts(sectorData) {
    const ctx = document.getElementById('sector-chart').getContext('2d');
    
    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: sectorData.labels,
            datasets: [{
                label: 'Sector Allocation (%)',
                data: sectorData.values,
                backgroundColor: sectorData.colors
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

function updateChartVisualization() {
    const chartType = document.getElementById('chart-type').value;
    if (currentPortfolio) {
        loadPortfolioPerformance(currentPortfolio.id);
    }
}

// Utility Functions
function refreshPortfolioData() {
    if (currentPortfolio) {
        loadPortfolioDetails(currentPortfolio.id);
        showNotification('Portfolio data refreshed', 'success');
    } else {
        showNotification('Please select a portfolio first', 'warning');
    }
}

function refreshMarketData() {
    loadMarketData();
    showNotification('Market data refreshed', 'success');
}

function showNotification(message, type = 'info') {
    // Simple notification system
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.remove();
    }, 3000);
}

function setupResponsiveDesign() {
    // Handle window resize for responsive design
    window.addEventListener('resize', debounce(() => {
        if (currentPortfolio) {
            loadPortfolioPerformance(currentPortfolio.id);
        }
    }, 250));
}

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

// Error handling for fetch requests
function handleFetchError(error, context) {
    console.error(`Error in ${context}:`, error);
    showNotification(`Failed to ${context}: ${error.message}`, 'error');
}

// Initialize charts with empty data on load
function initializeCharts() {
    const chartConfigs = {
        performance: { type: 'line', data: { labels: [], datasets: [] } },
        sector: { type: 'bar', data: { labels: [], datasets: [] } }
    };
    
    Object.keys(chartConfigs).forEach(chartId => {
        const ctx = document.getElementById(`${chartId}-chart`).getContext('2d');
        new Chart(ctx, {
            type: chartConfigs[chartId].type,
            data: chartConfigs[chartId].data,
            options: { responsive: true }
        });
    });
}

// Export functions for testing (if needed)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        initializeApplication,
        handlePortfolioSelect,
        toggleAdvisorMode,
        refreshPortfolioData,
        refreshMarketData
    };
}