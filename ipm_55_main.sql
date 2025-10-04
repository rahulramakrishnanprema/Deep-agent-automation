-- IPM-55: Portfolio Management System Database Schema
-- MVP for Indian Equity Portfolio Management with Advisory Signals

-- Create database
CREATE DATABASE IF NOT EXISTS portfolio_management;
USE portfolio_management;

-- Users table for authentication and role-based access
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('advisor', 'client') NOT NULL DEFAULT 'client',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Clients table for additional client information
CREATE TABLE clients (
    client_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15),
    risk_profile ENUM('conservative', 'moderate', 'aggressive') DEFAULT 'moderate',
    investment_horizon ENUM('short', 'medium', 'long') DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
);

-- Stocks table for Indian equity market data
CREATE TABLE stocks (
    stock_id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector VARCHAR(100) NOT NULL,
    industry VARCHAR(100),
    market_cap DECIMAL(20,2),
    current_price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_symbol (symbol),
    INDEX idx_sector (sector)
);

-- Historical price data for technical analysis
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
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE KEY unique_stock_date (stock_id, date),
    INDEX idx_date (date)
);

-- Portfolio table for client holdings
CREATE TABLE portfolios (
    portfolio_id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    INDEX idx_client_id (client_id)
);

-- Portfolio holdings table
CREATE TABLE portfolio_holdings (
    holding_id INT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT NOT NULL,
    stock_id INT NOT NULL,
    quantity INT NOT NULL,
    average_buy_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE KEY unique_portfolio_stock (portfolio_id, stock_id),
    INDEX idx_portfolio_id (portfolio_id),
    INDEX idx_stock_id (stock_id)
);

-- Sector analysis table for sector potential scoring
CREATE TABLE sector_analysis (
    analysis_id INT AUTO_INCREMENT PRIMARY KEY,
    sector VARCHAR(100) NOT NULL,
    analysis_date DATE NOT NULL,
    growth_potential_score DECIMAL(3,2) DEFAULT 0.5,
    risk_score DECIMAL(3,2) DEFAULT 0.5,
    market_sentiment_score DECIMAL(3,2) DEFAULT 0.5,
    overall_score DECIMAL(3,2) DEFAULT 0.5,
    analysis_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_sector_date (sector, analysis_date),
    INDEX idx_sector (sector),
    INDEX idx_date (analysis_date)
);

-- Market buzz/sentiment data
CREATE TABLE market_sentiment (
    sentiment_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    sentiment_date DATE NOT NULL,
    news_sentiment_score DECIMAL(3,2) DEFAULT 0.5,
    social_media_score DECIMAL(3,2) DEFAULT 0.5,
    analyst_rating_score DECIMAL(3,2) DEFAULT 0.5,
    overall_sentiment_score DECIMAL(3,2) DEFAULT 0.5,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE KEY unique_stock_date (stock_id, sentiment_date),
    INDEX idx_stock_id (stock_id),
    INDEX idx_date (sentiment_date)
);

-- Technical indicators table
CREATE TABLE technical_indicators (
    indicator_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    indicator_date DATE NOT NULL,
    rsi DECIMAL(5,2),
    macd DECIMAL(5,2),
    moving_avg_20 DECIMAL(10,2),
    moving_avg_50 DECIMAL(10,2),
    bollinger_upper DECIMAL(10,2),
    bollinger_lower DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE KEY unique_stock_date (stock_id, indicator_date),
    INDEX idx_stock_id (stock_id),
    INDEX idx_date (indicator_date)
);

