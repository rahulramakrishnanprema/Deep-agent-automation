// script.js - Main JavaScript file for Indian Equity Portfolio Management MVP
// Handles frontend logic, API communication, UI interactions, and data visualization

// Global variables
let currentPortfolioId = null;
let portfolios = [];
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
    console.log('Initializing Indian Equity Portfolio Management Application');
    
    // Check if user is logged in (placeholder for future authentication)
    const userToken = localStorage.getItem('userToken');
    if (!userToken) {
        console.log('No user token found - running in demo mode');
    }
    
    // Initialize charts and UI components
    initializeCharts();
    updateDashboardSummary();
}

// Set up event listeners
function setupEventListeners() {
    // Portfolio management
    document.getElementById('create-portfolio-btn')?.addEventListener('click', showCreatePortfolioModal);
    document.getElementById('portfolio-form')?.addEventListener('submit', handlePortfolioSubmit);
    document.getElementById('refresh-data-btn')?.addEventListener('click', refreshAllData);
    
    // Navigation
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', handleNavigation);
    });
    
    // Search functionality
    const searchInput = document.getElementById('search-stocks');
    if (searchInput) {
        searchInput.addEventListener('input', debounce(handleStockSearch, 300));
    }
}

// Load initial data
async function loadInitialData() {
    try {
        showLoadingIndicator();
        
        // Load portfolios
        await loadPortfolios();
        
        // Load market data
        await loadMarketData();
        
        // Load advisory signals if a portfolio is selected
        if (currentPortfolioId) {
            await loadAdvisorySignals(currentPortfolioId);
        }
        
        hideLoadingIndicator();
    } catch (error) {
        console.error('Error loading initial data:', error);
        showError('Failed to load application data');
        hideLoadingIndicator();
    }
}

// Portfolio Management Functions
async function loadPortfolios() {
    try {
        const response = await fetch('/api/portfolios', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('userToken') || ''}`
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        portfolios = await response.json();
        renderPortfoliosList(portfolios);
        
        if (portfolios.length > 0 && !currentPortfolioId) {
            currentPortfolioId = portfolios[0].id;
            await loadPortfolioDetails(currentPortfolioId);
        }
        
    } catch (error) {
        console.error('Error loading portfolios:', error);
        // Fallback to dummy data
        portfolios = generateDummyPortfolios();
        renderPortfoliosList(portfolios);
    }
}

async function loadPortfolioDetails(portfolioId) {
    try {
        const response = await fetch(`/api/portfolios/${portfolioId}`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('userToken') || ''}`
            }
        });
        
        if (response.ok) {
            const portfolio = await response.json();
            renderPortfolioDetails(portfolio);
            await loadAdvisorySignals(portfolioId);
        } else {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
    } catch (error) {
        console.error('Error loading portfolio details:', error);
        // Fallback to dummy data
        const portfolio = portfolios.find(p => p.id === portfolioId);
        if (portfolio) {
            renderPortfolioDetails(portfolio);
            advisorySignals = generateDummyAdvisorySignals(portfolioId);
            renderAdvisorySignals(advisorySignals);
        }
    }
}

async function createPortfolio(portfolioData) {
    try {
        const response = await fetch('/api/portfolios', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('userToken') || ''}`
            },
            body: JSON.stringify(portfolioData)
        });
        
        if (response.ok) {
            const newPortfolio = await response.json();
            portfolios.push(newPortfolio);
            renderPortfoliosList(portfolios);
            hideModal('create-portfolio-modal');
            showSuccess('Portfolio created successfully');
            return newPortfolio;
        } else {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
    } catch (error) {
        console.error('Error creating portfolio:', error);
        showError('Failed to create portfolio');
        throw error;
    }
}

async function updatePortfolio(portfolioId, updateData) {
    try {
        const response = await fetch(`/api/portfolios/${portfolioId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('userToken') || ''}`
            },
            body: JSON.stringify(updateData)
        });
        
        if (response.ok) {
            const updatedPortfolio = await response.json();
            const index = portfolios.findIndex(p => p.id === portfolioId);
            if (index !== -1) {
                portfolios[index] = updatedPortfolio;
                renderPortfoliosList(portfolios);
                
                if (currentPortfolioId === portfolioId) {
                    renderPortfolioDetails(updatedPortfolio);
                }
                
                showSuccess('Portfolio updated successfully');
            }
            return updatedPortfolio;
        } else {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
    } catch (error) {
        console.error('Error updating portfolio:', error);
        showError('Failed to update portfolio');
        throw error;
    }
}

async function deletePortfolio(portfolioId) {
    try {
        const response = await fetch(`/api/portfolios/${portfolioId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('userToken') || ''}`
            }
        });
        
        if (response.ok) {
            portfolios = portfolios.filter(p => p.id !== portfolioId);
            renderPortfoliosList(portfolios);
            
            if (currentPortfolioId === portfolioId) {
                currentPortfolioId = portfolios.length > 0 ? portfolios[0].id : null;
                if (currentPortfolioId) {
                    await loadPortfolioDetails(currentPortfolioId);
                } else {
                    clearPortfolioDetails();
                }
            }
            
            showSuccess('Portfolio deleted successfully');
        } else {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
    } catch (error) {
        console.error('Error deleting portfolio:', error);
        showError('Failed to delete portfolio');
        throw error;
    }
}

// Advisory Signals Functions
async function loadAdvisorySignals(portfolioId) {
    try {
        const response = await fetch(`/api/portfolios/${portfolioId}/advisory-signals`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('userToken') || ''}`
            }
        });
        
        if (response.ok) {
            advisorySignals = await response.json();
            renderAdvisorySignals(advisorySignals);
            updateSignalsChart(advisorySignals);
        } else {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
    } catch (error) {
        console.error('Error loading advisory signals:', error);
        // Fallback to dummy data
        advisorySignals = generateDummyAdvisorySignals(portfolioId);
        renderAdvisorySignals(advisorySignals);
        updateSignalsChart(advisorySignals);
    }
}

