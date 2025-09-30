-- IPM-55: Portfolio Management System SQL Schema
-- This file creates the database schema for the Indian equity portfolio management MVP
-- Includes tables for portfolios, stocks, technical indicators, advisory signals, and market data

-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS portfolio_stocks;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS technical_indicators;
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS sector_performance;
DROP TABLE IF EXISTS market_buzz;
DROP TABLE IF EXISTS historical_performance;
DROP TABLE IF EXISTS advisors;
DROP TABLE IF EXISTS clients;

-- Clients table
CREATE TABLE clients (
    client_id INT PRIMARY KEY AUTO_INCREMENT,
    client_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(15),
    risk_profile ENUM('LOW', 'MEDIUM', 'HIGH') DEFAULT 'MEDIUM',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Advisors table
CREATE TABLE advisors (
    advisor_id INT PRIMARY KEY AUTO_INCREMENT,
    advisor_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    specialization VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stocks table (NSE/BSE listed Indian equities)
CREATE TABLE stocks (
    stock_id INT PRIMARY KEY AUTO_INCREMENT,
    symbol VARCHAR(20) NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector VARCHAR(100) NOT NULL,
    industry VARCHAR(100),
    current_price DECIMAL(10,2) NOT NULL,
    market_cap DECIMAL(15,2),
    pe_ratio DECIMAL(10,2),
    dividend_yield DECIMAL(5,2),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_symbol (symbol)
);

-- Portfolios table
CREATE TABLE portfolios (
    portfolio_id INT PRIMARY KEY AUTO_INCREMENT,
    client_id INT NOT NULL,
    advisor_id INT NOT NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    total_value DECIMAL(12,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (client_id) REFERENCES clients(client_id),
    FOREIGN KEY (advisor_id) REFERENCES advisors(advisor_id)
);

-- Portfolio stocks junction table
CREATE TABLE portfolio_stocks (
    portfolio_stock_id INT PRIMARY KEY AUTO_INCREMENT,
    portfolio_id INT NOT NULL,
    stock_id INT NOT NULL,
    quantity INT NOT NULL,
    purchase_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    current_value DECIMAL(12,2) GENERATED ALWAYS AS (quantity * (SELECT current_price FROM stocks WHERE stock_id = portfolio_stocks.stock_id)) STORED,
    unrealized_pnl DECIMAL(12,2) GENERATED ALWAYS AS (quantity * ((SELECT current_price FROM stocks WHERE stock_id = portfolio_stocks.stock_id) - purchase_price)) STORED,
    weight DECIMAL(5,2) GENERATED ALWAYS AS (
        (quantity * (SELECT current_price FROM stocks WHERE stock_id = portfolio_stocks.stock_id)) / 
        (SELECT total_value FROM portfolios WHERE portfolio_id = portfolio_stocks.portfolio_id)
    ) STORED,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id),
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    CHECK (quantity > 0),
    CHECK (purchase_price > 0)
);

-- Technical indicators table
CREATE TABLE technical_indicators (
    indicator_id INT PRIMARY KEY AUTO_INCREMENT,
    stock_id INT NOT NULL,
    rsi DECIMAL(5,2),
    macd DECIMAL(8,4),
    macd_signal DECIMAL(8,4),
    moving_avg_50 DECIMAL(10,2),
    moving_avg_200 DECIMAL(10,2),
    bollinger_upper DECIMAL(10,2),
    bollinger_lower DECIMAL(10,2),
    stochastic_k DECIMAL(5,2),
    stochastic_d DECIMAL(5,2),
    volume_avg_20 BIGINT,
    calculated_date DATE NOT NULL,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    UNIQUE KEY unique_stock_date (stock_id, calculated_date)
);

-- Advisory signals table
CREATE TABLE advisory_signals (
    signal_id INT PRIMARY KEY AUTO_INCREMENT,
    stock_id INT NOT NULL,
    signal_type ENUM('BUY', 'HOLD', 'SELL') NOT NULL,
    confidence_score DECIMAL(4,2) CHECK (confidence_score BETWEEN 0 AND 1),
    rationale TEXT,
    generated_by INT NOT NULL,
    valid_until DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id),
    FOREIGN KEY (generated_by) REFERENCES advisors(advisor_id)
);

-- Sector performance table
CREATE TABLE sector_performance (
    sector_id INT PRIMARY KEY AUTO_INCREMENT,
    sector_name VARCHAR(100) NOT NULL,
    performance_score DECIMAL(5,2) CHECK (performance_score BETWEEN 0 AND 100),
    growth_potential ENUM('LOW', 'MEDIUM', 'HIGH') DEFAULT 'MEDIUM',
    market_sentiment ENUM('BEARISH', 'NEUTRAL', 'BULLISH') DEFAULT 'NEUTRAL',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_sector (sector_name)
);

-- Market buzz table
CREATE TABLE market_buzz (
    buzz_id INT PRIMARY KEY AUTO_INCREMENT,
    stock_id INT,
    buzz_type ENUM('NEWS', 'SOCIAL_MEDIA', 'ANALYST_REPORT', 'RUMOR') NOT NULL,
    sentiment ENUM('NEGATIVE', 'NEUTRAL', 'POSITIVE') DEFAULT 'NEUTRAL',
    content TEXT NOT NULL,
    source VARCHAR(200),
    impact_score DECIMAL(3,2) CHECK (impact_score BETWEEN 0 AND 1),
    published_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id)
);

