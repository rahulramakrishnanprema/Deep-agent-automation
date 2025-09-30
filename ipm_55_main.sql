-- IPM-55: SQL Schema for Indian Equity Portfolio Management System
-- This file creates the database schema for the MVP web application
-- Includes tables for portfolio management, Indian equities, advisory signals, and advisor access control

-- Drop existing tables to ensure clean creation
DROP TABLE IF EXISTS portfolio_transactions;
DROP TABLE IF EXISTS portfolio_holdings;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS indian_equities;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS advisors;
DROP TABLE IF EXISTS users;

-- Users table for authentication system
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    user_type ENUM('advisor', 'client') NOT NULL DEFAULT 'client',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Advisors table for advisor-specific information
CREATE TABLE advisors (
    advisor_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    license_number VARCHAR(20) UNIQUE,
    specialization VARCHAR(100),
    experience_years INT,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_advisor_user (user_id)
);

-- Clients table for client information
CREATE TABLE clients (
    client_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    date_of_birth DATE,
    risk_profile ENUM('conservative', 'moderate', 'aggressive') DEFAULT 'moderate',
    investment_horizon ENUM('short_term', 'medium_term', 'long_term') DEFAULT 'medium_term',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_client_user (user_id)
);

-- Indian equities table with focus on Indian market data
CREATE TABLE indian_equities (
    equity_id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(100) NOT NULL,
    sector VARCHAR(50) NOT NULL,
    industry VARCHAR(50),
    market_cap DECIMAL(18,2) COMMENT 'Market capitalization in INR Crores',
    current_price DECIMAL(10,2) NOT NULL,
    previous_close DECIMAL(10,2),
    pe_ratio DECIMAL(8,2),
    pb_ratio DECIMAL(8,2),
    dividend_yield DECIMAL(5,2),
    beta DECIMAL(5,2),
    volatility DECIMAL(5,2),
    is_nifty50 BOOLEAN DEFAULT FALSE,
    is_sensex BOOLEAN DEFAULT FALSE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_symbol (symbol),
    INDEX idx_sector (sector),
    INDEX idx_market_cap (market_cap DESC)
);

