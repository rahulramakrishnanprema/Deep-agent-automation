-- IPM-55: Database Schema for Indian Equity Portfolio Management System
-- This SQL file creates the database schema for an MVP web application managing client stock portfolios
-- Includes tables for user accounts, portfolios, holdings, market data, and advisory signals

-- Create database
CREATE DATABASE IF NOT EXISTS portfolio_management;
USE portfolio_management;

-- Users table for authentication and role-based access
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    user_role ENUM('advisor', 'client') DEFAULT 'client',
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Clients table extending users for client-specific information
CREATE TABLE clients (
    client_id INT PRIMARY KEY,
    risk_profile ENUM('conservative', 'moderate', 'aggressive'),
    investment_horizon INT, -- in years
    total_investment_value DECIMAL(15,2) DEFAULT 0.00,
    FOREIGN KEY (client_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Advisors table extending users for advisor-specific information
CREATE TABLE advisors (
    advisor_id INT PRIMARY KEY,
    specialization VARCHAR(100),
    experience_years INT,
    FOREIGN KEY (advisor_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Client-Advisor relationship table
CREATE TABLE client_advisor_relationship (
    relationship_id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    advisor_id INT NOT NULL,
    start_date DATE,
    end_date DATE NULL,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (client_id) REFERENCES clients(client_id),
    FOREIGN KEY (advisor_id) REFERENCES advisors(advisor_id),
    UNIQUE KEY unique_client_advisor (client_id, advisor_id)
);

-- Stocks master table for Indian equity securities
CREATE TABLE stocks (
    stock_id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector VARCHAR(100),
    industry VARCHAR(100),
    market_cap DECIMAL(18,2),
    listing_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolios table
CREATE TABLE portfolios (
    portfolio_id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_date DATE NOT NULL,
    total_value DECIMAL(15,2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (client_id) REFERENCES clients(client_id),
    INDEX idx_client_portfolio (client_id, portfolio_name)
);

-- Portfolio holdings table
CREATE TABLE portfolio_holdings (
    holding_id INT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT NOT NULL,
    stock_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    purchase_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    current_price DECIMAL(10,2),
    current_value DECIMAL(15,2) GENERATED ALWAYS AS (quantity * current_price) STORED,
    investment_value DECIMAL(15,2) GENERATED ALWAYS AS (quantity * purchase_price) STORED,
    unrealized_pnl DECIMAL(15,2) GENERATED ALWAYS AS (quantity * (current_price - purchase_price)) STORED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    INDEX idx_portfolio_stock (portfolio_id, stock_id)
);

-- Market data table for historical prices
CREATE TABLE market_data (
    data_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    date DATE NOT NULL,
    open_price DECIMAL(10,2),
    high_price DECIMAL(10,2),
    low_price DECIMAL(10,2),
    close_price DECIMAL(10,2),
    volume BIGINT,
    adjusted_close DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_stock_date (stock_id, date),
    INDEX idx_stock_date (stock_id, date)
);

-- Technical indicators table
CREATE TABLE technical_indicators (
    indicator_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    date DATE NOT NULL,
    moving_avg_50 DECIMAL(10,2),
    moving_avg_200 DECIMAL(10,2),
    rsi DECIMAL(5,2) CHECK (rsi BETWEEN 0 AND 100),
    macd DECIMAL(10,2),
    bollinger_upper DECIMAL(10,2),
    bollinger_lower DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_stock_indicator_date (stock_id, date),
    INDEX idx_stock_technical (stock_id, date)
);

-- Sector performance data
CREATE TABLE sector_performance (
    sector_id INT AUTO_INCREMENT PRIMARY KEY,
    sector_name VARCHAR(100) UNIQUE NOT NULL,
    performance_score DECIMAL(5,2) DEFAULT 0.00,
    growth_potential ENUM('low', 'medium', 'high'),
    last_updated DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Market sentiment/buzz data
CREATE TABLE market_sentiment (
    sentiment_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    sentiment_date DATE NOT NULL,
    sentiment_score DECIMAL(5,2) CHECK (sentiment_score BETWEEN -1 AND 1),
    news_count INT DEFAULT 0,
    social_mentions INT DEFAULT 0,
    source VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    INDEX idx_stock_sentiment (stock_id, sentiment_date)
);

-- Advisory signals table
CREATE TABLE advisory_signals (
    signal_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    portfolio_id INT NULL,
    holding_id INT NULL,
    signal_date DATE NOT NULL,
    signal_type ENUM('BUY', 'HOLD', 'SELL') NOT NULL,
    confidence_score DECIMAL(3,2) CHECK (confidence_score BETWEEN 0 AND 1),
    reasoning TEXT,
    -- Component scores
    historical_score DECIMAL(3,2),
    technical_score DECIMAL(3,2),
    sector_score DECIMAL(3,2),
    sentiment_score DECIMAL(3,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at DATE,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id),
    FOREIGN KEY (holding_id) REFERENCES portfolio_holdings(holding_id),
    INDEX idx_stock_signal (stock_id, signal_date),
    INDEX idx_portfolio_signal (portfolio_id, signal_date)
);

-- Advisor reports table for visual dashboards
CREATE TABLE advisor_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    advisor_id INT NOT NULL,
    report_name VARCHAR(200) NOT NULL,
    report_type ENUM('portfolio', 'sector', 'market', 'client') NOT NULL,
    report_data JSON, -- Stores chart configurations and data
    generated_date DATE NOT NULL,
    is_shared BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (advisor_id) REFERENCES advisors(advisor_id),
    INDEX idx_advisor_reports (advisor_id, generated_date)
);

-- Audit table for tracking changes
CREATE TABLE audit_log (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id INT,
    old_values JSON,
    new_values JSON,
    action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_audit_user (user_id, action_timestamp),
    INDEX idx_audit_table (table_name, action_timestamp)
);

-- Insert dummy data for demonstration
INSERT INTO users (username, email, password_hash, user_role, first_name, last_name) VALUES
('advisor1', 'advisor1@example.com', 'hashed_password_1', 'advisor', 'Rajesh', 'Sharma'),
('client1', 'client1@example.com', 'hashed_password_2', 'client', 'Priya', 'Patel'),
('client2', 'client2@example.com', 'hashed_password_3', 'client', 'Amit', 'Kumar');

INSERT INTO advisors (advisor_id, specialization, experience_years) VALUES
(1, 'Equity Portfolio Management', 8);

INSERT INTO clients (client_id, risk_profile, investment_horizon, total_investment_value) VALUES
(2, 'moderate', 5, 500000.00),
(3, 'aggressive', 10, 750000.00);

INSERT INTO client_advisor_relationship (client_id, advisor_id, start_date) VALUES
(2, 1, '2024-01-15'),
(3, 1, '2024-02-01');

INSERT INTO stocks (symbol, company_name, sector, industry, market_cap) VALUES
('RELIANCE', 'Reliance Industries Limited', 'Energy', 'Oil & Gas', 1500000000000.00),
('TCS', 'Tata Consultancy Services Limited', 'IT', 'Software', 1200000000000.00),
('HDFCBANK', 'HDFC Bank Limited', 'Financial Services', 'Banking', 800000000000.00),
('INFY', 'Infosys Limited', 'IT', 'Software', 700000000000.00),
('ICICIBANK', 'ICICI Bank Limited', 'Financial Services', 'Banking', 600000000000.00);

INSERT INTO portfolios (client_id, portfolio_name, description, created_date, total_value) VALUES
(2, 'Primary Portfolio', 'Main investment portfolio', '2024-01-20', 350000.00),
(2, 'Retirement Portfolio', 'Long-term retirement savings', '2024-01-25', 150000.00),
(3, 'Growth Portfolio', 'High-growth stock portfolio', '2024-02-05', 750000.00);

INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, purchase_price, purchase_date, current_price) VALUES
(1, 1, 100, 2500.00, '2024-01-20', 2600.00),
(1, 2, 50, 3500.00, '2024-01-21', 3700.00),
(2, 3, 75, 1500.00, '2024-01-25', 1600.00),
(3, 1, 200, 2450.00, '2024-02-05', 2600.00),
(3, 4, 100, 1400.00, '2024-02-10', 1500.00);

INSERT INTO market_data (stock_id, date, open_price, high_price, low_price, close_price, volume, adjusted_close) VALUES
(1, '2024-03-01', 2590.00, 2620.00, 2580.00, 2600.00, 1000000, 2600.00),
(2, '2024-03-01', 3680.00, 3720.00, 3660.00, 3700.00, 500000, 3700.00),
(3, '2024-03-01', 1590.00, 1610.00, 1580.00, 1600.00, 750000, 1600.00);

INSERT INTO technical_indicators (stock_id, date, moving_avg_50, moving_avg_200, rsi, macd) VALUES
(1, '2024-03-01', 2550.00, 2400.00, 65.50, 12.50),
(2, '2024-03-01', 3600.00, 3400.00, 70.20, 15.80),
(3, '2024-03-01', 1550.00, 1450.00, 58.30, 8.20);

INSERT INTO sector_performance (sector_name, performance_score, growth_potential, last_updated) VALUES
('IT', 85.50, 'high', '2024-03-01'),
('Financial Services', 72.30, 'medium', '2024-03-01'),
('Energy', 68.90, 'medium', '2024-03-01');

INSERT INTO market_sentiment (stock_id, sentiment_date, sentiment_score, news_count, social_mentions) VALUES
(1, '2024-03-01', 0.75, 25, 150),
(2, '2024-03-01', 0.82, 18, 120),
(3, '2024-03-01', 0.65, 12, 80);

INSERT INTO advisory_signals (stock_id, portfolio_id, holding_id, signal_date, signal_type, confidence_score, reasoning, historical_score, technical_score, sector_score, sentiment_score) VALUES
(1, 1, 1, '2024-03-01', 'BUY', 0.85, 'Strong technicals and positive sentiment', 0.80, 0.90, 0.75, 0.85),
(2, 1, 2, '2024-03-01', 'HOLD', 0.70, 'Good performance but overbought conditions', 0.85, 0.60, 0.80, 0.75),
(3, 2, 3, '2024-03-01', 'BUY', 0.78, 'Undervalued with strong sector outlook', 0.70, 0.75, 0.85, 0.70);

-- Create views for common queries
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    p.client_id,
    u.first_name,
    u.last_name,
    COUNT(ph.holding_id) as total_holdings,
    SUM(ph.current_value) as current_total_value,
    SUM(ph.investment_value) as total_investment,
    SUM(ph.unrealized_pnl) as total_unrealized_pnl
FROM portfolios p
JOIN clients c ON p.client_id = c.client_id
JOIN users u ON c.client_id = u.user_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
GROUP BY p.portfolio_id, p.portfolio_name, p.client_id, u.first_name, u.last_name;

CREATE VIEW advisor_client_portfolios AS
SELECT 
    a.advisor_id,
    ua.first_name as advisor_first_name,
    ua.last_name as advisor_last_name,
    c.client_id,
    uc.first_name as client_first_name,
    uc.last_name as client_last_name,
    p.portfolio_id,
    p.portfolio_name,
    p.total_value
FROM advisors a
JOIN client_advisor_relationship car ON a.advisor_id = car.advisor_id
JOIN clients c ON car.client_id = c.client_id
JOIN users ua ON a.advisor_id = ua.user_id
JOIN users uc ON c.client_id = uc.user_id
JOIN portfolios p ON c.client_id = p.client_id
WHERE car.is_active = TRUE AND p.is_active = TRUE;

-- Create stored procedures for common operations
DELIMITER //

CREATE PROCEDURE GetPortfolioHoldings(IN portfolio_id_param INT)
BEGIN
    SELECT 
        ph.holding_id,
        s.symbol,
        s.company_name,
        s.sector,
        ph.quantity,
        ph.purchase_price,
        ph.current_price,
        ph.current_value,
        ph.investment_value,
        ph.unrealized_pnl,
        ph.purchase_date
    FROM portfolio_holdings ph
    JOIN stocks s ON ph.stock_id = s.stock_id
    WHERE ph.portfolio_id = portfolio_id_param
    ORDER BY ph.current_value DESC;
END //

CREATE PROCEDURE GenerateAdvisorySignals(IN portfolio_id_param INT)
BEGIN
    -- This procedure would generate advisory signals based on multiple factors
    -- Simplified version for demonstration
    INSERT INTO advisory_signals (
        stock_id, portfolio_id, signal_date, signal_type, confidence_score,
        historical_score, technical_score, sector_score, sentiment_score,
        reasoning
    )
    SELECT 
        ph.stock_id,
        portfolio_id_param,
        CURDATE(),
        CASE 
            WHEN (ti.rsi < 30 AND ms.sentiment_score > 0.7) THEN 'BUY'
            WHEN (ti.rsi > 70 OR ms.sentiment_score < 0.3) THEN 'SELL'
            ELSE 'HOLD'
        END as signal_type,
        ROUND((COALESCE(ti.rsi, 50)/100 * 0.3 + COALESCE(ms.sentiment_score, 0.5) * 0.3 + 
               COALESCE(sp.performance_score, 50)/100 * 0.2 + 0.2)::DECIMAL(3,2), 2) as confidence_score,
        COALESCE(ti.rsi, 50)/100 as historical_score,
        CASE WHEN ti.rsi < 30 THEN 0.8 WHEN ti.rsi > 70 THEN 0.2 ELSE 0.5 END as technical_score,
        COALESCE(sp.performance_score, 50)/100 as sector_score,
        COALESCE(ms.sentiment_score, 