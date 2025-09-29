// script.js
// Main JavaScript file for MVP Portfolio Management Web Application
// Handles frontend interactions, API calls, and UI updates

// Global variables
let currentPortfolio = [];
let advisorySignals = [];
let isAdvisorView = false;

// DOM Content Loaded Event Listener
document.addEventListener('DOMContentLoaded', function() {
    initializeApplication();
    setupEventListeners();
});

/**
 * Initialize the application
 */
function initializeApplication() {
    // Check if user is advisor (for demo purposes, using localStorage flag)
    isAdvisorView = localStorage.getItem('isAdvisor') === 'true';
    
    // Load initial data
    loadPortfolioData();
    loadAdvisorySignals();
    
    // Update UI based on user role
    updateUIForUserRole();
}

/**
 * Set up event listeners for UI interactions
 */
function setupEventListeners() {
    // Portfolio management
    document.getElementById('addStockForm').addEventListener('submit', handleAddStock);
    document.getElementById('refreshPortfolio').addEventListener('click', loadPortfolioData);
    
    // Advisor view toggle
    const advisorToggle = document.getElementById('advisorToggle');
    if (advisorToggle) {
        advisorToggle.addEventListener('change', toggleAdvisorView);
    }
    
    // Modal handlers
    const modal = document.getElementById('stockModal');
    if (modal) {
        modal.addEventListener('hidden.bs.modal', resetModalForm);
    }
}

/**
 * Load portfolio data from backend API
 */
