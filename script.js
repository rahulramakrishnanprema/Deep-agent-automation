// script.js - Frontend JavaScript for Indian Equity Portfolio Management MVP

// Global variables
let currentUser = null;
let portfolioData = [];
let advisorySignals = [];
let reportData = [];

// DOM Content Loaded Event
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

// Initialize the application
function initializeApp() {
    checkAuthentication();
    setupEventListeners();
    loadInitialData();
}

// Check user authentication status
async function checkAuthentication() {
    try {
        const response = await fetch('/api/auth/status', {
            credentials: 'include'
        });
        
        if (response.ok) {
            const data = await response.json();
            currentUser = data.user;
            updateUIForUserRole();
        } else {
            redirectToLogin();
        }
    } catch (error) {
        console.error('Authentication check failed:', error);
        redirectToLogin();
    }
}

// Redirect to login page
function redirectToLogin() {
    window.location.href = '/login.html';
}

// Setup event listeners for UI interactions
function setupEventListeners() {
    // Portfolio management
    document.getElementById('addStockForm')?.addEventListener('submit', handleAddStock);
    document.getElementById('updateStockForm')?.addEventListener('submit', handleUpdateStock);
    document.getElementById('deleteStockBtn')?.addEventListener('click', handleDeleteStock);
    
    // Report filtering
    document.getElementById('reportFilter')?.addEventListener('change', filterReports);
    document.getElementById('dateRangeFilter')?.addEventListener('change', updateReports);
    
    // Navigation
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', handleNavigation);
    });
}

// Load initial data for the dashboard
async function loadInitialData() {
    try {
        await Promise.all([
            loadPortfolioData(),
            loadAdvisorySignals(),
            loadReportData()
        ]);
        
        updateDashboard();
    } catch (error) {
        console.error('Failed to load initial data:', error);
        showNotification('Error loading data. Please refresh the page.', 'error');
    }
}

// Load portfolio data from backend
async function loadPortfolioData() {
    try {
        const response = await fetch('/api/portfolio', {
            credentials: 'include'
        });
        
        if (response.ok) {
            portfolioData = await response.json();
            renderPortfolioTable(portfolioData);
            updatePortfolioSummary(portfolioData);
        } else {
            throw new Error('Failed to fetch portfolio data');
        }
    } catch (error) {
        console.error('Error loading portfolio data:', error);
        throw error;
    }
}

// Load advisory signals from backend
async function loadAdvisorySignals() {
    try {
        const response = await fetch('/api/advisory/signals', {
            credentials: 'include'
        });
        
        if (response.ok) {
            advisorySignals = await response.json();
            renderAdvisorySignals(advisorySignals);
        } else {
            throw new Error('Failed to fetch advisory signals');
        }
    } catch (error) {
        console.error('Error loading advisory signals:', error);
        throw error;
    }
}

// Load report data from backend
async function loadReportData() {
    try {
        const response = await fetch('/api/reports', {
            credentials: 'include'
        });
        
        if (response.ok) {
            reportData = await response.json();
            renderReports(reportData);
        } else {
            throw new Error('Failed to fetch report data');
        }
    } catch (error) {
        console.error('Error loading report data:', error);
        throw error;
    }
}

// Handle add stock form submission
async function handleAddStock(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const stockData = {
        symbol: formData.get('symbol'),
        name: formData.get('name'),
        quantity: parseInt(formData.get('quantity')),
        purchasePrice: parseFloat(formData.get('purchasePrice')),
        sector: formData.get('sector'),
        exchange: formData.get('exchange')
    };
    
    try {
        const response = await fetch('/api/portfolio', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            credentials: 'include',
            body: JSON.stringify(stockData)
        });
        
        if (response.ok) {
            showNotification('Stock added successfully!', 'success');
            event.target.reset();
            await loadPortfolioData();
        } else {
            throw new Error('Failed to add stock');
        }
    } catch (error) {
        console.error('Error adding stock:', error);
        showNotification('Error adding stock. Please try again.', 'error');
    }
}

