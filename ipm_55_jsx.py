import React, { useState, useEffect } from 'react';
import { 
  LineChart, Line, BarChart, Bar, PieChart, Pie, 
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer 
} from 'recharts';
import { 
  Box, Typography, Paper, Grid, Card, CardContent, 
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
  Chip, Alert, CircularProgress, Tabs, Tab, AppBar, Button, IconButton
} from '@mui/material';
import { 
  Refresh as RefreshIcon, 
  Settings as SettingsIcon,
  AccountBalance as PortfolioIcon,
  TrendingUp as SignalsIcon,
  Dashboard as DashboardIcon,
  ExitToApp as LogoutIcon
} from '@mui/icons-material';
import { useTheme } from '@mui/material/styles';

// Main Dashboard Component
const IPMDashboard = () => {
  const theme = useTheme();
  const [activeTab, setActiveTab] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [userData, setUserData] = useState(null);
  const [portfolioData, setPortfolioData] = useState([]);
  const [signalsData, setSignalsData] = useState([]);
  const [marketNews, setMarketNews] = useState([]);
  const [performanceData, setPerformanceData] = useState([]);
  const [assetAllocation, setAssetAllocation] = useState([]);

  // Mock authentication state - would come from context/Redux in real app
  const isAuthenticated = true;

  // Fetch data on component mount
  useEffect(() => {
    if (isAuthenticated) {
      fetchDashboardData();
    }
  }, [isAuthenticated]);

  const fetchDashboardData = async () => {
    setIsLoading(true);
    try {
      // In a real application, these would be API calls to your backend
      const [
        userResponse, 
        portfolioResponse, 
        signalsResponse, 
        newsResponse, 
        performanceResponse,
        allocationResponse
      ] = await Promise.all([
        fetch('/api/user/profile'),
        fetch('/api/portfolio/holdings'),
        fetch('/api/signals/latest'),
        fetch('/api/market/news'),
        fetch('/api/portfolio/performance'),
        fetch('/api/portfolio/allocation')
      ]);

      // Set state with fetched data
      setUserData(await userResponse.json());
      setPortfolioData(await portfolioResponse.json());
      setSignalsData(await signalsResponse.json());
      setMarketNews(await newsResponse.json());
      setPerformanceData(await performanceResponse.json());
      setAssetAllocation(await allocationResponse.json());
      
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleTabChange = (event, newValue) => {
    setActiveTab(newValue);
  };

  const handleLogout = () => {
    // Implement logout logic
    console.log('User logged out');
  };

  const handleRefresh = () => {
    fetchDashboardData();
  };

  const handleSettings = () => {
    // Navigate to settings page
    console.log('Navigate to settings');
  };

  if (!isAuthenticated) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="100vh">
        <Alert severity="warning">Please log in to access the dashboard</Alert>
      </Box>
    );
  }

  if (isLoading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="100vh">
        <CircularProgress />
        <Typography variant="h6" sx={{ ml: 2 }}>Loading Dashboard...</Typography>
      </Box>
    );
  }

  return (
    <Box sx={{ flexGrow: 1, padding: 3 }}>
      {/* Header */}
      <AppBar position="static" color="default" sx={{ mb: 3 }}>
        <Box display="flex" justifyContent="space-between" alignItems="center" p={2}>
          <Typography variant="h4" component="h1">
            Indian Portfolio Manager
          </Typography>
          <Box>
            <IconButton onClick={handleRefresh} sx={{ mr: 1 }}>
              <RefreshIcon />
            </IconButton>
            <IconButton onClick={handleSettings} sx={{ mr: 2 }}>
              <SettingsIcon />
            </IconButton>
            <Button 
              color="inherit" 
              onClick={handleLogout}
              startIcon={<LogoutIcon />}
            >
              Logout
            </Button>
          </Box>
        </Box>
      </AppBar>

      {/* Navigation Tabs */}
      <Box sx={{ borderBottom: 1, borderColor: 'divider', mb: 3 }}>
        <Tabs value={activeTab} onChange={handleTabChange}>
          <Tab icon={<DashboardIcon />} label="Dashboard" />
          <Tab icon={<PortfolioIcon />} label="Portfolio" />
          <Tab icon={<SignalsIcon />} label="Advisory Signals" />
        </Tabs>
      </Box>

      {/* Dashboard Content */}
      {activeTab === 0 && (
        <Grid container spacing={3}>
          {/* Portfolio Summary */}
          <Grid item xs={12} md={6}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Portfolio Summary
                </Typography>
                <Typography variant="h4" color="primary">
                  ₹{userData?.totalPortfolioValue?.toLocaleString('en-IN')}
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Total Value
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          {/* Recent Performance */}
          <Grid item xs={12} md={6}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Recent Performance
                </Typography>
                <ResponsiveContainer width="100%" height={200}>
                  <LineChart data={performanceData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" />
                    <YAxis />
                    <Tooltip />
                    <Line type="monotone" dataKey="value" stroke={theme.palette.primary.main} />
                  </LineChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </Grid>

          {/* Asset Allocation */}
          <Grid item xs={12} md={6}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Asset Allocation
                </Typography>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={assetAllocation}
                      dataKey="value"
                      nameKey="name"
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      fill={theme.palette.primary.main}
                      label
                    />
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </Grid>

          {/* Market News */}
          <Grid item xs={12} md={6}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Market News
                </Typography>
                <Box sx={{ maxHeight: 300, overflow: 'auto' }}>
                  {marketNews.map((news, index) => (
                    <Box key={index} sx={{ mb: 2, p: 1, borderBottom: '1px solid #eee' }}>
                      <Typography variant="subtitle2">{news.title}</Typography>
                      <Typography variant="body2" color="textSecondary">
                        {news.source} - {new Date(news.date).toLocaleDateString()}
                      </Typography>
                    </Box>
                  ))}
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}

      {/* Portfolio Tab */}
      {activeTab === 1 && (
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Portfolio Holdings
                </Typography>
                <TableContainer>
                  <Table>
                    <TableHead>
                      <TableRow>
                        <TableCell>Stock</TableCell>
                        <TableCell>Quantity</TableCell>
                        <TableCell>Avg. Price</TableCell>
                        <TableCell>Current Price</TableCell>
                        <TableCell>Value</TableCell>
                        <TableCell>Change</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {portfolioData.map((holding, index) => (
                        <TableRow key={index}>
                          <TableCell>{holding.symbol}</TableCell>
                          <TableCell>{holding.quantity}</TableCell>
                          <TableCell>₹{holding.avgPrice.toFixed(2)}</TableCell>
                          <TableCell>₹{holding.currentPrice.toFixed(2)}</TableCell>
                          <TableCell>₹{(holding.quantity * holding.currentPrice).toLocaleString('en-IN')}</TableCell>
                          <TableCell>
                            <Chip
                              label={`${holding.changePercent.toFixed(2)}%`}
                              color={holding.changePercent >= 0 ? 'success' : 'error'}
                              size="small"
                            />
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}

      {/* Signals Tab */}
      {activeTab === 2 && (
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" 
# Code truncated at 10000 characters