async function loadPortfolioData() {
    try {
        showLoading('portfolioLoading');
        
        const response = await fetch('/api/portfolio', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const portfolioData = await response.json();
        currentPortfolio = portfolioData;
        renderPortfolio(portfolioData);
        
    } catch (error) {
        console.error('Error loading portfolio:', error);
        showError('Failed to load portfolio data');
        
        // Fallback to dummy data if API fails
        loadDummyPortfolioData();
    } finally {
        hideLoading('portfolioLoading');
    }
}

/**
 * Load advisory signals from backend API
 */
async function loadAdvisorySignals() {
    if (!isAdvisorView) return;
    
    try {
        showLoading('signalsLoading');
        
        const response = await fetch('/api/advisory-signals', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const signalsData = await response.json();
        advisorySignals = signalsData;
        renderAdvisorySignals(signalsData);
        
    } catch (error) {
        console.error('Error loading advisory signals:', error);
        showError('Failed to load advisory signals');
        
        // Fallback to dummy data if API fails
        loadDummyAdvisorySignals();
    } finally {
        hideLoading('signalsLoading');
    }
}

/**
 * Handle adding a new stock to portfolio
 * @param {Event} event - Form submit event
 */
async function handleAddStock(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const stockData = {
        symbol: formData.get('symbol'),
        name: formData.get('name'),
        quantity: parseInt(formData.get('quantity')),
        purchasePrice: parseFloat(formData.get('purchasePrice')),
        sector: formData.get('sector')
    };
    
    try {
        const response = await fetch('/api/portfolio', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(stockData)
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const result = await response.json();
        showSuccess('Stock added successfully!');
        
        // Close modal and refresh portfolio
        bootstrap.Modal.getInstance(document.getElementById('stockModal')).hide();
        loadPortfolioData();
        
    } catch (error) {
        console.error('Error adding stock:', error);
        showError('Failed to add stock');
    }
}

/**
 * Render portfolio data in the UI
 * @param {Array} portfolio - Array of stock objects
 */
function renderPortfolio(portfolio) {
    const portfolioTable = document.getElementById('portfolioTable');
    const portfolioValueElement = document.getElementById('portfolioValue');
    
    if (!portfolioTable) return;
    
    // Clear existing rows except header
    while (portfolioTable.rows.length > 1) {
        portfolioTable.deleteRow(1);
    }
    
    let totalValue = 0;
    
    portfolio.forEach((stock, index) => {
        const row = portfolioTable.insertRow();
        const currentPrice = stock.currentPrice || stock.purchasePrice * (1 + (Math.random() * 0.2 - 0.1)); // Simulated price movement
        
        const marketValue = currentPrice * stock.quantity;
        const gainLoss = marketValue - (stock.purchasePrice * stock.quantity);
        const gainLossPercent = (gainLoss / (stock.purchasePrice * stock.quantity)) * 100;
        
        totalValue += marketValue;
        
        row.innerHTML = `
            <td>${stock.symbol}</td>
            <td>${stock.name}</td>
            <td>${stock.quantity}</td>
            <td>₹${stock.purchasePrice.toFixed(2)}</td>
            <td>₹${currentPrice.toFixed(2)}</td>
            <td>₹${marketValue.toFixed(2)}</td>
            <td class="${gainLoss >= 0 ? 'text-success' : 'text-danger'}">
                ₹${gainLoss.toFixed(2)} (${gainLossPercent.toFixed(2)}%)
            </td>
            <td>${stock.sector}</td>
            <td>
                <button class="btn btn-sm btn-outline-danger" onclick="removeStock(${index})">
                    Remove
                </button>
            </td>
        `;
    });
    
    if (portfolioValueElement) {
        portfolioValueElement.textContent = `₹${totalValue.toFixed(2)}`;
    }
}

/**
 * Render advisory signals in the UI (advisor view only)
 * @param {Array} signals - Array of advisory signal objects
 */
function renderAdvisorySignals(signals) {
    const signalsContainer = document.getElementById('advisorySignals');
    if (!signalsContainer) return;
    
    signalsContainer.innerHTML = '';
    
    signals.forEach(signal => {
        const signalCard = document.createElement('div');
        signalCard.className = 'col-md-6 col-lg-4 mb-3';
        
        let badgeClass = 'bg-secondary';
        if (signal.recommendation === 'Buy') badgeClass = 'bg-success';
        if (signal.recommendation === 'Sell') badgeClass = 'bg-danger';
        if (signal.recommendation === 'Hold') badgeClass = 'bg-warning';
        
        signalCard.innerHTML = `
            <div class="card h-100">
                <div class="card-header d-flex justify-content-between align-items-center">
                    <strong>${signal.symbol}</strong>
                    <span class="badge ${badgeClass}">${signal.recommendation}</span>
                </div>
                <div class="card-body">
                    <h6 class="card-title">${signal.name}</h6>
                    <p class="card-text">${signal.reason}</p>
                    <div class="row">
                        <div class="col-6">
                            <small class="text-muted">Confidence: ${signal.confidence}%</small>
                        </div>
                        <div class="col-6 text-end">
                            <small class="text-muted">${new Date(signal.timestamp).toLocaleDateString()}</small>
                        </div>
                    </div>
                </div>
            </div>
        `;
        
        signalsContainer.appendChild(signalCard);
    });
}

/**
 * Remove a stock from portfolio
 * @param {number} index - Index of the stock to remove
 */
async function removeStock(index) {
    if (index < 0 || index >= currentPortfolio.length) return;
    
    const stock = currentPortfolio[index];
    
    if (!confirm(`Are you sure you want to remove ${stock.name} (${stock.symbol}) from your portfolio?`)) {
        return;
    }
    
    try {
        const response = await fetch(`/api/portfolio/${stock.symbol}`, {
            method: 'DELETE',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        showSuccess('Stock removed successfully!');
        loadPortfolioData();
        
    } catch (error) {
        console.error('Error removing stock:', error);
        showError('Failed to remove stock');
    }
}

/**
 * Toggle advisor view
 * @param {Event} event - Change event from toggle switch
 */
function toggleAdvisorView(event) {
    isAdvisorView = event.target.checked;
    localStorage.setItem('isAdvisor', isAdvisorView);
    updateUIForUserRole();
    loadAdvisorySignals();
}

/**
 * Update UI based on user role (client vs advisor)
 */
function updateUIForUserRole() {
    const advisorSection = document.getElementById('advisorSection');
    const advisorToggle = document.getElementById('advisorToggle');
    
    if (advisorSection) {
        advisorSection.style.display = isAdvisorView ? 'block' : 'none';
    }
    
    if (advisorToggle) {
        advisorToggle.checked = isAdvisorView;
    }
}

/**
 * Reset modal form
 */
function resetModalForm() {
    document.getElementById('addStockForm').reset();
}

/**
 * Show loading indicator
 * @param {string} elementId - ID of the loading element
 */
function showLoading(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        element.style.display = 'block';
    }
}

/**
 * Hide loading indicator
 * @param {string} elementId - ID of the loading element
 */
function hideLoading(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        element.style.display = 'none';
    }
}

/**
 * Show success message
 * @param {string} message - Success message to display
 */
function showSuccess(message) {
    showAlert(message, 'success');
}

/**
 * Show error message
 * @param {string} message - Error message to display
 */
function showError(message) {
    showAlert(message, 'danger');
}

/**
 * Show alert message
 * @param {string} message - Message to display
 * @param {string} type - Alert type (success, danger, warning, info)
 */
function showAlert(message, type) {
    // Create or reuse alert container
    let alertContainer = document.getElementById('alertContainer');
    if (!alertContainer) {
        alertContainer = document.createElement('div');
        alertContainer.id = 'alertContainer';
        alertContainer.className = 'fixed-top mt-5 mx-3';
        document.body.appendChild(alertContainer);
    }
    
    const alertId = `alert-${Date.now()}`;
    const alertHtml = `
        <div id="${alertId}" class="alert alert-${type} alert-dismissible fade show" role="alert">
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
        </div>
    `;
    
    alertContainer.insertAdjacentHTML('beforeend', alertHtml);
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
        const alert = document.getElementById(alertId);
        if (alert) {
            bootstrap.Alert.getOrCreateInstance(alert).close();
        }
    }, 5000);
}

// Dummy data fallback functions
function loadDummyPortfolioData() {
    const dummyData = [
        {
            symbol: 'RELIANCE',
            name: 'Reliance Industries Ltd.',
            quantity: 10,
            purchasePrice: 2450.50,
            sector: 'Energy'
        },
        {
            symbol: 'TCS',
            name: 'Tata Consultancy Services Ltd.',
            quantity: 5,
            purchasePrice: 3250.75,
            sector: 'IT'
        },
        {
            symbol: 'HDFCBANK',
            name: 'HDFC Bank Ltd.',
            quantity: 8,
            purchasePrice: 1450.25,
            sector: 'Banking'
        }
    ];
    
    currentPortfolio = dummyData;
    renderPortfolio(dummyData);
    showError('Using demo data - backend connection failed');
}

function loadDummyAdvisorySignals() {
    const dummySignals = [
        {
            symbol: 'RELIANCE',
            name: 'Reliance Industries Ltd.',
            recommendation: 'Buy',
            reason: 'Strong quarterly results and positive sector outlook',
            confidence: 85,
            timestamp: new Date().toISOString()
        },
        {
            symbol: 'TCS',
            name: 'Tata Consultancy Services Ltd.',
            recommendation: 'Hold',
            reason: 'Stable performance but limited upside potential',
            confidence: 65,
            timestamp: new Date().toISOString()
        },
        {
            symbol: 'INFY',
            name: 'Infosys Ltd.',
            recommendation: 'Buy',
            reason: 'New large contracts and digital transformation demand',
            confidence: 78,
            timestamp: new Date().toISOString()
        },
        {
            symbol: 'HDFCBANK',
            name: 'HDFC Bank Ltd.',
            recommendation: 'Sell',
            reason: 'Regulatory concerns and margin pressure',
            confidence: 72,
            timestamp: new Date().toISOString()
        }
    ];
    
    advisorySignals = dummySignals;
    renderAdvisorySignals(dummySignals);
    showError('Using demo advisory signals - backend connection failed');
}

// Export functions for testing (if needed)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        initializeApplication,
        loadPortfolioData,
        loadAdvisorySignals,
        renderPortfolio,
        renderAdvisorySignals,
        showSuccess,
        showError
    };
}