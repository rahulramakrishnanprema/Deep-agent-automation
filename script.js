// script.js
// Main JavaScript file for the portfolio management dashboard
// Handles API calls, chart rendering, and UI interactions

// Global variables
let portfolioData = [];
let advisorySignals = [];
let performanceData = [];

// DOM Content Loaded Event
document.addEventListener('DOMContentLoaded', function() {
    initializeDashboard();
    loadPortfolioData();
    loadAdvisorySignals();
    loadPerformanceData();
});

// Initialize dashboard components
function initializeDashboard() {
    // Initialize tooltips
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });

    // Set up event listeners
    document.getElementById('refresh-btn').addEventListener('click', refreshData);
    document.getElementById('export-report-btn').addEventListener('click', exportReport);
}

// Load portfolio data from backend
async function loadPortfolioData() {
    try {
        const response = await fetch('/api/portfolio');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        portfolioData = await response.json();
        renderPortfolioTable(portfolioData);
        updatePortfolioSummary(portfolioData);
    } catch (error) {
        console.error('Error loading portfolio data:', error);
        showError('Failed to load portfolio data. Using demo data.');
        loadDemoPortfolioData();
    }
}

// Load advisory signals from backend
async function loadAdvisorySignals() {
    try {
        const response = await fetch('/api/advisory-signals');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        advisorySignals = await response.json();
        renderAdvisorySignals(advisorySignals);
        renderSignalDistributionChart(advisorySignals);
    } catch (error) {
        console.error('Error loading advisory signals:', error);
        showError('Failed to load advisory signals.');
    }
}

// Load performance data for charts
async function loadPerformanceData() {
    try {
        const response = await fetch('/api/performance');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        performanceData = await response.json();
        renderPerformanceChart(performanceData);
        renderSectorAllocationChart(performanceData);
    } catch (error) {
        console.error('Error loading performance data:', error);
        showError('Failed to load performance data.');
    }
}

// Render portfolio table
function renderPortfolioTable(data) {
    const tableBody = document.getElementById('portfolio-table-body');
    tableBody.innerHTML = '';

    data.forEach(holding => {
        const row = document.createElement('tr');
        
        row.innerHTML = `
            <td>${holding.symbol}</td>
            <td>${holding.company_name}</td>
            <td>${holding.quantity}</td>
            <td>₹${holding.average_price.toFixed(2)}</td>
            <td>₹${holding.current_price.toFixed(2)}</td>
            <td>₹${(holding.quantity * holding.current_price).toFixed(2)}</td>
            <td class="${getReturnClass(holding)}">${calculateReturn(holding)}%</td>
            <td><span class="badge ${getSignalBadgeClass(holding.signal)}">${holding.signal}</span></td>
        `;
        
        tableBody.appendChild(row);
    });
}

// Update portfolio summary
function updatePortfolioSummary(data) {
    const totalValue = data.reduce((sum, holding) => sum + (holding.quantity * holding.current_price), 0);
    const totalInvestment = data.reduce((sum, holding) => sum + (holding.quantity * holding.average_price), 0);
    const totalReturn = ((totalValue - totalInvestment) / totalInvestment) * 100;

    document.getElementById('total-value').textContent = `₹${totalValue.toFixed(2)}`;
    document.getElementById('total-investment').textContent = `₹${totalInvestment.toFixed(2)}`;
    document.getElementById('total-return').textContent = `${totalReturn.toFixed(2)}%`;
    document.getElementById('total-return').className = `fw-bold ${totalReturn >= 0 ? 'text-success' : 'text-danger'}`;
}

// Render advisory signals
function renderAdvisorySignals(signals) {
    const signalsContainer = document.getElementById('advisory-signals');
    signalsContainer.innerHTML = '';

    signals.forEach(signal => {
        const card = document.createElement('div');
        card.className = 'col-md-6 col-lg-4 mb-3';
        
        card.innerHTML = `
            <div class="card h-100">
                <div class="card-body">
                    <h6 class="card-title">${signal.symbol}</h6>
                    <span class="badge ${getSignalBadgeClass(signal.recommendation)} mb-2">${signal.recommendation}</span>
                    <p class="card-text small mb-1"><strong>Confidence:</strong> ${signal.confidence_score}%</p>
                    <p class="card-text small mb-1"><strong>Reason:</strong> ${signal.reason}</p>
                    <p class="card-text small text-muted">Updated: ${new Date(signal.timestamp).toLocaleDateString()}</p>
                </div>
            </div>
        `;
        
        signalsContainer.appendChild(card);
    });
}

// Render performance chart using Chart.js
function renderPerformanceChart(data) {
    const ctx = document.getElementById('performance-chart').getContext('2d');
    
    if (window.performanceChart) {
        window.performanceChart.destroy();
    }

    window.performanceChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: data.dates,
            datasets: [{
                label: 'Portfolio Value',
                data: data.values,
                borderColor: '#007bff',
                backgroundColor: 'rgba(0, 123, 255, 0.1)',
                fill: true,
                tension: 0.4
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
                    beginAtZero: false,
                    ticks: {
                        callback: function(value) {
                            return '₹' + value.toLocaleString();
                        }
                    }
                }
            }
        }
    });
}

// Render sector allocation chart
function renderSectorAllocationChart(data) {
    const ctx = document.getElementById('sector-chart').getContext('2d');
    
    if (window.sectorChart) {
        window.sectorChart.destroy();
    }

    window.sectorChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: data.sectors,
            datasets: [{
                data: data.allocations,
                backgroundColor: [
                    '#007bff', '#28a745', '#dc3545', '#ffc107', '#17a2b8',
                    '#6f42c1', '#e83e8c', '#fd7e14', '#20c997', '#6c757d'
                ]
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Sector Allocation'
                },
                legend: {
                    position: 'right'
                }
            }
        }
    });
}

// Render signal distribution chart
function renderSignalDistributionChart(signals) {
    const signalCounts = {
        'Buy': 0,
        'Hold': 0,
        'Sell': 0
    };

    signals.forEach(signal => {
        signalCounts[signal.recommendation]++;
    });

    const ctx = document.getElementById('signal-chart').getContext('2d');
    
    if (window.signalChart) {
        window.signalChart.destroy();
    }

    window.signalChart = new Chart(ctx, {
        type: 'pie',
        data: {
            labels: ['Buy', 'Hold', 'Sell'],
            datasets: [{
                data: [signalCounts.Buy, signalCounts.Hold, signalCounts.Sell],
                backgroundColor: ['#28a745', '#ffc107', '#dc3545']
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Signal Distribution'
                }
            }
        }
    });
}

// Helper functions
function calculateReturn(holding) {
    const investment = holding.quantity * holding.average_price;
    const currentValue = holding.quantity * holding.current_price;
    return (((currentValue - investment) / investment) * 100).toFixed(2);
}

function getReturnClass(holding) {
    const returnPercent = parseFloat(calculateReturn(holding));
    return returnPercent >= 0 ? 'text-success fw-bold' : 'text-danger fw-bold';
}

function getSignalBadgeClass(signal) {
    const signalClass = {
        'Buy': 'bg-success',
        'Hold': 'bg-warning',
        'Sell': 'bg-danger'
    };
    return signalClass[signal] || 'bg-secondary';
}

// Load demo data for fallback
function loadDemoPortfolioData() {
    portfolioData = [
        {
            symbol: 'RELIANCE',
            company_name: 'Reliance Industries Ltd',
            quantity: 50,
            average_price: 2450.75,
            current_price: 2680.50,
            signal: 'Buy'
        },
        {
            symbol: 'INFY',
            company_name: 'Infosys Ltd',
            quantity: 75,
            average_price: 1450.25,
            current_price: 1520.00,
            signal: 'Hold'
        },
        {
            symbol: 'HDFCBANK',
            company_name: 'HDFC Bank Ltd',
            quantity: 30,
            average_price: 1560.00,
            current_price: 1420.75,
            signal: 'Sell'
        }
    ];
    
    renderPortfolioTable(portfolioData);
    updatePortfolioSummary(portfolioData);
}

// Refresh all data
async function refreshData() {
    const refreshBtn = document.getElementById('refresh-btn');
    refreshBtn.disabled = true;
    refreshBtn.innerHTML = '<span class="spinner-border spinner-border-sm" role="status"></span> Refreshing...';

    try {
        await Promise.all([
            loadPortfolioData(),
            loadAdvisorySignals(),
            loadPerformanceData()
        ]);
        showSuccess('Data refreshed successfully');
    } catch (error) {
        console.error('Error refreshing data:', error);
        showError('Failed to refresh data');
    } finally {
        refreshBtn.disabled = false;
        refreshBtn.innerHTML = '<i class="bi bi-arrow-clockwise"></i> Refresh Data';
    }
}

// Export report functionality
async function exportReport() {
    try {
        const response = await fetch('/api/export-report', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (response.ok) {
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.style.display = 'none';
            a.href = url;
            a.download = 'portfolio-report.pdf';
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            showSuccess('Report exported successfully');
        } else {
            throw new Error('Export failed');
        }
    } catch (error) {
        console.error('Error exporting report:', error);
        showError('Failed to export report');
    }
}

// Notification functions
function showError(message) {
    showNotification(message, 'danger');
}

function showSuccess(message) {
    showNotification(message, 'success');
}

function showNotification(message, type) {
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
    notification.style.cssText = 'top: 20px; right: 20px; z-index: 1050; min-width: 300px;';
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        if (notification.parentNode) {
            notification.parentNode.removeChild(notification);
        }
    }, 5000);
}

// Responsive table handling
function handleResponsiveTables() {
    const tables = document.querySelectorAll('.table-responsive');
    tables.forEach(table => {
        if (table.scrollWidth > table.clientWidth) {
            table.classList.add('scrollable-table');
        }
    });
}

// Window resize handler
window.addEventListener('resize', function() {
    handleResponsiveTables();
    if (window.performanceChart) window.performanceChart.resize();
    if (window.sectorChart) window.sectorChart.resize();
    if (window.signalChart) window.signalChart.resize();
});

// Initialize responsive tables on load
setTimeout(handleResponsiveTables, 1000);