// script.js - Frontend JavaScript for Portfolio Management Dashboard
// This file handles the frontend logic for the MVP web application for managing client stock portfolios
// focused on Indian equity markets. It includes API integration, data visualization, and UI interactions.

document.addEventListener('DOMContentLoaded', function() {
    // Authentication state management
    let currentUser = null;
    let authToken = null;

    // Initialize application
    initApp();

    // Initialize the application
    function initApp() {
        checkAuthentication();
        setupEventListeners();
        loadInitialData();
    }

    // Check if user is authenticated
    function checkAuthentication() {
        const token = localStorage.getItem('authToken');
        const userData = localStorage.getItem('userData');
        
        if (token && userData) {
            authToken = token;
            currentUser = JSON.parse(userData);
            updateUIForAuthentication(true);
        } else {
            updateUIForAuthentication(false);
        }
    }

    // Setup all event listeners
    function setupEventListeners() {
        // Login form submission
        const loginForm = document.getElementById('loginForm');
        if (loginForm) {
            loginForm.addEventListener('submit', handleLogin);
        }

        // Portfolio form submission
        const portfolioForm = document.getElementById('portfolioForm');
        if (portfolioForm) {
            portfolioForm.addEventListener('submit', handlePortfolioSubmit);
        }

        // Logout button
        const logoutBtn = document.getElementById('logoutBtn');
        if (logoutBtn) {
            logoutBtn.addEventListener('click', handleLogout);
        }

        // Navigation links
        document.querySelectorAll('.nav-link').forEach(link => {
            link.addEventListener('click', handleNavigation);
        });
    }

    // Handle user login
    async function handleLogin(e) {
        e.preventDefault();
        
        const email = document.getElementById('email').value;
        const password = document.getElementById('password').value;
        
        try {
            const response = await fetch('/api/auth/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ email, password })
            });

            if (response.ok) {
                const data = await response.json();
                authToken = data.token;
                currentUser = data.user;
                
                // Store authentication data
                localStorage.setItem('authToken', authToken);
                localStorage.setItem('userData', JSON.stringify(currentUser));
                
                updateUIForAuthentication(true);
                showNotification('Login successful!', 'success');
                loadDashboard();
            } else {
                const error = await response.json();
                showNotification(error.message || 'Login failed', 'error');
            }
        } catch (error) {
            showNotification('Network error. Please try again.', 'error');
        }
    }

    // Handle logout
    function handleLogout() {
        localStorage.removeItem('authToken');
        localStorage.removeItem('userData');
        authToken = null;
        currentUser = null;
        updateUIForAuthentication(false);
        showNotification('Logged out successfully', 'success');
    }

    // Update UI based on authentication state
    function updateUIForAuthentication(isAuthenticated) {
        const authElements = document.querySelectorAll('.auth-only');
        const unauthElements = document.querySelectorAll('.unauth-only');
        
        if (isAuthenticated) {
            authElements.forEach(el => el.style.display = 'block');
            unauthElements.forEach(el => el.style.display = 'none');
            
            // Update user info
            const userInfo = document.getElementById('userInfo');
            if (userInfo && currentUser) {
                userInfo.textContent = `Welcome, ${currentUser.name}`;
            }
        } else {
            authElements.forEach(el => el.style.display = 'none');
            unauthElements.forEach(el => el.style.display = 'block');
        }
    }

    // Load initial data for the dashboard
    async function loadInitialData() {
        if (!authToken) return;

        try {
            await Promise.all([
                loadPortfolios(),
                loadMarketData(),
                loadAdvisorySignals()
            ]);
        } catch (error) {
            console.error('Error loading initial data:', error);
            showNotification('Failed to load data', 'error');
        }
    }

    // Load user portfolios
    async function loadPortfolios() {
        try {
            const response = await fetch('/api/portfolios', {
                headers: {
                    'Authorization': `Bearer ${authToken}`
                }
            });

            if (response.ok) {
                const portfolios = await response.json();
                renderPortfolios(portfolios);
            }
        } catch (error) {
            console.error('Error loading portfolios:', error);
        }
    }

    // Load market data
    async function loadMarketData() {
        try {
            const response = await fetch('/api/market/data', {
                headers: {
                    'Authorization': `Bearer ${authToken}`
                }
            });

            if (response.ok) {
                const marketData = await response.json();
                renderMarketOverview(marketData);
            }
        } catch (error) {
            console.error('Error loading market data:', error);
        }
    }

    // Load advisory signals
    async function loadAdvisorySignals() {
        try {
            const response = await fetch('/api/advisory/signals', {
                headers: {
                    'Authorization': `Bearer ${authToken}`
                }
            });

            if (response.ok) {
                const signals = await response.json();
                renderAdvisorySignals(signals);
            }
        } catch (error) {
            console.error('Error loading advisory signals:', error);
        }
    }

    // Handle portfolio form submission
    async function handlePortfolioSubmit(e) {
        e.preventDefault();
        
        const formData = new FormData(e.target);
        const portfolioData = {
            name: formData.get('portfolioName'),
            description: formData.get('description'),
            stocks: []
        };

        try {
            const response = await fetch('/api/portfolios', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${authToken}`
                },
                body: JSON.stringify(portfolioData)
            });

            if (response.ok) {
                showNotification('Portfolio created successfully', 'success');
                e.target.reset();
                loadPortfolios();
            } else {
                const error = await response.json();
                showNotification(error.message || 'Failed to create portfolio', 'error');
            }
        } catch (error) {
            showNotification('Network error. Please try again.', 'error');
        }
    }

    // Render portfolios list
    function renderPortfolios(portfolios) {
        const container = document.getElementById('portfoliosList');
        if (!container) return;

        container.innerHTML = portfolios.map(portfolio => `
            <div class="col-md-6 col-lg-4 mb-4">
                <div class="card portfolio-card">
                    <div class="card-body">
                        <h5 class="card-title">${portfolio.name}</h5>
                        <p class="card-text">${portfolio.description || 'No description'}</p>
                        <p class="text-muted">Stocks: ${portfolio.stocks.length}</p>
                        <button class="btn btn-primary btn-sm" onclick="viewPortfolio(${portfolio.id})">
                            View Details
                        </button>
                    </div>
                </div>
            </div>
        `).join('');
    }

    // Render market overview
    function renderMarketOverview(marketData) {
        const container = document.getElementById('marketOverview');
        if (!container) return;

        container.innerHTML = `
            <div class="row">
                ${marketData.sectors.map(sector => `
                    <div class="col-md-3 col-sm-6 mb-3">
                        <div class="card sector-card">
                            <div class="card-body">
                                <h6 class="card-title">${sector.name}</h6>
                                <p class="card-text ${getSignalClass(sector.signal)}">
                                    ${sector.signal}
                                </p>
                                <small class="text-muted">Growth: ${sector.growth}%</small>
                            </div>
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
    }

    // Render advisory signals
    function renderAdvisorySignals(signals) {
        const container = document.getElementById('advisorySignals');
        if (!container) return;

        container.innerHTML = signals.map(signal => `
            <div class="col-md-6 mb-3">
                <div class="card signal-card">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <h6 class="card-title mb-0">${signal.stock_symbol}</h6>
                            <span class="badge ${getSignalClass(signal.signal)}">
                                ${signal.signal}
                            </span>
                        </div>
                        <p class="card-text mb-1">${signal.stock_name}</p>
                        <div class="row mt-2">
                            <div class="col-6">
                                <small class="text-muted">Technical: ${signal.technical_score}/10</small>
                            </div>
                            <div class="col-6">
                                <small class="text-muted">Sector: ${signal.sector_score}/10</small>
                            </div>
                        </div>
                        <div class="row">
                            <div class="col-6">
                                <small class="text-muted">Sentiment: ${signal.sentiment_score}/10</small>
                            </div>
                            <div class="col-6">
                                <small class="text-muted">Confidence: ${signal.confidence}%</small>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `).join('');
    }

    // Get CSS class based on signal type
    function getSignalClass(signal) {
        const signalLower = signal.toLowerCase();
        if (signalLower === 'buy') return 'text-success';
        if (signalLower === 'sell') return 'text-danger';
        if (signalLower === 'hold') return 'text-warning';
        return 'text-secondary';
    }

    // Handle navigation
    function handleNavigation(e) {
        e.preventDefault();
        const target = e.target.getAttribute('data-target');
        showSection(target);
    }

    // Show specific section
    function showSection(sectionId) {
        // Hide all sections
        document.querySelectorAll('.content-section').forEach(section => {
            section.style.display = 'none';
        });

        // Show target section
        const targetSection = document.getElementById(sectionId);
        if (targetSection) {
            targetSection.style.display = 'block';
        }

        // Update active navigation
        document.querySelectorAll('.nav-link').forEach(link => {
            link.classList.remove('active');
        });
        document.querySelector(`[data-target="${sectionId}"]`).classList.add('active');
    }

    // Load dashboard view
    function loadDashboard() {
        showSection('dashboard');
        loadInitialData();
    }

    // View portfolio details (to be implemented)
    function viewPortfolio(portfolioId) {
        // Implementation for viewing portfolio details
        console.log('Viewing portfolio:', portfolioId);
        showNotification('Portfolio details view not implemented yet', 'info');
    }

    // Show notification
    function showNotification(message, type = 'info') {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `alert alert-${type} alert-dismissible fade show`;
        notification.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;

        // Add to notification container
        const container = document.getElementById('notificationContainer');
        if (container) {
            container.appendChild(notification);
            
            // Auto remove after 5 seconds
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.remove();
                }
            }, 5000);
        }
    }

    // Expose functions to global scope for HTML onclick attributes
    window.viewPortfolio = viewPortfolio;
    window.loadDashboard = loadDashboard;
});

// Chart initialization function (to be called when chart containers are available)
function initializeCharts() {
    // Portfolio performance chart
    const perfCtx = document.getElementById('portfolioPerformanceChart');
    if (perfCtx) {
        new Chart(perfCtx, {
            type: 'line',
            data: {
                labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                datasets: [{
                    label: 'Portfolio Value',
                    data: [100000, 105000, 110000, 108000, 115000, 120000],
                    borderColor: '#007bff',
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        display: false
                    }
                }
            }
        });
    }

    // Sector allocation chart
    const allocCtx = document.getElementById('sectorAllocationChart');
    if (allocCtx) {
        new Chart(allocCtx, {
            type: 'pie',
            data: {
                labels: ['IT', 'Banking', 'Pharma', 'Auto', 'FMCG'],
                datasets: [{
                    data: [35, 25, 15, 15, 10],
                    backgroundColor: ['#007bff', '#28a745', '#dc3545', '#ffc107', '#17a2b8']
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
}

// Initialize charts when document is fully loaded
document.addEventListener('DOMContentLoaded', initializeCharts);