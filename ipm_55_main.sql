-- IPM-55: Database Schema for Indian Portfolio Management System
-- This SQL file creates the complete database schema for the MVP web application
-- managing client stock portfolios focused on Indian equity markets

-- Drop existing database and create new one
DROP DATABASE IF EXISTS portfolio_management;
CREATE DATABASE portfolio_management;
USE portfolio_management;

-- Users table for authentication and access control
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    user_type ENUM('advisor', 'client') DEFAULT 'client',
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Indian sectors classification
CREATE TABLE sectors (
    sector_id INT AUTO_INCREMENT PRIMARY KEY,
    sector_name VARCHAR(100) NOT NULL,
    sector_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indian stocks master data
CREATE TABLE stocks (
    stock_id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector_id INT,
    industry VARCHAR(100),
    market_cap DECIMAL(20,2),
    current_price DECIMAL(10,2),
    isin_code VARCHAR(20),
    exchange VARCHAR(20) DEFAULT 'NSE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (sector_id) REFERENCES sectors(sector_id)
);

-- Portfolio master table
CREATE TABLE portfolios (
    portfolio_id INT AUTO_INCREMENT PRIMARY KEY,
    portfolio_name VARCHAR(100) NOT NULL,
    client_user_id INT,
    advisor_user_id INT,
    total_value DECIMAL(15,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (client_user_id) REFERENCES users(user_id),
    FOREIGN KEY (advisor_user_id) REFERENCES users(user_id)
);

-- Portfolio holdings (stocks in each portfolio)
CREATE TABLE portfolio_holdings (
    holding_id INT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT,
    stock_id INT,
    quantity INT NOT NULL,
    purchase_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    current_value DECIMAL(15,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id),
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_portfolio_stock (portfolio_id, stock_id)
);

-- Historical stock prices for technical analysis
CREATE TABLE stock_prices (
    price_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT,
    date DATE NOT NULL,
    open_price DECIMAL(10,2),
    high_price DECIMAL(10,2),
    low_price DECIMAL(10,2),
    close_price DECIMAL(10,2),
    volume BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_stock_date (stock_id, date)
);

-- Technical indicators data
CREATE TABLE technical_indicators (
    indicator_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT,
    date DATE NOT NULL,
    moving_avg_50 DECIMAL(10,2),
    moving_avg_200 DECIMAL(10,2),
    rsi DECIMAL(5,2),
    macd DECIMAL(8,4),
    bollinger_upper DECIMAL(10,2),
    bollinger_lower DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_stock_date_tech (stock_id, date)
);

-- Sector performance metrics
CREATE TABLE sector_performance (
    performance_id INT AUTO_INCREMENT PRIMARY KEY,
    sector_id INT,
    date DATE NOT NULL,
    sector_return DECIMAL(8,4),
    volatility DECIMAL(8,4),
    pe_ratio DECIMAL(8,2),
    pb_ratio DECIMAL(8,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sector_id) REFERENCES sectors(sector_id),
    UNIQUE KEY unique_sector_date (sector_id, date)
);

-- Market sentiment/buzz data
CREATE TABLE market_sentiment (
    sentiment_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT,
    date DATE NOT NULL,
    sentiment_score DECIMAL(5,2),
    news_count INT,
    social_mentions INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_stock_date_sentiment (stock_id, date)
);

-- Advisory signals table
CREATE TABLE advisory_signals (
    signal_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT,
    signal_date DATE NOT NULL,
    signal_type ENUM('BUY', 'SELL', 'HOLD') NOT NULL,
    confidence_score DECIMAL(5,2),
    technical_score DECIMAL(5,2),
    sector_score DECIMAL(5,2),
    sentiment_score DECIMAL(5,2),
    reasoning TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_stock_date_signal (stock_id, signal_date)
);

-- Portfolio signals (aggregated signals for each portfolio)
CREATE TABLE portfolio_signals (
    portfolio_signal_id INT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT,
    signal_date DATE NOT NULL,
    overall_signal ENUM('BUY', 'SELL', 'HOLD'),
    risk_score DECIMAL(5,2),
    expected_return DECIMAL(8,4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id),
    UNIQUE KEY unique_portfolio_date (portfolio_id, signal_date)
);

-- Visual reports metadata
CREATE TABLE visual_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT,
    report_type VARCHAR(50),
    report_date DATE NOT NULL,
    report_data JSON,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id),
    FOREIGN KEY (created_by) REFERENCES users(user_id)
);

-- Indexes for performance optimization
CREATE INDEX idx_stock_prices_date ON stock_prices(date);
CREATE INDEX idx_technical_indicators_date ON technical_indicators(date);
CREATE INDEX idx_advisory_signals_date ON advisory_signals(signal_date);
CREATE INDEX idx_market_sentiment_date ON market_sentiment(date);
CREATE INDEX idx_users_type ON users(user_type);
CREATE INDEX idx_portfolios_client ON portfolios(client_user_id);
CREATE INDEX idx_portfolios_advisor ON portfolios(advisor_user_id);

