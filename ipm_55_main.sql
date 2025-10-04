-- IPM-55: Main SQL Schema for Indian Portfolio Management MVP
-- This file creates the complete database schema for the stock portfolio management system
-- Focuses on Indian equity markets with support for portfolio storage, technical indicators, and advisory signals

-- Enable UUID extension for unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create main database schema
CREATE SCHEMA IF NOT EXISTS ipm_portfolio;
SET search_path TO ipm_portfolio;

-- Users table for advisor access control
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'advisor' CHECK (role IN ('advisor', 'admin')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Indian stock symbols reference table
CREATE TABLE indian_stocks (
    stock_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20) NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector VARCHAR(100) NOT NULL,
    industry VARCHAR(100),
    exchange VARCHAR(50) DEFAULT 'NSE' CHECK (exchange IN ('NSE', 'BSE')),
    isin_code VARCHAR(12) UNIQUE NOT NULL,
    market_cap DECIMAL(20, 2),
    listing_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(symbol, exchange)
);

-- Portfolio master table
CREATE TABLE portfolios (
    portfolio_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_name VARCHAR(100) NOT NULL,
    client_name VARCHAR(100) NOT NULL,
    description TEXT,
    initial_investment DECIMAL(15, 2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'INR',
    risk_profile VARCHAR(20) CHECK (risk_profile IN ('Low', 'Medium', 'High', 'Very High')),
    created_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Portfolio holdings table
CREATE TABLE portfolio_holdings (
    holding_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    stock_id UUID REFERENCES indian_stocks(stock_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    average_price DECIMAL(10, 2) NOT NULL CHECK (average_price > 0),
    purchase_date DATE NOT NULL,
    sector VARCHAR(100),
    current_price DECIMAL(10, 2),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, stock_id)
);

-- Historical price data for technical analysis
CREATE TABLE stock_prices (
    price_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID REFERENCES indian_stocks(stock_id),
    date DATE NOT NULL,
    open_price DECIMAL(10, 2),
    high_price DECIMAL(10, 2),
    low_price DECIMAL(10, 2),
    close_price DECIMAL(10, 2) NOT NULL,
    volume BIGINT,
    adjusted_close DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_id, date)
);

-- Technical indicators table
CREATE TABLE technical_indicators (
    indicator_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID REFERENCES indian_stocks(stock_id),
    date DATE NOT NULL,
    sma_20 DECIMAL(10, 2),  -- Simple Moving Average 20 days
    sma_50 DECIMAL(10, 2),  -- Simple Moving Average 50 days
    ema_12 DECIMAL(10, 2),  -- Exponential Moving Average 12 days
    ema_26 DECIMAL(10, 2),  -- Exponential Moving Average 26 days
    rsi DECIMAL(5, 2) CHECK (rsi BETWEEN 0 AND 100),  -- Relative Strength Index
    macd DECIMAL(10, 2),    -- MACD line
    macd_signal DECIMAL(10, 2),  -- MACD signal line
    macd_histogram DECIMAL(10, 2),  -- MACD histogram
    bollinger_upper DECIMAL(10, 2),  -- Bollinger Bands upper
    bollinger_lower DECIMAL(10, 2),  -- Bollinger Bands lower
    stochastic_k DECIMAL(5, 2),  -- Stochastic %K
    stochastic_d DECIMAL(5, 2),  -- Stochastic %D
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_id, date)
);

-- Advisory signals table
CREATE TABLE advisory_signals (
    signal_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID REFERENCES indian_stocks(stock_id),
    signal_date DATE NOT NULL,
    signal_type VARCHAR(10) CHECK (signal_type IN ('BUY', 'SELL', 'HOLD')),
    confidence_score DECIMAL(5, 2) CHECK (confidence_score BETWEEN 0 AND 100),
    rationale TEXT,
    technical_score INTEGER CHECK (technical_score BETWEEN 0 AND 100),
    fundamental_score INTEGER CHECK (fundamental_score BETWEEN 0 AND 100),
    market_sentiment_score INTEGER CHECK (market_sentiment_score BETWEEN 0 AND 100),
    target_price DECIMAL(10, 2),
    stop_loss DECIMAL(10, 2),
    time_horizon VARCHAR(20) CHECK (time_horizon IN ('Short', 'Medium', 'Long')),
    generated_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_id, signal_date)
);

-- Sector analysis table
CREATE TABLE sector_analysis (
    analysis_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sector VARCHAR(100) NOT NULL,
    analysis_date DATE NOT NULL,
    overall_score INTEGER CHECK (overall_score BETWEEN 0 AND 100),
    growth_potential VARCHAR(20) CHECK (growth_potential IN ('Low', 'Medium', 'High', 'Very High')),
    risk_level VARCHAR(20) CHECK (risk_level IN ('Low', 'Medium', 'High', 'Very High')),
    market_cap_contribution DECIMAL(5, 2),
    pe_ratio_avg DECIMAL(10, 2),
    dividend_yield_avg DECIMAL(5, 2),
    top_performers JSONB,  -- JSON array of top performing stocks in sector
    analyst_recommendations TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(sector, analysis_date)
);