-- Portfolios table for portfolio management functionality
CREATE TABLE portfolios (
    portfolio_id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    advisor_id INT NOT NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    total_value DECIMAL(15,2) DEFAULT 0.00,
    cash_balance DECIMAL(15,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    FOREIGN KEY (advisor_id) REFERENCES advisors(advisor_id) ON DELETE CASCADE,
    INDEX idx_portfolio_client (client_id),
    INDEX idx_portfolio_advisor (advisor_id)
);

-- Portfolio holdings table for storing equity positions
CREATE TABLE portfolio_holdings (
    holding_id INT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT NOT NULL,
    equity_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    average_buy_price DECIMAL(10,2) NOT NULL,
    current_value DECIMAL(15,2) DEFAULT 0.00,
    unrealized_pnl DECIMAL(15,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (equity_id) REFERENCES indian_equities(equity_id) ON DELETE CASCADE,
    UNIQUE KEY unique_portfolio_equity (portfolio_id, equity_id),
    INDEX idx_holding_portfolio (portfolio_id),
    INDEX idx_holding_equity (equity_id)
);

-- Portfolio transactions table for audit trail
CREATE TABLE portfolio_transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT NOT NULL,
    equity_id INT NOT NULL,
    transaction_type ENUM('BUY', 'SELL') NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    transaction_value DECIMAL(15,2) NOT NULL,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (equity_id) REFERENCES indian_equities(equity_id) ON DELETE CASCADE,
    INDEX idx_transaction_portfolio (portfolio_id),
    INDEX idx_transaction_date (transaction_date DESC),
    INDEX idx_transaction_type (transaction_type)
);

-- Advisory signals table for Buy/Hold/Sell recommendations
CREATE TABLE advisory_signals (
    signal_id INT AUTO_INCREMENT PRIMARY KEY,
    equity_id INT NOT NULL,
    advisor_id INT NOT NULL,
    signal_type ENUM('BUY', 'HOLD', 'SELL') NOT NULL,
    target_price DECIMAL(10,2),
    stop_loss DECIMAL(10,2),
    confidence_score DECIMAL(5,2) CHECK (confidence_score BETWEEN 0 AND 100),
    rationale TEXT NOT NULL,
    factors_considered JSON COMMENT 'JSON array of factors considered for the signal',
    signal_valid_until DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (equity_id) REFERENCES indian_equities(equity_id) ON DELETE CASCADE,
    FOREIGN KEY (advisor_id) REFERENCES advisors(advisor_id) ON DELETE CASCADE,
    INDEX idx_signal_equity (equity_id),
    INDEX idx_signal_advisor (advisor_id),
    INDEX idx_signal_type (signal_type),
    INDEX idx_signal_active (is_active, signal_valid_until)
);

-- Insert dummy data for Indian equities (focus on Indian market)
INSERT INTO indian_equities (symbol, company_name, sector, industry, market_cap, current_price, previous_close, pe_ratio, pb_ratio, dividend_yield, beta, volatility, is_nifty50, is_sensex) VALUES
('RELIANCE', 'Reliance Industries Limited', 'Energy', 'Oil & Gas', 1500000.00, 2750.50, 2720.75, 25.30, 2.10, 0.85, 1.25, 1.80, TRUE, TRUE),
('TCS', 'Tata Consultancy Services Limited', 'IT', 'Software', 1200000.00, 3250.25, 3225.50, 30.15, 8.50, 1.20, 0.95, 1.50, TRUE, TRUE),
('HDFCBANK', 'HDFC Bank Limited', 'Financial Services', 'Banking', 800000.00, 1450.75, 1435.25, 20.80, 3.20, 1.50, 1.10, 2.00, TRUE, TRUE),
('INFY', 'Infosys Limited', 'IT', 'Software', 600000.00, 1425.50, 1410.75, 25.60, 6.80, 2.10, 0.90, 1.40, TRUE, TRUE),
('ICICIBANK', 'ICICI Bank Limited', 'Financial Services', 'Banking', 450000.00, 925.25, 915.50, 18.90, 2.80, 1.80, 1.15, 2.20, TRUE, TRUE),
('SBIN', 'State Bank of India', 'Financial Services', 'Banking', 400000.00, 550.75, 545.25, 15.40, 1.60, 2.50, 1.30, 2.50, TRUE, TRUE),
('BHARTI', 'Bharti Airtel Limited', 'Telecom', 'Telecom Services', 350000.00, 825.50, 815.75, 22.10, 3.50, 0.70, 1.05, 1.90, TRUE, FALSE),
('LT', 'Larsen & Toubro Limited', 'Industrials', 'Construction', 300000.00, 2150.25, 2125.50, 28.70, 3.80, 1.10, 1.20, 2.10, TRUE, TRUE),
('HINDUNILVR', 'Hindustan Unilever Limited', 'Consumer Goods', 'FMCG', 280000.00, 2450.75, 2425.25, 60.80, 15.20, 1.80, 0.85, 1.30, TRUE, TRUE),
('ITC', 'ITC Limited', 'Consumer Goods', 'FMCG', 250000.00, 425.50, 420.75, 22.50, 4.80, 3.20, 1.10, 1.70, TRUE, TRUE);

-- Insert dummy users
INSERT INTO users (username, email, password_hash, user_type) VALUES
('advisor1', 'advisor1@example.com', 'hashed_password_1', 'advisor'),
('advisor2', 'advisor2@example.com', 'hashed_password_2', 'advisor'),
('client1', 'client1@example.com', 'hashed_password_3', 'client'),
('client2', 'client2@example.com', 'hashed_password_4', 'client');

-- Insert dummy advisors
INSERT INTO advisors (user_id, first_name, last_name, license_number, specialization, experience_years) VALUES
(1, 'Rajesh', 'Sharma', 'ADV123456', 'Equity Research', 8),
(2, 'Priya', 'Patel', 'ADV654321', 'Portfolio Management', 12);

-- Insert dummy clients
INSERT INTO clients (user_id, first_name, last_name, date_of_birth, risk_profile, investment_horizon) VALUES
(3, 'Amit', 'Kumar', '1980-05-15', 'moderate', 'long_term'),
(4, 'Sneha', 'Singh', '1975-12-20', 'conservative', 'medium_term');

-- Insert dummy portfolios
INSERT INTO portfolios (client_id, advisor_id, portfolio_name, description, total_value, cash_balance) VALUES
(1, 1, 'Growth Portfolio', 'Long-term growth focused portfolio', 500000.00, 50000.00),
(2, 2, 'Conservative Portfolio', 'Low risk income focused portfolio', 300000.00, 75000.00);

-- Insert dummy portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, equity_id, quantity, average_buy_price, current_value, unrealized_pnl) VALUES
(1, 1, 50, 2500.00, 137525.00, 12525.00),
(1, 2, 30, 3000.00, 97507.50, 7507.50),
(1, 3, 40, 1400.00, 58030.00, 2030.00),
(2, 4, 60, 1350.00, 85530.00, 1530.00),
(2, 5, 70, 900.00, 64767.50, 1767.50);

