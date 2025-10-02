// script.js - Frontend JavaScript for Portfolio Management Dashboard
// This file handles UI interactions, API calls, and data visualization for the advisor dashboard

document.addEventListener('DOMContentLoaded', function() {
    // Check authentication status
    checkAuthStatus();
    
    // Initialize dashboard components
    initializeDashboard();
});

// Authentication and Authorization Functions
function checkAuthStatus() {
    const token = localStorage.getItem('advisor_token');
    if (!token) {
        window.location.href = '/login.html';
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
            localStorage.removeItem('advisor_token');
            window.location.href = '/login.html';
        }
    })
    .catch(error => {
        console.error('Auth verification failed:', error);
        localStorage.removeItem('advisor_token');
        window.location.href = '/login.html';
    });
}

function logout() {
    localStorage.removeItem('advisor_token');
    window.location.href = '/login.html';
}

// Dashboard Initialization
function initializeDashboard() {
    loadPortfolioData();
    loadAdvisorySignals();
    initializeCharts();
    setupEventListeners();
}

// Portfolio Data Management
async function loadPortfolioData() {
    try {
        const token = localStorage.getItem('advisor_token');
        const response = await fetch('/api/portfolios', {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            throw new Error('Failed to fetch portfolio data');
        }
        
        const portfolios = await response.json();
        displayPortfolios(portfolios);
    } catch (error) {
        console.error('Error loading portfolio data:', error);
        showNotification('Failed to load portfolio data', 'error');
    }
}

function displayPortfolios(portfolios) {
    const portfolioList = document.getElementById('portfolio-list');
    if (!portfolioList) return;
    
    portfolioList.innerHTML = portfolios.map(portfolio => `
        <div class="portfolio-card" data-portfolio-id="${portfolio.id}">
            <h3>${portfolio.client_name}</h3>
            <p>Total Value: ₹${portfolio.total_value.toLocaleString()}</p>
            <p>Stocks: ${portfolio.stocks_count}</p>
            <button onclick="viewPortfolioDetails(${portfolio.id})">View Details</button>
        </div>
    `).join('');
}

async function viewPortfolioDetails(portfolioId) {
    try {
        const token = localStorage.getItem('advisor_token');
        const response = await fetch(`/api/portfolios/${portfolioId}`, {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            throw new Error('Failed to fetch portfolio details');
        }
        
        const portfolio = await response.json();
        showPortfolioModal(portfolio);
    } catch (error) {
        console.error('Error loading portfolio details:', error);
        showNotification('Failed to load portfolio details', 'error');
    }
}

// Advisory Signals
async function loadAdvisorySignals() {
    try {
        const token = localStorage.getItem('advisor_token');
        const response = await fetch('/api/advisory/signals', {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            throw new Error('Failed to fetch advisory signals');
        }
        
        const signals = await response.json();
        displayAdvisorySignals(signals);
    } catch (error) {
        console.error('Error loading advisory signals:', error);
        showNotification('Failed to load advisory signals', 'error');
    }
}

function displayAdvisorySignals(signals) {
    const signalsContainer = document.getElementById('advisory-signals');
    if (!signalsContainer) return;
    
    signalsContainer.innerHTML = signals.map(signal => `
        <div class="signal-card ${signal.signal_type.toLowerCase()}">
            <h4>${signal.stock_symbol}</h4>
            <p class="signal-type">${signal.signal_type}</p>
            <p>${signal.recommendation}</p>
            <p>Confidence: ${signal.confidence_score}%</p>
            <p>Based on: ${signal.analysis_criteria.join(', ')}</p>
        </div>
    `).join('');
}

// Chart Visualization
function initializeCharts() {
    // Initialize performance chart
    initPerformanceChart();
    
    // Initialize sector allocation chart
    initSectorAllocationChart();
    
    // Initialize technical indicators chart
    initTechnicalIndicatorsChart();
}

function initPerformanceChart() {
    const ctx = document.getElementById('performance-chart');
    if (!ctx) return;
    
    // Mock data for demonstration
    const performanceData = {
        labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
        datasets: [{
            label: 'Portfolio Performance',
            data: [100, 115, 125, 130, 140, 155],
            borderColor: '#4CAF50',
            tension: 0.1
        }]
    };
    
    new Chart(ctx, {
        type: 'line',
        data: performanceData,
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Portfolio Performance (6 Months)'
                }
            }
        }
    });
}