async function generateNewSignals(portfolioId) {
    try {
        showLoadingIndicator();
        const response = await fetch(`/api/portfolios/${portfolioId}/generate-signals`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('userToken') || ''}`
            }
        });
        
        if (response.ok) {
            const newSignals = await response.json();
            advisorySignals = newSignals;
            renderAdvisorySignals(newSignals);
            updateSignalsChart(newSignals);
            showSuccess('New advisory signals generated successfully');
        } else {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
    } catch (error) {
        console.error('Error generating new signals:', error);
        showError('Failed to generate new advisory signals');
    } finally {
        hideLoadingIndicator();
    }
}

// Market Data Functions
async function loadMarketData() {
    try {
        const response = await fetch('/api/market-data', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('userToken') || ''}`
            }
        });
        
        if (response.ok) {
            marketData = await response.json();
            updateMarketOverview(marketData);
        } else {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
    } catch (error) {
        console.error('Error loading market data:', error);
        // Fallback to dummy data
        marketData = generateDummyMarketData();
        updateMarketOverview(marketData);
    }
}

// UI Rendering Functions
function renderPortfoliosList(portfolios) {
    const portfolioList = document.getElementById('portfolio-list');
    if (!portfolioList) return;
    
    portfolioList.innerHTML = portfolios.map(portfolio => `
        <div class="portfolio-item ${portfolio.id === currentPortfolioId ? 'active' : ''}" 
             data-portfolio-id="${portfolio.id}">
            <div class="portfolio-name">${portfolio.name}</div>
            <div class="portfolio-value">₹${formatCurrency(portfolio.totalValue)}</div>
            <div class="portfolio-actions">
                <button class="btn btn-sm btn-outline-primary view-portfolio" data-portfolio-id="${portfolio.id}">
                    View
                </button>
                <button class="btn btn-sm btn-outline-secondary edit-portfolio" data-portfolio-id="${portfolio.id}">
                    Edit
                </button>
                <button class="btn btn-sm btn-outline-danger delete-portfolio" data-portfolio-id="${portfolio.id}">
                    Delete
                </button>
            </div>
        </div>
    `).join('');
    
    // Add event listeners to portfolio items
    portfolioList.querySelectorAll('.view-portfolio').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const portfolioId = btn.dataset.portfolioId;
            selectPortfolio(portfolioId);
        });
    });
    
    portfolioList.querySelectorAll('.edit-portfolio').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const portfolioId = btn.dataset.portfolioId;
            showEditPortfolioModal(portfolioId);
        });
    });
    
    portfolioList.querySelectorAll('.delete-portfolio').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const portfolioId = btn.dataset.portfolioId;
            confirmDeletePortfolio(portfolioId);
        });
    });
    
    portfolioList.querySelectorAll('.portfolio-item').forEach(item => {
        item.addEventListener('click', (e) => {
            if (!e.target.closest('.portfolio-actions')) {
                const portfolioId = item.dataset.portfolioId;
                selectPortfolio(portfolioId);
            }
        });
    });
}

