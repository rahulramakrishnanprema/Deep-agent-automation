-- IPM-55: Portfolio Management System Database Schema
-- MVP for Indian Equity Portfolio Management with Advisory Signals

-- Drop existing tables to allow clean recreation
DROP TABLE IF EXISTS portfolio_holdings;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS market_data;
DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS sectors;
DROP TABLE IF EXISTS advisors;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS users;

-- Users table for authentication and access control
CREATE TABLE users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    user_type VARCHAR(20) CHECK(user_type IN ('advisor', 'client')) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Clients table extending users for client-specific information
CREATE TABLE clients (
    client_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone VARCHAR(15),
    risk_profile VARCHAR(20) CHECK(risk_profile IN ('conservative', 'moderate', 'aggressive')),
    investment_horizon VARCHAR(20) CHECK(investment_horizon IN ('short', 'medium', 'long')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Advisors table extending users for advisor-specific information
CREATE TABLE advisors (
    advisor_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    specialization VARCHAR(50),
    experience_years INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Sectors table for industry classification
CREATE TABLE sectors (
    sector_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sector_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    growth_potential_score DECIMAL(3,2) CHECK(growth_potential_score BETWEEN 0 AND 10),
    market_cap_billion DECIMAL(10,2),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stocks table with company information and sector classification
CREATE TABLE stocks (
    stock_id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol VARCHAR(20) NOT NULL UNIQUE,
    company_name VARCHAR(200) NOT NULL,
    sector_id INTEGER NOT NULL,
    current_price DECIMAL(10,2) NOT NULL,
    market_cap_billion DECIMAL(10,2),
    pe_ratio DECIMAL(8,2),
    dividend_yield DECIMAL(5,2),
    is_nifty50 BOOLEAN DEFAULT FALSE,
    is_sensex BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sector_id) REFERENCES sectors(sector_id)
);

-- Market data table for historical price and technical indicators
CREATE TABLE market_data (
    data_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER NOT NULL,
    date DATE NOT NULL,
    open_price DECIMAL(10,2),
    high_price DECIMAL(10,2),
    low_price DECIMAL(10,2),
    close_price DECIMAL(10,2) NOT NULL,
    volume BIGINT,
    sma_20 DECIMAL(10,2),  -- Simple Moving Average 20 days
    sma_50 DECIMAL(10,2),  -- Simple Moving Average 50 days
    rsi DECIMAL(5,2),      -- Relative Strength Index
    macd DECIMAL(8,4),     -- Moving Average Convergence Divergence
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE(stock_id, date)
);

-- Portfolios table for client investment portfolios
CREATE TABLE portfolios (
    portfolio_id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER NOT NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    total_value DECIMAL(12,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE
);

-- Portfolio holdings table for individual stock positions
CREATE TABLE portfolio_holdings (
    holding_id INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id INTEGER NOT NULL,
    stock_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    purchase_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    current_value DECIMAL(12,2),
    weight_percentage DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id)
);

-- Market buzz table for news and sentiment analysis
CREATE TABLE market_buzz (
    buzz_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER,
    sector_id INTEGER,
    news_headline TEXT NOT NULL,
    news_content TEXT,
    sentiment_score DECIMAL(3,2) CHECK(sentiment_score BETWEEN -1 AND 1),
    source VARCHAR(100),
    published_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    FOREIGN KEY (sector_id) REFERENCES sectors(sector_id)
);

-- Advisory signals table for Buy/Hold/Sell recommendations
CREATE TABLE advisory_signals (
    signal_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER NOT NULL,
    signal_type VARCHAR(10) CHECK(signal_type IN ('BUY', 'HOLD', 'SELL')) NOT NULL,
    confidence_score DECIMAL(3,2) CHECK(confidence_score BETWEEN 0 AND 1),
    rationale TEXT NOT NULL,
    technical_indicators JSON,  -- Stores multiple technical indicators
    sector_influence DECIMAL(3,2),
    market_sentiment DECIMAL(3,2),
    generated_by INTEGER NOT NULL,
    valid_until DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    FOREIGN KEY (generated_by) REFERENCES advisors(advisor_id)
);

-- Portfolio performance history table
CREATE TABLE portfolio_performance (
    performance_id INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id INTEGER NOT NULL,
    date DATE NOT NULL,
    total_value DECIMAL(12,2) NOT NULL,
    daily_return DECIMAL(8,4),
    cumulative_return DECIMAL(8,4),
    volatility DECIMAL(8,4),
    sharpe_ratio DECIMAL(8,4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    UNIQUE(portfolio_id, date)
);

-- Insert dummy data for sectors
INSERT INTO sectors (sector_name, description, growth_potential_score, market_cap_billion) VALUES
('Information Technology', 'Software services, IT consulting, and technology solutions', 8.5, 4500.00),
('Banking & Financial Services', 'Banks, NBFCs, insurance companies, and financial institutions', 7.8, 3800.00),
('Healthcare & Pharmaceuticals', 'Pharmaceutical companies, hospitals, and healthcare services', 8.2, 2200.00),
('Automobile', 'Automobile manufacturers and ancillary industries', 6.5, 1800.00),
('Fast Moving Consumer Goods', 'Consumer goods companies including food, beverages, and personal care', 7.2, 2500.00),
('Energy', 'Oil & gas, renewable energy, and power companies', 6.8, 1500.00),
('Infrastructure', 'Construction, engineering, and infrastructure development', 7.5, 1200.00);

-- Insert dummy data for stocks
INSERT INTO stocks (symbol, company_name, sector_id, current_price, market_cap_billion, pe_ratio, dividend_yield, is_nifty50, is_sensex) VALUES
('INFY', 'Infosys Limited', 1, 1850.50, 750.25, 28.5, 2.1, TRUE, TRUE),
('TCS', 'Tata Consultancy Services', 1, 3850.75, 1450.80, 30.2, 1.8, TRUE, TRUE),
('HDFCBANK', 'HDFC Bank Limited', 2, 1650.25, 950.50, 22.8, 1.2, TRUE, TRUE),
('ICICIBANK', 'ICICI Bank Limited', 2, 980.40, 680.30, 20.5, 1.5, TRUE, TRUE),
('RELIANCE', 'Reliance Industries Limited', 6, 2750.80, 1850.40, 25.6, 0.9, TRUE, TRUE),
('ITC', 'ITC Limited', 5, 430.25, 350.75, 23.4, 3.2, TRUE, TRUE),
('SBIN', 'State Bank of India', 2, 650.75, 550.60, 18.9, 2.1, TRUE, TRUE),
('HINDUNILVR', 'Hindustan Unilever Limited', 5, 2450.90, 580.40, 65.8, 1.5, TRUE, TRUE),
('SUNPHARMA', 'Sun Pharmaceutical Industries', 3, 1250.30, 320.25, 35.2, 1.1, TRUE, FALSE),
('MARUTI', 'Maruti Suzuki India Limited', 4, 9800.45, 290.80, 28.7, 1.0, TRUE, TRUE);

-- Insert dummy market data
INSERT INTO market_data (stock_id, date, open_price, high_price, low_price, close_price, volume, sma_20, sma_50, rsi, macd) VALUES
(1, '2024-01-15', 1830.00, 1865.00, 1825.00, 1850.50, 2500000, 1820.25, 1785.40, 62.5, 12.3456),
(2, '2024-01-15', 3820.00, 3880.00, 3810.00, 3850.75, 1800000, 3780.50, 3725.80, 65.2, 15.7890),
(3, '2024-01-15', 1635.00, 1665.00, 1628.00, 1650.25, 3200000, 1620.75, 1585.30, 58.8, 8.4567),
(1, '2024-01-14', 1815.00, 1840.00, 1805.00, 1830.00, 2200000, 1810.20, 1778.60, 60.2, 11.2345),
(2, '2024-01-14', 3805.00, 3840.00, 3795.00, 3820.00, 1650000, 3765.40, 3710.25, 63.5, 14.5678);

-- Insert dummy users
INSERT INTO users (username, email, password_hash, user_type, is_active) VALUES
('advisor1', 'advisor1@wealthmanager.com', 'hashed_password_1', 'advisor', TRUE),
('advisor2', 'advisor2@wealthmanager.com', 'hashed_password_2', 'advisor', TRUE),
('client1', 'client1@example.com', 'hashed_password_3', 'client', TRUE),
('client2', 'client2@example.com', 'hashed_password_4', 'client', TRUE);

-- Insert dummy advisors
INSERT INTO advisors (user_id, first_name, last_name, specialization, experience_years) VALUES
(1, 'Rajesh', 'Sharma', 'Equity Portfolio Management', 8),
(2, 'Priya', 'Patel', 'Technical Analysis', 5);

-- Insert dummy clients
INSERT INTO clients (user_id, first_name, last_name, phone, risk_profile, investment_horizon) VALUES
(3, 'Amit', 'Kumar', '+91-9876543210', 'moderate', 'medium'),
(4, 'Sneha', 'Singh', '+91-8765432109', 'conservative', 'long');

-- Insert dummy portfolios
INSERT INTO portfolios (client_id, portfolio_name, total_value) VALUES
(1, 'Growth Portfolio', 2500000.00),
(1, 'Dividend Portfolio', 1200000.00),
(2, 'Conservative Portfolio', 1800000.00);

-- Insert dummy portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, purchase_price, purchase_date, current_value, weight_percentage) VALUES
(1, 1, 100, 1750.00, '2024-01-01', 185050.00, 7.4),
(1, 3, 200, 1600.00, '2024-01-01', 330050.00, 13.2),
(1, 5, 50, 2700.00, '2024-01-01', 137540.00, 5.5),
(2, 6, 500, 420.00, '2024-01-01', 215125.00, 17.9),
(2, 8, 80, 2400.00, '2024-01-01', 196072.00, 16.3),
(3, 2, 30, 3800.00, '2024-01-01', 115522.50, 6.4),
(3, 4, 150, 950.00, '2024-01-01', 147060.00, 8.2);

-- Insert dummy market buzz
INSERT INTO market_buzz (stock_id, sector_id, news_headline, news_content, sentiment_score, source, published_date) VALUES
(1, 1, 'Infosys reports strong Q3 earnings', 'Infosys beat analyst expectations with 15% revenue growth...', 0.8, 'Economic Times', '2024-01-15 10:00:00'),
(5, 6, 'Reliance announces new renewable energy initiative', 'Reliance plans to invest $10B in green energy projects...', 0.7, 'Business Standard', '2024-01-15 09:30:00'),
(NULL, 2, 'RBI maintains repo rate at 6.5%', 'The Reserve Bank kept interest rates unchanged...', 0.5, 'Financial Express', '2024-01-15 11:00:00');

-- Insert dummy advisory signals
INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, rationale, technical_indicators, sector_influence, market_sentiment, generated_by, valid_until) VALUES
(1, 'BUY', 0.85, 'Strong technical indicators combined with positive sector outlook', '{"sma_20": 1820.25, "sma_50": 1785.40, "rsi": 62.5, "macd": 12.3456}', 0.8, 0.7, 1, '2024-01-31'),
(3, 'HOLD', 0.65, 'Stable performance but limited upside potential in short term', '{"sma_20": 1620.75, "sma_50": 1585.30, "rsi": 58.8, "macd": 8.4567}', 0.6, 0.5, 1, '2024-01-31'),
(5, 'SELL', 0.75, 'Overvalued with declining technical momentum', '{"sma_20": 2720.50, "sma_50": 2685.20, "rsi": 42.3, "macd": -5.6789}', 0.4, 0.3, 2, '2024-01-31');

-- Insert dummy portfolio performance data
INSERT INTO portfolio_performance (portfolio_id, date, total_value, daily_return, cumulative_return, volatility, sharpe_ratio) VALUES
(1, '2024-01-15', 2500000.00, 0.015, 0.125, 0.023, 1.85),
(1, '2024-01-14', 2462500.00, -0.008, 0.108, 0.022, 1.78),
(2, '2024-01-15', 1200000.00, 0.009, 0.085, 0.015, 1.45),
(3, '2024-01-15', 1800000.00, 0.006, 0.065, 0.012, 1.25);

-- Create indexes for performance optimization
CREATE INDEX idx_market_data_stock_date ON market_data(stock_id, date);
CREATE INDEX idx_portfolio_holdings_portfolio ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_advisory_signals_stock ON advisory_signals(stock_id);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_stocks_symbol ON stocks(symbol);

-- Create views for common queries

-- View for portfolio summary with client information
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    c.client_id,
    c.first_name || ' ' || c.last_name AS client_name,
    p.total_value,
    p.created_at,
    p.last_updated
FROM portfolios p
JOIN clients c ON p.client_id = c.client_id;

-- View for current advisory signals with stock details
CREATE VIEW current_advisory