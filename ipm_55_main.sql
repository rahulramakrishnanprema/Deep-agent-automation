-- IPM-55: Portfolio Management System Database Schema
-- This SQL file creates the database schema for an Indian equity portfolio management system
-- It supports advisor role-based access, portfolio storage, and advisory signal generation

-- Drop existing tables to ensure clean creation
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS holdings;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS equities;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS roles;

-- Create roles table for role-based access control
CREATE TABLE roles (
    role_id INT PRIMARY KEY AUTO_INCREMENT,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create users table with role-based access
CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role_id INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE RESTRICT
);

-- Create equities table for Indian market stocks
CREATE TABLE equities (
    equity_id INT PRIMARY KEY AUTO_INCREMENT,
    symbol VARCHAR(20) NOT NULL UNIQUE,
    company_name VARCHAR(255) NOT NULL,
    sector VARCHAR(100),
    industry VARCHAR(100),
    exchange VARCHAR(50) DEFAULT 'NSE',
    current_price DECIMAL(15,2) DEFAULT 0.00,
    previous_close DECIMAL(15,2) DEFAULT 0.00,
    market_cap DECIMAL(20,2) DEFAULT 0.00,
    volume BIGINT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create portfolios table for client portfolios
CREATE TABLE portfolios (
    portfolio_id INT PRIMARY KEY AUTO_INCREMENT,
    portfolio_name VARCHAR(255) NOT NULL,
    client_name VARCHAR(255) NOT NULL,
    advisor_id INT NOT NULL,
    total_value DECIMAL(15,2) DEFAULT 0.00,
    cash_balance DECIMAL(15,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (advisor_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Create holdings table for portfolio equity positions
CREATE TABLE holdings (
    holding_id INT PRIMARY KEY AUTO_INCREMENT,
    portfolio_id INT NOT NULL,
    equity_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    average_cost DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    current_value DECIMAL(15,2) DEFAULT 0.00,
    unrealized_pnl DECIMAL(15,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (equity_id) REFERENCES equities(equity_id) ON DELETE CASCADE,
    UNIQUE KEY unique_portfolio_equity (portfolio_id, equity_id)
);

-- Create transactions table for trade history
CREATE TABLE transactions (
    transaction_id INT PRIMARY KEY AUTO_INCREMENT,
    portfolio_id INT NOT NULL,
    equity_id INT NOT NULL,
    transaction_type ENUM('BUY', 'SELL') NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(15,2) NOT NULL,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (equity_id) REFERENCES equities(equity_id) ON DELETE CASCADE
);

-- Create advisory_signals table for AI-generated recommendations
CREATE TABLE advisory_signals (
    signal_id INT PRIMARY KEY AUTO_INCREMENT,
    equity_id INT NOT NULL,
    signal_type ENUM('BUY', 'SELL', 'HOLD') NOT NULL,
    confidence_score DECIMAL(5,2) DEFAULT 0.00,
    rationale TEXT,
    technical_indicators JSON,
    target_price DECIMAL(15,2),
    stop_loss DECIMAL(15,2),
    time_horizon VARCHAR(50),
    generated_by INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (equity_id) REFERENCES equities(equity_id) ON DELETE CASCADE,
    FOREIGN KEY (generated_by) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Insert default roles
INSERT INTO roles (role_name, description) VALUES
('ADMIN', 'System administrator with full access'),
('ADVISOR', 'Financial advisor with portfolio management access'),
('CLIENT', 'Client with read-only access to own portfolio');

-- Insert sample advisor users
INSERT INTO users (username, email, password_hash, first_name, last_name, role_id) VALUES
('advisor1', 'advisor1@example.com', '$2b$10$examplehash', 'Rajesh', 'Sharma', 2),
('advisor2', 'advisor2@example.com', '$2b$10$examplehash', 'Priya', 'Patel', 2);

-- Insert sample Indian equities
INSERT INTO equities (symbol, company_name, sector, industry, current_price, previous_close) VALUES
('RELIANCE', 'Reliance Industries Limited', 'Energy', 'Oil & Gas', 2850.50, 2800.75),
('TCS', 'Tata Consultancy Services Limited', 'IT', 'Software', 3850.25, 3800.50),
('HDFCBANK', 'HDFC Bank Limited', 'Financial Services', 'Banking', 1650.75, 1625.25),
('INFY', 'Infosys Limited', 'IT', 'Software', 1750.30, 1725.80),
('ICICIBANK', 'ICICI Bank Limited', 'Financial Services', 'Banking', 1125.40, 1100.60),
('HINDUNILVR', 'Hindustan Unilever Limited', 'FMCG', 'Consumer Goods', 2650.90, 2600.45),
('SBIN', 'State Bank of India', 'Financial Services', 'Banking', 780.35, 765.20),
('BAJFINANCE', 'Bajaj Finance Limited', 'Financial Services', 'NBFC', 7850.60, 7800.25),
('BHARTIARTL', 'Bharti Airtel Limited', 'Telecom', 'Telecommunications', 1125.80, 1100.45),
('KOTAKBANK', 'Kotak Mahindra Bank Limited', 'Financial Services', 'Banking', 1980.70, 1950.25);

-- Insert sample portfolios
INSERT INTO portfolios (portfolio_name, client_name, advisor_id, total_value, cash_balance) VALUES
('Retirement Portfolio', 'Amit Kumar', 1, 1250000.00, 150000.00),
('Growth Portfolio', 'Neha Singh', 1, 850000.00, 75000.00),
('Conservative Portfolio', 'Vikram Mehta', 2, 950000.00, 120000.00);

-- Insert sample holdings
INSERT INTO holdings (portfolio_id, equity_id, quantity, average_cost, current_value, unrealized_pnl) VALUES
(1, 1, 100, 2500.00, 285050.00, 35050.00),
(1, 2, 50, 3500.00, 192512.50, 17512.50),
(1, 3, 200, 1500.00, 330150.00, 30150.00),
(2, 4, 150, 1600.00, 262545.00, 22545.00),
(2, 5, 300, 1000.00, 337620.00, 37620.00),
(3, 6, 80, 2400.00, 212072.00, 32072.00),
(3, 7, 400, 700.00, 312140.00, 32140.00);

-- Insert sample transactions
INSERT INTO transactions (portfolio_id, equity_id, transaction_type, quantity, price, total_amount) VALUES
(1, 1, 'BUY', 100, 2500.00, 250000.00),
(1, 2, 'BUY', 50, 3500.00, 175000.00),
(1, 3, 'BUY', 200, 1500.00, 300000.00),
(2, 4, 'BUY', 150, 1600.00, 240000.00),
(2, 5, 'BUY', 300, 1000.00, 300000.00),
(3, 6, 'BUY', 80, 2400.00, 192000.00),
(3, 7, 'BUY', 400, 700.00, 280000.00);

-- Insert sample advisory signals
INSERT INTO advisory_signals (equity_id, signal_type, confidence_score, rationale, target_price, stop_loss, time_horizon, generated_by) VALUES
(1, 'BUY', 0.85, 'Strong technical breakout above resistance with high volume', 3000.00, 2750.00, '3-6 months', 1),
(2, 'HOLD', 0.70, 'Consolidating within range, wait for breakout direction', 4000.00, 3700.00, '1-3 months', 1),
(3, 'SELL', 0.90, 'Technical indicators showing overbought conditions', 1600.00, 1700.00, '1-2 months', 2),
(4, 'BUY', 0.80, 'Strong fundamentals with improving technicals', 1850.00, 1700.00, '6-12 months', 1);

-- Create indexes for performance optimization
CREATE INDEX idx_users_role ON users(role_id);
CREATE INDEX idx_portfolios_advisor ON portfolios(advisor_id);
CREATE INDEX idx_holdings_portfolio ON holdings(portfolio_id);
CREATE INDEX idx_holdings_equity ON holdings(equity_id);
CREATE INDEX idx_transactions_portfolio ON transactions(portfolio_id);
CREATE INDEX idx_transactions_equity ON transactions(equity_id);
CREATE INDEX idx_advisory_signals_equity ON advisory_signals(equity_id);
CREATE INDEX idx_advisory_signals_generated ON advisory_signals(generated_by);

-- Create views for common queries
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    p.client_name,
    u.username as advisor_username,
    p.total_value,
    p.cash_balance,
    COUNT(DISTINCT h.holding_id) as number_of_holdings,
    p.created_at
FROM portfolios p
JOIN users u ON p.advisor_id = u.user_id
LEFT JOIN holdings h ON p.portfolio_id = h.portfolio_id
GROUP BY p.portfolio_id;

CREATE VIEW equity_performance AS
SELECT 
    e.equity_id,
    e.symbol,
    e.company_name,
    e.current_price,
    e.previous_close,
    ROUND(((e.current_price - e.previous_close) / e.previous_close) * 100, 2) as daily_change_percent,
    e.volume,
    e.market_cap
FROM equities e
WHERE e.is_active = TRUE;

-- Create stored procedures for common operations
DELIMITER //

CREATE PROCEDURE GetPortfolioHoldings(IN portfolio_id_param INT)
BEGIN
    SELECT 
        h.holding_id,
        e.symbol,
        e.company_name,
        h.quantity,
        h.average_cost,
        h.current_value,
        h.unrealized_pnl,
        ROUND(((e.current_price - h.average_cost) / h.average_cost) * 100, 2) as gain_loss_percent
    FROM holdings h
    JOIN equities e ON h.equity_id = e.equity_id
    WHERE h.portfolio_id = portfolio_id_param
    ORDER BY h.current_value DESC;
END //

CREATE PROCEDURE GetAdvisorPortfolios(IN advisor_id_param INT)
BEGIN
    SELECT 
        p.portfolio_id,
        p.portfolio_name,
        p.client_name,
        p.total_value,
        p.cash_balance,
        COUNT(h.holding_id) as number_of_holdings,
        p.created_at
    FROM portfolios p
    LEFT JOIN holdings h ON p.portfolio_id = h.portfolio_id
    WHERE p.advisor_id = advisor_id_param
    GROUP BY p.portfolio_id
    ORDER BY p.total_value DESC;
END //

CREATE PROCEDURE UpdatePortfolioValue(IN portfolio_id_param INT)
BEGIN
    DECLARE total_holdings_value DECIMAL(15,2);
    
    -- Calculate total value of all holdings
    SELECT COALESCE(SUM(h.current_value), 0) INTO total_holdings_value
    FROM holdings h
    WHERE h.portfolio_id = portfolio_id_param;
    
    -- Update portfolio total value
    UPDATE portfolios 
    SET total_value = total_holdings_value + cash_balance,
        updated_at = CURRENT_TIMESTAMP
    WHERE portfolio_id = portfolio_id_param;
END //

CREATE PROCEDURE GenerateDummyData()
BEGIN
    -- Update equity prices with random fluctuations
    UPDATE equities 
    SET current_price = previous_close * (0.95 + RAND() * 0.1),
        volume = FLOOR(100000 + RAND() * 900000),
        updated_at = CURRENT_TIMESTAMP;
    
    -- Update holding values based on current prices
    UPDATE holdings h
    JOIN equities e ON h.equity_id = e.equity_id
    SET h.current_value = h.quantity * e.current_price,
        h.unrealized_pnl = h.current_value - (h.quantity * h.average_cost),
        h.updated_at = CURRENT_TIMESTAMP;
    
    -- Update portfolio values
    UPDATE portfolios p
    SET total_value = (
        SELECT COALESCE(SUM(h.current_value), 0) + p.cash_balance
        FROM holdings h
        WHERE h.portfolio_id = p.portfolio_id
    ),
    updated_at = CURRENT_TIMESTAMP;
END //

DELIMITER ;

-- Create triggers for automatic updates
CREATE TRIGGER after_holding_insert
AFTER INSERT ON holdings
FOR EACH ROW
BEGIN
    CALL UpdatePortfolioValue(NEW.portfolio_id);
END;

CREATE TRIGGER after_holding_update
AFTER UPDATE ON holdings
FOR EACH ROW
BEGIN
    CALL UpdatePortfolioValue(NEW.portfolio_id);
END;

CREATE TRIGGER after_holding_delete
AFTER DELETE ON holdings
FOR EACH ROW
BEGIN
    CALL UpdatePortfolioValue(OLD.portfolio_id);
END;

CREATE TRIGGER after_transaction_insert
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    -- Update cash balance based on transaction
    IF NEW.transaction_type = 'BUY' THEN
        UPDATE portfolios 
        SET cash_balance = cash_balance - NEW.total_amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE portfolio_id = NEW.portfolio_id;
    ELSE
        UPDATE portfolios 
        SET cash_balance = cash_balance + NEW.total_amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE portfolio_id = NEW.portfolio_id;
    END IF;
END;

-- Insert additional sample data for testing
INSERT INTO transactions (portfolio_id, equity_id, transaction_type, quantity, price, total_amount) VALUES
(1, 1, 'SELL', 20, 2900.00, 58000.00),
(2, 4, 'BUY', 30, 1700.00, 51000.00),
(3, 6, 'SELL', 10, 2700.00, 27000.00);

-- Generate initial dummy data
CALL GenerateDummyData();

-- Verify data insertion
SELECT 'Database schema created successfully with sample data' as status;