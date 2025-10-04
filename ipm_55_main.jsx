import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import Box from '@mui/material/Box';

// Components
import Navbar from './components/Navbar';
import Sidebar from './components/Sidebar';
import Dashboard from './pages/Dashboard';
import Portfolio from './pages/Portfolio';
import Analysis from './pages/Analysis';
import Reports from './pages/Reports';
import Login from './pages/Login';

// Services
import AuthService from './services/AuthService';
import PortfolioService from './services/PortfolioService';
import AnalysisService from './services/AnalysisService';

// Dummy data
import { dummyPortfolios, dummyHistoricalData, dummySectorData } from './data/dummyData';

// Theme
const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
    background: {
      default: '#f5f5f5',
    },
  },
  typography: {
    fontFamily: '"Roboto", "Helvetica", "Arial", sans-serif',
  },
});

function App() {
  const [user, setUser] = useState(null);
  const [portfolios, setPortfolios] = useState([]);
  const [selectedPortfolio, setSelectedPortfolio] = useState(null);
  const [analysisData, setAnalysisData] = useState(null);
  const [sidebarOpen, setSidebarOpen] = useState(false);

  // Check if user is logged in on component mount
  useEffect(() => {
    const loggedInUser = AuthService.getCurrentUser();
    if (loggedInUser) {
      setUser(loggedInUser);
      loadPortfolios();
    }
  }, []);

  // Load portfolios for the current user
  const loadPortfolios = async () => {
    try {
      const userPortfolios = await PortfolioService.getPortfolios();
      setPortfolios(userPortfolios);
      if (userPortfolios.length > 0) {
        setSelectedPortfolio(userPortfolios[0]);
      }
    } catch (error) {
      console.error('Failed to load portfolios:', error);
      // Fallback to dummy data
      setPortfolios(dummyPortfolios);
      setSelectedPortfolio(dummyPortfolios[0]);
    }
  };

  // Handle login
  const handleLogin = (userData) => {
    setUser(userData);
    loadPortfolios();
  };

  // Handle logout
  const handleLogout = () => {
    AuthService.logout();
    setUser(null);
    setPortfolios([]);
    setSelectedPortfolio(null);
    setAnalysisData(null);
  };

  // Handle portfolio selection
  const handlePortfolioSelect = (portfolio) => {
    setSelectedPortfolio(portfolio);
    // Load analysis data for selected portfolio
    loadAnalysisData(portfolio.id);
  };

  // Load analysis data for a portfolio
  const loadAnalysisData = async (portfolioId) => {
    try {
      const analysis = await AnalysisService.getPortfolioAnalysis(portfolioId);
      setAnalysisData(analysis);
    } catch (error) {
      console.error('Failed to load analysis data:', error);
      // Fallback to dummy analysis data
      setAnalysisData({
        historicalData: dummyHistoricalData,
        sectorAnalysis: dummySectorData,
        technicalIndicators: {
          rsi: 65,
          macd: 0.5,
          movingAverages: {
            shortTerm: 150,
            longTerm: 145
          }
        },
        marketSentiment: 'Bullish',
        advisorySignals: [
          { symbol: 'RELIANCE', signal: 'Buy', confidence: 0.8 },
          { symbol: 'TCS', signal: 'Hold', confidence: 0.6 },
          { symbol: 'HDFC', signal: 'Sell', confidence: 0.7 }
        ]
      });
    }
  };

  // Toggle sidebar
  const toggleSidebar = () => {
    setSidebarOpen(!sidebarOpen);
  };

  // Protected route component
  const ProtectedRoute = ({ children }) => {
    return user ? children : <Navigate to="/login" />;
  };

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Router>
        {user && (
          <>
            <Navbar user={user} onLogout={handleLogout} onMenuClick={toggleSidebar} />
            <Sidebar 
              open={sidebarOpen} 
              onClose={toggleSidebar}
              portfolios={portfolios}
              selectedPortfolio={selectedPortfolio}
              onPortfolioSelect={handlePortfolioSelect}
            />
          </>
        )}
        
        <Box component="main" sx={{ 
          flexGrow: 1, 
          p: 3, 
          marginLeft: user && sidebarOpen ? '240px' : 0,
          transition: theme.transitions.create(['margin'], {
            easing: theme.transitions.easing.sharp,
            duration: theme.transitions.duration.leavingScreen,
          }),
          ...(user && {
            marginLeft: 0,
          }),
        }}>
          <Routes>
            <Route 
              path="/login" 
              element={user ? <Navigate to="/dashboard" /> : <Login onLogin={handleLogin} />} 
            />
            <Route 
              path="/dashboard" 
              element={
                <ProtectedRoute>
                  <Dashboard 
                    portfolio={selectedPortfolio} 
                    analysisData={analysisData} 
                  />
                </ProtectedRoute>
              } 
            />
            <Route 
              path="/portfolio" 
              element={
                <ProtectedRoute>
                  <Portfolio 
                    portfolios={portfolios}
                    selectedPortfolio={selectedPortfolio}
                    onPortfolioSelect={handlePortfolioSelect}
                  />
                </ProtectedRoute>
              } 
            />
            <Route 
              path="/analysis" 
              element={
                <ProtectedRoute>
                  <Analysis 
                    portfolio={selectedPortfolio}
                    analysisData={analysisData}
                  />
                </ProtectedRoute>
              } 
            />
            <Route 
              path="/reports" 
              element={
                <ProtectedRoute>
                  <Reports 
                    portfolio={selectedPortfolio}
                    analysisData={analysisData}
                  />
                </ProtectedRoute>
              } 
            />
            <Route 
              path="/" 
              element={<Navigate to={user ? "/dashboard" : "/login"} />} 
            />
          </Routes>
        </Box>
      </Router>
    </ThemeProvider>
  );
}

export default App;