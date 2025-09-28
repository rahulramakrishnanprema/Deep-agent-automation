// ipm_55_main.js - Main application entry point for Indian Portfolio Manager MVP

class PortfolioManagerApp {
    constructor() {
        this.currentUser = null;
        this.portfolios = [];
        this.dummyData = new DummyDataStorage();
        this.technicalAnalyzer = new TechnicalAnalyzer();
        this.sentimentAnalyzer = new SentimentAnalyzer();
        this.visualizationEngine = new VisualizationEngine();
        this.init();
    }

    init() {
        this.initializeAuth();
        this.setupEventListeners();
        this.loadInitialData();
    }

    // User Authentication Methods
    initializeAuth() {
        this.auth = {
            login: (email, password, userType) => {
                const user = this.dummyData.authenticateUser(email, password, userType);
                if (user) {
                    this.currentUser = user;
                    this.onLoginSuccess();
                    return true;
                }
                return false;
            },
            
            logout: () => {
                this.currentUser = null;
                this.onLogout();
            },
            
            register: (userData) => {
                return this.dummyData.registerUser(userData);
            }
        };
    }

    // Portfolio Management
    createPortfolio(portfolioData) {
        const portfolio = {
            id: Date.now().toString(),
            name: portfolioData.name,
            owner: this.currentUser.id,
            holdings: portfolioData.holdings || [],
            createdAt: new Date(),
            ...portfolioData
        };
        
        this.portfolios.push(portfolio);
        this.dummyData.savePortfolio(portfolio);
        return portfolio;
    }

    getPortfolio(id) {
        return this.portfolios.find(p => p.id === id) || this.dummyData.getPortfolio(id);
    }

    updatePortfolioHoldings(portfolioId, holdings) {
        const portfolio = this.getPortfolio(portfolioId);
        if (portfolio && portfolio.owner === this.currentUser.id) {
            portfolio.holdings = holdings;
            portfolio.updatedAt = new Date();
            this.dummyData.updatePortfolio(portfolio);
            return portfolio;
        }
        return null;
    }

    // Advisory Signal Generation
    generateAdvisorySignals(portfolioId) {
        const portfolio = this.getPortfolio(portfolioId);
        if (!portfolio) return null;

        const signals = portfolio.holdings.map(holding => {
            const technicalSignals = this.technicalAnalyzer.calculateSignals(holding.symbol);
            const sentimentScore = this.sentimentAnalyzer.getMarketSentiment(holding.symbol);
            const sectorPotential = this.analyzeSectorPotential(holding.sector);
            
            return this.generateSignal(holding, technicalSignals, sentimentScore, sectorPotential);
        });

        return signals;
    }

    generateSignal(holding, technicalSignals, sentimentScore, sectorPotential) {
        let score = 0;
        
        // Technical analysis weight: 40%
        score += technicalSignals.rsi < 30 ? 40 : technicalSignals.rsi > 70 ? -40 : 0;
        score += technicalSignals.macd > 0 ? 20 : -20;
        
        // Sentiment weight: 30%
        score += sentimentScore * 30;
        
        // Sector potential weight: 30%
        score += sectorPotential * 30;
        
        let signal = 'HOLD';
        if (score >= 60) signal = 'BUY';
        if (score <= -60) signal = 'SELL';
        
        return {
            symbol: holding.symbol,
            name: holding.name,
            currentPrice: holding.currentPrice,
            signal,
            score,
            technicalSignals,
            sentimentScore,
            sectorPotential,
            timestamp: new Date()
        };
    }

    // Technical Analysis
    analyzeSectorPotential(sector) {
        const sectors = {
            'IT': 0.8,
            'Finance': 0.7,
            'Healthcare': 0.6,
            'Automobile': 0.5,
            'Energy': 0.4
        };
        return sectors[sector] || 0.5;
    }

    // Performance Analysis
    calculatePortfolioPerformance(portfolioId) {
        const portfolio = this.getPortfolio(portfolioId);
        if (!portfolio) return null;

        const performance = {
            totalValue: 0,
            totalInvestment: 0,
            dailyReturn: 0,
            weeklyReturn: 0,
            monthlyReturn: 0,
            annualReturn: 0,
            holdingsPerformance: []
        };

        portfolio.holdings.forEach(holding => {
            const holdingPerf = this.calculateHoldingPerformance(holding);
            performance.holdingsPerformance.push(holdingPerf);
            performance.totalValue += holdingPerf.currentValue;
            performance.totalInvestment += holdingPerf.investment;
        });

        performance.totalReturn = ((performance.totalValue - performance.totalInvestment) / performance.totalInvestment) * 100;
        
        return performance;
    }

