-- IPM-55: Portfolio Management System for Indian Equity Markets
-- Main SQL Schema and Initial Data Population

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS portfolio_management;
USE portfolio_management;

-- Users table for authentication and role management
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('advisor', 'client') NOT NULL DEFAULT 'client',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Indian stocks master table with sector classification
CREATE TABLE stocks (
    stock_id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector VARCHAR(100) NOT NULL,
    industry VARCHAR(100),
    market_cap DECIMAL(18,2),
    is_nifty50 BOOLEAN DEFAULT FALSE,
    is_sensex BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_stock_symbol (symbol)
);

-- Stock price history table for technical analysis
CREATE TABLE stock_prices (
    price_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    date DATE NOT NULL,
    open_price DECIMAL(10,2),
    high_price DECIMAL(10,2),
    low_price DECIMAL(10,2),
    close_price DECIMAL(10,2) NOT NULL,
    volume BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_stock_date (stock_id, date)
);

-- Client portfolios table
CREATE TABLE portfolios (
    portfolio_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Portfolio holdings table
CREATE TABLE portfolio_holdings (
    holding_id INT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT NOT NULL,
    stock_id INT NOT NULL,
    quantity INT NOT NULL,
    average_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id),
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_portfolio_stock (portfolio_id, stock_id)
);

-- Technical indicators table for signal generation
CREATE TABLE technical_indicators (
    indicator_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    date DATE NOT NULL,
    moving_avg_50 DECIMAL(10,2),
    moving_avg_200 DECIMAL(10,2),
    rsi DECIMAL(5,2),
    macd DECIMAL(10,4),
    bollinger_upper DECIMAL(10,2),
    bollinger_lower DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_stock_date_tech (stock_id, date)
);

-- Sector analysis table for market potential
CREATE TABLE sector_analysis (
    analysis_id INT AUTO_INCREMENT PRIMARY KEY,
    sector VARCHAR(100) NOT NULL,
    analysis_date DATE NOT NULL,
    growth_potential ENUM('High', 'Medium', 'Low') NOT NULL,
    market_sentiment ENUM('Positive', 'Neutral', 'Negative') NOT NULL,
    analyst_rating DECIMAL(3,1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_sector_date (sector, analysis_date)
);

-- Market buzz and news sentiment
CREATE TABLE market_buzz (
    buzz_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    buzz_date DATE NOT NULL,
    sentiment_score DECIMAL(3,2),
    news_count INT DEFAULT 0,
    social_mentions INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_stock_date_buzz (stock_id, buzz_date)
);

-- Advisory signals table
CREATE TABLE advisory_signals (
    signal_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    portfolio_id INT,
    signal_date DATE NOT NULL,
    signal_type ENUM('BUY', 'HOLD', 'SELL') NOT NULL,
    confidence_score DECIMAL(3,2),
    reasoning TEXT,
    technical_score DECIMAL(3,2),
    sector_score DECIMAL(3,2),
    buzz_score DECIMAL(3,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id),
    UNIQUE KEY unique_stock_portfolio_date (stock_id, portfolio_id, signal_date)
);

-- Advisor reports and dashboard configurations
CREATE TABLE advisor_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    advisor_id INT NOT NULL,
    report_type VARCHAR(50) NOT NULL,
    report_data JSON,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_public BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (advisor_id) REFERENCES users(user_id)
);

-- Insert dummy data for Indian equity market focus
INSERT INTO stocks (symbol, company_name, sector, industry, market_cap, is_nifty50, is_sensex) VALUES
('RELIANCE', 'Reliance Industries Limited', 'Energy', 'Oil & Gas', 1500000.00, TRUE, TRUE),
('TCS', 'Tata Consultancy Services Limited', 'IT', 'Software', 1200000.00, TRUE, TRUE),
('HDFCBANK', 'HDFC Bank Limited', 'Banking', 'Banking', 800000.00, TRUE, TRUE),
('INFY', 'Infosys Limited', 'IT', 'Software', 700000.00, TRUE, TRUE),
('ICICIBANK', 'ICICI Bank Limited', 'Banking', 'Banking', 600000.00, TRUE, TRUE),
('HINDUNILVR', 'Hindustan Unilever Limited', 'FMCG', 'Consumer Goods', 500000.00, TRUE, TRUE),
('SBIN', 'State Bank of India', 'Banking', 'Banking', 450000.00, TRUE, TRUE),
('BHARTI', 'Bharti Airtel Limited', 'Telecom', 'Telecommunications', 400000.00, TRUE, TRUE),
('ITC', 'ITC Limited', 'FMCG', 'Consumer Goods', 350000.00, TRUE, TRUE),
('LT', 'Larsen & Toubro Limited', 'Infrastructure', 'Construction', 300000.00, TRUE, TRUE);

