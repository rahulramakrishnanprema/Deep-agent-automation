// IPM-55 JavaScript Implementation
// Main application file for portfolio management dashboard

class PortfolioManager {
    constructor() {
        this.apiBaseUrl = 'http://localhost:8000/api';
        this.currentUser = null;
        this.portfolioData = null;
        this.advisorySignals = [];
        this.marketData = {};
        this.init();
    }

    async init() {
        await this.checkAuthentication();
        await this.loadMarketData();
        await this.loadPortfolioData();
        await this.loadAdvisorySignals();
        this.renderDashboard();
        this.setupEventListeners();
    }

    // Authentication methods
    async checkAuthentication() {
        const token = localStorage.getItem('authToken');
        if (!token) {
            this.redirectToLogin();
            return;
        }

        try {
            const response = await fetch(`${this.apiBaseUrl}/auth/verify`, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            
            if (response.ok) {
                this.currentUser = await response.json();
            } else {
                this.redirectToLogin();
            }
        } catch (error) {
            console.error('Auth verification failed:', error);
            this.redirectToLogin();
        }
    }

    redirectToLogin() {
        window.location.href = '/login.html';
    }

    // Data loading methods
    async loadMarketData() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/market/data`);
            this.marketData = await response.json();
        } catch (error) {
            console.error('Failed to load market data:', error);
        }
    }

    async loadPortfolioData() {
        try {
            const token = localStorage.getItem('authToken');
            const response = await fetch(`${this.apiBaseUrl}/portfolio`, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            this.portfolioData = await response.json();
        } catch (error) {
            console.error('Failed to load portfolio data:', error);
        }
    }

    async loadAdvisorySignals() {
        try {
            const token = localStorage.getItem('authToken');
            const response = await fetch(`${this.apiBaseUrl}/advisory/signals`, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            this.advisorySignals = await response.json();
        } catch (error) {
            console.error('Failed to load advisory signals:', error);
        }
    }

    // Dashboard rendering
    renderDashboard() {
        this.renderPortfolioSummary();
        this.renderHoldingsTable();
        this.renderAdvisorySignals();
        this.renderMarketOverview();
        this.renderPerformanceCharts();
    }

    renderPortfolioSummary() {
        const summaryElement = document.getElementById('portfolio-summary');
        if (this.portfolioData && summaryElement) {
            summaryElement.innerHTML = `
                <div class="summary-card">
                    <h3>Total Value</h3>
                    <p class="value">₹${this.formatCurrency(this.portfolioData.totalValue)}</p>
                </div>
                <div class="summary-card">
                    <h3>Daily Change</h3>
                    <p class="value ${this.portfolioData.dailyChange >= 0 ? 'positive' : 'negative'}">
                        ${this.portfolioData.dailyChange >= 0 ? '+' : ''}${this.portfolioData.dailyChange}%
                    </p>
                </div>
                <div class="summary-card">
                    <h3>Holdings</h3>
                    <p class="value">${this.portfolioData.holdingsCount}</p>
                </div>
            `;
        }
    }

    renderHoldingsTable() {
        const tableElement = document.getElementById('holdings-table');
        if (this.portfolioData && tableElement) {
            const rows = this.portfolioData.holdings.map(holding => `
                <tr>
                    <td>${holding.symbol}</td>
                    <td>${holding.name}</td>
                    <td>${holding.quantity}</td>
                    <td>₹${this.formatCurrency(holding.currentPrice)}</td>
                    <td>₹${this.formatCurrency(holding.investment)}</td>
                    <td class="${holding.change >= 0 ? 'positive' : 'negative'}">
                        ${holding.change >= 0 ? '+' : ''}${holding.change}%
                    </td>
                </tr>
            `).join('');
            
            tableElement.innerHTML = rows;
        }
    }

    renderAdvisorySignals() {
        const signalsElement = document.getElementById('advisory-signals');
        if (signalsElement) {
            const signalsHtml = this.advisorySignals.map(signal => `
                <div class="signal-card ${signal.confidence > 70 ? 'high-confidence' : signal.confidence > 50 ? 'medium-confidence' : 'low-confidence'}">
                    <h4>${signal.symbol} - ${signal.action}</h4>
                    <p>${signal.reason}</p>
                    <div class="confidence-meter">
                        <span>Confidence: ${signal.confidence}%</span>
                        <div class="meter-bar">
                            <div class="meter-fill" style="width: ${signal.confidence}%"></div>
                        </div>
                    </div>
                    <span class="timestamp">${new Date(signal.timestamp).toLocaleString()}</span>
                </div>
            `).join('');
            
            signalsElement.innerHTML = signalsHtml;
        }
    }

    renderMarketOverview() {
        const marketElement = document.getElementById('market-overview');
        if (this.marketData && marketElement) {
            marketElement.innerHTML = `
                <div class="market-index">
                    <h4>NIFTY 50</h4>
                    <p>${this.marketData.nifty50.value} 
                       <span class="${this.marketData.nifty50.change >= 0 ? 'positive' : 'negative'}">
                           ${this.marketData.nifty50.change >= 0 ? '+' : ''}${this.marketData.nifty50.change}%
                       </span>
                    </p>
                </div>
                <div class="market-index">
                    <h4>SENSEX</h4>
                    <p>${this.marketData.sensex.value} 
                       <span class="${this.marketData.sensex.change >= 0 ? 'positive' : 'negative'}">
                           ${this.marketData.sensex.change >= 0 ? '+' : ''}${this.marketData.sensex.change}%
                       </span>
                    </p>
                </div>
            `;
        }
    }

    renderPerformanceCharts() {
        // Chart rendering logic using Chart.js or similar library
        this.renderPortfolioValueChart();
        this.renderSectorAllocationChart();
    }

    renderPortfolioValueChart() {
        const ctx = document.getElementById('portfolio-chart');
        if (ctx && this.portfolioData) {
            // Implementation for portfolio value chart
            console.log('Rendering portfolio chart with data:', this.portfolioData.historicalValues);
        }
    }

    renderSectorAllocationChart() {
        const ctx = document.getElementById('sector-chart');
        if (ctx && this.portfolioData) {
            // Implementation for sector allocation chart
            console.log('Rendering sector allocation chart');
        }
    }

    // Utility methods
    formatCurrency(amount) {
        return new Intl.NumberFormat('en-IN').format(amount);
    }

    setupEventListeners() {
        // Logout functionality
        const logoutBtn = document.getElementById('logout-btn');
        if (logoutBtn) {
            logoutBtn.addEventListener('click', () => {
                localStorage.removeItem('authToken');
                this.redirectToLogin();
            });
        }

        // Refresh data
        const refreshBtn = document.getElementById('refresh-btn');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', async () => {
                await this.loadMarketData();
                await this.loadPortfolioData();
                await this.loadAdvisorySignals();
                this.renderDashboard();
            });
        }
    }

    // API methods for portfolio operations
    async addHolding(symbol, quantity, price) {
        try {
            const token = localStorage.getItem('authToken');
            const response = await fetch(`${this.apiBaseUrl}/portfolio/holdings`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ symbol, quantity, price })
            });
            
            if (response.ok) {
                await this.loadPortfolioData();
                this.renderDashboard();
                return true;
            }
            return false;
        } catch (error) {
            console.error('Failed to add holding:', error);
            return false;
        }
    }

    async updateHolding(holdingId, quantity, price) {
        try {
            const token = localStorage.getItem('authToken');
            const response = await fetch(`${this.apiBaseUrl}/portfolio/holdings/${holdingId}`, {
                method: 'PUT',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ quantity, price })
            });
            
            if (response.ok) {
                await this.loadPortfolioData();
                this.renderDashboard();
                return true;
            }
            return false;
        } catch
# Code truncated at 10000 characters