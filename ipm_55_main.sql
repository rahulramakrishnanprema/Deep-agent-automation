-- IPM-55: Database Schema for Indian Portfolio Management MVP
-- This SQL file creates the database schema for a stock portfolio management system
-- focused on Indian equity markets with advisory signals and role-based access

-- Drop existing tables to ensure clean creation
DROP TABLE IF EXISTS portfolio_signals;
DROP TABLE IF EXISTS portfolio_holdings;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS sectors;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS roles;

-- Create roles table for role-based access control
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create users table with role-based access
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role_id INTEGER NOT NULL REFERENCES roles(role_id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create sectors table for Indian market sectors
CREATE TABLE sectors (
    sector_id SERIAL PRIMARY KEY,
    sector_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    market_cap_category VARCHAR(50),
    growth_potential_rating INTEGER CHECK (growth_potential_rating BETWEEN 1 AND 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create stocks table for Indian equity instruments
CREATE TABLE stocks (
    stock_id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL UNIQUE,
    company_name VARCHAR(200) NOT NULL,
    isin_code VARCHAR(12) NOT NULL UNIQUE,
    sector_id INTEGER NOT NULL REFERENCES sectors(sector_id),
    current_price DECIMAL(15,2),
    market_cap DECIMAL(20,2),
    pe_ratio DECIMAL(10,2),
    dividend_yield DECIMAL(5,2),
    volume BIGINT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create portfolios table for client portfolios
CREATE TABLE portfolios (
    portfolio_id SERIAL PRIMARY KEY,
    portfolio_name VARCHAR(200) NOT NULL,
    client_name VARCHAR(200) NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    total_value DECIMAL(20,2) DEFAULT 0,
    created_date DATE DEFAULT CURRENT_DATE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create portfolio_holdings table for individual stock holdings
CREATE TABLE portfolio_holdings (
    holding_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(portfolio_id),
    stock_id INTEGER NOT NULL REFERENCES stocks(stock_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    purchase_price DECIMAL(15,2) NOT NULL,
    purchase_date DATE NOT NULL,
    current_value DECIMAL(20,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, stock_id)
);

-- Create portfolio_signals table for advisory signals
CREATE TABLE portfolio_signals (
    signal_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(portfolio_id),
    stock_id INTEGER NOT NULL REFERENCES stocks(stock_id),
    signal_type VARCHAR(10) NOT NULL CHECK (signal_type IN ('BUY', 'SELL', 'HOLD')),
    confidence_score DECIMAL(5,2) CHECK (confidence_score BETWEEN 0 AND 100),
    historical_performance_score DECIMAL(5,2),
    technical_indicator_score DECIMAL(5,2),
    sector_potential_score DECIMAL(5,2),
    market_buzz_score DECIMAL(5,2),
    reasoning TEXT,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Insert default roles
INSERT INTO roles (role_name, description) VALUES
('ADMIN', 'System administrator with full access'),
('ADVISOR', 'Financial advisor with access to signals and reports'),
('CLIENT', 'Client with view-only access to own portfolio');

-- Insert sample sectors for Indian market
INSERT INTO sectors (sector_name, description, market_cap_category, growth_potential_rating) VALUES
('Information Technology', 'Software services, IT consulting, and technology solutions', 'LARGE_CAP', 4),
('Banking & Financial Services', 'Banks, NBFCs, insurance companies, and financial institutions', 'LARGE_CAP', 3),
('Pharmaceuticals', 'Drug manufacturers, biotechnology, and healthcare products', 'MID_CAP', 4),
('Automobile', 'Automobile manufacturers and ancillary industries', 'LARGE_CAP', 3),
('Fast Moving Consumer Goods', 'Consumer goods, food products, and personal care', 'LARGE_CAP', 2),
('Energy', 'Oil & gas, power generation, and renewable energy', 'LARGE_CAP', 3),
('Infrastructure', 'Construction, engineering, and infrastructure development', 'MID_CAP', 4),
('Telecommunications', 'Telecom services and network providers', 'LARGE_CAP', 2),
('Real Estate', 'Real estate development and property management', 'SMALL_CAP', 3),
('Metals & Mining', 'Metal production, mining, and mineral processing', 'MID_CAP', 3);

-- Insert sample Indian stocks
INSERT INTO stocks (symbol, company_name, isin_code, sector_id, current_price, market_cap, pe_ratio, dividend_yield, volume) VALUES
('RELIANCE', 'Reliance Industries Limited', 'INE002A01018', 6, 2750.50, 1860000.00, 28.5, 0.45, 2500000),
('INFY', 'Infosys Limited', 'INE009A01021', 1, 1650.75, 685000.00, 25.8, 2.1, 1800000),
('HDFCBANK', 'HDFC Bank Limited', 'INE040A01026', 2, 1625.25, 890000.00, 20.3, 0.9, 3200000),
('TCS', 'Tata Consultancy Services Limited', 'INE467B01029', 1, 3850.00, 1420000.00, 30.2, 1.8, 1200000),
('ICICIBANK', 'ICICI Bank Limited', 'INE090A01021', 2, 985.60, 680000.00, 18.7, 0.7, 2800000),
('SBIN', 'State Bank of India', 'INE062A01020', 2, 650.80, 580000.00, 16.5, 1.2, 3500000),
('HINDUNILVR', 'Hindustan Unilever Limited', 'INE030A01027', 5, 2450.30, 580000.00, 55.8, 1.5, 850000),
('ITC', 'ITC Limited', 'INE154A01025', 5, 430.25, 540000.00, 24.3, 3.2, 2200000),
('BAJFINANCE', 'Bajaj Finance Limited', 'INE296A01024', 2, 7850.00, 470000.00, 35.6, 0.4, 450000),
('BHARTIARTL', 'Bharti Airtel Limited', 'INE397D01024', 8, 880.45, 500000.00, 22.1, 0.8, 1900000);

-- Create indexes for performance optimization
CREATE INDEX idx_portfolios_user_id ON portfolios(user_id);
CREATE INDEX idx_portfolio_holdings_portfolio_id ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_portfolio_holdings_stock_id ON portfolio_holdings(stock_id);
CREATE INDEX idx_portfolio_signals_portfolio_id ON portfolio_signals(portfolio_id);
CREATE INDEX idx_portfolio_signals_stock_id ON portfolio_signals(stock_id);
CREATE INDEX idx_stocks_sector_id ON stocks(sector_id);
CREATE INDEX idx_users_role_id ON users(role_id);

-- Create function to update portfolio total value
CREATE OR REPLACE FUNCTION update_portfolio_value()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE portfolios 
    SET total_value = (
        SELECT COALESCE(SUM(ph.quantity * s.current_price), 0)
        FROM portfolio_holdings ph
        JOIN stocks s ON ph.stock_id = s.stock_id
        WHERE ph.portfolio_id = NEW.portfolio_id
    ),
    last_updated = CURRENT_TIMESTAMP
    WHERE portfolio_id = NEW.portfolio_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update portfolio value after holdings changes
CREATE TRIGGER trigger_update_portfolio_value
AFTER INSERT OR UPDATE OR DELETE ON portfolio_holdings
FOR EACH ROW
EXECUTE FUNCTION update_portfolio_value();

-- Create function to generate advisory signals
CREATE OR REPLACE FUNCTION generate_advisory_signals(
    p_portfolio_id INTEGER,
    p_historical_weight DECIMAL DEFAULT 0.3,
    p_technical_weight DECIMAL DEFAULT 0.25,
    p_sector_weight DECIMAL DEFAULT 0.25,
    p_buzz_weight DECIMAL DEFAULT 0.2
)
RETURNS TABLE (
    stock_id INTEGER,
    signal_type VARCHAR(10),
    confidence_score DECIMAL(5,2),
    reasoning TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH stock_analysis AS (
        SELECT 
            ph.stock_id,
            -- Historical performance analysis (30%)
            CASE 
                WHEN s.current_price > ph.purchase_price * 1.2 THEN 80
                WHEN s.current_price > ph.purchase_price THEN 60
                ELSE 40
            END as historical_score,
            
            -- Technical indicator analysis (25%)
            CASE 
                WHEN s.pe_ratio < 15 THEN 90
                WHEN s.pe_ratio BETWEEN 15 AND 25 THEN 70
                ELSE 50
            END as technical_score,
            
            -- Sector potential analysis (25%)
            CASE 
                WHEN sec.growth_potential_rating >= 4 THEN 85
                WHEN sec.growth_potential_rating = 3 THEN 65
                ELSE 45
            END as sector_score,
            
            -- Market buzz analysis (20%)
            CASE 
                WHEN s.volume > 1000000 THEN 75
                WHEN s.volume > 500000 THEN 60
                ELSE 45
            END as buzz_score,
            
            -- Generate reasoning
            CASE 
                WHEN s.current_price > ph.purchase_price * 1.2 THEN 'Strong historical performance with 20%+ gains'
                WHEN s.current_price > ph.purchase_price THEN 'Moderate gains with positive momentum'
                ELSE 'Underperforming purchase price'
            END as historical_reasoning,
            
            CASE 
                WHEN s.pe_ratio < 15 THEN 'Attractive valuation with low P/E ratio'
                WHEN s.pe_ratio BETWEEN 15 AND 25 THEN 'Fair valuation within market norms'
                ELSE 'High valuation relative to earnings'
            END as technical_reasoning,
            
            CASE 
                WHEN sec.growth_potential_rating >= 4 THEN 'High-growth sector with strong potential'
                WHEN sec.growth_potential_rating = 3 THEN 'Stable sector with moderate growth outlook'
                ELSE 'Sector facing headwinds or slow growth'
            END as sector_reasoning,
            
            CASE 
                WHEN s.volume > 1000000 THEN 'High trading volume indicating strong market interest'
                WHEN s.volume > 500000 THEN 'Moderate trading volume with decent liquidity'
                ELSE 'Low trading volume, limited market activity'
            END as buzz_reasoning
            
        FROM portfolio_holdings ph
        JOIN stocks s ON ph.stock_id = s.stock_id
        JOIN sectors sec ON s.sector_id = sec.sector_id
        WHERE ph.portfolio_id = p_portfolio_id
    ),
    final_scores AS (
        SELECT
            stock_id,
            (historical_score * p_historical_weight + 
             technical_score * p_technical_weight + 
             sector_score * p_sector_weight + 
             buzz_score * p_buzz_weight) as final_score,
            historical_score,
            technical_score,
            sector_score,
            buzz_score,
            historical_reasoning || '; ' || technical_reasoning || '; ' || 
            sector_reasoning || '; ' || buzz_reasoning as full_reasoning
        FROM stock_analysis
    )
    SELECT 
        fs.stock_id,
        CASE 
            WHEN fs.final_score >= 70 THEN 'BUY'
            WHEN fs.final_score >= 50 THEN 'HOLD'
            ELSE 'SELL'
        END as signal_type,
        fs.final_score as confidence_score,
        'Overall score: ' || ROUND(fs.final_score, 2) || 
        ' (Historical: ' || fs.historical_score || 
        ', Technical: ' || fs.technical_score || 
        ', Sector: ' || fs.sector_score || 
        ', Buzz: ' || fs.buzz_score || '). ' || fs.full_reasoning as reasoning
    FROM final_scores fs;
END;
$$ LANGUAGE plpgsql;

-- Create view for advisor portfolio reports
CREATE OR REPLACE VIEW advisor_portfolio_reports AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    p.client_name,
    u.username as advisor_username,
    p.total_value,
    COUNT(ph.holding_id) as number_of_holdings,
    AVG(s.pe_ratio) as avg_pe_ratio,
    SUM(ph.quantity * s.current_price) / p.total_value as portfolio_diversification_score,
    p.created_date,
    p.last_updated
FROM portfolios p
JOIN users u ON p.user_id = u.user_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
LEFT JOIN stocks s ON ph.stock_id = s.stock_id
GROUP BY p.portfolio_id, p.portfolio_name, p.client_name, u.username, p.total_value, p.created_date, p.last_updated;

-- Create view for detailed portfolio signals
CREATE OR REPLACE VIEW portfolio_signals_detail AS
SELECT 
    ps.signal_id,
    p.portfolio_name,
    p.client_name,
    s.symbol,
    s.company_name,
    sec.sector_name,
    ps.signal_type,
    ps.confidence_score,
    ps.historical_performance_score,
    ps.technical_indicator_score,
    ps.sector_potential_score,
    ps.market_buzz_score,
    ps.reasoning,
    ps.generated_at,
    ps.valid_until
FROM portfolio_signals ps
JOIN portfolios p ON ps.portfolio_id = p.portfolio_id
JOIN stocks s ON ps.stock_id = s.stock_id
JOIN sectors sec ON s.sector_id = sec.sector_id
WHERE ps.is_active = TRUE;

-- Insert sample users
INSERT INTO users (username, email, password_hash, first_name, last_name, role_id) VALUES
('admin_user', 'admin@ipm.com', 'hashed_password_1', 'Admin', 'User', 1),
('advisor_rahul', 'rahul@ipm.com', 'hashed_password_2', 'Rahul', 'Sharma', 2),
('advisor_priya', 'priya@ipm.com', 'hashed_password_3', 'Priya', 'Patel', 2),
('client_mohan', 'mohan@client.com', 'hashed_password_4', 'Mohan', 'Kumar', 3);

-- Insert sample portfolios
INSERT INTO portfolios (portfolio_name, client_name, user_id, total_value) VALUES
('Growth Portfolio - Tech Focus', 'Rajesh Mehta', 2, 0),
('Conservative Income Portfolio', 'Sunita Reddy', 3, 0),
('Balanced Growth Fund', 'Vikram Singh', 2, 0);

-- Insert sample portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, purchase_price, purchase_date) VALUES
(1, 2, 100, 1500.00, '2024-01-15'),  -- INFY
(1, 4, 50, 3500.00, '2024-02-01'),   -- TCS
(1, 1, 25, 2500.00, '2024-01-20'),   -- RELIANCE
(2, 7, 200, 2300.00, '2024-03-10'),  -- HINDUNILVR
(2, 8, 300, 400.00, '2024-02-15'),   -- ITC
(2, 9, 10, 7500.00, '2024-01-25'),   -- BAJFINANCE
(3, 3, 80, 1550.00, '2024-03-01'),   -- HDFCBANK
(3, 5, 120, 900.00, '2024-02-20'),   -- ICICIBANK
(3, 10, 60, 850.00, '2024-01-30');   -- BHARTIARTL

-- Generate sample advisory signals
INSERT INTO portfolio_signals (portfolio_id, stock_id, signal_type, confidence_score, 
                              historical_performance_score, technical_indicator_score, 
                              sector_potential_score, market_buzz_score, reasoning, valid_until)
SELECT 
    ph.portfolio_id,
    ph.stock_id,
    gs.signal_type,
    gs.confidence_score,
    CASE 
        WHEN s.current_price > ph.purchase_price * 1.2 THEN 80
        WHEN s.current_price > ph.purchase_price THEN 60
        ELSE 40
    END as historical_score,
    CASE 
        WHEN s.pe_ratio < 