-- Insert dummy transactions
INSERT INTO portfolio_transactions (portfolio_id, equity_id, transaction_type, quantity, price, transaction_value, transaction_date) VALUES
(1, 1, 'BUY', 50, 2500.00, 125000.00, '2023-01-15 10:30:00'),
(1, 2, 'BUY', 30, 3000.00, 90000.00, '2023-02-20 11:15:00'),
(1, 3, 'BUY', 40, 1400.00, 56000.00, '2023-03-10 14:45:00'),
(2, 4, 'BUY', 60, 1350.00, 81000.00, '2023-04-05 09:30:00'),
(2, 5, 'BUY', 70, 900.00, 63000.00, '2023-05-12 13:20:00');

-- Insert dummy advisory signals
INSERT INTO advisory_signals (equity_id, advisor_id, signal_type, target_price, stop_loss, confidence_score, rationale, factors_considered, signal_valid_until) VALUES
(1, 1, 'BUY', 3000.00, 2500.00, 85.50, 'Strong fundamentals and growth potential in energy sector', '["PE Ratio", "Market Cap", "Sector Outlook"]', '2023-12-31'),
(2, 1, 'HOLD', 3400.00, 3000.00, 75.00, 'Stable performance but limited upside in current market', '["Revenue Growth", "Client Acquisitions", "IT Sector Trends"]', '2023-12-31'),
(3, 2, 'BUY', 1600.00, 1300.00, 90.00, 'Undervalued with strong banking fundamentals', '["NPA Ratio", "Credit Growth", "Interest Rates"]', '2023-12-31'),
(4, 2, 'SELL', 1300.00, 1500.00, 80.00, 'Valuation concerns and slowing growth in IT sector', '["Attrition Rate", "Client Concentration", "Currency Impact"]', '2023-12-31');

-- Create views for common reporting needs
CREATE VIEW portfolio_summary_view AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    c.first_name AS client_first_name,
    c.last_name AS client_last_name,
    a.first_name AS advisor_first_name,
    a.last_name AS advisor_last_name,
    p.total_value,
    p.cash_balance,
    COUNT(ph.holding_id) AS number_of_holdings,
    SUM(ph.current_value) AS equity_value,
    p.created_at
FROM portfolios p
JOIN clients c ON p.client_id = c.client_id
JOIN advisors a ON p.advisor_id = a.advisor_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
GROUP BY p.portfolio_id;

CREATE VIEW equity_signals_view AS
SELECT 
    e.symbol,
    e.company_name,
    e.sector,
    e.current_price,
    s.signal_type,
    s.target_price,
    s.stop_loss,
    s.confidence_score,
    s.rationale,
    adv.first_name AS advisor_first_name,
    adv.last_name AS advisor_last_name,
    s.created_at AS signal_date,
    s.signal_valid_until
FROM advisory_signals s
JOIN indian_equities e ON s.equity_id = e.equity_id
JOIN advisors adv ON s.advisor_id = adv.advisor_id
WHERE s.is_active = TRUE AND s.signal_valid_until >= CURDATE();

-- Create stored procedures for common operations
DELIMITER //

CREATE PROCEDURE update_portfolio_value(IN p_portfolio_id INT)
BEGIN
    DECLARE total_equity_value DECIMAL(15,2);
    
    SELECT COALESCE(SUM(ph.current_value), 0) INTO total_equity_value
    FROM portfolio_holdings ph
    WHERE ph.portfolio_id = p_portfolio_id;
    
    UPDATE portfolios 
    SET total_value = total_equity_value + cash_balance,
        updated_at = CURRENT_TIMESTAMP
    WHERE portfolio_id = p_portfolio_id;
END //

CREATE PROCEDURE get_client_portfolios(IN p_client_id INT)
BEGIN
    SELECT 
        p.portfolio_id,
        p.portfolio_name,
        p.description,
        p.total_value,
        p.cash_balance,
        a.first_name AS advisor_first_name,
        a.last_name AS advisor_last_name,
        p.created_at
    FROM portfolios p
    JOIN advisors a ON p.advisor_id = a.advisor_id
    WHERE p.client_id = p_client_id
    ORDER BY p.created_at DESC;
END //

CREATE PROCEDURE get_portfolio_performance(IN p_portfolio_id INT)
BEGIN
    SELECT 
        p.portfolio_id,
        p.portfolio_name,
        p.total_value,
        p.cash_balance,
        COUNT(ph.holding_id) AS number_of_holdings,
        SUM(ph.unrealized_pnl) AS total_unrealized_pnl,
        (SELECT SUM(transaction_value) 
         FROM portfolio_transactions 
         WHERE portfolio_id = p_portfolio_id AND transaction_type = 'BUY') AS total_investment
    FROM portfolios p
    LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
    WHERE p.portfolio_id = p_portfolio_id
    GROUP BY p.portfolio_id;
END //

DELIMITER ;

-- Create indexes for performance optimization
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX