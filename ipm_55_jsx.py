import React, { useState, useEffect } from 'react';
import { useAuth } from './AuthContext';
import PortfolioDisplay from './PortfolioDisplay';
import AdvisorySignals from './AdvisorySignals';
import MarketVisualizations from './MarketVisualizations';
import Reports from './Reports';
import './Dashboard.css';

const Dashboard = () => {
  const { user, logout } = useAuth();
  const [activeTab, setActiveTab] = useState('portfolio');
  const [portfolioData, setPortfolioData] = useState(null);
  const [advisorySignals, setAdvisorySignals] = useState([]);
  const [marketData, setMarketData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem('authToken');
      
      // Fetch portfolio data
      const portfolioResponse = await fetch('/api/portfolio', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      
      if (!portfolioResponse.ok) {
        throw new Error('Failed to fetch portfolio data');
      }
      
      const portfolioData = await portfolioResponse.json();
      setPortfolioData(portfolioData);

      // Fetch advisory signals
      const signalsResponse = await fetch('/api/advisory/signals', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      
      if (!signalsResponse.ok) {
        throw new Error('Failed to fetch advisory signals');
      }
      
      const signalsData = await signalsResponse.json();
      setAdvisorySignals(signalsData);

      // Fetch market data
      const marketResponse = await fetch('/api/market/data', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      
      if (!marketResponse.ok) {
        throw new Error('Failed to fetch market data');
      }
      
      const marketData = await marketResponse.json();
      setMarketData(marketData);

      setLoading(false);
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  };

  const handleTabChange = (tabName) => {
    setActiveTab(tabName);
  };

  const handleRefresh = () => {
    fetchDashboardData();
  };

  if (loading) {
    return (
      <div className="dashboard-loading">
        <div className="loading-spinner"></div>
        <p>Loading dashboard data...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="dashboard-error">
        <h2>Error Loading Dashboard</h2>
        <p>{error}</p>
        <button onClick={handleRefresh} className="refresh-button">
          Try Again
        </button>
      </div>
    );
  }

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <div className="header-left">
          <h1>Portfolio Management Dashboard</h1>
          <p>Welcome back, {user?.name}</p>
        </div>
        <div className="header-right">
          <button onClick={handleRefresh} className="refresh-button">
            Refresh Data
          </button>
          <button onClick={logout} className="logout-button">
            Logout
          </button>
        </div>
      </header>

      <nav className="dashboard-nav">
        <button 
          className={`nav-button ${activeTab === 'portfolio' ? 'active' : ''}`}
          onClick={() => handleTabChange('portfolio')}
        >
          Portfolio
        </button>
        <button 
          className={`nav-button ${activeTab === 'signals' ? 'active' : ''}`}
          onClick={() => handleTabChange('signals')}
        >
          Advisory Signals
        </button>
        <button 
          className={`nav-button ${activeTab === 'market' ? 'active' : ''}`}
          onClick={() => handleTabChange('market')}
        >
          Market Data
        </button>
        <button 
          className={`nav-button ${activeTab === 'reports' ? 'active' : ''}`}
          onClick={() => handleTabChange('reports')}
        >
          Reports
        </button>
      </nav>

      <main className="dashboard-content">
        {activeTab === 'portfolio' && (
          <PortfolioDisplay 
            portfolioData={portfolioData} 
            marketData={marketData}
          />
        )}
        
        {activeTab === 'signals' && (
          <AdvisorySignals 
            signals={advisorySignals}
            portfolioData={portfolioData}
          />
        )}
        
        {activeTab === 'market' && (
          <MarketVisualizations 
            marketData={marketData}
          />
        )}
        
        {activeTab === 'reports' && (
          <Reports 
            portfolioData={portfolioData}
            signals={advisorySignals}
          />
        )}
      </main>

      <footer className="dashboard-footer">
        <p>Data as of {new Date().toLocaleDateString()} | 
           Last updated: {marketData?.lastUpdated || 'N/A'}</p>
      </footer>
    </div>
  );
};

export default Dashboard;