function initSectorAllocationChart() {
    const ctx = document.getElementById('sector-chart');
    if (!ctx) return;
    
    const sectorData = {
        labels: ['Technology', 'Financial', 'Healthcare', 'Energy', 'Consumer'],
        datasets: [{
            data: [30, 25, 20, 15, 10],
            backgroundColor: ['#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF']
        }]
    };
    
    new Chart(ctx, {
        type: 'doughnut',
        data: sectorData,
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

function initTechnicalIndicatorsChart() {
    const ctx = document.getElementById('technical-chart');
    if (!ctx) return;
    
    const technicalData = {
        labels: ['RSI', 'MACD', 'Bollinger', 'Stochastic', 'Volume'],
        datasets: [{
            label: 'Technical Indicators',
            data: [65, 59, 80, 45, 75],
            backgroundColor: 'rgba(54, 162, 235, 0.2)',
            borderColor: 'rgba(54, 162, 235, 1)',
            borderWidth: 1
        }]
    };
    
    new Chart(ctx, {
        type: 'bar',
        data: technicalData,
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Technical Indicators Analysis'
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    max: 100
                }
            }
        }
    });
}

// Event Listeners
function setupEventListeners() {
    // Refresh button
    const refreshBtn = document.getElementById('refresh-btn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
            loadPortfolioData();
            loadAdvisorySignals();
            showNotification('Data refreshed successfully', 'success');
        });
    }
    
    // Logout button
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', logout);
    }
    
    // Search functionality
    const searchInput = document.getElementById('search-input');
    if (searchInput) {
        searchInput.addEventListener('input', debounce(handleSearch, 300));
    }
}

function handleSearch(event) {
    const searchTerm = event.target.value.toLowerCase();
    const portfolioCards = document.querySelectorAll('.portfolio-card');
    
    portfolioCards.forEach(card => {
        const clientName = card.querySelector('h3').textContent.toLowerCase();
        if (clientName.includes(searchTerm)) {
            card.style.display = 'block';
        } else {
            card.style.display = 'none';
        }
    });
}

// Utility Functions
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

function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    // Add to DOM
    document.body.appendChild(notification);
    
    // Remove after delay
    setTimeout(() => {
        notification.remove();
    }, 3000);
}

function showPortfolioModal(portfolio) {
    // Create modal content
    const modalContent = `
        <div class="modal-header">
            <h2>${portfolio.client_name}'s Portfolio</h2>
            <span class="close">&times;</span>
        </div>
        <div class="modal-body">
            <h3>Holdings</h3>
            <table>
                <thead>
                    <tr>
                        <th>Stock</th>
                        <th>Quantity</th>
                        <th>Current Price</th>
                        <th>Value</th>
                    </tr>
                </thead>
                <tbody>
                    ${portfolio.holdings.map(holding => `
                        <tr>
                            <td>${holding.stock_symbol}</td>
                            <td>${holding.quantity}</td>
                            <td>₹${holding.current_price}</td>
                            <td>₹${holding.value}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
    
    // Create and show modal
    const modal = document.createElement('div');
    modal.className = 'modal';
    modal.innerHTML = modalContent;
    document.body.appendChild(modal);
    
    // Close modal functionality
    modal.querySelector('.close').addEventListener('click', () => {
        modal.remove();
    });
    
    // Close when clicking outside
    modal.addEventListener('click', (e) => {
        if (e.target === modal) {
            modal.remove();
        }
    });
}

// Export functions for global access (if needed)
window.viewPortfolioDetails = viewPortfolioDetails;
window.logout = logout;