-- Insert sample users
INSERT INTO users (username, email, password_hash, role) VALUES
('advisor1', 'advisor1@portfolio.com', 'hashed_password_1', 'advisor'),
('client1', 'client1@portfolio.com', 'hashed_password_2', 'client'),
('client2', 'client2@portfolio.com', 'hashed_password_3', 'client');

-- Insert sample portfolios
INSERT INTO portfolios (user_id, portfolio_name, description) VALUES
(2, 'Long Term Portfolio', 'Long term investment portfolio'),
(3, 'Growth Portfolio', 'Aggressive growth focused portfolio');

-- Insert sample portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, average_price, purchase_date) VALUES
(1, 1, 100, 2500.00, '2023-01-15'),
(1, 2, 50, 3200.00, '2023-02-20'),
(2, 3, 75, 1400.00, '2023-03-10'),
(2, 4, 60, 1500.00, '2023-04-05');

-- Insert sample stock prices for technical analysis
INSERT INTO stock_prices (stock_id, date, open_price, high_price, low_price, close_price, volume) VALUES
(1, '2023-12-01', 2550.00, 2580.00, 2540.00, 2565.00, 1000000),
(1, '2023-12-02', 2565.00, 2590.00, 2555.00, 2578.00, 950000),
(2, '2023-12-01', 3250.00, 3280.00, 3230.00, 3265.00, 800000),
(2, '2023-12-02', 3265.00, 3300.00, 3250.00, 3280.00, 750000);

-- Insert technical indicators
INSERT INTO technical_indicators (stock_id, date, moving_avg_50, moving_avg_200, rsi, macd) VALUES
(1, '2023-12-02', 2520.00, 2450.00, 65.50, 12.3456),
(2, '2023-12-02', 3200.00, 3150.00, 58.75, 8.9123);

-- Insert sector analysis
INSERT INTO sector_analysis (sector, analysis_date, growth_potential, market_sentiment, analyst_rating) VALUES
('Energy', '2023-12-02', 'High', 'Positive', 4.2),
('IT', '2023-12-02', 'Medium', 'Neutral', 3.8),
('Banking', '2023-12-02', 'High', 'Positive', 4.5),
('FMCG', '2023-12-02', 'Medium', 'Positive', 4.0);

-- Insert market buzz data
INSERT INTO market_buzz (stock_id, buzz_date, sentiment_score, news_count, social_mentions) VALUES
(1, '2023-12-02', 0.75, 15, 120),
(2, '2023-12-02', 0.65, 8, 85),
(3, '2023-12-02', 0.82, 20, 150);

-- Insert advisory signals
INSERT INTO advisory_signals (stock_id, portfolio_id, signal_date, signal_type, confidence_score, reasoning, technical_score, sector_score, buzz_score) VALUES
(1, 1, '2023-12-02', 'BUY', 0.85, 'Strong technical indicators and positive sector outlook', 0.80, 0.85, 0.75),
(2, 1, '2023-12-02', 'HOLD', 0.70, 'Stable performance but limited upside potential', 0.65, 0.75, 0.65),
(3, 2, '2023-12-02', 'BUY', 0.90, 'Excellent banking sector growth and strong fundamentals', 0.85, 0.95, 0.82);

-- Create indexes for performance optimization
CREATE INDEX idx_stock_prices_date ON stock_prices(date);
CREATE INDEX idx_stock_prices_stock ON stock_prices(stock_id);
CREATE INDEX idx_advisory_signals_date ON advisory_signals(signal_date);
CREATE INDEX idx_advisory_signals_portfolio ON advisory_signals(portfolio_id);
CREATE INDEX idx_technical_indicators_date ON technical_indicators(date);