-- Historical performance table
CREATE TABLE historical_performance (
    performance_id INT PRIMARY KEY AUTO_INCREMENT,
    portfolio_id INT NOT NULL,
    date DATE NOT NULL,
    total_value DECIMAL(12,2) NOT NULL,
    daily_return DECIMAL(8,4),
    cumulative_return DECIMAL(8,4),
    volatility DECIMAL(8,4),
    sharpe_ratio DECIMAL(8,4),
    max_drawdown DECIMAL(8,4),
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id),
    UNIQUE KEY unique_portfolio_date (portfolio_id, date)
);

-- Indexes for performance optimization
CREATE INDEX idx_portfolio_stocks_portfolio ON portfolio_stocks(portfolio_id);
CREATE INDEX idx_portfolio_stocks_stock ON portfolio_stocks(stock_id);
CREATE INDEX idx_technical_indicators_stock ON technical_indicators(stock_id);
CREATE INDEX idx_advisory_signals_stock ON advisory_signals(stock_id);
CREATE INDEX idx_market_buzz_stock ON market_buzz(stock_id);
CREATE INDEX idx_historical_performance_portfolio ON historical_performance(portfolio_id);
CREATE INDEX idx_stocks_sector ON stocks(sector);

-- Insert dummy data for demonstration
INSERT INTO clients (client_name, email, phone, risk_profile) VALUES
('Rajesh Kumar', 'rajesh.kumar@email.com', '+919876543210', 'MEDIUM'),
('Priya Sharma', 'priya.sharma@email.com', '+919876543211', 'LOW'),
('Amit Patel', 'amit.patel@email.com', '+919876543212', 'HIGH');

INSERT INTO advisors (advisor_name, email, specialization) VALUES
('Deepak Mehta', 'deepak.mehta@advisory.com', 'Equity Research'),
('Neha Gupta', 'neha.gupta@advisory.com', 'Portfolio Management'),
('Vikram Singh', 'vikram.singh@advisory.com', 'Technical Analysis');

INSERT INTO stocks (symbol, company_name, sector, industry, current_price, market_cap, pe_ratio, dividend_yield) VALUES
('RELIANCE', 'Reliance Industries Ltd', 'Energy', 'Oil & Gas', 2750.50, 1860000.00, 28.50, 0.45),
('INFY', 'Infosys Ltd', 'IT', 'Software', 1650.75, 685000.00, 25.30, 2.10),
('HDFCBANK', 'HDFC Bank Ltd', 'Financial', 'Banking', 1625.25, 895000.00, 20.10, 1.20),
('TCS', 'Tata Consultancy Services Ltd', 'IT', 'Software', 3450.00, 1320000.00, 30.20, 1.80),
('ICICIBANK', 'ICICI Bank Ltd', 'Financial', 'Banking', 980.50, 675000.00, 18.75, 0.90);

