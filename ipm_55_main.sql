-- IPM-55: SQL Schema for Indian Portfolio Management MVP
-- This file creates the database schema for storing portfolio data, Indian equity market information,
-- and supporting advisory signal generation and visualization reports.

-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS portfolio_holdings;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS equity_prices;
DROP TABLE IF EXISTS indian_equities;
DROP TABLE IF EXISTS sectors;

-- Create sectors table to categorize Indian equities
CREATE TABLE sectors (
    sector_id INT PRIMARY KEY AUTO_INCREMENT,
    sector_name VARCHAR(100) NOT NULL UNIQUE,
    sector_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create indian_equities table to store Indian stock information
CREATE TABLE indian_equities (
    equity_id INT PRIMARY KEY AUTO_INCREMENT,
    symbol VARCHAR(20) NOT NULL UNIQUE,
    company_name VARCHAR(200) NOT NULL,
    isin_code VARCHAR(12) NOT NULL UNIQUE,
    sector_id INT,
    market_cap DECIMAL(20,2) COMMENT 'Market capitalization in INR Crores',
    current_price DECIMAL(10,2) COMMENT 'Current price in INR',
    pe_ratio DECIMAL(10,2) COMMENT 'Price to Earnings ratio',
    pb_ratio DECIMAL(10,2) COMMENT 'Price to Book ratio',
    dividend_yield DECIMAL(5,2) COMMENT 'Dividend yield percentage',
    volatility DECIMAL(8,4) COMMENT 'Historical volatility measure',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (sector_id) REFERENCES sectors(sector_id) ON DELETE SET NULL,
    INDEX idx_symbol (symbol),
    INDEX idx_sector (sector_id),
    INDEX idx_market_cap (market_cap)
);

-- Create equity_prices table to store historical price data
CREATE TABLE equity_prices (
    price_id INT PRIMARY KEY AUTO_INCREMENT,
    equity_id INT NOT NULL,
    price_date DATE NOT NULL,
    open_price DECIMAL(10,2),
    high_price DECIMAL(10,2),
    low_price DECIMAL(10,2),
    close_price DECIMAL(10,2) NOT NULL,
    volume BIGINT COMMENT 'Trading volume',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (equity_id) REFERENCES indian_equities(equity_id) ON DELETE CASCADE,
    UNIQUE KEY unique_equity_date (equity_id, price_date),
    INDEX idx_price_date (price_date),
    INDEX idx_equity_date (equity_id, price_date)
);

-- Create advisory_signals table to store generated Buy/Hold/Sell recommendations
CREATE TABLE advisory_signals (
    signal_id INT PRIMARY KEY AUTO_INCREMENT,
    equity_id INT NOT NULL,
    signal_date DATE NOT NULL,
    recommendation ENUM('BUY', 'HOLD', 'SELL') NOT NULL,
    confidence_score DECIMAL(5,2) COMMENT 'Confidence score from 0-100',
    rationale TEXT COMMENT 'Explanation for the recommendation',
    technical_score DECIMAL(5,2) COMMENT 'Technical analysis score',
    fundamental_score DECIMAL(5,2) COMMENT 'Fundamental analysis score',
    sentiment_score DECIMAL(5,2) COMMENT 'Market sentiment score',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (equity_id) REFERENCES indian_equities(equity_id) ON DELETE CASCADE,
    INDEX idx_signal_date (signal_date),
    INDEX idx_recommendation (recommendation),
    INDEX idx_equity_signal (equity_id, signal_date)
);

-- Create clients table to store advisor client information
CREATE TABLE clients (
    client_id INT PRIMARY KEY AUTO_INCREMENT,
    client_name VARCHAR(200) NOT NULL,
    email VARCHAR(150) UNIQUE,
    phone VARCHAR(15),
    risk_profile ENUM('LOW', 'MEDIUM', 'HIGH', 'VERY_HIGH') DEFAULT 'MEDIUM',
    investment_horizon ENUM('SHORT', 'MEDIUM', 'LONG') DEFAULT 'MEDIUM',
    total_investment DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Total investment amount in INR',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_risk_profile (risk_profile),
    INDEX idx_investment_horizon (investment_horizon)
);

-- Create portfolios table to store client portfolio information
CREATE TABLE portfolios (
    portfolio_id INT PRIMARY KEY AUTO_INCREMENT,
    client_id INT NOT NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_date DATE NOT NULL,
    total_value DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Total portfolio value in INR',
    performance_ytd DECIMAL(8,4) COMMENT 'Year-to-date performance percentage',
    volatility DECIMAL(8,4) COMMENT 'Portfolio volatility measure',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    INDEX idx_client_id (client_id),
    INDEX idx_created_date (created_date)
);

-- Create portfolio_holdings table to store individual stock holdings within portfolios
CREATE TABLE portfolio_holdings (
    holding_id INT PRIMARY KEY AUTO_INCREMENT,
    portfolio_id INT NOT NULL,
    equity_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    purchase_price DECIMAL(10,2) NOT NULL COMMENT 'Purchase price per share in INR',
    purchase_date DATE NOT NULL,
    current_value DECIMAL(12,2) COMMENT 'Current value of holding in INR',
    weight_percentage DECIMAL(5,2) COMMENT 'Percentage weight in portfolio',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (equity_id) REFERENCES indian_equities(equity_id) ON DELETE CASCADE,
    UNIQUE KEY unique_portfolio_equity (portfolio_id, equity_id),
    INDEX idx_portfolio_id (portfolio_id),
    INDEX idx_equity_id (equity_id)
);

-- Insert sample sectors data
INSERT INTO sectors (sector_name, sector_description) VALUES
('Banking', 'Banking and financial services sector'),
('Information Technology', 'Software development and IT services'),
('Pharmaceuticals', 'Drug manufacturing and healthcare'),
('Automobile', 'Automobile manufacturing and components'),
('Energy', 'Oil, gas, and renewable energy companies'),
('FMCG', 'Fast-moving consumer goods'),
('Telecom', 'Telecommunication services'),
('Infrastructure', 'Construction and infrastructure development');

-- Insert sample Indian equities data
INSERT INTO indian_equities (symbol, company_name, isin_code, sector_id, market_cap, current_price, pe_ratio, pb_ratio, dividend_yield, volatility) VALUES
('RELIANCE', 'Reliance Industries Limited', 'INE002A01018', 5, 1500000.00, 2500.50, 25.30, 2.10, 0.80, 0.0156),
('INFY', 'Infosys Limited', 'INE009A01021', 2, 750000.00, 1750.25, 28.45, 8.75, 2.10, 0.0128),
('HDFCBANK', 'HDFC Bank Limited', 'INE040A01026', 1, 900000.00, 1650.75, 20.15, 3.20, 1.50, 0.0142),
('TCS', 'Tata Consultancy Services Limited', 'INE467B01029', 2, 1200000.00, 3200.00, 30.20, 12.50, 1.80, 0.0115),
('ITC', 'ITC Limited', 'INE154A01025', 6, 350000.00, 425.30, 22.80, 4.50, 3.20, 0.0138),
('SBIN', 'State Bank of India', 'INE062A01020', 1, 450000.00, 550.60, 15.40, 1.80, 2.50, 0.0167),
('SUNPHARMA', 'Sun Pharmaceutical Industries Ltd.', 'INE044A01036', 3, 250000.00, 980.45, 35.60, 3.80, 1.20, 0.0152),
('MARUTI', 'Maruti Suzuki India Limited', 'INE585B01010', 4, 300000.00, 8500.00, 28.90, 4.20, 0.90, 0.0149),
('BHARTIARTL', 'Bharti Airtel Limited', 'INE397D01024', 7, 400000.00, 720.80, 18.30, 2.90, 1.10, 0.0163),
('LT', 'Larsen & Toubro Limited', 'INE018A01030', 8, 280000.00, 1950.25, 22.10, 3.40, 1.80, 0.0158);

-- Insert sample equity prices data
INSERT INTO equity_prices (equity_id, price_date, open_price, high_price, low_price, close_price, volume) VALUES
(1, '2024-01-15', 2480.00, 2520.00, 2475.00, 2500.50, 2500000),
(2, '2024-01-15', 1730.00, 1760.00, 1725.00, 1750.25, 1800000),
(3, '2024-01-15', 1635.00, 1665.00, 1620.00, 1650.75, 2200000),
(1, '2024-01-14', 2470.00, 2490.00, 2455.00, 2480.00, 2300000),
(2, '2024-01-14', 1715.00, 1740.00, 1700.00, 1730.00, 1600000);

-- Insert sample advisory signals data
INSERT INTO advisory_signals (equity_id, signal_date, recommendation, confidence_score, rationale, technical_score, fundamental_score, sentiment_score) VALUES
(1, '2024-01-15', 'BUY', 85.50, 'Strong fundamentals with positive technical indicators', 82.00, 88.00, 79.50),
(2, '2024-01-15', 'HOLD', 72.30, 'Stable performance but limited upside potential', 68.50, 75.00, 74.00),
(3, '2024-01-15', 'BUY', 91.20, 'Excellent financials and positive market sentiment', 89.50, 93.00, 90.50),
(4, '2024-01-15', 'SELL', 65.80, 'High valuation concerns and technical weakness', 62.00, 68.00, 67.50),
(5, '2024-01-15', 'HOLD', 78.90, 'Defensive stock with steady dividends', 75.00, 82.00, 76.50);

-- Insert sample clients data
INSERT INTO clients (client_name, email, phone, risk_profile, investment_horizon, total_investment) VALUES
('Rajesh Sharma', 'rajesh.sharma@email.com', '9876543210', 'MEDIUM', 'LONG', 500000.00),
('Priya Patel', 'priya.patel@email.com', '8765432109', 'LOW', 'MEDIUM', 250000.00),
('Amit Kumar', 'amit.kumar@email.com', '7654321098', 'HIGH', 'SHORT', 750000.00),
('Sneha Desai', 'sneha.desai@email.com', '6543210987', 'MEDIUM', 'LONG', 1000000.00);

-- Insert sample portfolios data
INSERT INTO portfolios (client_id, portfolio_name, description, created_date, total_value, performance_ytd, volatility) VALUES
(1, 'Growth Portfolio', 'Long-term growth focused portfolio', '2023-01-15', 500000.00, 12.50, 0.0142),
(1, 'Dividend Portfolio', 'Income generating portfolio', '2023-03-20', 250000.00, 8.20, 0.0098),
(2, 'Conservative Portfolio', 'Low risk investment portfolio', '2023-02-10', 250000.00, 6.80, 0.0075),
(3, 'Aggressive Portfolio', 'High risk high return portfolio', '2023-04-05', 750000.00, 18.20, 0.0215);

-- Insert sample portfolio holdings data
INSERT INTO portfolio_holdings (portfolio_id, equity_id, quantity, purchase_price, purchase_date, current_value, weight_percentage) VALUES
(1, 1, 100, 2400.00, '2023-01-15', 250050.00, 50.01),
(1, 2, 100, 1700.00, '2023-01-15', 175025.00, 35.01),
(1, 3, 50, 1600.00, '2023-01-15', 82537.50, 16.51),
(2, 5, 200, 400.00, '2023-03-20', 85060.00, 34.02),
(2, 6, 300, 500.00, '2023-03-20', 165180.00, 66.07);

-- Create views for common queries

-- View for portfolio performance summary
CREATE VIEW portfolio_performance_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    c.client_name,
    p.total_value,
    p.performance_ytd,
    p.volatility,
    COUNT(ph.holding_id) as number_of_holdings,
    MAX(ph.updated_at) as last_updated
FROM portfolios p
JOIN clients c ON p.client_id = c.client_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
GROUP BY p.portfolio_id, p.portfolio_name, c.client_name, p.total_value, p.performance_ytd, p.volatility;

-- View for equity signals with company details
CREATE VIEW equity_signals_with_details AS
SELECT 
    s.signal_id,
    e.equity_id,
    e.symbol,
    e.company_name,
    sec.sector_name,
    s.signal_date,
    s.recommendation,
    s.confidence_score,
    s.rationale,
    s.technical_score,
    s.fundamental_score,
    s.sentiment_score,
    e.current_price,
    e.pe_ratio,
    e.pb_ratio,
    e.dividend_yield
FROM advisory_signals s
JOIN indian_equities e ON s.equity_id = e.equity_id
LEFT JOIN sectors sec ON e.sector_id = sec.sector_id;

-- View for portfolio holdings with current values
CREATE VIEW portfolio_holdings_details AS
SELECT 
    ph.holding_id,
    p.portfolio_id,
    p.portfolio_name,
    c.client_name,
    e.equity_id,
    e.symbol,
    e.company_name,
    ph.quantity,
    ph.purchase_price,
    ph.purchase_date,
    e.current_price as current_market_price,
    ph.current_value,
    ph.weight_percentage,
    (e.current_price - ph.purchase_price) * ph.quantity as unrealized_gain_loss,
    ((e.current_price - ph.purchase_price) / ph.purchase_price) * 100 as gain_loss_percentage
FROM portfolio_holdings ph
JOIN portfolios p ON ph.portfolio_id = p.portfolio_id
JOIN clients c ON p.client_id = c.client_id
JOIN indian_equities e ON ph.equity_id = e.equity_id;

-- Create stored procedures for common operations

-- Procedure to update portfolio total value
DELIMITER //
CREATE PROCEDURE UpdatePortfolioValue(IN portfolio_id_param INT)
BEGIN
    UPDATE portfolios p
    SET p.total_value = (
        SELECT COALESCE(SUM(ph.current_value), 0)
        FROM portfolio_holdings ph
        WHERE ph.portfolio_id = portfolio_id_param
    ),
    p.updated_at = CURRENT_TIMESTAMP
    WHERE p.portfolio_id = portfolio_id_param;
END //
DELIMITER ;

-- Procedure to get client portfolio summary
DELIMITER //
CREATE PROCEDURE GetClientPortfolioSummary(IN client_id_param INT)
BEGIN
    SELECT 
        c.client_id,
        c.client_name,
        c.risk_profile,
        c.total_investment,
        COUNT(p.portfolio_id) as number_of_portfolios,
        SUM(p.total_value) as total_portfolio_value,
        AVG(p.performance_ytd) as avg_performance
    FROM clients c
    LEFT JOIN portfolios p ON c.client_id = p.client_id
    WHERE c.client_id = client_id_param
    GROUP BY c.client_id, c.client_name, c.risk_profile, c.total_investment;
END //
DELIMITER ;

-- Procedure to get equity recommendations by sector
DELIMITER //
CREATE PROCEDURE GetRecommendationsBySector(IN signal_date_param DATE)
BEGIN
    SELECT 
        sec.sector_name,
        s.recommendation,
        COUNT(*) as count,
        AVG(s.confidence_score) as avg_confidence
    FROM advisory_signals s