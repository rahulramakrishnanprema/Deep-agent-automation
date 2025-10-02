-- IPM-55: Portfolio Management Database Schema
-- MVP web application for managing client stock portfolios in Indian equity markets
-- Features advisory signals and advisor-only reports with dummy data

-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS portfolio_holdings;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS sectors;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS advisors;
DROP TABLE IF EXISTS users;

-- Users table for authentication/authorization
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    user_type VARCHAR(20) CHECK (user_type IN ('advisor', 'admin')) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Advisors table (extends users for advisor-specific data)
CREATE TABLE advisors (
    advisor_id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    license_number VARCHAR(100),
    experience_years INTEGER,
    specialization VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clients table
CREATE TABLE clients (
    client_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    risk_profile VARCHAR(20) CHECK (risk_profile IN ('conservative', 'moderate', 'aggressive')),
    investment_horizon VARCHAR(20) CHECK (investment_horizon IN ('short', 'medium', 'long')),
    total_investment_value DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sectors table for sector analysis
CREATE TABLE sectors (
    sector_id SERIAL PRIMARY KEY,
    sector_name VARCHAR(100) UNIQUE NOT NULL,
    sector_description TEXT,
    growth_potential VARCHAR(20) CHECK (growth_potential IN ('low', 'medium', 'high')),
    market_buzz_score INTEGER CHECK (market_buzz_score BETWEEN 1 AND 10),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stocks table for Indian equity market data
CREATE TABLE stocks (
    stock_id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector_id INTEGER REFERENCES sectors(sector_id) ON DELETE SET NULL,
    current_price DECIMAL(10,2) NOT NULL,
    day_high DECIMAL(10,2),
    day_low DECIMAL(10,2),
    volume BIGINT,
    market_cap DECIMAL(15,2),
    pe_ratio DECIMAL(10,2),
    dividend_yield DECIMAL(5,2),
    beta DECIMAL(5,2),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolios table for client portfolio management
CREATE TABLE portfolios (
    portfolio_id SERIAL PRIMARY KEY,
    client_id INTEGER REFERENCES clients(client_id) ON DELETE CASCADE,
    advisor_id INTEGER REFERENCES advisors(advisor_id) ON DELETE SET NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    total_value DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio holdings table
CREATE TABLE portfolio_holdings (
    holding_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    stock_id INTEGER REFERENCES stocks(stock_id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    purchase_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    current_value DECIMAL(15,2) GENERATED ALWAYS AS (quantity * (SELECT current_price FROM stocks WHERE stocks.stock_id = portfolio_holdings.stock_id)) STORED,
    unrealized_gain_loss DECIMAL(15,2) GENERATED ALWAYS AS (quantity * ((SELECT current_price FROM stocks WHERE stocks.stock_id = portfolio_holdings.stock_id) - purchase_price)) STORED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, stock_id)
);

-- Advisory signals table for generated investment recommendations
CREATE TABLE advisory_signals (
    signal_id SERIAL PRIMARY KEY,
    stock_id INTEGER REFERENCES stocks(stock_id) ON DELETE CASCADE,
    signal_type VARCHAR(50) CHECK (signal_type IN ('buy', 'sell', 'hold', 'strong_buy', 'strong_sell')),
    confidence_score DECIMAL(5,2) CHECK (confidence_score BETWEEN 0 AND 100),
    rationale TEXT NOT NULL,
    historical_performance_score INTEGER CHECK (historical_performance_score BETWEEN 1 AND 10),
    technical_indicator_score INTEGER CHECK (technical_indicator_score BETWEEN 1 AND 10),
    sector_potential_score INTEGER CHECK (sector_potential_score BETWEEN 1 AND 10),
    market_buzz_score INTEGER CHECK (market_buzz_score BETWEEN 1 AND 10),
    target_price DECIMAL(10,2),
    stop_loss DECIMAL(10,2),
    time_horizon VARCHAR(20) CHECK (time_horizon IN ('short_term', 'medium_term', 'long_term')),
    generated_by INTEGER REFERENCES advisors(advisor_id) ON DELETE SET NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Indexes for performance optimization
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_advisors_user_id ON advisors(user_id);
CREATE INDEX idx_clients_email ON clients(email);
CREATE INDEX idx_stocks_symbol ON stocks(symbol);
CREATE INDEX idx_stocks_sector_id ON stocks(sector_id);
CREATE INDEX idx_portfolios_client_id ON portfolios(client_id);
CREATE INDEX idx_portfolios_advisor_id ON portfolios(advisor_id);
CREATE INDEX idx_portfolio_holdings_portfolio_id ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_portfolio_holdings_stock_id ON portfolio_holdings(stock_id);
CREATE INDEX idx_advisory_signals_stock_id ON advisory_signals(stock_id);
CREATE INDEX idx_advisory_signals_signal_type ON advisory_signals(signal_type);
CREATE INDEX idx_advisory_signals_generated_at ON advisory_signals(generated_at);

-- Views for common queries
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.client_id,
    c.first_name || ' ' || c.last_name AS client_name,
    p.portfolio_name,
    p.total_value,
    COUNT(ph.holding_id) AS number_of_holdings,
    p.created_at,
    p.updated_at
FROM portfolios p
JOIN clients c ON p.client_id = c.client_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
GROUP BY p.portfolio_id, c.first_name, c.last_name;

CREATE VIEW advisor_clients AS
SELECT 
    a.advisor_id,
    u.username AS advisor_username,
    a.first_name || ' ' || a.last_name AS advisor_name,
    c.client_id,
    c.first_name || ' ' || c.last_name AS client_name,
    c.risk_profile,
    c.total_investment_value
FROM advisors a
JOIN users u ON a.user_id = u.user_id
JOIN portfolios p ON a.advisor_id = p.advisor_id
JOIN clients c ON p.client_id = c.client_id;

CREATE VIEW stock_performance AS
SELECT 
    s.stock_id,
    s.symbol,
    s.company_name,
    s.current_price,
    sec.sector_name,
    s.pe_ratio,
    s.dividend_yield,
    COALESCE(AVG(asig.confidence_score), 0) AS avg_signal_confidence,
    COUNT(asig.signal_id) AS signal_count
FROM stocks s
LEFT JOIN sectors sec ON s.sector_id = sec.sector_id
LEFT JOIN advisory_signals asig ON s.stock_id = asig.stock_id AND asig.is_active = TRUE
GROUP BY s.stock_id, sec.sector_name;

-- Insert dummy data for testing and demonstration
-- Insert users (advisors)
INSERT INTO users (username, email, password_hash, user_type, is_active) VALUES
('advisor1', 'advisor1@example.com', 'hashed_password_1', 'advisor', TRUE),
('advisor2', 'advisor2@example.com', 'hashed_password_2', 'advisor', TRUE),
('admin1', 'admin@example.com', 'hashed_admin_password', 'admin', TRUE);

-- Insert advisors
INSERT INTO advisors (user_id, first_name, last_name, license_number, experience_years, specialization) VALUES
(1, 'Rajesh', 'Sharma', 'SEBI123456', 8, 'Equity Markets'),
(2, 'Priya', 'Patel', 'SEBI654321', 5, 'Portfolio Management');

-- Insert sectors
INSERT INTO sectors (sector_name, sector_description, growth_potential, market_buzz_score) VALUES
('Information Technology', 'Software services and IT consulting', 'high', 8),
('Banking & Financial Services', 'Banks, NBFCs, and financial institutions', 'medium', 7),
('Pharmaceuticals', 'Drug manufacturers and healthcare', 'high', 6),
('Automobile', 'Auto manufacturers and components', 'medium', 5),
('Consumer Goods', 'FMCG and consumer products', 'medium', 4);

-- Insert stocks
INSERT INTO stocks (symbol, company_name, sector_id, current_price, day_high, day_low, volume, market_cap, pe_ratio, dividend_yield, beta) VALUES
('INFY', 'Infosys Limited', 1, 1850.50, 1865.00, 1830.25, 4523100, 750000, 28.5, 2.1, 0.95),
('TCS', 'Tata Consultancy Services', 1, 3450.75, 3475.50, 3420.00, 3215800, 1300000, 30.2, 1.8, 0.92),
('HDFCBANK', 'HDFC Bank Limited', 2, 1650.25, 1665.75, 1635.00, 7854200, 900000, 22.8, 1.2, 1.05),
('ICICIBANK', 'ICICI Bank Limited', 2, 950.80, 965.40, 940.25, 6523100, 650000, 20.1, 0.9, 1.08),
('SUNPHARMA', 'Sun Pharmaceutical Industries', 3, 1025.60, 1040.00, 1015.25, 3214500, 230000, 25.6, 1.5, 0.88),
('MARUTI', 'Maruti Suzuki India', 4, 8750.00, 8820.50, 8685.75, 1542300, 260000, 28.9, 0.8, 1.12),
('ITC', 'ITC Limited', 5, 425.75, 432.00, 420.50, 4521800, 350000, 24.3, 3.2, 0.85);

-- Insert clients
INSERT INTO clients (first_name, last_name, email, phone, risk_profile, investment_horizon, total_investment_value) VALUES
('Amit', 'Kumar', 'amit.kumar@example.com', '+91-9876543210', 'moderate', 'medium', 500000.00),
('Neha', 'Singh', 'neha.singh@example.com', '+91-8765432109', 'conservative', 'long', 750000.00),
('Vikram', 'Malhotra', 'vikram.m@example.com', '+91-7654321098', 'aggressive', 'short', 300000.00);

-- Insert portfolios
INSERT INTO portfolios (client_id, advisor_id, portfolio_name, description, total_value) VALUES
(1, 1, 'Growth Portfolio', 'Moderate risk growth-oriented portfolio', 250000.00),
(2, 1, 'Conservative Income', 'Low risk income generating portfolio', 500000.00),
(3, 2, 'Aggressive Growth', 'High risk high return portfolio', 150000.00);

-- Insert portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, purchase_price, purchase_date) VALUES
(1, 1, 50, 1800.00, '2023-01-15'),
(1, 3, 75, 1600.00, '2023-02-20'),
(1, 5, 100, 950.00, '2023-03-10'),
(2, 2, 30, 3400.00, '2023-01-10'),
(2, 4, 200, 900.00, '2023-02-05'),
(2, 7, 500, 400.00, '2023-03-20'),
(3, 1, 25, 1750.00, '2023-04-01'),
(3, 6, 10, 8500.00, '2023-04-15');

-- Insert advisory signals
INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, rationale, historical_performance_score, technical_indicator_score, sector_potential_score, market_buzz_score, target_price, stop_loss, time_horizon, generated_by, expires_at) VALUES
(1, 'buy', 85.5, 'Strong earnings growth and positive sector outlook', 9, 8, 8, 7, 2000.00, 1750.00, 'medium_term', 1, CURRENT_TIMESTAMP + INTERVAL '30 days'),
(2, 'hold', 65.0, 'Stable performance but limited upside potential', 7, 6, 7, 6, 3550.00, 3300.00, 'short_term', 1, CURRENT_TIMESTAMP + INTERVAL '15 days'),
(3, 'strong_buy', 92.0, 'Excellent fundamentals and sector tailwinds', 9, 9, 8, 8, 1800.00, 1550.00, 'long_term', 2, CURRENT_TIMESTAMP + INTERVAL '45 days'),
(5, 'buy', 78.0, 'Undervalued with strong growth potential', 8, 7, 9, 6, 1200.00, 950.00, 'medium_term', 1, CURRENT_TIMESTAMP + INTERVAL '30 days');

-- Update portfolio total values based on holdings
UPDATE portfolios p
SET total_value = (
    SELECT COALESCE(SUM(ph.current_value), 0)
    FROM portfolio_holdings ph
    WHERE ph.portfolio_id = p.portfolio_id
),
updated_at = CURRENT_TIMESTAMP;

-- Update client total investment values
UPDATE clients c
SET total_investment_value = (
    SELECT COALESCE(SUM(p.total_value), 0)
    FROM portfolios p
    WHERE p.client_id = c.client_id
),
updated_at = CURRENT_TIMESTAMP;

-- Function to update stock prices (for dummy data updates)
CREATE OR REPLACE FUNCTION update_stock_prices()
RETURNS TRIGGER AS $$
BEGIN
    -- Random price fluctuation between -2% and +2%
    NEW.current_price := OLD.current_price * (0.98 + RANDOM() * 0.04);
    NEW.day_high := GREATEST(NEW.current_price, OLD.day_high);
    NEW.day_low := LEAST(NEW.current_price, OLD.day_low);
    NEW.last_updated := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for periodic stock price updates (simulated)
CREATE TRIGGER trigger_update_stock_prices
    BEFORE UPDATE ON stocks
    FOR EACH ROW
    EXECUTE FUNCTION update_stock_prices();

-- Function to get portfolio performance
CREATE OR REPLACE FUNCTION get_portfolio_performance(portfolio_id INTEGER)
RETURNS TABLE (
    total_value DECIMAL(15,2),
    total_investment DECIMAL(15,2),
    total_gain_loss DECIMAL(15,2),
    gain_loss_percentage DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.total_value,
        SUM(ph.quantity * ph.purchase_price) AS total_investment,
        SUM(ph.unrealized_gain_loss) AS total_gain_loss,
        CASE 
            WHEN SUM(ph.quantity * ph.purchase_price) > 0 
            THEN (SUM(ph.unrealized_gain_loss) / SUM(ph.quantity * ph.purchase_price)) * 100 
            ELSE 0 
        END AS gain_loss_percentage
    FROM portfolios p
    JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
    WHERE p.portfolio_id = $1
    GROUP BY p.portfolio_id, p.total_value;
END;
$$ LANGUAGE plpgsql;

-- Function to get advisor dashboard statistics
CREATE OR REPLACE FUNCTION get_advisor_dashboard(advisor_id INTEGER)
RETURNS TABLE (
    total_clients INTEGER,
    total_aum DECIMAL(15,2),
    average_portfolio_return DECIMAL(10,2),
    active_signals INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT p.client_id) AS total_clients,
        COALESCE(SUM(p.total_value), 0) AS total_aum,
        COALESCE(AVG(
            (SELECT gain_loss_percentage FROM get