INSERT INTO portfolios (client_id, advisor_id, portfolio_name, total_value) VALUES
(1, 1, 'Rajesh Growth Portfolio', 0),
(2, 2, 'Priya Conservative Portfolio', 0),
(3, 3, 'Amit Aggressive Portfolio', 0);

INSERT INTO portfolio_stocks (portfolio_id, stock_id, quantity, purchase_price, purchase_date) VALUES
(1, 1, 10, 2600.00, '2024-01-15'),
(1, 2, 15, 1500.00, '2024-02-01'),
(2, 3, 8, 1550.00, '2024-01-20'),
(2, 5, 20, 920.00, '2024-02-10'),
(3, 4, 5, 3300.00, '2024-01-25'),
(3, 1, 8, 2700.00, '2024-02-05');

-- Update portfolio total values
UPDATE portfolios p
SET total_value = (
    SELECT COALESCE(SUM(ps.current_value), 0)
    FROM portfolio_stocks ps
    WHERE ps.portfolio_id = p.portfolio_id
);

INSERT INTO technical_indicators (stock_id, rsi, macd, macd_signal, moving_avg_50, moving_avg_200, calculated_date) VALUES
(1, 62.5, 12.3456, 11.2345, 2680.25, 2550.75, CURDATE()),
(2, 45.2, -5.6789, -4.5678, 1620.50, 1580.25, CURDATE()),
(3, 58.7, 8.9012, 7.8901, 1600.75, 1550.50, CURDATE()),
(4, 70.3, 15.6789, 14.5678, 3400.00, 3250.25, CURDATE()),
(5, 40.1, -3.4567, -2.3456, 950.00, 920.75, CURDATE());

INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, rationale, generated_by, valid_until) VALUES
(1, 'BUY', 0.85, 'Strong fundamentals and positive technical indicators', 1, DATE_ADD(CURDATE(), INTERVAL 30 DAY)),
(2, 'HOLD', 0.65, 'Stable performance but limited upside potential', 2, DATE_ADD(CURDATE(), INTERVAL 15 DAY)),
(3, 'BUY', 0.78, 'Undervalued with improving technicals', 3, DATE_ADD(CURDATE(), INTERVAL 30 DAY)),
(4, 'SELL', 0.72, 'Overvalued and showing bearish technical signals', 1, DATE_ADD(CURDATE(), INTERVAL 15 DAY)),
(5, 'HOLD', 0.60, 'Neutral signals, wait for clearer direction', 2, DATE_ADD(CURDATE(), INTERVAL 15 DAY));

INSERT INTO sector_performance (sector_name, performance_score, growth_potential, market_sentiment) VALUES
('Energy', 75.5, 'HIGH', 'BULLISH'),
('IT', 60.2, 'MEDIUM', 'NEUTRAL'),
('Financial', 68.7, 'HIGH', 'BULLISH'),
('Healthcare', 55.3, 'MEDIUM', 'NEUTRAL'),
('Automobile', 45.8, 'LOW', 'BEARISH');

INSERT INTO market_buzz (stock_id, buzz_type, sentiment, content, source, impact_score, published_date) VALUES
(1, 'NEWS', 'POSITIVE', 'Reliance announces new renewable energy initiatives', 'Economic Times', 0.8, NOW()),
(2, 'ANALYST_REPORT', 'NEUTRAL', 'Infosys Q3 results meet expectations', 'Morgan Stanley', 0.6, NOW()),
(3, 'SOCIAL_MEDIA', 'POSITIVE', 'Positive sentiment around HDFC Bank digital transformation', 'Twitter', 0.5, NOW()),
(4, 'NEWS', 'NEGATIVE', 'TCS faces margin pressure in international markets', 'Business Standard', 0.7, NOW()),
(5, 'RUMOR', 'NEUTRAL', 'Rumors of ICICI Bank expansion plans', 'Market Sources', 0.4, NOW());

-- Views for common queries
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    c.client_name,
    a.advisor_name,
    p.total_value,
    COUNT(ps.stock_id) as number_of_stocks,
    MAX(ps.purchase_date) as latest_purchase