-- Market buzz and news integration
CREATE TABLE market_buzz (
    buzz_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID REFERENCES indian_stocks(stock_id),
    buzz_date TIMESTAMP NOT NULL,
    source VARCHAR(100) NOT NULL,
    headline VARCHAR(500) NOT NULL,
    content TEXT,
    sentiment_score INTEGER CHECK (sentiment_score BETWEEN -100 AND 100),
    impact_level VARCHAR(20) CHECK (impact_level IN ('Low', 'Medium', 'High')),
    category VARCHAR(50) CHECK (category IN ('News', 'Social Media', 'Analyst Report', 'Regulatory')),
    url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio performance history
CREATE TABLE portfolio_performance (
    performance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    total_value DECIMAL(15, 2) NOT NULL,
    daily_return DECIMAL(10, 4),
    weekly_return DECIMAL(10, 4),
    monthly_return DECIMAL(10, 4),
    quarterly_return DECIMAL(10, 4),
    yearly_return DECIMAL(10, 4),
    volatility DECIMAL(10, 4),
    sharpe_ratio DECIMAL(10, 4),
    beta DECIMAL(10, 4),
    alpha DECIMAL(10, 4),
    sector_allocation JSONB,  -- JSON object with sector allocations
    top_holdings JSONB,      -- JSON array of top holdings
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, snapshot_date)
);