-- Insert dummy data for Indian sectors
INSERT INTO sectors (sector_name, sector_description) VALUES
('Information Technology', 'Software services, IT consulting, and technology solutions'),
('Banking', 'Public and private sector banks, financial services'),
('Pharmaceuticals', 'Drug manufacturers, biotechnology companies'),
('Automobile', 'Auto manufacturers, auto components, and ancillaries'),
('Energy', 'Oil & gas, power generation, renewable energy'),
('FMCG', 'Fast-moving consumer goods and retail'),
('Infrastructure', 'Construction, engineering, and infrastructure development'),
('Telecom', 'Telecommunication services and equipment');

-- Insert dummy data for popular Indian stocks
INSERT INTO stocks (symbol, company_name, sector_id, industry, market_cap, current_price, isin_code) VALUES
('INFY', 'Infosys Limited', 1, 'Software Services', 750000, 1850.75, 'INE009A01021'),
('TCS', 'Tata Consultancy Services', 1, 'Software Services', 1200000, 3250.50, 'INE467B01029'),
('HDFCBANK', 'HDFC Bank Limited', 2, 'Private Bank', 900000, 1650.25, 'INE040A01034'),
('ICICIBANK', 'ICICI Bank Limited', 2, 'Private Bank', 650000, 950.80, 'INE090A01021'),
('RELIANCE', 'Reliance Industries', 5, 'Oil & Gas', 1500000, 2750.00, 'INE002A01018'),
('SBIN', 'State Bank of India', 2, 'Public Bank', 500000, 650.45, 'INE062A01020'),
('HINDUNILVR', 'Hindustan Unilever', 6, 'FMCG', 600000, 2450.30, 'INE030A01027'),
('ITC', 'ITC Limited', 6, 'FMCG', 350000, 425.75, 'INE154A01025'),
('SUNPHARMA', 'Sun Pharmaceutical', 3, 'Pharmaceuticals', 300000, 1250.90, 'INE044A01036'),
('MARUTI', 'Maruti Suzuki India', 4, 'Automobile', 280000, 9500.00, 'INE585B01010');

-- Insert sample users
INSERT INTO users (username, email, password_hash, user_type, first_name, last_name) VALUES
('advisor1', 'advisor1@portfolio.com', 'hashed_password_1', 'advisor', 'Rajesh', 'Sharma'),
('client1', 'client1@portfolio.com', 'hashed_password_2', 'client', 'Amit', 'Patel'),
('client2', 'client2@portfolio.com', 'hashed_password_3', 'client', 'Priya', 'Singh');

-- Insert sample portfolios
INSERT INTO portfolios (portfolio_name, client_user_id, advisor_user_id, total_value) VALUES
('Growth Portfolio', 2, 1, 500000),
('Conservative Portfolio', 3, 1, 300000);

-- Insert sample portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, purchase_price, purchase_date, current_value) VALUES
(1, 1, 100, 1700.00, '2024-01-15', 185075),
(1, 3, 50, 1600.00, '2024-02-01', 82512),
(2, 6, 200, 600.00, '2024-01-20', 130090),
(2, 8, 100, 400.00, '2024-02-10', 42575);

-- Insert sample stock prices (last 5 days for INFY)
INSERT INTO stock_prices (stock_id, date, open_price, high_price, low_price, close_price, volume) VALUES
(1, CURDATE() - INTERVAL 4 DAY, 1830.00, 1865.00, 1825.00, 1850.75, 2500000),
(1, CURDATE() - INTERVAL 3 DAY, 1855.00, 1870.00, 1840.00, 1860.25, 2300000),
(1, CURDATE() - INTERVAL 2 DAY, 1865.00, 1880.00, 1855.00, 1872.50, 2100000),
(1, CURDATE() - INTERVAL 1 DAY, 1870.00, 1885.00, 1860.00, 1875.00, 1950000),
(1, CURDATE(), 1878.00, 1890.00, 1870.00, 1882.25, 1800000);

-- Insert sample technical indicators
INSERT INTO technical_indicators (stock_id, date, moving_avg_50, moving_avg_200, rsi, macd) VALUES
(1, CURDATE(), 1820.50, 1750.25, 65.30, 12.45),
(3, CURDATE(), 1620.75, 1580.40, 58.20, 8.75),
(6, CURDATE(), 620.30, 580.15, 42.10, -5.20);

-- Insert sample sector performance
INSERT INTO sector_performance (sector_id, date, sector_return, volatility, pe_ratio, pb_ratio) VALUES
(1, CURDATE(), 12.50, 8.20, 25.30, 4.50),
(2, CURDATE(), 8.75, 6.80, 18.20, 2.80),
(3, CURDATE(), 6.20, 7.50, 22.10, 3.20);

-- Insert sample market sentiment
INSERT INTO market_sentiment (stock_id, date, sentiment_score, news_count, social_mentions) VALUES
(1, CURDATE(), 72.50, 15, 120),
(3, CURDATE(), 65.80, 8, 85),
(6, CURDATE(), 45.20, 12, 60);

