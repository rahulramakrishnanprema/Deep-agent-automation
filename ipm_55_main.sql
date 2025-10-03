-- IPM-55: Database Schema for Indian Equity Portfolio Management System
-- This SQL file creates the complete database schema for the MVP web application
-- that manages client stock portfolios in Indian equity markets with advisory signals

-- Database: portfolio_management
CREATE DATABASE IF NOT EXISTS portfolio_management;
USE portfolio_management;

-- Table: users - Stores user information with role-based access control
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    role ENUM('advisor', 'client') NOT NULL DEFAULT 'client',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_role (role),
    INDEX idx_user_active (is_active)
);

-- Table: clients - Extended client information
CREATE TABLE clients (
    client_id INT PRIMARY KEY,
    pan_number VARCHAR(10) UNIQUE NOT NULL,
    phone_number VARCHAR(15),
    address TEXT,
    risk_profile ENUM('LOW', 'MEDIUM', 'HIGH') DEFAULT 'MEDIUM',
    investment_horizon ENUM('SHORT', 'MEDIUM', 'LONG') DEFAULT 'MEDIUM',
    total_investment_value DECIMAL(15,2) DEFAULT 0.00,
    FOREIGN KEY (client_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_client_risk (risk_profile),
    INDEX idx_client_horizon (investment_horizon)
);

-- Table: advisors - Extended advisor information
CREATE TABLE advisors (
    advisor_id INT PRIMARY KEY,
    employee_id VARCHAR(20) UNIQUE NOT NULL,
    department VARCHAR(50),
    specialization VARCHAR(100),
    years_of_experience INT DEFAULT 0,
    FOREIGN KEY (advisor_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_advisor_dept (department)
);

-- Table: client_advisor_mapping - Relationship between clients and advisors
CREATE TABLE client_advisor_mapping (
    mapping_id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    advisor_id INT NOT NULL,
    assigned_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    FOREIGN KEY (advisor_id) REFERENCES advisors(advisor_id) ON DELETE CASCADE,
    UNIQUE KEY unique_client_advisor (client_id, advisor_id),
    INDEX idx_mapping_active (is_active)
);

-- Table: sectors - Indian market sectors
CREATE TABLE sectors (
    sector_id INT AUTO_INCREMENT PRIMARY KEY,
    sector_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    market_cap_category ENUM('LARGE', 'MID', 'SMALL') DEFAULT 'MID',
    growth_potential ENUM('LOW', 'MEDIUM', 'HIGH') DEFAULT 'MEDIUM',
    INDEX idx_sector_market_cap (market_cap_category),
    INDEX idx_sector_growth (growth_potential)
);

-- Table: stocks - Indian equity stocks with sector classification
CREATE TABLE stocks (
    stock_id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector_id INT NOT NULL,
    current_price DECIMAL(10,2) NOT NULL,
    previous_close DECIMAL(10,2) NOT NULL,
    market_cap DECIMAL(15,2),
    pe_ratio DECIMAL(10,2),
    dividend_yield DECIMAL(5,2),
    volume BIGINT DEFAULT 0,
    beta DECIMAL(5,2) DEFAULT 1.0,
    is_nifty50 BOOLEAN DEFAULT FALSE,
    is_nifty_next50 BOOLEAN DEFAULT FALSE,
    is_nifty_midcap150 BOOLEAN DEFAULT FALSE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sector_id) REFERENCES sectors(sector_id) ON DELETE RESTRICT,
    INDEX idx_stock_symbol (symbol),
    INDEX idx_stock_sector (sector_id),
    INDEX idx_stock_nifty (is_nifty50),
    INDEX idx_stock_price (current_price)
);

-- Table: stock_history - Historical price data for technical analysis
CREATE TABLE stock_history (
    history_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    date DATE NOT NULL,
    open_price DECIMAL(10,2) NOT NULL,
    high_price DECIMAL(10,2) NOT NULL,
    low_price DECIMAL(10,2) NOT NULL,
    close_price DECIMAL(10,2) NOT NULL,
    volume BIGINT NOT NULL,
    adj_close DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE KEY unique_stock_date (stock_id, date),
    INDEX idx_history_date (date),
    INDEX idx_history_stock (stock_id)
);

-- Table: technical_indicators - Pre-calculated technical indicators
CREATE TABLE technical_indicators (
    indicator_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    date DATE NOT NULL,
    sma_20 DECIMAL(10,2),
    sma_50 DECIMAL(10,2),
    sma_200 DECIMAL(10,2),
    rsi_14 DECIMAL(5,2),
    macd DECIMAL(8,4),
    macd_signal DECIMAL(8,4),
    macd_histogram DECIMAL(8,4),
    bollinger_upper DECIMAL(10,2),
    bollinger_lower DECIMAL(10,2),
    stochastic_k DECIMAL(5,2),
    stochastic_d DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE KEY unique_indicator_stock_date (stock_id, date),
    INDEX idx_indicators_date (date),
    INDEX idx_indicators_stock (stock_id)
);

-- Table: market_buzz - Social media and news sentiment data
CREATE TABLE market_buzz (
    buzz_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    buzz_date DATE NOT NULL,
    sentiment_score DECIMAL(5,2) DEFAULT 0.00,
    news_count INT DEFAULT 0,
    social_mentions INT DEFAULT 0,
    analyst_rating ENUM('STRONG_BUY', 'BUY', 'HOLD', 'SELL', 'STRONG_SELL') DEFAULT 'HOLD',
    buzz_trend ENUM('POSITIVE', 'NEUTRAL', 'NEGATIVE') DEFAULT 'NEUTRAL',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE KEY unique_buzz_stock_date (stock_id, buzz_date),
    INDEX idx_buzz_date (buzz_date),
    INDEX idx_buzz_sentiment (sentiment_score)
);

-- Table: portfolios - Main portfolio table for clients
CREATE TABLE portfolios (
    portfolio_id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    total_value DECIMAL(15,2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    INDEX idx_portfolio_client (client_id),
    INDEX idx_portfolio_active (is_active)
);

-- Table: portfolio_holdings - Individual stock holdings within portfolios
CREATE TABLE portfolio_holdings (
    holding_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT NOT NULL,
    stock_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    average_buy_price DECIMAL(10,2) NOT NULL,
    current_value DECIMAL(15,2) DEFAULT 0.00,
    purchase_date DATE NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE RESTRICT,
    UNIQUE KEY unique_portfolio_stock (portfolio_id, stock_id),
    INDEX idx_holdings_portfolio (portfolio_id),
    INDEX idx_holdings_stock (stock_id)
);

-- Table: transactions - Buy/sell transaction history
CREATE TABLE transactions (
    transaction_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT NOT NULL,
    stock_id INT NOT NULL,
    transaction_type ENUM('BUY', 'SELL') NOT NULL,
    quantity INT NOT NULL,
    price_per_share DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(15,2) NOT NULL,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    broker_fee DECIMAL(10,2) DEFAULT 0.00,
    taxes DECIMAL(10,2) DEFAULT 0.00,
    notes TEXT,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE RESTRICT,
    INDEX idx_transactions_portfolio (portfolio_id),
    INDEX idx_transactions_stock (stock_id),
    INDEX idx_transactions_date (transaction_date),
    INDEX idx_transactions_type (transaction_type)
);

-- Table: advisory_signals - Generated Buy/Hold/Sell signals
CREATE TABLE advisory_signals (
    signal_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    stock_id INT NOT NULL,
    signal_date DATE NOT NULL,
    signal_type ENUM('BUY', 'HOLD', 'SELL') NOT NULL,
    confidence_score DECIMAL(5,2) DEFAULT 0.00,
    reasoning TEXT NOT NULL,
    historical_performance_score DECIMAL(5,2),
    technical_indicators_score DECIMAL(5,2),
    sector_potential_score DECIMAL(5,2),
    market_buzz_score DECIMAL(5,2),
    generated_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    FOREIGN KEY (generated_by) REFERENCES advisors(advisor_id) ON DELETE CASCADE,
    INDEX idx_signals_stock (stock_id),
    INDEX idx_signals_date (signal_date),
    INDEX idx_signals_type (signal_type),
    INDEX idx_signals_advisor (generated_by)
);

-- Table: portfolio_signals - Signals applied to specific portfolio holdings
CREATE TABLE portfolio_signals (
    portfolio_signal_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    portfolio_id INT NOT NULL,
    signal_id BIGINT NOT NULL,
    holding_id BIGINT NOT NULL,
    applied_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('PENDING', 'ACCEPTED', 'REJECTED', 'IMPLEMENTED') DEFAULT 'PENDING',
    advisor_notes TEXT,
    client_feedback TEXT,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (signal_id) REFERENCES advisory_signals(signal_id) ON DELETE CASCADE,
    FOREIGN KEY (holding_id) REFERENCES portfolio_holdings(holding_id) ON DELETE CASCADE,
    INDEX idx_portfolio_signal_status (status),
    INDEX idx_portfolio_signal_applied (applied_date)
);

-- Table: analytics_reports - Advisor-only visual reports metadata
CREATE TABLE analytics_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    report_name VARCHAR(200) NOT NULL,
    report_type ENUM('PORTFOLIO', 'SECTOR', 'MARKET', 'PERFORMANCE') NOT NULL,
    generated_by INT NOT NULL,
    generated_for INT NULL,
    parameters JSON NOT NULL,
    report_data JSON NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    is_archived BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (generated_by) REFERENCES advisors(advisor_id) ON DELETE CASCADE,
    FOREIGN KEY (generated_for) REFERENCES clients(client_id) ON DELETE SET NULL,
    INDEX idx_reports_type (report_type),
    INDEX idx_reports_generated (generated_at),
    INDEX idx_reports_advisor (generated_by)
);

-- Table: audit_log - System audit trail
CREATE TABLE audit_log (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    action_type VARCHAR(100) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id VARCHAR(100) NOT NULL,
    old_values JSON NULL,
    new_values JSON NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_user (user_id),
    INDEX idx_audit_action (action_type),
    INDEX idx_audit_timestamp (timestamp)
);

-- Views for common queries

-- View: portfolio_summary_view
CREATE VIEW portfolio_summary_view AS
SELECT 
    p.portfolio_id,
    p.client_id,
    u.first_name,
    u.last_name,
    p.portfolio_name,
    p.total_value,
    COUNT(ph.holding_id) as number_of_holdings,
    MAX(ph.last_updated) as last_updated
FROM portfolios p
JOIN clients c ON p.client_id = c.client_id
JOIN users u ON c.client_id = u.user_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
WHERE p.is_active = TRUE
GROUP BY p.portfolio_id, p.client_id, u.first_name, u.last_name, p.portfolio_name, p.total_value;

-- View: stock_signals_view
CREATE VIEW stock_signals_view AS
SELECT 
    s.signal_id,
    s.stock_id,
    st.symbol,
    st.company_name,
    s.signal_date,
    s.signal_type,
    s.confidence_score,
    s.reasoning,
    a.advisor_id,
    u.first_name as advisor_first_name,
    u.last_name as advisor_last_name
FROM advisory_signals s
JOIN stocks st ON s.stock_id = st.stock_id
JOIN advisors a ON s.generated_by = a.advisor_id
JOIN users u ON a.advisor_id = u.user_id
WHERE s.expires_at IS NULL OR s.expires_at > CURRENT_TIMESTAMP;

-- View: portfolio_performance_view
CREATE VIEW portfolio_performance_view AS
SELECT 
    p.portfolio_id,
    p.client_id,
    p.portfolio_name,
    p.total_value,
    SUM(ph.quantity * st.current_price) as current_market_value,
    SUM(ph.quantity * ph.average_buy_price) as total_investment,
    (SUM(ph.quantity * st.current_price) - SUM(ph.quantity * ph.average_buy_price)) as unrealized_pnl,
    ((SUM(ph.quantity * st.current_price) - SUM(ph.quantity * ph.average_buy_price)) / SUM(ph.quantity * ph.average_buy_price)) * 100 as return_percentage
FROM portfolios p
JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
JOIN stocks st ON ph.stock_id = st.stock_id
WHERE p.is_active = TRUE
GROUP BY p.portfolio_id, p.client_id, p.portfolio_name, p.total_value;

-- Stored Procedures

-- Procedure: Calculate portfolio value
DELIMITER //
CREATE PROCEDURE UpdatePortfolioValue(IN portfolio_id_param INT)
BEGIN
    UPDATE portfolios p
    SET p.total_value = (
        SELECT COALESCE(SUM(ph.quantity * s.current_price), 0)
        FROM portfolio_holdings ph
        JOIN stocks s ON ph.stock_id = s.stock_id
        WHERE ph.portfolio_id = portfolio_id_param
    ),
    p.last_updated = CURRENT_TIMESTAMP
    WHERE p.portfolio_id = portfolio_id_param;
END //
DELIMITER ;

-- Procedure: Generate advisory signal
DELIMITER //
CREATE PROCEDURE GenerateAdvisorySignal(
    IN stock_id_param INT,
    IN advisor_id_param INT,
    IN historical_weight DECIMAL(5,2),
    IN technical_weight DECIMAL(5,2),
    IN sector_weight DECIMAL(5,2),
    IN buzz_weight DECIMAL(5,2)
)
BEGIN
    DECLARE historical_score DECIMAL(5,2);
    DECLARE technical_score DECIMAL(5,2);
    DECLARE sector_score DECIMAL(5,2);
    DECLARE buzz_score DECIMAL(5,2);
    DECLARE final_score DECIMAL(5,2);
    DECLARE signal_type_val ENUM('BUY', 'HOLD', 'SELL');
    DECLARE reasoning_text TEXT;
    
    -- Calculate individual scores (simplified for MVP)
    SELECT COALESCE(AVG((close_price - open_price) / open_price * 100), 0) INTO historical_score
    FROM stock_history 
    WHERE stock_id = stock_id_param AND date >= DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY);
    
    SELECT COALESCE(AVG(rsi_14), 50) INTO technical_score
    FROM technical_indicators 
    WHERE stock_id = stock_id_param AND date >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY);
    
    SELECT COALESCE(growth_potential_score, 0.5) INTO sector_score
    FROM sectors s
    JOIN stocks st ON s.sector_id = st.sector_id
    WHERE st.stock_id = stock_id_param;
    
    SELECT COALESCE(AVG(sentiment_score), 0) INTO buzz_score
    FROM market_buzz 
    WHERE stock_id = stock_id_param AND buzz_date >= DATE_SUB(CURRENT_DATE, INTERVAL 3 DAY);
    
    -- Calculate final weighted score
    SET final_score = (historical_score * historical_weight + 
                      technical_score * technical_weight + 
                      sector_score * sector_weight + 
                      buzz_score * buzz_weight);
    
    -- Determine signal type based on final score
    IF final_score >= 70 THEN
        SET signal_type_val = 'BUY';
        SET reasoning_text = CONCAT('Strong