function renderPortfolioDetails(portfolio) {
    const portfolioDetails = document.getElementById('portfolio-details');
    if (!portfolioDetails) return;
    
    portfolioDetails.innerHTML = `
        <div class="portfolio-header">
            <h3>${portfolio.name}</h3>
            <div class="portfolio-meta">
                <span class="badge bg-${portfolio.riskLevel}">${portfolio.riskLevel} Risk</span>
                <span>Created: ${new Date(portfolio.createdAt).toLocaleDateString()}</span>
            </div>
        </div>
        
        <div class="portfolio-stats">
            <div class="stat-card">
                <div class="stat-value">₹${formatCurrency(portfolio.totalValue)}</div>
                <div class="stat-label">Total Value</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${portfolio.holdings.length}</div>
                <div class="stat-label">Holdings</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${calculatePortfolioReturn(portfolio)}%</div>
                <div class="stat-label">Total Return</div>
            </div>
        </div>
        
        <div class="holdings-section">
            <h4>Holdings</h4>
            <div class="holdings-list">
                ${portfolio.holdings.map(holding => `
                    <div class="holding-item">
                        <div class="holding-info">
                            <div class="stock-name">${holding.stockName} (${holding.symbol})</div>
                            <div class="stock-sector">${holding.sector}</div>
                        </div>
                        <div class="holding-details">
                            <div class="quantity">${holding.quantity} shares</div>
                            <div class="value">₹${formatCurrency(holding.currentValue)}</div>
                            <div class="return ${holding.return >= 0 ? 'positive' : 'negative'}">
                                ${holding.return >= 0 ? '+' : ''}${holding.return}%
                            </div>
                        </div>
                    </div>
                `).join('')}
            </div>
        </div>
    `;
}

function renderAdvisorySignals(signals) {
    const signalsContainer = document.getElementById('advisory-signals');
    if (!signalsContainer) return;
    
    signalsContainer.innerHTML = `
        <h4>Advisory Signals</h4>
        <div class="signals-grid">
            ${signals.map(signal => `
                <div class="signal-card signal-${signal.recommendation.toLowerCase()}">
                    <div class="signal-header">
                        <div class="stock-info">
                            <div class="stock-name">${signal.stockName}</div>
                            <div class="stock-symbol">${signal.symbol}</div>
                        </div>
                        <div class="signal-badge ${signal.recommendation.toLowerCase()}">
                            ${signal.recommendation}
                        </div>
                    </div>
                    
                    <div class="signal-details">
                        <div class="signal-metric">
                            <span class="label">Current Price:</span>
                            <span class="value">₹${formatCurrency(signal.currentPrice)}</span>
                        </div>
                        <div class="signal-metric">
                            <span class="label">Target Price:</span>
                            <span class="value">₹${formatCurrency(signal.targetPrice)}</span>
                        </div>
                        <div class="signal-metric">
                            <span class="label">Upside:</span>
                            <span class="value ${signal.upside >= 0 ? 'positive' : 'negative'}">
                                ${signal.upside >= 0 ? '+' : ''}${signal.upside}%
                            </span>
                        </div>
                    </div>
                    
                    <div class="signal-factors">
                        <div class="factors-title">Key Factors:</div>
                        <div class="factors-list">
                            ${signal.keyFactors.map(factor => `
                                <span class="factor-tag">${factor}</span>
                            `).join('')}
                        </div>
                    </div>
                    
                    <div class="signal-confidence">
                        <div class="confidence-label">Confidence:</div>
                        <div class="confidence-bar">
                            <div class="confidence-fill" style="width: ${signal.confidence}%"></div>
                        </div>
                        <div class="confidence-value">${signal.confidence}%</div>
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

// Chart Initialization and Update Functions
function initializeCharts() {
    // Initialize signals distribution chart
    const signalsCtx = document.getElementById('signals-chart');
    if (signalsCtx) {
        window.signalsChart = new Chart(signalsCtx, {
            type: 'doughnut',
            data: {
                labels: ['Buy', 'Hold', 'Sell'],
                datasets: [{
                    data: [0, 0, 0],
                    backgroundColor: ['#28a745', '#ffc107', '#dc3545']
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
    
    // Initialize portfolio performance chart
    const performanceCtx = document.getElementById('performance-chart');
    if (performanceCtx) {
        window.performanceChart = new Chart(performanceCtx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'Portfolio Value',
                    data: [],
                    borderColor: '#007bff',
                    tension: 0.1,
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

function updateSignalsChart(signals) {
    if (!window.signalsChart) return;
    
    const buyCount = signals.filter(s => s.recommendation === 'BUY').length;
    const holdCount = signals.filter(s => s.recommendation === 'HOLD').length;
    const sellCount = signals.filter(s => s.recommendation === 'SELL').length;
    
    window.signalsChart.data.datasets[0].data = [buyCount, holdCount, sellCount];
    window.signalsChart.update();
}

function updateMarketOverview(marketData) {
    const marketOverview = document.getElementById('market-overview');
   