-- Insert sample advisory signals
INSERT INTO advisory_signals (stock_id, signal_date, signal_type, confidence_score, technical_score, sector_score, sentiment_score, reasoning) VALUES
(1, CURDATE(), 'BUY', 82.50, 85.00, 78.00, 72.50, 'Strong technical momentum combined with positive sector outlook'),
(3, CURDATE(), 'HOLD', 65.80, 70.00, 62.00, 65.80, 'Stable performance with moderate growth potential'),
(6, CURDATE(), 'SELL', 45.20, 40.00, 48.00, 45.20, 'Weak technical indicators and negative sector sentiment');

-- Insert sample portfolio signals
INSERT INTO portfolio_signals (portfolio_id, signal_date, overall_signal, risk_score, expected_return) VALUES
(1, CURDATE(), 'BUY', 65.50, 12.80),
(2, CURDATE(), 'HOLD', 45.20, 7.50);

-- Create views for common queries
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    u.username as client_name,
    COUNT(ph.holding_id) as num_holdings,
    SUM(ph.current_value) as total_value,
    ps.overall_signal as latest_signal
FROM portfolios p
JOIN users u ON p.client_user_id = u.user_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
LEFT JOIN portfolio_signals ps ON p.portfolio_id = ps.portfolio_id 
    AND ps.signal_date = (SELECT MAX(signal_date) FROM portfolio_signals WHERE portfolio_id = p.portfolio_id)
GROUP BY p.portfolio_id, p.portfolio_name, u.username, ps.overall_signal;

CREATE VIEW stock_signals_view AS
SELECT 
    s.stock_id,
    s.symbol,
    s.company_name,
    sec.sector_name,
    a.signal_type,
    a.confidence_score,
    a.signal_date,
    sp.close_price as current_price
FROM stocks s
JOIN sectors sec ON s.sector_id = sec.sector_id
JOIN advisory_signals a ON s.stock_id = a.stock_id
JOIN stock_prices sp ON s.stock_id = sp.stock_id AND sp.date = (SELECT MAX(date) FROM stock_prices WHERE stock_id = s.stock_id)
WHERE a.signal_date = (SELECT MAX(signal_date) FROM advisory_signals WHERE stock_id = s.stock_id);

-- Stored procedure for updating portfolio values
DELIMITER //
CREATE PROCEDURE UpdatePortfolioValue(IN portfolio_id_param INT)
BEGIN
    DECLARE total_val DECIMAL(15,2);
    
    SELECT SUM(ph.quantity * sp.close_price) INTO total_val
    FROM portfolio_holdings ph
    JOIN stocks s ON ph.stock_id = s.stock_id
    JOIN stock_prices sp ON s.stock_id = sp.stock_id 
        AND sp.date = (SELECT MAX(date) FROM stock_prices WHERE stock_id = s.stock_id)
    WHERE ph.portfolio_id = portfolio_id_param;
    
    UPDATE portfolios 
    SET total_value = total_val, 
        updated_at = CURRENT_TIMESTAMP
    WHERE portfolio_id = portfolio_id_param;
    
    -- Update individual holding current values
    UPDATE portfolio_holdings ph
    JOIN stocks s ON ph.stock_id = s.stock_id
    JOIN stock_prices sp ON s.stock_id = sp.stock_id 
        AND sp.date = (SELECT MAX(date) FROM stock_prices WHERE stock_id = s.stock_id)
    SET ph.current_value = ph.quantity * sp.close_price,
        ph.updated_at = CURRENT_TIMESTAMP
    WHERE ph.portfolio_id = portfolio_id_param;
END//
DELIMITER ;

-- Trigger to update portfolio value after holding changes
DELIMITER //
CREATE TRIGGER after_holding_change
AFTER INSERT OR UPDATE OR DELETE ON portfolio_holdings
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        CALL UpdatePortfolioValue(NEW.portfolio_id);
    ELSEIF UPDATING THEN
        CALL UpdatePortfolioValue(NEW.portfolio_id);
    ELSEIF DELETING THEN
        CALL UpdatePortfolioValue(OLD.portfolio_id);
    END IF;
END//
DELIMITER ;

-- Create database user for application access
CREATE USER 'portfolio_app'@'localhost' IDENTIFIED BY 'secure_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON portfolio_management.* TO 'portfolio_app'@'localhost';
GRANT EXECUTE ON PROCEDURE portfolio_management.UpdatePortfolioValue TO 'portfolio_app'@'localhost';

-- Comments for documentation
COMMENT ON TABLE users IS 'Stores user information including advisors and clients with authentication details';
COMMENT ON TABLE portfolios IS 'Main portfolio information linking clients with their advisors';
COMMENT ON TABLE portfolio_holdings IS 'Individual stock holdings within each portfolio with purchase details';
COMMENT ON TABLE advisory_signals IS 'Buy