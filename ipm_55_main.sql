-- IPM-55: Portfolio Management Database Schema
-- This SQL file creates the database schema for an MVP web application managing Indian equity portfolios
-- Includes tables for user management, portfolio storage, stocks, advisory signals, and visual reports

-- Enable UUID extension for unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table for authentication and role-based access control
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('client', 'advisor', 'admin')) DEFAULT 'client',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clients table extending users with additional client-specific information
CREATE TABLE clients (
    client_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone_number VARCHAR(15),
    date_of_birth DATE,
    risk_profile VARCHAR(20) CHECK (risk_profile IN ('conservative', 'moderate', 'aggressive')),
    investment_horizon VARCHAR(20) CHECK (investment_horizon IN ('short', 'medium', 'long')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Advisors table extending users with advisor-specific information
CREATE TABLE advisors (
    advisor_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    license_number VARCHAR(50),
    specialization VARCHAR(100),
    experience_years INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indian stocks master table with sector information
CREATE TABLE stocks (
    stock_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector VARCHAR(100) NOT NULL,
    industry VARCHAR(100),
    market_cap DECIMAL(20, 2),
    current_price DECIMAL(10, 2),
    ipo_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolios table storing client portfolio information
CREATE TABLE portfolios (
    portfolio_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    total_value DECIMAL(15, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio holdings table for individual stock positions
CREATE TABLE portfolio_holdings (
    holding_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    stock_id UUID NOT NULL REFERENCES stocks(stock_id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    purchase_price DECIMAL(10, 2) NOT NULL,
    purchase_date DATE NOT NULL,
    current_value DECIMAL(15, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, stock_id)
);

-- Historical performance data for stocks
CREATE TABLE stock_performance (
    performance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID NOT NULL REFERENCES stocks(stock_id) ON DELETE CASCADE,
    date DATE NOT NULL,
    open_price DECIMAL(10, 2),
    high_price DECIMAL(10, 2),
    low_price DECIMAL(10, 2),
    close_price DECIMAL(10, 2),
    volume BIGINT,
    returns DECIMAL(8, 4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_id, date)
);

-- Technical indicators table
CREATE TABLE technical_indicators (
    indicator_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID NOT NULL REFERENCES stocks(stock_id) ON DELETE CASCADE,
    date DATE NOT NULL,
    moving_avg_50 DECIMAL(10, 2),
    moving_avg_200 DECIMAL(10, 2),
    rsi DECIMAL(6, 2),
    macd DECIMAL(8, 4),
    bollinger_upper DECIMAL(10, 2),
    bollinger_lower DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_id, date)
);

-- Sector analysis table
CREATE TABLE sector_analysis (
    sector_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sector_name VARCHAR(100) UNIQUE NOT NULL,
    growth_potential DECIMAL(6, 2) CHECK (growth_potential BETWEEN -100 AND 100),
    risk_level VARCHAR(20) CHECK (risk_level IN ('low', 'medium', 'high')),
    outlook VARCHAR(20) CHECK (outlook IN ('positive', 'neutral', 'negative')),
    analysis_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Market buzz and sentiment analysis
CREATE TABLE market_sentiment (
    sentiment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID NOT NULL REFERENCES stocks(stock_id) ON DELETE CASCADE,
    sentiment_score DECIMAL(4, 2) CHECK (sentiment_score BETWEEN -1 AND 1),
    news_count INTEGER DEFAULT 0,
    social_mentions INTEGER DEFAULT 0,
    analyst_rating VARCHAR(10) CHECK (analyst_rating IN ('strong_buy', 'buy', 'hold', 'sell', 'strong_sell')),
    analysis_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_id, analysis_date)
);

-- Advisory signals table
CREATE TABLE advisory_signals (
    signal_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID NOT NULL REFERENCES stocks(stock_id) ON DELETE CASCADE,
    signal_type VARCHAR(10) CHECK (signal_type IN ('BUY', 'HOLD', 'SELL')),
    confidence_score DECIMAL(4, 2) CHECK (confidence_score BETWEEN 0 AND 1),
    rationale TEXT,
    generated_date DATE NOT NULL,
    valid_until DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Advisor reports table for visual dashboards
CREATE TABLE advisor_reports (
    report_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    advisor_id UUID NOT NULL REFERENCES advisors(advisor_id) ON DELETE CASCADE,
    report_type VARCHAR(50) NOT NULL,
    report_data JSONB NOT NULL,
    generated_date DATE NOT NULL,
    is_shared BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Client-advisor relationship table
CREATE TABLE client_advisor_relationships (
    relationship_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    advisor_id UUID NOT NULL REFERENCES advisors(advisor_id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(20) CHECK (status IN ('active', 'inactive', 'pending')) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(client_id, advisor_id)
);

-- Indexes for performance optimization
CREATE INDEX idx_portfolios_client_id ON portfolios(client_id);
CREATE INDEX idx_portfolio_holdings_portfolio_id ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_portfolio_holdings_stock_id ON portfolio_holdings(stock_id);
CREATE INDEX idx_stock_performance_stock_id ON stock_performance(stock_id);
CREATE INDEX idx_stock_performance_date ON stock_performance(date);
CREATE INDEX idx_technical_indicators_stock_id ON technical_indicators(stock_id);
CREATE INDEX idx_advisory_signals_stock_id ON advisory_signals(stock_id);
CREATE INDEX idx_market_sentiment_stock_id ON market_sentiment(stock_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_clients_risk_profile ON clients(risk_profile);

-- Insert dummy data for testing
INSERT INTO users (username, email, password_hash, role) VALUES
('client1', 'client1@example.com', 'hashed_password_1', 'client'),
('client2', 'client2@example.com', 'hashed_password_2', 'client'),
('advisor1', 'advisor1@example.com', 'hashed_password_3', 'advisor'),
('admin1', 'admin1@example.com', 'hashed_password_4', 'admin');

INSERT INTO clients (client_id, first_name, last_name, risk_profile, investment_horizon) VALUES
((SELECT user_id FROM users WHERE username = 'client1'), 'Raj', 'Sharma', 'moderate', 'medium'),
((SELECT user_id FROM users WHERE username = 'client2'), 'Priya', 'Patel', 'conservative', 'long');

INSERT INTO advisors (advisor_id, first_name, last_name, experience_years) VALUES
((SELECT user_id FROM users WHERE username = 'advisor1'), 'Amit', 'Verma', 8);

INSERT INTO stocks (symbol, company_name, sector, current_price) VALUES
('RELIANCE', 'Reliance Industries Limited', 'Energy', 2456.75),
('TCS', 'Tata Consultancy Services Limited', 'IT', 3210.50),
('HDFCBANK', 'HDFC Bank Limited', 'Banking', 1420.25),
('INFY', 'Infosys Limited', 'IT', 1550.80),
('ICICIBANK', 'ICICI Bank Limited', 'Banking', 890.45);

INSERT INTO portfolios (client_id, portfolio_name, total_value) VALUES
((SELECT client_id FROM clients WHERE first_name = 'Raj'), 'Main Portfolio', 500000),
((SELECT client_id FROM clients WHERE first_name = 'Priya'), 'Retirement Portfolio', 750000);

INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, purchase_price, purchase_date) VALUES
((SELECT portfolio_id FROM portfolios WHERE portfolio_name = 'Main Portfolio'), 
 (SELECT stock_id FROM stocks WHERE symbol = 'RELIANCE'), 100, 2400.00, '2023-01-15'),
((SELECT portfolio_id FROM portfolios WHERE portfolio_name = 'Main Portfolio'), 
 (SELECT stock_id FROM stocks WHERE symbol = 'TCS'), 50, 3100.00, '2023-02-20'),
((SELECT portfolio_id FROM portfolios WHERE portfolio_name = 'Retirement Portfolio'), 
 (SELECT stock_id FROM stocks WHERE symbol = 'HDFCBANK'), 200, 1400.00, '2023-03-10');

INSERT INTO sector_analysis (sector_name, growth_potential, risk_level, outlook, analysis_date) VALUES
('IT', 15.5, 'medium', 'positive', '2023-12-01'),
('Banking', 8.2, 'high', 'neutral', '2023-12-01'),
('Energy', 12.8, 'high', 'positive', '2023-12-01');

INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, rationale, generated_date, valid_until) VALUES
((SELECT stock_id FROM stocks WHERE symbol = 'RELIANCE'), 'BUY', 0.85, 'Strong fundamentals and sector growth', '2023-12-01', '2023-12-15'),
((SELECT stock_id FROM stocks WHERE symbol = 'TCS'), 'HOLD', 0.70, 'Stable performance, wait for better entry', '2023-12-01', '2023-12-15'),
((SELECT stock_id FROM stocks WHERE symbol = 'HDFCBANK'), 'SELL', 0.60, 'Sector headwinds and regulatory concerns', '2023-12-01', '2023-12-15');

-- Views for common queries
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    c.first_name || ' ' || c.last_name as client_name,
    COUNT(ph.holding_id) as number_of_holdings,
    SUM(ph.quantity * s.current_price) as current_value,
    p.total_value as book_value
FROM portfolios p
JOIN clients c ON p.client_id = c.client_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
LEFT JOIN stocks s ON ph.stock_id = s.stock_id
GROUP BY p.portfolio_id, p.portfolio_name, client_name, p.total_value;

CREATE VIEW advisor_client_view AS
SELECT 
    a.advisor_id,
    a.first_name || ' ' || a.last_name as advisor_name,
    c.client_id,
    c.first_name || ' ' || c.last_name as client_name,
    car.start_date,
    car.status
FROM advisors a
JOIN client_advisor_relationships car ON a.advisor_id = car.advisor_id
JOIN clients c ON car.client_id = c.client_id;

-- Stored procedures for common operations
CREATE OR REPLACE PROCEDURE update_portfolio_value(portfolio_uuid UUID)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE portfolios 
    SET total_value = (
        SELECT COALESCE(SUM(ph.quantity * s.current_price), 0)
        FROM portfolio_holdings ph
        JOIN stocks s ON ph.stock_id = s.stock_id
        WHERE ph.portfolio_id = portfolio_uuid
    ),
    updated_at = CURRENT_TIMESTAMP
    WHERE portfolio_id = portfolio_uuid;
END;
$$;

CREATE OR REPLACE PROCEDURE generate_advisory_signal(stock_uuid UUID, analysis_date DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    final_signal VARCHAR(10);
    confidence DECIMAL(4,2);
    rationale_text TEXT;
BEGIN
    -- This is a simplified signal generation logic
    -- In production, this would incorporate technical indicators, sector analysis, and market sentiment
    SELECT 
        CASE 
            WHEN s.current_price > sp.avg_price * 1.1 THEN 'SELL'
            WHEN s.current_price < sp.avg_price * 0.9 THEN 'BUY'
            ELSE 'HOLD'
        END,
        CASE 
            WHEN s.current_price > sp.avg_price * 1.1 THEN 0.8
            WHEN s.current_price < sp.avg_price * 0.9 THEN 0.85
            ELSE 0.7
        END,
        'Generated based on price movement analysis'
    INTO final_signal, confidence, rationale_text
    FROM stocks s
    CROSS JOIN (
        SELECT AVG(close_price) as avg_price
        FROM stock_performance 
        WHERE stock_id = stock_uuid 
        AND date >= analysis_date - INTERVAL '30 days'
    ) sp
    WHERE s.stock_id = stock_uuid;
    
    INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, rationale, generated_date, valid_until)
    VALUES (stock_uuid, final_signal, confidence, rationale_text, analysis_date, analysis_date + INTERVAL '14 days');
END;
$$;

-- Comments for documentation
COMMENT ON TABLE portfolios IS 'Stores client portfolio information with total valuation';
COMMENT ON TABLE advisory_signals IS 'Contains Buy/Hold/Sell recommendations with confidence scores and rationale';
COMMENT ON TABLE advisor_reports IS 'Stores visual reports and analytics data for advisor dashboards (advisor-only access)';
COMMENT ON COLUMN users.role IS 'Defines user access levels: client, advisor, admin';
COMMENT ON COLUMN clients.risk_profile IS 'Client risk tolerance: conservative, moderate, aggressive';