-- Advisory signals table
CREATE TABLE advisory_signals (
    signal_id INT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    signal_date DATE NOT NULL,
    signal_type ENUM('BUY', 'HOLD', 'SELL') NOT NULL,
    confidence_score DECIMAL(3,2) DEFAULT 0.5,
    reasoning TEXT,
    historical_score DECIMAL(3,2),
    technical_score DECIMAL(3,2),
    sector_score DECIMAL(3,2),
    sentiment_score DECIMAL(3,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE KEY unique_stock_date (stock_id, signal_date),
    INDEX idx_stock_id (stock_id),
    INDEX idx_date (signal_date),
    INDEX idx_signal_type (signal_type)
);

-- Portfolio performance reports (advisor only)
CREATE TABLE portfolio_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT NOT NULL,
    report_date DATE NOT NULL,
    total_value DECIMAL(15,2),
    daily_return DECIMAL(8,4),
    weekly_return DECIMAL(8,4),
    monthly_return DECIMAL(8,4),
    annual_return DECIMAL(8,4),
    sharpe_ratio DECIMAL(8,4),
    max_drawdown DECIMAL(8,4),
    volatility DECIMAL(8,4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    UNIQUE KEY unique_portfolio_date (portfolio_id, report_date),
    INDEX idx_portfolio_id (portfolio_id),
    INDEX idx_date (report_date)
);

-- Advisor recommendations table
CREATE TABLE advisor_recommendations (
    recommendation_id INT AUTO_INCREMENT PRIMARY KEY,
    advisor_id INT NOT NULL,
    client_id INT NOT NULL,
    portfolio_id INT NOT NULL,
    recommendation_date DATE NOT NULL,
    action_type ENUM('BUY', 'SELL', 'HOLD', 'REBALANCE') NOT NULL,
    stock_id INT,
    target_quantity INT,
    target_price DECIMAL(10,2),
    reasoning TEXT,
    status ENUM('PENDING', 'APPROVED', 'REJECTED', 'EXECUTED') DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (advisor_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE SET NULL,
    INDEX idx_advisor_id (advisor_id),
    INDEX idx_client_id (client_id),
    INDEX idx_portfolio_id (portfolio_id),
    INDEX idx_date (recommendation_date)
);

-- Views for common queries

-- View for current portfolio values
CREATE VIEW portfolio_current_values AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    c.client_id,
    c.full_name as client_name,
    SUM(ph.quantity * s.current_price) as current_value,
    SUM(ph.quantity * ph.average_buy_price) as invested_value,
    COUNT(ph.holding_id) as number_of_holdings
FROM portfolios p
JOIN clients c ON p.client_id = c.client_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
LEFT JOIN stocks s ON ph.stock_id = s.stock_id
GROUP BY p.portfolio_id, p.portfolio_name, c.client_id, c.full_name;

-- View for latest advisory signals
CREATE VIEW latest_advisory_signals AS
SELECT 
    s.stock_id,
    s.symbol,
    s.company_name,
    s.sector,
    asig.signal_date,
    asig.signal_type,
    asig.confidence_score,
    asig.reasoning,
    asig.historical_score,
    asig.technical_score,
    asig.sector_score,
    asig.sentiment_score
FROM advisory_signals asig
JOIN stocks s ON asig.stock_id = s.stock_id
WHERE asig.signal_date = (SELECT MAX(signal_date) FROM advisory_signals WHERE stock_id = asig.stock_id);

-- Stored procedures for common operations

-- Procedure to calculate portfolio performance
DELIMITER //
CREATE PROCEDURE CalculatePortfolioPerformance(IN portfolio_id_param INT, IN report_date_param DATE)
BEGIN
    INSERT INTO portfolio_reports (
        portfolio_id, 
        report_date, 
        total_value, 
        daily_return, 
        weekly_return, 
        monthly_return, 
        annual_return,
        sharpe_ratio,
        max_drawdown,
        volatility
    )
    SELECT 
        portfolio_id_param,
        report_date_param,
        SUM(ph.quantity * s.current_price) as total_value,
        -- Placeholder for actual return calculations (would require historical data)
        0.0 as daily_return,
        0.0 as weekly_return,
        0.0 as monthly_return,
        0.0 as annual_return,
        0.0 as sharpe_ratio,
        0.0 as max_drawdown,
        0.0 as volatility
    FROM portfolio_holdings ph
    JOIN stocks s ON ph.stock_id = s.stock_id
    WHERE ph.portfolio_id = portfolio_id_param
    ON DUPLICATE KEY UPDATE
        total_value = VALUES(total_value),
        daily_return = VALUES(daily_return),
        weekly_return = VALUES(weekly_return),
        monthly_return = VALUES(monthly_return),
        annual_return = VALUES(annual_return),
        sharpe_ratio = VALUES(sharpe_ratio),
        max_drawdown = VALUES(max_drawdown),
        volatility = VALUES(volatility);
END //
DELIMITER ;

-- Procedure to generate advisory signal for a stock
DELIMITER //
CREATE PROCEDURE GenerateAdvisorySignal(IN stock_id_param INT, IN signal_date_param DATE)
BEGIN
    DECLARE historical_score DECIMAL(3,2);
    DECLARE technical_score DECIMAL(3,2);
    DECLARE sector_score DECIMAL(3,2);
    DECLARE sentiment_score DECIMAL(3,2);
    DECLARE overall_score DECIMAL(3,2);
    DECLARE signal_type VARCHAR(10);
    
    -- Calculate historical performance score (simplified)
    SELECT COALESCE(AVG(close_price / LAG(close_price) OVER (ORDER BY date)), 0.5)
    INTO historical_score
    FROM stock_prices
    WHERE stock_id = stock_id_param 
    AND date >= DATE_SUB(signal_date_param, INTERVAL 30 DAY)
    LIMIT 1;
    
    -- Calculate technical score (simplified)
    SELECT COALESCE(AVG(
        CASE 
            WHEN rsi < 30 THEN 0.8
            WHEN rsi > 70 THEN 0.2
            ELSE 0.5
        END), 0.5)
    INTO technical_score
    FROM technical_indicators
    WHERE stock_id = stock_id_param 
    AND indicator_date >= DATE_SUB(signal_date_param, INTERVAL 7 DAY);
    
    -- Get sector score
    SELECT COALESCE(overall_score, 0.5)
    INTO sector_score
    FROM sector_analysis sa
    JOIN stocks s ON sa.sector = s.sector
    WHERE s.stock_id = stock_id_param
    AND sa.analysis_date = signal_date_param;
    
    -- Get sentiment score
    SELECT COALESCE(overall_sentiment_score, 0.5)
    INTO sentiment_score
    FROM market_sentiment
    WHERE stock_id = stock_id_param
    AND sentiment_date = signal_date_param;
    
    -- Calculate overall score (weighted average)
    SET overall_score = (
        historical_score * 0.3 +
        technical_score * 0.3 +
        sector_score * 0.2 +
        sentiment_score * 0.2
    );
    
    -- Determine signal type based on overall score
    IF overall_score >= 0.7 THEN
        SET signal_type = 'BUY';
    ELSEIF overall_score >= 0.4 THEN
        SET signal_type = 'HOLD';
    ELSE
        SET signal_type = 'SELL';
    END IF;
    
    -- Insert or update the advisory signal
    INSERT INTO advisory_signals (
        stock_id,
        signal_date,
        signal_type,
        confidence_score,
        reasoning,
        historical_score,
        technical_score,
        sector_score,
        sentiment_score
    ) VALUES (
        stock_id_param,
        signal_date_param,
        signal_type,
        overall_score,
        CONCAT('Generated based on historical performance (', historical_score, 
               '), technical indicators (', technical_score, 
               '), sector potential (', sector_score, 
               '), and market sentiment (', sentiment_score, ')'),
        historical_score,
        technical_score,
        sector_score,
        sentiment_score
    )
    ON DUPLICATE KEY UPDATE
        signal_type = VALUES(signal_type),
        confidence_score = VALUES(confidence_score),
        reasoning = VALUES(reasoning),
        historical_score = VALUES(historical_score),
        technical_score = VALUES(technical_score),
        sector_score = VALUES(sector_score),
        sentiment_score = VALUES(sentiment_score);
END //
DELIMITER ;

-- Insert dummy data for testing

-- Insert sample users
INSERT INTO users (username, email, password_hash, role) VALUES
('advisor1', 'advisor1@example.com', 'hashed_password_1', 'advisor'),
('client1', 'client1@example.com', 'hashed_password_2', 'client'),
('client2', 'client2@example.com', 'hashed_password_3', 'client');

-- Insert client details
INSERT INTO clients (user_id, full_name, phone_number, risk_profile, investment_horizon) VALUES
(2, 'Rahul Sharma', '+919876543210', 'moderate', 'long'),
(3, 'Priya Patel', '+919876543211', 'conservative', 'medium');

-- Insert sample Indian stocks
INSERT INTO stocks (symbol, company_name, sector, industry, market_cap, current_price) VALUES
('RELIANCE', 'Reliance Industries Limited', 'Energy', 'Oil & Gas', 1500000.00, 2500.00),
('TCS', 'Tata Consultancy Services Limited', 'IT', 'Software', 1200000.00, 3200.00),
('HDFCBANK', 'HDFC Bank Limited', 'Financial', 'Banking', 800000.00, 1500.00),
('INFY', 'Infosys Limited', 'IT', 'Software', 900000.00, 1600.00),
('ICICIBANK', 'ICICI Bank Limited', 'Financial', 'Banking', 600000.00, 900.00);

-- Insert sample portfolios
INSERT INTO portfolios (client_id, portfolio_name, description) VALUES
(1, 'Long Term Growth', 'Primary long-term investment portfolio'),
(2, 'Conservative Income', 'Conservative portfolio focused on dividends');

-- Insert sample portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, average_buy_price, purchase_date) VALUES
(1, 1, 10, 2400.00, '2023-01-15'),
(1, 2, 5, 3000.00, '2023-02-20'),
(1, 3, 8, 1400.00, '2023-03-10'),
(2, 4, 15, 1500.00, '2023-04-05'),
(2, 5, 20, 850.00, '2023-05-12');

-- Insert sample historical prices
INSERT INTO stock_prices (stock_id, date, open_price, high_price, low_price, close_price, volume) VALUES
(1, '2023-06-01', 2480.00, 2520.00, 2470.00, 2500.00, 1000000),
(2, '2023-06-01', 3180.00, 3220.00, 3160.00, 3200.00, 800000),
(3, '2023-06-01', 1480.00, 1520.00, 1470.00, 1500.00, 600000),
(4, '2023-06-01', 1580.00, 1620.00, 1570.