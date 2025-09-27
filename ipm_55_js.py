// ipm_55_js.py - Main JavaScript/Node.js application entry point
// This file serves as the main entry point for the IPM (Indian Portfolio Manager) application

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const mongoose = require('mongoose');
const config = require('./config/config');
const authRoutes = require('./routes/auth');
const portfolioRoutes = require('./routes/portfolio');
const signalsRoutes = require('./routes/signals');
const dashboardRoutes = require('./routes/dashboard');
const marketDataRoutes = require('./routes/marketData');
const { errorHandler } = require('./middleware/errorHandler');
const { authenticateToken } = require('./middleware/auth');

class IPMApplication {
    constructor() {
        this.app = express();
        this.setupMiddleware();
        this.setupRoutes();
        this.connectDatabase();
    }

    setupMiddleware() {
        // Security middleware
        this.app.use(helmet());
        
        // CORS configuration
        this.app.use(cors({
            origin: config.cors.origin,
            credentials: true
        }));
        
        // Rate limiting
        const limiter = rateLimit({
            windowMs: 15 * 60 * 1000, // 15 minutes
            max: 100 // limit each IP to 100 requests per windowMs
        });
        this.app.use(limiter);
        
        // Body parsing middleware
        this.app.use(express.json({ limit: '10mb' }));
        this.app.use(express.urlencoded({ extended: true }));
        
        // Static files
        this.app.use(express.static('public'));
    }

    setupRoutes() {
        // Public routes
        this.app.use('/api/auth', authRoutes);
        
        // Protected routes
        this.app.use('/api/portfolio', authenticateToken, portfolioRoutes);
        this.app.use('/api/signals', authenticateToken, signalsRoutes);
        this.app.use('/api/dashboard', authenticateToken, dashboardRoutes);
        this.app.use('/api/market-data', authenticateToken, marketDataRoutes);
        
        // Health check endpoint
        this.app.get('/health', (req, res) => {
            res.status(200).json({ 
                status: 'OK', 
                timestamp: new Date().toISOString(),
                uptime: process.uptime()
            });
        });
        
        // Error handling middleware (should be last)
        this.app.use(errorHandler);
    }

    async connectDatabase() {
        try {
            await mongoose.connect(config.database.uri, {
                useNewUrlParser: true,
                useUnifiedTopology: true,
                useCreateIndex: true,
                useFindAndModify: false
            });
            console.log('Connected to MongoDB successfully');
        } catch (error) {
            console.error('MongoDB connection error:', error);
            process.exit(1);
        }
    }

    startServer() {
        const PORT = config.server.port || 3000;
        this.server = this.app.listen(PORT, () => {
            console.log(`IPM Server running on port ${PORT}`);
            console.log(`Environment: ${config.env}`);
        });
    }

    async shutdown() {
        console.log('Shutting down server...');
        if (this.server) {
            this.server.close();
        }
        await mongoose.connection.close();
        console.log('Server shut down successfully');
    }
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
    const app = require('./app').appInstance;
    await app.shutdown();
    process.exit(0);
});

process.on('SIGTERM', async () => {
    const app = require('./app').appInstance;
    await app.shutdown();
    process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
    console.error('Uncaught Exception:', error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

module.exports = IPMApplication;

// Main execution
if (require.main === module) {
    const app = new IPMApplication();
    app.startServer();
    
    // Export for testing and other modules
    module.exports.appInstance = app;
}