// script.js - Frontend JavaScript for Indian Equity Portfolio Management System

document.addEventListener('DOMContentLoaded', function() {
    // Authentication state management
    let currentUser = null;
    let authToken = localStorage.getItem('authToken');
    
    // DOM Elements
    const loginForm = document.getElementById('loginForm');
    const portfolioTable = document.getElementById('portfolioTable');
    const advisorDashboard = document.getElementById('advisorDashboard');
    const logoutBtn = document.getElementById('logoutBtn');
    const portfolioForm = document.getElementById('portfolioForm');
    const chartsContainer = document.getElementById('chartsContainer');
    
    // Initialize application
    initApp();
    
    function initApp() {
        checkAuthentication();
        setupEventListeners();
    }
    
    function checkAuthentication() {
        if (authToken) {
            verifyToken();
        } else {
            showLogin();
        }
    }
    
    async function verifyToken() {
        try {
            const response = await fetch('/api/verify-token', {
                headers: {
                    'Authorization': `Bearer ${authToken}`
                }
            });
            
            if (response.ok) {
                const userData = await response.json();
                currentUser = userData;
                showDashboard();
                loadPortfolioData();
                if (currentUser.role === 'advisor') {
                    loadAdvisoryData();
                }
            } else {
                localStorage.removeItem('authToken');
                showLogin();
            }
        } catch (error) {
            console.error('Token verification failed:', error);
            showLogin();
        }
    }
    
    function setupEventListeners() {
        // Login form submission
        if (loginForm) {
            loginForm.addEventListener('submit', handleLogin);
        }
        
        // Logout button
        if (logoutBtn) {
            logoutBtn.addEventListener('click', handleLogout);
        }
        
        // Portfolio form submission
        if (portfolioForm) {
            portfolioForm.addEventListener('submit', handlePortfolioSubmit);
        }
    }
    
    async function handleLogin(e) {
        e.preventDefault();
        
        const email = document.getElementById('email').value;
        const password = document.getElementById('password').value;
        
        try {
            const response = await fetch('/api/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ email, password })
            });
            
            if (response.ok) {
                const data = await response.json();
                authToken = data.token;
                localStorage.setItem('authToken', authToken);
                currentUser = data.user;
                showDashboard();
                loadPortfolioData();
            } else {
                alert('Login failed. Please check your credentials.');
            }
        } catch (error) {
            console.error('Login error:', error);
            alert('Login failed. Please try again.');
        }
    }
    
    function handleLogout() {
        localStorage.removeItem('authToken');
        authToken = null;
        currentUser = null;
        showLogin();
    }
    
    function showLogin() {
        document.getElementById('loginSection').classList.remove('d-none');
        document.getElementById('dashboardSection').classList.add('d-none');
        document.getElementById('advisorSection').classList.add('d-none');
    }
    
    function showDashboard() {
        document.getElementById('loginSection').classList.add('d-none');
        document.getElementById('dashboardSection').classList.remove('d-none');
        
        if (currentUser.role === 'advisor') {
            document.getElementById('advisorSection').classList.remove('d-none');
        } else {
            document.getElementById('advisorSection').classList.add('d-none');
        }
    }
    
    async function loadPortfolioData() {
        try {
            const response = await fetch('/api/portfolio', {
                headers: {
                    'Authorization': `Bearer ${authToken}`
                }
            });
            
            if (response.ok) {
                const portfolioData = await response.json();
                renderPortfolioTable(portfolioData);
                renderPortfolioCharts(portfolioData);
            }
        } catch (error) {
            console.error('Failed to load portfolio:', error);
        }
    }
    
    async function loadAdvisoryData() {
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
            console.error('Failed to load advisory signals:', error);
        }
    }
    
    async function handlePortfolioSubmit(e) {
        e.preventDefault();
        
        const formData = new FormData(portfolioForm);
        const portfolioItem = {
            stock_symbol: formData.get('stock_symbol'),
            quantity: parseInt(formData.get('quantity')),
            purchase_price: parseFloat(formData.get('purchase_price')),
            purchase_date: formData.get('purchase_date')
        };
        
        try {
            const response = await fetch('/api/portfolio', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${authToken}`
                },
                body: JSON.stringify(portfolioItem)
            });
            
            if (response.ok) {
                portfolioForm.reset();
                loadPortfolioData();
            } else {
                alert('Failed to add portfolio item');
            }
        } catch (error) {
            console.error('Portfolio submission error:', error);
            alert('Failed to add portfolio item');
        }
    }
    
    function renderPortfolioTable(portfolioData) {
        const tbody = portfolioTable.querySelector('tbody');
        tbody.innerHTML = '';
        
        portfolioData.forEach(item => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${item.stock_symbol}</td>
                <td>${item.quantity}</td>
                <td>₹${item.purchase_price.toFixed(2)}</td>
                <td>₹${item.current_price.toFixed(2)}</td>
                <td>${item.purchase_date}</td>
                <td>₹${(item.quantity * item.current_price).toFixed(2)}</td>
                <td>
                    <button class="btn btn-sm btn-danger" onclick="deletePortfolioItem(${item.id})">
                        Delete
                    </button>
                </td>
            `;
            tbody.appendChild(row);
        });
    }
    
    function renderPortfolioCharts(portfolioData) {
        // Clear previous charts
        chartsContainer.innerHTML = '';
        
        // Create allocation chart
        const allocationCanvas = document.createElement('canvas');
        allocationCanvas.id = 'allocationChart';
        chartsContainer.appendChild(allocationCanvas);
        
        const allocationData = {
            labels: portfolioData.map(item => item.stock_symbol),
            datasets: [{
                data: portfolioData.map(item => item.quantity * item.current_price),
                backgroundColor: ['#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF']
            }]
        };
        
        new Chart(allocationCanvas, {
            type: 'pie',
            data: allocationData,
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Portfolio Allocation'
                    }
                }
            }
        });
        
        // Create performance chart
        const performanceCanvas = document.createElement('canvas');
        performanceCanvas.id = 'performanceChart';
        chartsContainer.appendChild(performanceCanvas);
        
        const performanceData = {
            labels: portfolioData.map(item => item.stock_symbol),
            datasets: [{
                label: 'Purchase Value',
                data: portfolioData.map(item => item.quantity * item.purchase_price),
                backgroundColor: '#36A2EB'
            }, {
                label: 'Current Value',
                data: portfolioData.map(item => item.quantity * item.current_price),
                backgroundColor: '#FF6384'
            }]
        };
        
        new Chart(performanceCanvas, {
            type: 'bar',
            data: performanceData,
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Investment Performance'
                    }
                }
            }
        });
    }
    
    function renderAdvisorySignals(signals) {
        const signalsContainer = document.getElementById('advisorySignals');
        signalsContainer.innerHTML = '';
        
        signals.forEach(signal => {
            const card = document.createElement('div');
            card.className = 'card mb-3';
            
            let badgeClass = 'bg-secondary';
            if (signal.recommendation === 'Buy') badgeClass = 'bg-success';
            else if (signal.recommendation === 'Sell') badgeClass = 'bg-danger';
            
            card.innerHTML = `
                <div class="card-body">
                    <h5 class="card-title">
                        ${signal.stock_symbol}
                        <span class="badge ${badgeClass} float-end">${signal.recommendation}</span>
                    </h5>
                    <p class="card-text">
                        <strong>Target Price:</strong> ₹${signal.target_price.toFixed(2)}<br>
                        <strong>Confidence:</strong> ${signal.confidence_score}%<br>
                        <strong>Reason:</strong> ${signal.reason}
                    </p>
                    <small class="text-muted">Last updated: ${new Date(signal.updated_at).toLocaleDateString()}</small>
                </div>
            `;
            
            signalsContainer.appendChild(card);
        });
    }
    
    // Global function for portfolio deletion
    window.deletePortfolioItem = async function(itemId) {
        if (!confirm('Are you sure you want to delete this item?')) return;
        
        try {
            const response = await fetch(`/api/portfolio/${itemId}`, {
                method: 'DELETE',
                headers: {
                    'Authorization': `Bearer ${authToken}`
                }
            });
            
            if (response.ok) {
                loadPortfolioData();
            } else {
                alert('Failed to delete portfolio item');
            }
        } catch (error) {
            console.error('Delete error:', error);
            alert('Failed to delete portfolio item');
        }
    };
    
    // Responsive design adjustments
    function handleResize() {
        const charts = document.querySelectorAll('canvas');
        charts.forEach(chart => {
            chart.style.maxWidth = '100%';
            chart.style.height = 'auto';
        });
    }
    
    window.addEventListener('resize', handleResize);
    handleResize(); // Initial call
});