// Handle update stock form submission
async function handleUpdateStock(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const stockId = formData.get('stockId');
    const updateData = {
        quantity: parseInt(formData.get('quantity')),
        currentPrice: parseFloat(formData.get('currentPrice'))
    };
    
    try {
        const response = await fetch(`/api/portfolio/${stockId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            credentials: 'include',
            body: JSON.stringify(updateData)
        });
        
        if (response.ok) {
            showNotification('Stock updated successfully!', 'success');
            await loadPortfolioData();
        } else {
            throw new Error('Failed to update stock');
        }
    } catch (error) {
        console.error('Error updating stock:', error);
        showNotification('Error updating stock. Please try again.', 'error');
    }
}

// Handle delete stock action
async function handleDeleteStock() {
    const stockId = document.getElementById('deleteStockId').value;
    
    if (!stockId) {
        showNotification('Please select a stock to delete', 'warning');
        return;
    }
    
    if (!confirm('Are you sure you want to delete this stock?')) {
        return;
    }
    
    try {
        const response = await fetch(`/api/portfolio/${stockId}`, {
            method: 'DELETE',
            credentials: 'include'
        });
        
        if (response.ok) {
            showNotification('Stock deleted successfully!', 'success');
            await loadPortfolioData();
        } else {
            throw new Error('Failed to delete stock');
        }
    } catch (error) {
        console.error('Error deleting stock:', error);
        showNotification('Error deleting stock. Please try again.', 'error');
    }
}

// Render portfolio table
function renderPortfolioTable(data) {
    const tableBody = document.getElementById('portfolioTableBody');
    if (!tableBody) return;
    
    tableBody.innerHTML = data.map(stock => `
        <tr>
            <td>${stock.symbol}</td>
            <td>${stock.name}</td>
            <td>${stock.quantity}</td>
            <td>₹${stock.purchasePrice.toFixed(2)}</td>
            <td>₹${stock.currentPrice.toFixed(2)}</td>
            <td>₹${(stock.quantity * stock.currentPrice).toFixed(2)}</td>
            <td>${calculateProfitLoss(stock)}</td>
            <td>${stock.sector}</td>
            <td>
                <button class="btn btn-sm btn-outline-primary" onclick="editStock('${stock.id}')">
                    Edit
                </button>
            </td>
        </tr>
    `).join('');
}

// Calculate profit/loss for a stock
function calculateProfitLoss(stock) {
    const profitLoss = (stock.currentPrice - stock.purchasePrice) * stock.quantity;
    const className = profitLoss >= 0 ? 'text-success' : 'text-danger';
    return `<span class="${className}">₹${profitLoss.toFixed(2)}</span>`;
}

// Update portfolio summary
function updatePortfolioSummary(data) {
    const totalValue = data.reduce((sum, stock) => sum + (stock.quantity * stock.currentPrice), 0);
    const totalInvestment = data.reduce((sum, stock) => sum + (stock.quantity * stock.purchasePrice), 0);
    const totalGainLoss = totalValue - totalInvestment;
    
    document.getElementById('totalPortfolioValue').textContent = `₹${totalValue.toFixed(2)}`;
    document.getElementById('totalGainLoss').textContent = `₹${totalGainLoss.toFixed(2)}`;
    document.getElementById('totalGainLoss').className = totalGainLoss >= 0 ? 'text-success' : 'text-danger';
}

// Render advisory signals
function renderAdvisorySignals(signals) {
    const container = document.getElementById('advisorySignalsContainer');
    if (!container) return;
    
    container.innerHTML = signals.map(signal => `
        <div class="card mb-3">
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-center">
                    <h5 class="card-title">${signal.symbol} - ${signal.companyName}</h5>
                    <span class="badge bg-${getSignalBadgeClass(signal.signal)}">
                        ${signal.signal}
                    </span>
                </div>
                <p class="card-text">${signal.reason}</p>
                <small class="text-muted">Last updated: ${new Date(signal.timestamp).toLocaleString()}</small>
            </div>
        </div>
    `).join('');
}

// Get CSS class for signal badge
function getSignalBadgeClass(signal) {
    const classes = {
        'BUY': 'success',
        'HOLD': 'warning',
        'SELL': 'danger'
    };
    return classes[signal] || 'secondary';
}

// Render reports
function renderReports(reports) {
    const container = document.getElementById('reportsContainer');
    if (!container) return;
    
    // Implement chart rendering using Chart.js or similar
    renderPerformanceCharts(reports.performance);
    renderSectorAllocationCharts(reports.sectorAllocation);
    renderSignalDistributionCharts(reports.signalDistribution);
}

// Render performance charts
function renderPerformanceCharts(performanceData) {
    // Implementation for performance charts
    const ctx = document.getElementById('performanceChart');
    if (ctx && window.Chart) {
        new Chart(ctx, {
            type: 'line',
            data: {
                labels: performanceData.dates,
                datasets: [{
                    label: 'Portfolio Value',
                    data: performanceData.values,
                    borderColor: 'rgb(75, 192, 192)',
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
}

// Render sector allocation charts
function renderSectorAllocationCharts(sectorData) {
    // Implementation for sector allocation charts
    const ctx = document.getElementById('sectorAllocationChart');
    if (ctx && window.Chart) {
        new Chart(ctx, {
            type: 'pie',
            data: {
                labels: sectorData.labels,
                datasets: [{
                    data: sectorData.values,
                    backgroundColor: [
                        'rgb(255, 99, 132)',
                        'rgb(54, 162, 235)',
                        'rgb(255, 205, 86)',
                        'rgb(75, 192, 192)',
                        'rgb(153, 102, 255)'
                    ]
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
}

// Render signal distribution charts
function renderSignalDistributionCharts(signalData) {
    // Implementation for signal distribution charts
    const ctx = document.getElementById('signalDistributionChart');
    if (ctx && window.Chart) {
        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: ['BUY', 'HOLD', 'SELL'],
                datasets: [{
                    label: 'Signal Distribution',
                    data: [signalData.buy, signalData.hold, signalData.sell],
                    backgroundColor: [
                        'rgb(75, 192, 192)',
                        'rgb(255, 205, 86)',
                        'rgb(255, 99, 132)'
                    ]
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Advisory Signal Distribution'
                    }
                }
            }
        });
    }
}

// Filter reports based on criteria
function filterReports() {
    const filterValue = document.getElementById('reportFilter').value;
    const filteredData = reportData.filter(report => 
        filterValue === 'all' || report.type === filterValue
    );
    renderReports({...reportData, performance: filteredData});
}

// Update reports based on date range
function updateReports() {
    const dateRange = document.getElementById('dateRangeFilter').value;
    // Implement date-based filtering logic
    loadReportDataWithDateRange(dateRange);
}

// Load report data with date range filter
async function loadReportDataWithDateRange(dateRange) {
    try {
        const response = await fetch(`/api/reports?dateRange=${dateRange}`, {
            credentials: 'include'
        });
        
        if (response.ok) {
            reportData = await response.json();
            renderReports(reportData);
        }
    } catch (error) {
        console.error('Error loading filtered reports:', error);
    }
}

// Handle navigation
function handleNavigation(event) {
    event.preventDefault();
    const targetId = event.target.getAttribute('data-target');
    showSection(targetId);
}

// Show specific section
function showSection(sectionId) {
    // Hide all sections
    document.querySelectorAll('.content-section').forEach(section => {
        section.classList.add('d-none');
    });
    
    // Show target section
    const targetSection = document.getElementById(sectionId);
    if (targetSection) {
        targetSection.classList.remove('d-none');
    }
    
    // Update active navigation
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
    });
    document.querySelector(`[data-target="${sectionId}"]`).classList.add('active');
}

// Update UI based on user role
function updateUIForUserRole() {
    if (currentUser && currentUser.role === 'advisor') {
        // Show advisor-only features
        document.querySelectorAll('.advisor-only').forEach(element => {
            element.classList.remove('d-none');
        });
    } else {
        // Hide advisor-only features
        document.querySelectorAll('.advisor-only').forEach(element => {
            element.classList.add('d-none');
        });
    }
}

// Show notification
function showNotification(message, type = 'info') {
    // Implementation for showing notifications
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show`;
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    const container = document.getElementById('notificationContainer');
    if (container) {
        container.appendChild(notification);
        
        // Auto remove after 5 seconds
        setTimeout(() => {
            notification.remove();
        }, 5000);
    }
}

// Edit stock function
function editStock(stockId) {
    const stock = portfolioData.find(s => s.id === stockId);
    if (stock) {
        document.getElementById('editStockId').value = stock.id;
        document.getElementById('editQuantity').value = stock.quantity;
        document.getElementById('editCurrentPrice').value = stock.currentPrice;
        
        // Show modal
        const editModal = new bootstrap.Modal(document.getElementById('editStockModal'));
        editModal.show();
    }
}

// Export functions for global access
window.editStock = editStock;
window.handleAddStock = handleAddStock;
window.handleUpdateStock = handleUpdateStock;
window.handleDeleteStock = handleDeleteStock;
window.filterReports = filterReports;
window.updateReports = updateReports;

// Responsive design helpers
function setupResponsiveBehavior() {
    // Handle window resize for responsive adjustments
    window.addEventListener('resize', debounce(() => {
        adjustLayoutForScreenSize();
    }, 250));
}

function adjustLayoutForScreenSize() {
    const width = window.innerWidth;
    const isMobile = width < 768;
    
    // Adjust layout elements based on screen size
    document.body.classList.toggle('mobile-view', isMobile);
}

// Debounce function for performance
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

// Initialize responsive behavior
setupResponsiveBehavior();