-- Create views for common queries
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    u.username as client_name,
    COUNT(ph.holding_id) as number_of_holdings,
    SUM(ph.quantity * s.current_price) as total_value
FROM portfolios p
JOIN users u ON p.user_id = u.user_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
LEFT JOIN (
    SELECT stock_id, MAX(date) as latest_date
    FROM stock_prices
    GROUP BY stock_id
) latest ON ph.stock_id = latest.stock_id
LEFT JOIN stock_prices s ON latest.stock_id = s.stock_id AND latest.latest_date = s.date
GROUP BY p.portfolio_id, p.portfolio_name, u.username;

CREATE VIEW advisor_dashboard AS
SELECT 
    s.symbol,
    s.company_name,
    s.sector,
    asp.signal_type,
    asp.confidence_score,
    asp.signal_date,
    sp.close_price as current_price
FROM advisory_signals asp
JOIN stocks s ON asp.stock_id = s.stock_id
JOIN (
    SELECT stock_id, MAX(date) as latest_date
    FROM stock_prices
    GROUP BY stock_id
) latest ON s.stock_id = latest.stock_id
JOIN stock_prices sp ON latest.stock_id = sp.stock_id AND latest.latest_date = sp.date
WHERE asp.signal_date = CURRENT_DATE;

-- Stored procedure for generating advisory signals
DELIMITER //

CREATE PROCEDURE GenerateAdvisorySignals(IN portfolio_id_param INT)
BEGIN
    INSERT INTO advisory_signals (
        stock_id, 
        portfolio_id, 
        signal_date, 
        signal_type, 
        confidence_score, 
        reasoning, 
        technical_score, 
        sector_score, 
        buzz_score
    )
    SELECT 
        ph.stock_id,
        portfolio_id_param,
        CURRENT_DATE,
        CASE 
            WHEN (ti.rsi < 30 AND sa.growth_potential = 'High' AND mb.sentiment_score > 0.7) THEN 'BUY'
            WHEN (ti.rsi > 70 OR sa.market_sentiment = 'Negative') THEN 'SELL'
            ELSE 'HOLD'
        END as signal_type,
        (COALESCE(ti.rsi, 50)/100 * 0.4 + 
         CASE sa.growth_potential 
             WHEN 'High' THEN 0.9 
             WHEN 'Medium' THEN 0.6 
             ELSE 0.3 
         END * 0.3 +
         COALESCE(mb.sentiment_score, 0.5) * 0.3) as confidence_score,
        CONCAT('RSI: ', COALESCE(ti.rsi, 'N/A'), 
               ', Sector: ', sa.growth_potential,
               ', Buzz: ', ROUND(COALESCE(mb.sentiment_score, 0.5)*100, 1), '%') as reasoning,
        COALESCE(ti.rsi, 50)/100 as technical_score,
        CASE sa.growth_potential 
            WHEN 'High' THEN 0.9 
            WHEN 'Medium' THEN 0.6 
            ELSE 0.3 
        END as sector_score,
        COALESCE(mb.sentiment_score, 0.5) as buzz_score
    FROM portfolio_holdings ph
    LEFT JOIN technical_indicators ti ON ph.stock_id = ti.stock_id AND ti.date = CURRENT_DATE
    LEFT JOIN stocks s ON ph.stock_id = s.stock_id
    LEFT JOIN sector_analysis sa ON s.sector = sa.sector AND sa.analysis_date = CURRENT_DATE
    LEFT JOIN market_buzz mb ON ph.stock_id = mb.stock_id AND mb.buzz_date = CURRENT_DATE
    WHERE ph.portfolio_id = portfolio_id_param;
END //

DELIMITER ;

-- Create user for backend application with appropriate permissions
CREATE USER 'portfolio_app'@'localhost' IDENTIFIED BY 'secure_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON portfolio_management.* TO 'portfolio_app'@'localhost';
FLUSH PRIVILEGES;