-- User sessions for access control
CREATE TABLE user_sessions (
    session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    session_token VARCHAR(500) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit log table
CREATE TABLE audit_log (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    action_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX idx_portfolio_holdings_portfolio ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_portfolio_holdings_stock ON portfolio_holdings(stock_id);
CREATE INDEX idx_stock_prices_stock_date ON stock_prices(stock_id, date);
CREATE INDEX idx_technical_indicators_stock_date ON technical_indicators(stock_id, date);
CREATE INDEX idx_advisory_signals_stock_date ON advisory_signals(stock_id, signal_date);
CREATE INDEX idx_market_buzz_stock_date ON market_buzz(stock_id, buzz_date);
CREATE INDEX idx_portfolio_performance_portfolio_date ON portfolio_performance(portfolio_id, snapshot_date);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_indian_stocks_symbol ON indian_stocks(symbol);
CREATE INDEX idx_indian_stocks_sector ON indian_stocks(sector);

-- Views for common queries

-- Portfolio summary view
CREATE OR REPLACE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    p.client_name,
    p.initial_investment,
    COALESCE(SUM(ph.quantity * COALESCE(ph.current_price, sp.close_price)), 0) AS current_value,
    COALESCE(SUM(ph.quantity * ph.average_price), 0) AS invested_amount,
    COUNT(ph.holding_id) AS number_of_holdings,
    MAX(pp.snapshot_date) AS last_updated
FROM portfolios p
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
LEFT JOIN stock_prices sp ON ph.stock_id = sp.stock_id 
    AND sp.date = (SELECT MAX(date) FROM stock_prices WHERE stock_id = ph.stock_id)
LEFT JOIN portfolio_performance pp ON p.portfolio_id = pp.portfolio_id
WHERE p.is_active = TRUE
GROUP BY p.portfolio_id, p.portfolio_name, p.client_name, p.initial_investment;

-- Stock signals with latest prices view
CREATE OR REPLACE VIEW stock_signals_with_prices AS
SELECT 
    s.stock_id,
    s.symbol,
    s.company_name,
    s.sector,
    asp.signal_type,
    asp.confidence_score,
    asp.target_price,
    sp.close_price AS current_price,
    sp.date AS price_date,
    CASE 
        WHEN asp.signal_type = 'BUY' AND sp.close_price < asp.target_price THEN 'Undervalued'
        WHEN asp.signal_type = 'SELL' AND sp.close_price > asp.target_price THEN 'Overvalued'
        ELSE 'Fair Value'
    END AS valuation_status
FROM indian_stocks s
LEFT JOIN advisory_signals asp ON s.stock_id = asp.stock_id 
    AND asp.signal_date = (SELECT MAX(signal_date) FROM advisory_signals WHERE stock_id = s.stock_id)
LEFT JOIN stock_prices sp ON s.stock_id = sp.stock_id 
    AND sp.date = (SELECT MAX(date) FROM stock_prices WHERE stock_id = s.stock_id)
WHERE s.is_active = TRUE;

-- Sector performance view
CREATE OR REPLACE VIEW sector_performance AS
SELECT 
    s.sector,
    COUNT(DISTINCT s.stock_id) AS number_of_stocks,
    AVG(sp.close_price) AS avg_price,
    AVG(ti.rsi) AS avg_rsi,
    AVG(asp.confidence_score) FILTER (WHERE asp.signal_type = 'BUY') AS avg_buy_confidence,
    AVG(asp.confidence_score) FILTER (WHERE asp.signal_type = 'SELL') AS avg_sell_confidence,
    COUNT(asp.signal_id) FILTER (WHERE asp.signal_type = 'BUY') AS buy_signals,
    COUNT(asp.signal_id) FILTER (WHERE asp.signal_type = 'SELL') AS sell_signals,
    MAX(sa.overall_score) AS sector_score
FROM indian_stocks s
LEFT JOIN stock_prices sp ON s.stock_id = sp.stock_id 
    AND sp.date = (SELECT MAX(date) FROM stock_prices WHERE stock_id = s.stock_id)
LEFT JOIN technical_indicators ti ON s.stock_id = ti.stock_id 
    AND ti.date = (SELECT MAX(date) FROM technical_indicators WHERE stock_id = s.stock_id)
LEFT JOIN advisory_signals asp ON s.stock_id = asp.stock_id 
    AND asp.signal_date = (SELECT MAX(signal_date) FROM advisory_signals WHERE stock_id = s.stock_id)
LEFT JOIN sector_analysis sa ON s.sector = sa.sector 
    AND sa.analysis_date = (SELECT MAX(analysis_date) FROM sector_analysis WHERE sector = s.sector)
WHERE s.is_active = TRUE
GROUP BY s.sector;

-- Functions for common operations

-- Function to calculate portfolio value
CREATE OR REPLACE FUNCTION calculate_portfolio_value(p_portfolio_id UUID)
RETURNS DECIMAL(15, 2) AS $$
DECLARE
    total_value DECIMAL(15, 2);
BEGIN
    SELECT COALESCE(SUM(ph.quantity * COALESCE(ph.current_price, sp.close_price)), 0)
    INTO total_value
    FROM portfolio_holdings ph
    LEFT JOIN stock_prices sp ON ph.stock_id = sp.stock_id 
        AND sp.date = (SELECT MAX(date) FROM stock_prices WHERE stock_id = ph.stock_id)
    WHERE ph.portfolio_id = p_portfolio_id;
    
    RETURN total_value;
END;
$$ LANGUAGE plpgsql;

-- Function to update portfolio holdings current prices
CREATE OR REPLACE FUNCTION update_holding_prices()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE portfolio_holdings ph
    SET current_price = sp.close_price,
        last_updated = CURRENT_TIMESTAMP
    FROM stock_prices sp
    WHERE ph.stock_id = sp.stock_id
        AND sp.date = (SELECT MAX(date) FROM stock_prices WHERE stock_id = ph.stock_id)
        AND ph.current_price IS DISTINCT FROM sp.close_price;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to generate advisory signal based on technical indicators
CREATE OR REPLACE FUNCTION generate_advisory_signal(p_stock_id UUID, p_date DATE)
RETURNS TABLE (
    signal_type VARCHAR(10),
    confidence_score DECIMAL(5, 2),
    rationale TEXT
) AS $$
DECLARE
    v_rsi DECIMAL(5, 2);
    v_macd_histogram DECIMAL(10, 2);
    v_sma_20 DECIMAL(10, 2);
    v_sma_50 DECIMAL(10, 2);
    v_current_price DECIMAL(10, 2);
    v_signal_type VARCHAR(10);
    v_confidence DECIMAL(5, 2);
    v_rationale TEXT;
BEGIN
    -- Get latest technical indicators
    SELECT rsi, macd_histogram, sma_20, sma_50
    INTO v_rsi, v_macd_histogram, v_sma_20, v_sma_50
    FROM technical_indicators
    WHERE stock_id = p_stock_id AND date = p_date;
    
    -- Get current price
    SELECT close_price INTO v_current_price
    FROM stock_prices
    WHERE stock_id = p_stock_id AND date = p_date;
    
    -- Generate signal based on multiple indicators
    v_confidence := 0;
    v_rationale := '';
    
    -- RSI based signal
    IF v_rsi < 30 THEN
        v_signal_type := 'BUY';
        v_confidence := v_confidence + 25;
        v_rationale := v_rationale || 'RSI indicates oversold condition. ';
    ELSIF v_rsi > 70 THEN
        v_signal_type := 'SELL';
        v_confidence := v_confidence + 25;
        v_rationale := v_rationale || 'RSI indicates overbought condition. ';
    ELSE
        v_signal_type := 'HOLD';
        v_confidence := v_confidence + 10;
    END IF;
    
    -- MACD based signal
    IF v_macd_histogram > 0 THEN
        IF v_signal_type = 'BUY' THEN
            v_confidence := v_confidence + 25;
        END IF;
        v_rationale := v_rationale || 'MACD histogram positive. ';
    ELSIF v_macd_histogram < 0 THEN
        IF v_signal_type = 'SELL' THEN
            v_confidence := v_confidence + 25;
        END IF;
        v_rationale := v_rationale || 'MACD histogram negative. ';
    END IF;
    
    -- Moving averages crossover
    IF v_sma_20 > v