// script.js - Frontend JavaScript for Indian Equity Portfolio Management MVP

// Main application module
const PortfolioApp = (() => {
    // Configuration
    const API_BASE_URL = 'http://localhost:5000/api';
    const config = {
        endpoints: {
            portfolios: `${API_BASE_URL}/portfolios`,
            transactions: `${API_BASE_URL}/transactions`,
            securities: `${API_BASE_URL}/securities`,
            advisory: `${API_BASE_URL}/advisory`,
            reports: `${API_BASE_URL}/reports`
        }
    };

    // State management
    let state = {
        portfolios: [],
        selectedPortfolio: null,
        securities: [],
        advisorySignals: [],
        reports: {}
    };

    // DOM Elements cache
    const elements = {
        portfolioList: document.getElementById('portfolio-list'),
        portfolioForm: document.getElementById('portfolio-form'),
        transactionForm: document.getElementById('transaction-form'),
        advisoryContainer: document.getElementById('advisory-container'),
        dashboardContainer: document.getElementById('dashboard-container'),
        loadingIndicator: document.getElementById('loading-indicator'),
        errorAlert: document.getElementById('error-alert')
    };

    // API Service functions
    const apiService = {
        // Generic API request handler
        async request(endpoint, options = {}) {
            try {
                const response = await fetch(endpoint, {
                    headers: {
                        'Content-Type': 'application/json',
                        ...options.headers
                    },
                    ...options
                });

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                return await response.json();
            } catch (error) {
                console.error('API request failed:', error);
                ui.showError(`API Error: ${error.message}`);
                throw error;
            }
        },

        // Portfolio operations
        async getPortfolios() {
            return this.request(config.endpoints.portfolios);
        },

        async createPortfolio(portfolioData) {
            return this.request(config.endpoints.portfolios, {
                method: 'POST',
                body: JSON.stringify(portfolioData)
            });
        },

        async updatePortfolio(id, portfolioData) {
            return this.request(`${config.endpoints.portfolios}/${id}`, {
                method: 'PUT',
                body: JSON.stringify(portfolioData)
            });
        },

        async deletePortfolio(id) {
            return this.request(`${config.endpoints.portfolios}/${id}`, {
                method: 'DELETE'
            });
        },

        // Transaction operations
        async createTransaction(transactionData) {
            return this.request(config.endpoints.transactions, {
                method: 'POST',
                body: JSON.stringify(transactionData)
            });
        },

        // Security operations
        async getSecurities() {
            return this.request(config.endpoints.securities);
        },

        // Advisory operations
        async getAdvisorySignals(portfolioId) {
            return this.request(`${config.endpoints.advisory}/${portfolioId}`);
        },

        // Report operations
        async getPortfolioReports(portfolioId) {
            return this.request(`${config.endpoints.reports}/${portfolioId}`);
        }
    };

    // UI Controller functions
    const ui = {
        // Show/hide loading state
        showLoading(show = true) {
            if (elements.loadingIndicator) {
                elements.loadingIndicator.style.display = show ? 'block' : 'none';
            }
        },

        // Show error message
        showError(message) {
            if (elements.errorAlert) {
                elements.errorAlert.textContent = message;
                elements.errorAlert.style.display = 'block';
                setTimeout(() => {
                    elements.errorAlert.style.display = 'none';
                }, 5000);
            }
        },

        // Render portfolio list
        renderPortfolios(portfolios) {
            if (!elements.portfolioList) return;

            elements.portfolioList.innerHTML = portfolios.map(portfolio => `
                <div class="col-md-4 mb-3">
                    <div class="card portfolio-card" data-portfolio-id="${portfolio.id}">
                        <div class="card-body">
                            <h5 class="card-title">${portfolio.name}</h5>
                            <p class="card-text">
                                <strong>Client:</strong> ${portfolio.client_name}<br>
                                <strong>Value:</strong> ₹${portfolio.total_value.toLocaleString('en-IN')}<br>
                                <strong>Last Updated:</strong> ${new Date(portfolio.last_updated).toLocaleDateString('en-IN')}
                            </p>
                            <div class="btn-group" role="group">
                                <button class="btn btn-primary btn-sm view-portfolio" data-portfolio-id="${portfolio.id}">
                                    View Details
                                </button>
                                <button class="btn btn-outline-danger btn-sm delete-portfolio" data-portfolio-id="${portfolio.id}">
                                    Delete
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            `).join('');

            // Add event listeners
            this.attachPortfolioEventListeners();
        },

        // Render advisory signals
        renderAdvisorySignals(signals) {
            if (!elements.advisoryContainer) return;

            elements.advisoryContainer.innerHTML = signals.map(signal => `
                <div class="col-md-6 mb-3">
                    <div class="card advisory-card ${this.getSignalClass(signal.recommendation)}">
                        <div class="card-body">
                            <h6 class="card-title">${signal.security_name} (${signal.symbol})</h6>
                            <span class="badge ${this.getSignalBadgeClass(signal.recommendation)}">
                                ${signal.recommendation}
                            </span>
                            <p class="card-text mt-2">
                                <small>Current Price: ₹${signal.current_price}</small><br>
                                <small>Target Price: ₹${signal.target_price}</small><br>
                                <small>Confidence: ${signal.confidence_level}%</small>
                            </p>
                            <p class="card-text">
                                <strong>Reason:</strong> ${signal.reason}
                            </p>
                        </div>
                    </div>
                </div>
            `).join('');
        },

        // Render dashboard charts
        renderDashboardReports(reports) {
            if (!elements.dashboardContainer) return;

            // Placeholder for chart rendering - would integrate with Chart.js or similar
            elements.dashboardContainer.innerHTML = `
                <div class="row">
                    <div class="col-md-6">
                        <div class="card">
                            <div class="card-header">
                                <h5>Portfolio Performance</h5>
                            </div>
                            <div class="card-body">
                                <canvas id="performanceChart" width="400" height="200"></canvas>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="card">
                            <div class="card-header">
                                <h5>Sector Allocation</h5>
                            </div>
                            <div class="card-body">
                                <canvas id="sectorChart" width="400" height="200"></canvas>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="row mt-3">
                    <div class="col-12">
                        <div class="card">
                            <div class="card-header">
                                <h5>Top Holdings</h5>
                            </div>
                            <div class="card-body">
                                <canvas id="holdingsChart" width="400" height="150"></canvas>
                            </div>
                        </div>
                    </div>
                </div>
            `;

            // Initialize charts (mock implementation)
            this.initializeCharts(reports);
        },

        // Helper methods for UI
        getSignalClass(recommendation) {
            const classes = {
                'BUY': 'border-success',
                'SELL': 'border-danger',
                'HOLD': 'border-warning'
            };
            return classes[recommendation] || 'border-secondary';
        },

        getSignalBadgeClass(recommendation) {
            const classes = {
                'BUY': 'bg-success',
                'SELL': 'bg-danger',
                'HOLD': 'bg-warning'
            };
            return classes[recommendation] || 'bg-secondary';
        },

        initializeCharts(reports) {
            // Mock chart initialization - would use Chart.js in production
            console.log('Initializing charts with data:', reports);
        },

        attachPortfolioEventListeners() {
            // View portfolio details
            document.querySelectorAll('.view-portfolio').forEach(btn => {
                btn.addEventListener('click', (e) => {
                    const portfolioId = e.target.dataset.portfolioId;
                    PortfolioApp.loadPortfolioDetails(portfolioId);
                });
            });

            // Delete portfolio
            document.querySelectorAll('.delete-portfolio').forEach(btn => {
                btn.addEventListener('click', (e) => {
                    const portfolioId = e.target.dataset.portfolioId;
                    PortfolioApp.deletePortfolio(portfolioId);
                });
            });
        }
    };

    // Event handlers
    const handlePortfolioFormSubmit = async (e) => {
        e.preventDefault();
        
        const formData = new FormData(e.target);
        const portfolioData = {
            name: formData.get('portfolioName'),
            client_name: formData.get('clientName'),
            initial_cash: parseFloat(formData.get('initialCash'))
        };

        try {
            ui.showLoading();
            await apiService.createPortfolio(portfolioData);
            await loadPortfolios();
            e.target.reset();
            ui.showError('Portfolio created successfully!');
        } catch (error) {
            ui.showError('Failed to create portfolio');
        } finally {
            ui.showLoading(false);
        }
    };

    const handleTransactionFormSubmit = async (e) => {
        e.preventDefault();
        
        const formData = new FormData(e.target);
        const transactionData = {
            portfolio_id: parseInt(formData.get('portfolioId')),
            security_id: parseInt(formData.get('securityId')),
            transaction_type: formData.get('transactionType'),
            quantity: parseInt(formData.get('quantity')),
            price: parseFloat(formData.get('price')),
            transaction_date: formData.get('transactionDate')
        };

        try {
            ui.showLoading();
            await apiService.createTransaction(transactionData);
            await loadPortfolioDetails(transactionData.portfolio_id);
            e.target.reset();
            ui.showError('Transaction completed successfully!');
        } catch (error) {
            ui.showError('Failed to process transaction');
        } finally {
            ui.showLoading(false);
        }
    };

    // Public methods
    const loadPortfolios = async () => {
        try {
            ui.showLoading();
            state.portfolios = await apiService.getPortfolios();
            ui.renderPortfolios(state.portfolios);
        } catch (error) {
            ui.showError('Failed to load portfolios');
        } finally {
            ui.showLoading(false);
        }
    };

    const loadPortfolioDetails = async (portfolioId) => {
        try {
            ui.showLoading();
            // Load portfolio details, transactions, and advisory signals
            const [portfolio, signals, reports] = await Promise.all([
                apiService.getPortfolios().then(portfolios => 
                    portfolios.find(p => p.id === parseInt(portfolioId))
                ),
                apiService.getAdvisorySignals(portfolioId),
                apiService.getPortfolioReports(portfolioId)
            ]);

            state.selectedPortfolio = portfolio;
            state.advisorySignals = signals;
            state.reports = reports;

            ui.renderAdvisorySignals(signals);
            ui.renderDashboardReports(reports);
        } catch (error) {
            ui.showError('Failed to load portfolio details');
        } finally {
            ui.showLoading(false);
        }
    };

    const deletePortfolio = async (portfolioId) => {
        if (!confirm('Are you sure you want to delete this portfolio?')) return;

        try {
            ui.showLoading();
            await apiService.deletePortfolio(portfolioId);
            await loadPortfolios();
            ui.showError('Portfolio deleted successfully!');
        } catch (error) {
            ui.showError('Failed to delete portfolio');
        } finally {
            ui.showLoading(false);
        }
    };

    const initialize = () => {
        // Set up event listeners
        if (elements.portfolioForm) {
            elements.portfolioForm.addEventListener('submit', handlePortfolioFormSubmit);
        }

        if (elements.transactionForm) {
            elements.transactionForm.addEventListener('submit', handleTransactionFormSubmit);
        }

        // Load initial data
        loadPortfolios();
        loadSecurities();
    };

    const loadSecurities = async () => {
        try {
            state.securities = await apiService.getSecurities();
        } catch (error) {
            console.error('Failed to load securities:', error);
        }
    };

    // Public API
    return {
        initialize,
        loadPortfolios,
        loadPortfolioDetails,
        deletePortfolio,
        state
    };
})();

// Initialize application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    PortfolioApp.initialize();
});

// Utility functions
const utils = {
    formatCurrency(amount) {
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR'
        }).format(amount);
    },

    formatDate(date) {
        return new Intl.DateTimeFormat('en-IN').format(new Date(date));
    },

    debounce(func, wait) {
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
};

// Error handling
window.addEventListener('error', (e) => {
    console.error('Global error:', e.error);
    PortfolioApp.ui?.showError('An unexpected error occurred');
});

// Export for testing (if needed)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { PortfolioApp, utils };
}