FROM portfolios p
JOIN clients c ON p.client_id = c.client_id
JOIN advisors a ON p.advisor_id = a.advisor_id
LEFT JOIN portfolio_stocks ps ON p.portfolio_id = ps.portfolio_id
GROUP BY p.portfolio_id;

CREATE VIEW stock_signals AS
SELECT 
    s.symbol,
    s.company_name,
    s.sector,
    s.current_price,
    asig.signal_type,
    asig.confidence_score,
    asig.rationale,
    asig.valid_until
FROM stocks s
JOIN advisory_signals asig ON s.stock_id = asig.stock_id
WHERE asig.valid_until >= CURDATE();

-- Stored procedures for common operations
DELIMITER //

CREATE PROCEDURE CalculatePortfolioPerformance(IN portfolio_id_param INT)
BEGIN
    DECLARE current_total DECIMAL(12,2);
    DECLARE previous_total DECIMAL(12,2);
    DECLARE daily_return_val DECIMAL(8,4);
    
    SELECT total_value INTO current_total FROM portfolios WHERE portfolio_id = portfolio_id_param;
    
    SELECT total_value INTO previous_total 
    FROM historical_performance 
    WHERE portfolio_id = portfolio_id_param 
    AND date = DATE_SUB(CURDATE(), INTERVAL 1 DAY)
    ORDER BY date DESC LIMIT 1;
    
    IF previous_total IS NOT NULL AND previous_total > 0 THEN
        SET daily_return_val = (current_total - previous_total) / previous_total;
    ELSE
        SET daily_return_val = 0;
    END IF;
    
    INSERT INTO historical_performance (portfolio_id, date, total_value, daily_return)
    VALUES (portfolio_id_param, CURDATE(), current_total, daily_return_val)
    ON DUPLICATE KEY UPDATE 
        total_value = current_total,
        daily_return = daily_return_val;
END //

CREATE PROCEDURE GenerateAdvisorySignal(
    IN stock_id_param INT,
    IN advisor_id_param INT
)
BEGIN
    DECLARE rsi_val DECIMAL(5,2);
    DECLARE macd_val DECIMAL(8,4);
    DECLARE ma50_val DECIMAL(10,2);
    DECLARE ma200_val DECIMAL(10,2);
    DECLARE current_price_val DECIMAL(10,2);
    DECLARE signal_type_val ENUM('BUY', 'HOLD', 'SELL');
    DECLARE confidence_val DECIMAL(4,2);
    DECLARE rationale_text TEXT;
    
    -- Get latest technical indicators
    SELECT rsi, macd, moving_avg_50, moving_avg_200 INTO rsi_val, macd_val, ma50_val, ma200_val
    FROM technical_indicators 
    WHERE stock_id = stock_id_param 
    ORDER BY calculated_date DESC LIMIT 1;
    
    SELECT current_price INTO current_price_val FROM stocks WHERE stock_id = stock_id_param;
    
    -- Simple signal generation logic (example)
    IF rsi_val < 30 AND macd_val > 0 AND current_price_val > ma50_val THEN
        SET signal_type_val = 'BUY';
        SET confidence_val = 0.85;
        SET rationale_text = 'Oversold conditions with positive momentum and price above 50-day MA';
    ELSEIF rsi_val > 70 AND macd_val < 0 AND current_price_val < ma200_val THEN
        SET signal_type_val = 'SELL';
        SET confidence_val = 0.75;
        SET rationale_text = 'Overbought conditions with negative momentum and price below 200-day MA';
    ELSE
        SET signal_type_val = 'HOLD';
        SET confidence_val = 0.65;
        SET rationale_text = 'Mixed signals, recommend holding current position';
    END IF;
    
    INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, rationale, generated_by, valid_until)
    VALUES (stock_id_param, signal_type_val, confidence_val, rationale_text, advisor_id_param, DATE_ADD(CURDATE(), INTERVAL 30 DAY));
END //

DELIMITER ;

-- Triggers for maintaining data integrity
DELIMITER //

CREATE TRIGGER update_portfolio_value_after_insert
AFTER INSERT ON portfolio_stocks
FOR EACH ROW
BEGIN
    UPDATE portfolios 
    SET total