    calculateHoldingPerformance(holding) {
        const currentValue = holding.quantity * holding.currentPrice;
        const investment = holding.quantity * holding.purchasePrice;
        const absoluteReturn = currentValue - investment;
        const percentageReturn = (absoluteReturn / investment) * 100;

        return {
            symbol: holding.symbol,
            currentValue,
            investment,
            absoluteReturn,
            percentageReturn,
            quantity: holding.quantity
        };
    }

    // Data Visualization
    renderPortfolioDashboard(portfolioId) {
        const portfolio = this.getPortfolio(portfolioId);
        const performance = this.calculatePortfolioPerformance(portfolioId);
        const signals = this.generateAdvisorySignals(portfolioId);

        this.visualizationEngine.renderDashboard({
            portfolio,
            performance,
            signals,
            user: this.currentUser
        });
    }

    // Event Handlers
    setupEventListeners() {
        // Would typically set up DOM event listeners here
        console.log('Event listeners setup complete');
    }

    onLoginSuccess() {
        this.loadUserPortfolios();
        this.renderPortfolioDashboard(this.portfolios[0]?.id);
    }

    onLogout() {
        this.portfolios = [];
        // Clear UI elements
    }

    loadInitialData() {
        this.dummyData.initialize();
    }

    loadUserPortfolios() {
        if (this.currentUser) {
            this.portfolios = this.dummyData.getUserPortfolios(this.currentUser.id);
        }
    }
}

// Dummy Data Storage Class
class DummyDataStorage {
    constructor() {
        this.users = [];
        this.portfolios = [];
        this.marketData = {};
        this.initialize();
    }

    initialize() {
        this.createDummyUsers();
        this.createDummyPortfolios();
        this.createDummyMarketData();
    }

    createDummyUsers() {
        this.users = [
            {
                id: 'user1',
                email: 'advisor@example.com',
                password: 'password123',
                type: 'advisor',
                name: 'Financial Advisor',
                clients: ['client1']
            },
            {
                id: 'client1',
                email: 'client@example.com',
                password: 'password123',
                type: 'client',
                name: 'John Doe',
                advisor: 'user1'
            }
        ];
    }

    createDummyPortfolios() {
        this.portfolios = [
            {
                id: 'portfolio1',
                name: 'Main Portfolio',
                owner: 'client1',
                holdings: [
                    {
                        symbol: 'RELIANCE',
                        name: 'Reliance Industries',
                        sector: 'Energy',
                        quantity: 10,
                        purchasePrice: 2500,
                        currentPrice: 2800,
                        purchaseDate: new Date('2023-01-15')
                    },
                    {
                        symbol: 'INFY',
                        name: 'Infosys',
                        sector: 'IT',
                        quantity: 20,
                        purchasePrice: 1500,
                        currentPrice: 1650,
                        purchaseDate: new Date('2023-02-20')
                    }
                ],
                createdAt: new Date('2023-01-01')
            }
        ];
    }

    createDummyMarketData() {
        this.marketData = {
            'RELIANCE': { price: 2800, rsi: 45, macd: 12.5 },
            'INFY': { price: 1650, rsi: 65, macd: -8.2 },
            'HDFC': { price: 1650, rsi: 72, macd: -5.1 },
            'TCS': { price: 3450, rsi: 38, macd: 15.3 }
        };
    }

    authenticateUser(email, password, userType) {
        return this.users.find(user => 
            user.email === email && 
            user.password === password && 
            user.type === userType
        );
    }

    registerUser(userData) {
        const newUser = {
            id: `user${this.users.length + 1}`,
            ...userData,
            createdAt: new Date()
        };
        this.users.push(newUser);
        return newUser;
    }

    savePortfolio(portfolio) {
        this.portfolios.push(portfolio);
    }

    getPortfolio(id) {
        return this.portfolios.find(p => p.id === id);
    }

    updatePortfolio(portfolio) {
        const index = this.portfolios.findIndex(p => p.id === portfolio.id);
        if (index !== -1) {
            this.portfolios[index] = portfolio;
        }
    }

    getUserPortfolios(userId) {
        return this.portfolios.filter(p => p.owner === userId);
    }

    getMarketData(symbol) {
        return this.marketData[symbol] || { price: 0, rsi: 50, macd: 0 };
    }
}

// Technical Analysis Class
class TechnicalAnalyzer {
    calculateSignals(symbol) {
        cons
# Code truncated at 10000 characters