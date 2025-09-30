-- IPM-55: Portfolio Management System Database Schema
-- MVP web application for managing client stock portfolios in Indian equity markets

-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS portfolio_transactions;
DROP TABLE IF EXISTS portfolio_holdings;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS equity_securities;
DROP TABLE IF EXISTS sectors;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS technical_indicators;
DROP TABLE IF EXISTS market_sentiment;

-- Users table with role-based access control
CREATE TABLE users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    role VARCHAR(20) CHECK(role IN ('client', 'advisor', 'admin')) DEFAULT 'client',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Sectors table for Indian equity market classification
CREATE TABLE sectors (
    sector_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sector_name VARCHAR(100) NOT NULL UNIQUE,
    sector_description TEXT,
    growth_potential_rating INTEGER CHECK(growth_potential_rating BETWEEN 1 AND 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Equity securities table focusing on Indian market
CREATE TABLE equity_securities (
    security_id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol VARCHAR(20) NOT NULL UNIQUE,
    company_name VARCHAR(200) NOT NULL,
    isin_code VARCHAR(12) NOT NULL UNIQUE,
    sector_id INTEGER NOT NULL,
    current_price DECIMAL(15,2) NOT NULL,
    previous_close DECIMAL(15,2),
    market_cap DECIMAL(20,2),
    pe_ratio DECIMAL(10,2),
    dividend_yield DECIMAL(5,2),
    listed_on DATE,
    exchange VARCHAR(10) CHECK(exchange IN ('NSE', 'BSE')) DEFAULT 'NSE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sector_id) REFERENCES sectors(sector_id)
);

-- Technical indicators table for signal generation
CREATE TABLE technical_indicators (
    indicator_id INTEGER PRIMARY KEY AUTOINCREMENT,
    security_id INTEGER NOT NULL,
    rsi DECIMAL(5,2) CHECK(rsi BETWEEN 0 AND 100),
    macd DECIMAL(8,4),
    macd_signal DECIMAL(8,4),
    moving_avg_50 DECIMAL(15,2),
    moving_avg_200 DECIMAL(15,2),
    bollinger_upper DECIMAL(15,2),
    bollinger_lower DECIMAL(15,2),
    stochastic_k DECIMAL(5,2),
    stochastic_d DECIMAL(5,2),
    calculated_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (security_id) REFERENCES equity_securities(security_id),
    UNIQUE(security_id, calculated_date)
);

-- Market sentiment table for buzz analysis
CREATE TABLE market_sentiment (
    sentiment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    security_id INTEGER NOT NULL,
    sentiment_score DECIMAL(5,2) CHECK(sentiment_score BETWEEN -1 AND 1),
    news_count INTEGER DEFAULT 0,
    social_mentions INTEGER DEFAULT 0,
    analyst_rating VARCHAR(10) CHECK(analyst_rating IN ('Strong Buy', 'Buy', 'Hold', 'Sell', 'Strong Sell')),
    measured_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (security_id) REFERENCES equity_securities(security_id),
    UNIQUE(security_id, measured_date)
);

-- Portfolios table for client investment management
CREATE TABLE portfolios (
    portfolio_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    initial_investment DECIMAL(15,2) DEFAULT 0,
    current_value DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    UNIQUE(user_id, portfolio_name)
);

-- Portfolio holdings table for current positions
CREATE TABLE portfolio_holdings (
    holding_id INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id INTEGER NOT NULL,
    security_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    average_buy_price DECIMAL(15,2) NOT NULL,
    current_value DECIMAL(15,2),
    unrealized_pnl DECIMAL(15,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id),
    FOREIGN KEY (security_id) REFERENCES equity_securities(security_id),
    UNIQUE(portfolio_id, security_id)
);

-- Portfolio transactions table for audit trail
CREATE TABLE portfolio_transactions (
    transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id INTEGER NOT NULL,
    security_id INTEGER NOT NULL,
    transaction_type VARCHAR(10) CHECK(transaction_type IN ('BUY', 'SELL')) NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    price DECIMAL(15,2) NOT NULL,
    transaction_date DATE NOT NULL,
    brokerage DECIMAL(10,2) DEFAULT 0,
    taxes DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(portfolio_id),
    FOREIGN KEY (security_id) REFERENCES equity_securities(security_id)
);

-- Advisory signals table for Buy/Hold/Sell recommendations
CREATE TABLE advisory_signals (
    signal_id INTEGER PRIMARY KEY AUTOINCREMENT,
    security_id INTEGER NOT NULL,
    signal_type VARCHAR(10) CHECK(signal_type IN ('BUY', 'HOLD', 'SELL')) NOT NULL,
    confidence_score DECIMAL(5,2) CHECK(confidence_score BETWEEN 0 AND 1),
    reasoning TEXT NOT NULL,
    generated_by INTEGER NOT NULL,
    valid_until DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (security_id) REFERENCES equity_securities(security_id),
    FOREIGN KEY (generated_by) REFERENCES users(user_id)
);

-- Indexes for performance optimization
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_equity_sector ON equity_securities(sector_id);
CREATE INDEX idx_equity_symbol ON equity_securities(symbol);
CREATE INDEX idx_equity_exchange ON equity_securities(exchange);
CREATE INDEX idx_portfolio_user ON portfolios(user_id);
CREATE INDEX idx_holdings_portfolio ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_holdings_security ON portfolio_holdings(security_id);
CREATE INDEX idx_transactions_portfolio ON portfolio_transactions(portfolio_id);
CREATE INDEX idx_transactions_security ON portfolio_transactions(security_id);
CREATE INDEX idx_transactions_date ON portfolio_transactions(transaction_date);
CREATE INDEX idx_signals_security ON advisory_signals(security_id);
CREATE INDEX idx_signals_type ON advisory_signals(signal_type);
CREATE INDEX idx_technical_security_date ON technical_indicators(security_id, calculated_date);
CREATE INDEX idx_sentiment_security_date ON market_sentiment(security_id, measured_date);

-- Views for common queries

-- Portfolio summary view
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.user_id,
    p.portfolio_name,
    p.initial_investment,
    p.current_value,
    COUNT(h.holding_id) as number_of_holdings,
    COALESCE(SUM(h.current_value), 0) as total_current_value,
    COALESCE(SUM(h.unrealized_pnl), 0) as total_unrealized_pnl,
    p.created_at,
    p.updated_at
FROM portfolios p
LEFT JOIN portfolio_holdings h ON p.portfolio_id = h.portfolio_id
GROUP BY p.portfolio_id;

-- Security performance view
CREATE VIEW security_performance AS
SELECT 
    es.security_id,
    es.symbol,
    es.company_name,
    s.sector_name,
    es.current_price,
    es.previous_close,
    ROUND(((es.current_price - es.previous_close) / es.previous_close) * 100, 2) as daily_change_percent,
    ti.rsi,
    ti.macd,
    ms.sentiment_score,
    a.signal_type as latest_signal
FROM equity_securities es
JOIN sectors s ON es.sector_id = s.sector_id
LEFT JOIN technical_indicators ti ON es.security_id = ti.security_id 
    AND ti.calculated_date = (SELECT MAX(calculated_date) FROM technical_indicators WHERE security_id = es.security_id)
LEFT JOIN market_sentiment ms ON es.security_id = ms.security_id 
    AND ms.measured_date = (SELECT MAX(measured_date) FROM market_sentiment WHERE security_id = es.security_id)
LEFT JOIN advisory_signals a ON es.security_id = a.security_id 
    AND a.created_at = (SELECT MAX(created_at) FROM advisory_signals WHERE security_id = es.security_id);

-- Insert dummy data for MVP testing

-- Insert sectors
INSERT INTO sectors (sector_name, sector_description, growth_potential_rating) VALUES
('Information Technology', 'Software services, IT consulting, and technology solutions', 4),
('Banking & Financial Services', 'Banks, NBFCs, insurance companies, and financial institutions', 3),
('Pharmaceuticals', 'Drug manufacturers, biotechnology, and healthcare products', 4),
('Automobile', 'Automobile manufacturers and ancillary industries', 3),
('Fast Moving Consumer Goods', 'Consumer products, food, and beverages', 3),
('Energy', 'Oil & gas, power generation, and renewable energy', 2),
('Telecommunications', 'Telecom services and infrastructure', 3),
('Infrastructure', 'Construction, engineering, and infrastructure development', 4);

-- Insert sample users
INSERT INTO users (username, email, password_hash, first_name, last_name, role) VALUES
('advisor1', 'advisor1@example.com', 'hashed_password_1', 'Rajesh', 'Sharma', 'advisor'),
('client1', 'client1@example.com', 'hashed_password_2', 'Priya', 'Patel', 'client'),
('client2', 'client2@example.com', 'hashed_password_3', 'Amit', 'Kumar', 'client'),
('admin1', 'admin1@example.com', 'hashed_password_4', 'Sneha', 'Desai', 'admin');

-- Insert sample equity securities (Indian market focus)
INSERT INTO equity_securities (symbol, company_name, isin_code, sector_id, current_price, previous_close, market_cap, pe_ratio, dividend_yield, exchange) VALUES
('INFY', 'Infosys Limited', 'INE009A01021', 1, 1850.50, 1820.75, 7500000000000, 28.5, 1.2, 'NSE'),
('TCS', 'Tata Consultancy Services', 'INE467B01029', 1, 3450.25, 3420.00, 12500000000000, 30.2, 1.5, 'NSE'),
('HDFCBANK', 'HDFC Bank Limited', 'INE040A01026', 2, 1650.75, 1635.50, 9000000000000, 22.8, 0.8, 'NSE'),
('ICICIBANK', 'ICICI Bank Limited', 'INE090A01021', 2, 950.20, 945.75, 6500000000000, 20.1, 0.6, 'NSE'),
('SUNPHARMA', 'Sun Pharmaceutical Industries', 'INE044A01036', 3, 1025.80, 1015.25, 2500000000000, 25.3, 1.1, 'NSE'),
('MARUTI', 'Maruti Suzuki India', 'INE585B01010', 4, 8750.00, 8680.50, 2600000000000, 28.7, 0.9, 'NSE'),
('HINDUNILVR', 'Hindustan Unilever', 'INE030A01027', 5, 2450.30, 2435.75, 5500000000000, 65.2, 1.4, 'NSE'),
('RELIANCE', 'Reliance Industries', 'INE002A01018', 6, 2650.45, 2625.80, 17500000000000, 27.8, 0.7, 'NSE');

-- Insert sample technical indicators
INSERT INTO technical_indicators (security_id, rsi, macd, macd_signal, moving_avg_50, moving_avg_200, calculated_date) VALUES
(1, 62.5, 12.34, 11.89, 1800.25, 1750.80, date('now')),
(2, 58.2, 23.45, 22.10, 3400.50, 3350.25, date('now')),
(3, 45.8, -5.67, -4.89, 1620.75, 1580.30, date('now')),
(4, 52.1, 8.91, 7.65, 930.40, 910.25, date('now')),
(5, 68.9, 15.78, 14.23, 1000.50, 980.75, date('now'));

-- Insert sample market sentiment data
INSERT INTO market_sentiment (security_id, sentiment_score, news_count, social_mentions, analyst_rating, measured_date) VALUES
(1, 0.75, 15, 120, 'Buy', date('now')),
(2, 0.65, 12, 95, 'Hold', date('now')),
(3, 0.45, 8, 60, 'Hold', date('now')),
(4, 0.55, 10, 75, 'Buy', date('now')),
(5, 0.82, 18, 150, 'Strong Buy', date('now'));

-- Insert sample portfolios
INSERT INTO portfolios (user_id, portfolio_name, description, initial_investment, current_value) VALUES
(2, 'Long-Term Growth', 'Focus on growth stocks for long-term appreciation', 500000, 525000),
(2, 'Dividend Portfolio', 'Income-focused portfolio with dividend stocks', 300000, 315000),
(3, 'Retirement Fund', 'Conservative portfolio for retirement planning', 1000000, 1025000);

-- Insert sample portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, security_id, quantity, average_buy_price, current_value, unrealized_pnl) VALUES
(1, 1, 100, 1700.00, 185050, 15050),
(1, 3, 200, 1550.00, 330150, 20150),
(2, 5, 150, 950.00, 153870, 8870),
(2, 7, 100, 2350.00, 245030, 10030),
(3, 2, 50, 3300.00, 172512, 7512),
(3, 8, 200, 2500.00, 530090, 30090);

-- Insert sample transactions
INSERT INTO portfolio_transactions (portfolio_id, security_id, transaction_type, quantity, price, transaction_date, total_amount) VALUES
(1, 1, 'BUY', 100, 1700.00, date('now', '-30 days'), 170000),
(1, 3, 'BUY', 200, 1550.00, date('now', '-25 days'), 310000),
(2, 5, 'BUY', 150, 950.00, date('now', '-20 days'), 142500),
(2, 7, 'BUY', 100, 2350.00, date('now', '-15 days'), 235000),
(3, 2, 'BUY', 50, 3300.00, date('now', '-10 days'), 165000),
(3, 8, 'BUY', 200, 2500.00, date('now', '-5 days'), 500000);

-- Insert sample advisory signals
INSERT INTO advisory_signals (security_id, signal_type, confidence_score, reasoning, generated_by, valid_until) VALUES
(1, 'BUY', 0.85, 'Strong technical indicators combined with positive sector outlook and high market sentiment', 1, date('now', '+7 days')),
(5, 'STRONG BUY', 0.92, 'Excellent fundamentals, oversold condition, and very positive market buzz', 1, date('now', '+5 days')),
(3, 'HOLD', 0.68, 'Neutral technical signals with mixed market sentiment, wait for clearer direction', 1, date('now', '+3 days')),
(8, 'BUY', 0.78, 'Strong sector potential and improving technical indicators', 1, date('now', '+10 days'));

-- Stored procedures for common operations

-- Procedure to update portfolio current value
CREATE PROCEDURE update_portfolio_value(IN portfolio_id_param INTEGER)
BEGIN
    UPDATE portfolios 
    SET current_value = (
        SELECT COALESCE(SUM(h.current_value), 0)
        FROM portfolio_holdings h
        WHERE h.portfolio_id = portfolio_id_param
    ),
    updated_at = CURRENT_TIMESTAMP
    WHERE portfolio_id = portfolio_id_param;
END;

-- Procedure to add new transaction and update holdings
CREATE PROCEDURE add_transaction(
    IN portfolio_id_param INTEGER,
    IN security_id_param INTEGER,
    IN transaction_type_param VARCHAR(10),
    IN quantity_param