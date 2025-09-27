import React, { useState, useEffect } from 'react';
import { 
  LineChart, Line, BarChart, Bar, PieChart, Pie, 
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer 
} from 'recharts';
import { 
  Container, Row, Col, Card, CardBody, CardHeader, 
  Nav, NavItem, NavLink, TabContent, TabPane,
  Button, Alert, Spinner, Modal, ModalHeader, ModalBody, ModalFooter,
  Form, FormGroup, Label, Input, Table
} from 'reactstrap';
import './Dashboard.css';

const IPM_55_JSX = () => {
  const [activeTab, setActiveTab] = useState('portfolio');
  const [portfolioData, setPortfolioData] = useState([]);
  const [marketData, setMarketData] = useState([]);
  const [advisorySignals, setAdvisorySignals] = useState([]);
  const [newsData, setNewsData] = useState([]);
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(false);
  const [selectedStock, setSelectedStock] = useState(null);

  // Mock authentication context
  useEffect(() => {
    // Simulate user authentication
    const mockUser = {
      id: 1,
      name: 'Advisor User',
      role: 'advisor',
      email: 'advisor@example.com'
    };
    setUser(mockUser);
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      // Mock portfolio data
      const mockPortfolio = [
        { id: 1, symbol: 'RELIANCE', name: 'Reliance Industries', quantity: 100, avgPrice: 2500, currentPrice: 2650 },
        { id: 2, symbol: 'TCS', name: 'Tata Consultancy Services', quantity: 50, avgPrice: 3200, currentPrice: 3350 },
        { id: 3, symbol: 'HDFCBANK', name: 'HDFC Bank', quantity: 75, avgPrice: 1400, currentPrice: 1520 }
      ];

      // Mock market data
      const mockMarketData = [
        { name: 'RELIANCE', price: 2650, change: 6.0, volume: 2500000 },
        { name: 'TCS', price: 3350, change: 4.7, volume: 1800000 },
        { name: 'HDFCBANK', price: 1520, change: 8.6, volume: 3200000 },
        { name: 'INFY', price: 1850, change: 3.2, volume: 2100000 },
        { name: 'ICICIBANK', price: 950, change: 5.8, volume: 2800000 }
      ];

      // Mock advisory signals
      const mockSignals = [
        { symbol: 'RELIANCE', signal: 'BUY', confidence: 85, reasoning: 'Strong quarterly results and positive sector outlook' },
        { symbol: 'TCS', signal: 'HOLD', confidence: 78, reasoning: 'Stable performance but limited upside potential in short term' },
        { symbol: 'HDFCBANK', signal: 'BUY', confidence: 92, reasoning: 'Excellent asset quality and growth prospects' }
      ];

      // Mock news data
      const mockNews = [
        { id: 1, title: 'RBI maintains repo rate at 6.5%', source: 'Economic Times', timestamp: '2024-01-15T10:30:00' },
        { id: 2, title: 'Reliance announces new green energy initiative', source: 'Business Standard', timestamp: '2024-01-15T09:15:00' },
        { id: 3, title: 'IT sector shows strong Q3 results', source: 'Moneycontrol', timestamp: '2024-01-14T16:45:00' }
      ];

      setPortfolioData(mockPortfolio);
      setMarketData(mockMarketData);
      setAdvisorySignals(mockSignals);
      setNewsData(mockNews);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
      setLoading(false);
    }
  };

  const toggleModal = (stock = null) => {
    setSelectedStock(stock);
    setModal(!modal);
  };

  const handleTrade = (tradeData) => {
    // Handle trade execution logic
    console.log('Executing trade:', tradeData);
    toggleModal();
  };

  const calculatePortfolioValue = () => {
    return portfolioData.reduce((total, holding) => {
      return total + (holding.quantity * holding.currentPrice);
    }, 0);
  };

  const calculateUnrealizedGain = () => {
    return portfolioData.reduce((total, holding) => {
      const investment = holding.quantity * holding.avgPrice;
      const currentValue = holding.quantity * holding.currentPrice;
      return total + (currentValue - investment);
    }, 0);
  };

  if (loading) {
    return (
      <Container fluid className="dashboard-container">
        <div className="loading-spinner">
          <Spinner color="primary" />
          <p>Loading dashboard data...</p>
        </div>
      </Container>
    );
  }

  return (
    <Container fluid className="dashboard-container">
      {/* Header Section */}
      <Row className="dashboard-header">
        <Col md={6}>
          <h2>Indian Portfolio Manager</h2>
          <p>Welcome back, {user?.name}</p>
        </Col>
        <Col md={6} className="text-right">
          <Alert color="info" className="d-inline-block mr-3">
            Portfolio Value: ₹{calculatePortfolioValue().toLocaleString('en-IN')}
          </Alert>
          <Alert color="success" className="d-inline-block">
            Unrealized Gain: ₹{calculateUnrealizedGain().toLocaleString('en-IN')}
          </Alert>
        </Col>
      </Row>

      {/* Navigation Tabs */}
      <Nav tabs className="dashboard-tabs">
        <NavItem>
          <NavLink
            className={activeTab === 'portfolio' ? 'active' : ''}
            onClick={() => setActiveTab('portfolio')}
          >
            Portfolio
          </NavLink>
        </NavItem>
        <NavItem>
          <NavLink
            className={activeTab === 'market' ? 'active' : ''}
            onClick={() => setActiveTab('market')}
          >
            Market Data
          </NavLink>
        </NavItem>
        <NavItem>
          <NavLink
            className={activeTab === 'advisory' ? 'active' : ''}
            onClick={() => setActiveTab('advisory')}
          >
            Advisory Signals
          </NavLink>
        </NavItem>
        <NavItem>
          <NavLink
            className={activeTab === 'news' ? 'active' : ''}
            onClick={() => setActiveTab('news')}
          >
            News & Updates
          </NavLink>
        </NavItem>
      </Nav>

      <TabContent activeTab={activeTab} className="dashboard-content">
        
        {/* Portfolio Tab */}
        <TabPane tabId="portfolio">
          <Row>
            <Col md={8}>
              <Card>
                <CardHeader>
                  <h4>Portfolio Holdings</h4>
                </CardHeader>
                <CardBody>
                  <Table responsive>
                    <thead>
                      <tr>
                        <th>Symbol</th>
                        <th>Name</th>
                        <th>Quantity</th>
                        <th>Avg Price</th>
                        <th>Current Price</th>
                        <th>Value</th>
                        <th>Gain/Loss</th>
                        <th>Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {portfolioData.map(holding => (
                        <tr key={holding.id}>
                          <td>{holding.symbol}</td>
                          <td>{holding.name}</td>
                          <td>{holding.quantity}</td>
                          <td>₹{holding.avgPrice}</td>
                          <td>₹{holding.currentPrice}</td>
                          <td>₹{(holding.quantity * holding.currentPrice).toLocaleString('en-IN')}</td>
                          <td className={holding.currentPrice > holding.avgPrice ? 'text-success' : 'text-danger'}>
                            ₹{(holding.quantity * (holding.currentPrice - holding.avgPrice)).toLocaleString('en-IN')}
                          </td>
                          <td>
                            <Button color="primary" size="sm" onClick={() => toggleModal(holding)}>
                              Trade
                            </Button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                </CardBody>
              </Card>
            </Col>
            <Col md={4}>
              <Card>
                <CardHeader>
                  <h4>Portfolio Allocation</h4>
                </CardHeader>
                <CardBody>
                  <ResponsiveContainer width="100%" height={300}>
                    <PieChart>
                      <Pie
                        data={portfolioData.map(holding => ({
                          name: holding.symbol,
                          value: holding.quantity * holding.currentPrice
                        }))}
                        dataKey="value"
                        nameKey="name"
                        cx="50%"
                        cy="50%"
                        outerRadius={80}
                        fill="#8884d8"
                        label
                      />
                      <Tooltip formatter={(value) => [`₹${value.toLocaleString('en-IN')}`, 'Value']} />
                    </PieChart>
                  </ResponsiveContainer>
                </CardBody>
              </Card>
            </Col>
          </Row>
        </TabPane>

        {/* Market Data Tab */}
        <TabPane tabId="market">
          <Row>
            <Col md={12}>
              <Card>
                <CardHeader>
                  <h4>Indian Market Overview</h4>
                </CardHeader>
                <CardBody>
                  <ResponsiveContainer width="100%" height={400}>
                    <BarChart data={marketData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="name" />
                      <YAxis />
                      <Tooltip formatter={(value) => [`₹${value}`, 'Price']} />
                      <Legend />
                      <Bar dataKey="price" fill="#8884d8" name="Current Price" />
                      <Bar dataKey="volume" fill="#82ca9d" name="Volume" />
                    </BarChart>
                  </ResponsiveContainer>
                </CardBody>
              </Card>
            </Col>
          </Row>
        
# Code truncated at 10000 characters