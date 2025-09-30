-- IPM-55: Portfolio Management Database Schema
-- This SQL file creates the database schema for the Indian Portfolio Management MVP
-- Includes tables for portfolios, holdings, stocks, sectors, and advisory signals

-- Drop existing tables to ensure clean creation (use with caution in production)
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS holdings;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS sectors;
DROP TABLE IF EXISTS market_sentiment;

-- Table for storing sector information
CREATE TABLE sectors (
    sector_id INT PRIMARY KEY AUTO_INCREMENT,
    sector_name VARCHAR(100) NOT NULL UNIQUE,
    sector_potential_score DECIMAL(5,2) DEFAULT 0.0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for storing stock information
CREATE TABLE stocks (
    stock_id INT PRIMARY KEY AUTO_INCREMENT,
    symbol VARCHAR(20) NOT NULL UNIQUE,
    company_name VARCHAR(200) NOT NULL,
    sector_id INT,
    current_price DECIMAL(10,2) DEFAULT 0.0,
    historical_performance DECIMAL(5,2) DEFAULT 0.0, -- Percentage change over period
    technical_indicator_score DECIMAL(5,2) DEFAULT 0.0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sector_id) REFERENCES sectors(sector_id) ON DELETE SET NULL
);

-- Table for storing market sentiment/buzz data
CREATE TABLE market_sentiment (
    sentiment_id INT PRIMARY KEY AUTO_INCREMENT,
    stock_id INT,
    sentiment_score DECIMAL(5,2) DEFAULT 0.0, -- Range from -1.0 (negative) to 1.0 (positive)
    source_type ENUM('news', 'social_media', 'analyst_report') DEFAULT 'news',
    source_text TEXT,
    confidence_level DECIMAL(3,2) DEFAULT 0.8,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

-- Table for storing client portfolios
CREATE TABLE portfolios (
    portfolio_id INT PRIMARY KEY AUTO_INCREMENT,
    client_name VARCHAR(200) NOT NULL,
    advisor_id INT NOT NULL,
    total_value DECIMAL(15,2) DEFAULT 0.0,
    created_date DATE DEFAULT CURRENT_DATE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT
);

-- Table for storing portfolio holdings
CREATE TABLE holdings (
    holding_id INT PRIMARY KEY AUTO_INCREMENT,
    portfolio_id INT,
    stock_id INT,
    quantity INT NOT NULL DEFAULT 0,
    average_buy_price DECIMAL(10,2) NOT NULL,
    current_value DECIMAL(15,2) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE KEY unique_holding (portfolio_id, stock_id)
);

-- Table for storing advisory signals
CREATE TABLE advisory_signals (
    signal_id INT PRIMARY KEY AUTO_INCREMENT,
    stock_id INT,
    signal_type ENUM('BUY', 'HOLD', 'SELL') NOT NULL,
    confidence_score DECIMAL(3,2) DEFAULT 0.0, -- 0.0 to 1.0
    reasoning TEXT,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

-- Indexes for better query performance
CREATE INDEX idx_stocks_symbol ON stocks(symbol);
CREATE INDEX idx_stocks_sector ON stocks(sector_id);
CREATE INDEX idx_holdings_portfolio ON holdings(portfolio_id);
CREATE INDEX idx_holdings_stock ON holdings(stock_id);
CREATE INDEX idx_signals_stock ON advisory_signals(stock_id);
CREATE INDEX idx_signals_active ON advisory_signals(is_active);
CREATE INDEX idx_sentiment_stock ON market_sentiment(stock_id);
CREATE INDEX idx_portfolios_advisor ON portfolios(advisor_id);

-- Insert sample sector data
INSERT INTO sectors (sector_name, sector_potential_score) VALUES
('Information Technology', 85.5),
('Banking & Financial Services', 78.2),
('Pharmaceuticals', 72.8),
('Automobile', 68.4),
('Consumer Goods', 65.1),
('Energy', 60.7),
('Infrastructure', 55.3),
('Telecommunications', 50.9);

-- Insert sample stock data
INSERT INTO stocks (symbol, company_name, sector_id, current_price, historical_performance, technical_indicator_score) VALUES
('INFY', 'Infosys Limited', 1, 1850.75, 12.5, 78.3),
('TCS', 'Tata Consultancy Services', 1, 3450.25, 15.2, 82.1),
('HDFCBANK', 'HDFC Bank Limited', 2, 1650.50, 8.7, 70.5),
('ICICIBANK', 'ICICI Bank Limited', 2, 980.30, 10.3, 75.8),
('SUNPHARMA', 'Sun Pharmaceutical Industries', 3, 1120.45, 6.8, 65.2),
('DRREDDY', 'Dr. Reddy''s Laboratories', 3, 5430.80, 9.1, 68.7),
('TATAMOTORS', 'Tata Motors Limited', 4, 765.90, 18.2, 85.4),
('MARUTI', 'Maruti Suzuki India Limited', 4, 9450.60, 7.5, 62.3),
('HINDUNILVR', 'Hindustan Unilever Limited', 5, 2450.25, 5.9, 58.6),
('ITC', 'ITC Limited', 5, 430.75, 4.2, 55.1),
('RELIANCE', 'Reliance Industries Limited', 6, 2780.40, 20.1, 88.9),
('ONGC', 'Oil & Natural Gas Corporation', 6, 185.90, 3.7, 52.4),
('LT', 'Larsen & Toubro Limited', 7, 3450.80, 11.8, 76.5),
('ADANIPORTS', 'Adani Ports and Special Economic Zone', 7, 1230.45, 14.3, 79.2),
('BHARTIARTL', 'Bharti Airtel Limited', 8, 890.60, 16.7, 81.8),
('JIO', 'Reliance Jio Infocomm Limited', 8, 0.00, 0.0, 0.0); -- Placeholder for demonstration

-- Insert sample market sentiment data
INSERT INTO market_sentiment (stock_id, sentiment_score, source_type, source_text, confidence_level) VALUES
(1, 0.85, 'news', 'Strong quarterly results with increased guidance', 0.92),
(2, 0.78, 'analyst_report', 'Maintain buy rating with target price increase', 0.88),
(3, 0.65, 'social_media', 'Mixed reactions to new digital initiatives', 0.75),
(4, 0.72, 'news', 'Strong loan growth in latest quarterly report', 0.82),
(5, 0.58, 'analyst_report', 'FDA approval delays affecting sentiment', 0.68),
(6, 0.81, 'news', 'Successful new drug launch in international markets', 0.89),
(7, 0.92, 'social_media', 'Excellent response to new EV models', 0.95),
(8, 0.63, 'analyst_report', 'Competition intensifying in passenger vehicle segment', 0.71),
(9, 0.69, 'news', 'Steady growth in rural demand', 0.78),
(10, 0.55, 'social_media', 'Mixed reactions to diversification strategy', 0.65),
(11, 0.88, 'news', 'Strong performance across all business verticals', 0.93),
(12, 0.48, 'analyst_report', 'Volatile oil prices affecting profitability', 0.62),
(13, 0.76, 'news', 'Winning major infrastructure contracts', 0.84),
(14, 0.82, 'social_media', 'Positive sentiment around export growth', 0.87),
(15, 0.91, 'news', '5G rollout exceeding expectations', 0.94);

-- Insert sample portfolio data
INSERT INTO portfolios (client_name, advisor_id, total_value, created_date, notes) VALUES
('Rajesh Kumar', 101, 1250000.00, '2024-01-15', 'Long-term growth focused portfolio'),
('Priya Sharma', 101, 850000.00, '2024-02-01', 'Moderate risk appetite'),
('Amit Patel', 102, 2100000.00, '2024-01-20', 'High net worth client - aggressive growth'),
('Sneha Gupta', 102, 950000.00, '2024-02-10', 'Income generation focus'),
('Vikram Singh', 103, 1750000.00, '2024-01-25', 'Balanced portfolio with sector diversification');

-- Insert sample holdings data
INSERT INTO holdings (portfolio_id, stock_id, quantity, average_buy_price, current_value) VALUES
(1, 1, 50, 1700.00, 92537.50),
(1, 3, 100, 1550.00, 165050.00),
(1, 7, 80, 700.00, 61272.00),
(1, 11, 30, 2500.00, 83412.00),
(2, 2, 20, 3200.00, 69005.00),
(2, 5, 60, 1050.00, 67227.00),
(2, 9, 25, 2300.00, 61256.25),
(3, 1, 100, 1600.00, 185075.00),
(3, 4, 150, 900.00, 147045.00),
(3, 13, 40, 3200.00, 138032.00),
(4, 6, 15, 5000.00, 81462.00),
(4, 8, 8, 9200.00, 75604.80),
(4, 15, 80, 800.00, 71248.00),
(5, 3, 70, 1600.00, 115535.00),
(5, 7, 100, 750.00, 76590.00),
(5, 14, 60, 1100.00, 73827.00);

-- Insert sample advisory signals
INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, reasoning, valid_until) VALUES
(1, 'BUY', 0.88, 'Strong fundamentals and positive sector outlook', DATE_ADD(NOW(), INTERVAL 30 DAY)),
(2, 'HOLD', 0.75, 'Good performance but fully valued at current levels', DATE_ADD(NOW(), INTERVAL 15 DAY)),
(3, 'BUY', 0.82, 'Undervalued compared to peers with strong growth potential', DATE_ADD(NOW(), INTERVAL 45 DAY)),
(7, 'BUY', 0.92, 'Exceptional growth in EV segment and positive market sentiment', DATE_ADD(NOW(), INTERVAL 60 DAY)),
(11, 'HOLD', 0.68, 'Strong performance but facing margin pressures', DATE_ADD(NOW(), INTERVAL 20 DAY)),
(15, 'BUY', 0.85, '5G rollout success and expanding market share', DATE_ADD(NOW(), INTERVAL 30 DAY)),
(5, 'SELL', 0.78, 'Regulatory challenges and slowing growth', DATE_ADD(NOW(), INTERVAL 10 DAY)),
(12, 'SELL', 0.82, 'Commodity price volatility and declining margins', DATE_ADD(NOW(), INTERVAL 15 DAY));

-- View for portfolio summary with current values
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.client_name,
    p.advisor_id,
    p.total_value,
    COUNT(h.holding_id) as number_of_holdings,
    MAX(h.last_updated) as last_updated,
    p.created_date
FROM portfolios p
LEFT JOIN holdings h ON p.portfolio_id = h.portfolio_id
WHERE p.is_active = TRUE
GROUP BY p.portfolio_id, p.client_name, p.advisor_id, p.total_value, p.created_date;

-- View for stock signals with detailed information
CREATE VIEW stock_signals_detail AS
SELECT 
    s.stock_id,
    s.symbol,
    s.company_name,
    sec.sector_name,
    s.current_price,
    s.historical_performance,
    s.technical_indicator_score,
    asig.signal_type,
    asig.confidence_score,
    asig.reasoning,
    asig.generated_at,
    asig.valid_until,
    AVG(ms.sentiment_score) as avg_sentiment_score
FROM stocks s
JOIN sectors sec ON s.sector_id = sec.sector_id
LEFT JOIN advisory_signals asig ON s.stock_id = asig.stock_id AND asig.is_active = TRUE
LEFT JOIN market_sentiment ms ON s.stock_id = ms.stock_id
GROUP BY s.stock_id, s.symbol, s.company_name, sec.sector_name, s.current_price, 
         s.historical_performance, s.technical_indicator_score, asig.signal_type,
         asig.confidence_score, asig.reasoning, asig.generated_at, asig.valid_until;

-- Stored procedure to update portfolio total value
DELIMITER //
CREATE PROCEDURE UpdatePortfolioValue(IN portfolio_id_param INT)
BEGIN
    UPDATE portfolios p
    SET p.total_value = (
        SELECT COALESCE(SUM(h.current_value), 0)
        FROM holdings h
        WHERE h.portfolio_id = portfolio_id_param
    ),
    p.last_updated = CURRENT_TIMESTAMP
    WHERE p.portfolio_id = portfolio_id_param;
END //
DELIMITER ;

-- Stored procedure to generate advisory signal (simplified version)
DELIMITER //
CREATE PROCEDURE GenerateAdvisorySignal(IN stock_id_param INT)
BEGIN
    DECLARE historical_score DECIMAL(5,2);
    DECLARE technical_score DECIMAL(5,2);
    DECLARE sector_score DECIMAL(5,2);
    DECLARE sentiment_score DECIMAL(5,2);
    DECLARE final_score DECIMAL(5,2);
    DECLARE signal_type_val ENUM('BUY', 'HOLD', 'SELL');
    DECLARE confidence_val DECIMAL(3,2);
    DECLARE reasoning_text TEXT;
    
    -- Get component scores (simplified calculation)
    SELECT historical_performance INTO historical_score FROM stocks WHERE stock_id = stock_id_param;
    SELECT technical_indicator_score INTO technical_score FROM stocks WHERE stock_id = stock_id_param;
    SELECT sec.sector_potential_score INTO sector_score 
    FROM stocks s JOIN sectors sec ON s.sector_id = sec.sector_id 
    WHERE s.stock_id = stock_id_param;
    SELECT AVG(sentiment_score) INTO sentiment_score FROM market_sentiment WHERE stock_id = stock_id_param;
    
    -- Calculate final score (weighted average)
    SET final_score = (historical_score * 0.25) + (technical_score * 0.25) + 
                     (sector_score * 0.30) + (COALESCE(sentiment_score, 0.5) * 0.20);
    
    -- Determine signal type based on score
    IF final_score >= 75 THEN
        SET signal_type_val = 'BUY';
        SET confidence_val = (final_score - 75) / 25;
    ELSEIF final_score >= 50 THEN
        SET signal_type_val = 'HOLD';
        SET confidence_val = (final_score - 50) / 25;
    ELSE
        SET signal_type_val = 'SELL';
        SET confidence_val = (50 - final_score) / 50;
    END IF;
    
    -- Ensure confidence is between 0 and 1
    SET confidence_val = GREATEST(0.1, LEAST(0.99, confidence_val));
    
    -- Generate reasoning text
    SET reasoning_text = CONCAT('Generated based on: Historical(', historical_score, '), Technical(', 
                             technical_score, '), Sector(', sector_score, '), Sentiment(', 
                             COALESCE(sentiment_score, 'N/A'), ')');
    
    -- Insert or update the signal
    INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, reasoning, valid_until)
    VALUES (stock_id_param, signal_type_val, confidence_val, reasoning_text, 
            DATE_ADD(NOW(), INTERVAL 30 DAY))
    ON DUPLICATE KEY UPDATE
        signal_type = signal_type_val,
        confidence_score = confidence_val,
        reasoning = reasoning_text,
        valid_until = DATE_ADD(NOW(), INTERVAL 30 DAY),
        is_active = TRUE,
        generated_at = CURRENT_TIMESTAMP;
    
END //
DELIMITER ;

-- Trigger to update portfolio value when holdings change
DELIMITER //
CREATE TRIGGER after_holding_update
AFTER UPDATE ON holdings
FOR EACH ROW
BEGIN
    CALL UpdatePortfolioValue(NEW.portfolio_id);
END //
DELIMITER ;

-- Trigger