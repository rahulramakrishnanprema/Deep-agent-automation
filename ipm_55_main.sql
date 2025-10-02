-- IPM-55: SQL Database Schema for Investment Portfolio Management MVP
-- This file creates the complete database schema for the Indian equity portfolio management system
-- Includes tables for users, portfolios, Indian equities, technical indicators, advisory signals, and sector analysis

-- Drop existing tables to ensure clean creation (use with caution in production)
DROP TABLE IF EXISTS portfolio_holdings;
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS technical_indicators;
DROP TABLE IF EXISTS indian_equities;
DROP TABLE IF EXISTS sectors;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS users;

-- Users table for authentication and role management
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('advisor', 'client')) DEFAULT 'client',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sectors table for Indian market sector classification
CREATE TABLE sectors (
    sector_id SERIAL PRIMARY KEY,
    sector_name VARCHAR(100) UNIQUE NOT NULL,
    sector_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indian equities table with dummy data structure
CREATE TABLE indian_equities (
    equity_id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector_id INTEGER REFERENCES sectors(sector_id),
    current_price DECIMAL(15, 2) NOT NULL,
    previous_close DECIMAL(15, 2),
    market_cap DECIMAL(20, 2),
    volume BIGINT,
    day_high DECIMAL(15, 2),
    day_low DECIMAL(15, 2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolios table for storing user portfolios
CREATE TABLE portfolios (
    portfolio_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    total_value DECIMAL(15, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, portfolio_name)
);

-- Portfolio holdings junction table
CREATE TABLE portfolio_holdings (
    holding_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    equity_id INTEGER REFERENCES indian_equities(equity_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    purchase_price DECIMAL(15, 2) NOT NULL,
    purchase_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, equity_id)
);

-- Technical indicators table for storing calculated values
CREATE TABLE technical_indicators (
    indicator_id SERIAL PRIMARY KEY,
    equity_id INTEGER REFERENCES indian_equities(equity_id),
    rsi_14 DECIMAL(10, 4),
    macd DECIMAL(10, 4),
    macd_signal DECIMAL(10, 4),
    macd_histogram DECIMAL(10, 4),
    sma_20 DECIMAL(15, 2),
    sma_50 DECIMAL(15, 2),
    ema_12 DECIMAL(15, 2),
    ema_26 DECIMAL(15, 2),
    bollinger_upper DECIMAL(15, 2),
    bollinger_lower DECIMAL(15, 2),
    calculated_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(equity_id, calculated_date)
);

-- Advisory signals table for Buy/Hold/Sell recommendations
CREATE TABLE advisory_signals (
    signal_id SERIAL PRIMARY KEY,
    equity_id INTEGER REFERENCES indian_equities(equity_id),
    signal_type VARCHAR(10) CHECK (signal_type IN ('BUY', 'SELL', 'HOLD')) NOT NULL,
    confidence_score DECIMAL(5, 4) CHECK (confidence_score BETWEEN 0 AND 1),
    reasoning TEXT,
    technical_indicators JSONB,
    sector_sentiment VARCHAR(20),
    market_sentiment VARCHAR(20),
    generated_date DATE NOT NULL,
    valid_until DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(equity_id, generated_date)
);

-- Insert sample sectors for Indian market
INSERT INTO sectors (sector_name, sector_description) VALUES
('Information Technology', 'Software services, IT consulting, and technology solutions'),
('Banking', 'Public and private sector banks, financial institutions'),
('Pharmaceuticals', 'Drug manufacturers, biotechnology companies'),
('Automobile', 'Auto manufacturers, auto parts, and related services'),
('Energy', 'Oil, gas, renewable energy, and power companies'),
('Fast Moving Consumer Goods', 'Consumer products, food, and beverages'),
('Telecommunications', 'Telecom services, network providers'),
('Infrastructure', 'Construction, engineering, and infrastructure development'),
('Metals & Mining', 'Metal production, mining operations'),
('Healthcare', 'Hospitals, healthcare services, medical equipment');

-- Insert sample Indian equities with realistic data
INSERT INTO indian_equities (symbol, company_name, sector_id, current_price, previous_close, market_cap, volume, day_high, day_low) VALUES
('INFY', 'Infosys Limited', 1, 1850.50, 1832.75, 750000000000, 4500000, 1865.25, 1840.00),
('TCS', 'Tata Consultancy Services', 1, 3850.25, 3821.50, 1400000000000, 2200000, 3875.00, 3835.75),
('HDFCBANK', 'HDFC Bank Limited', 2, 1650.75, 1638.25, 900000000000, 5500000, 1665.50, 1642.00),
('ICICIBANK', 'ICICI Bank Limited', 2, 950.60, 942.80, 650000000000, 7800000, 958.75, 948.25),
('RELIANCE', 'Reliance Industries Limited', 5, 2750.00, 2725.50, 1800000000000, 3200000, 2775.25, 2732.75),
('ITC', 'ITC Limited', 6, 430.25, 425.75, 350000000000, 8500000, 435.50, 428.00),
('BHARTIARTL', 'Bharti Airtel Limited', 7, 820.50, 815.25, 450000000000, 4200000, 828.75, 818.00),
('SUNPHARMA', 'Sun Pharmaceutical Industries', 3, 1125.75, 1118.50, 270000000000, 1800000, 1135.00, 1120.25),
('MARUTI', 'Maruti Suzuki India Limited', 4, 9850.00, 9785.50, 290000000000, 950000, 9925.75, 9810.25),
('LT', 'Larsen & Toubro Limited', 8, 3250.25, 3225.75, 320000000000, 1500000, 3285.50, 3235.00);

-- Create indexes for better query performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_equities_symbol ON indian_equities(symbol);
CREATE INDEX idx_equities_sector ON indian_equities(sector_id);
CREATE INDEX idx_portfolios_user ON portfolios(user_id);
CREATE INDEX idx_holdings_portfolio ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_holdings_equity ON portfolio_holdings(equity_id);
CREATE INDEX idx_indicators_equity_date ON technical_indicators(equity_id, calculated_date);
CREATE INDEX idx_signals_equity_date ON advisory_signals(equity_id, generated_date);

-- Views for common queries

-- View for portfolio summary with current values
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.user_id,
    p.portfolio_name,
    p.total_value,
    COUNT(ph.holding_id) as number_of_holdings,
    MAX(ph.created_at) as last_updated
FROM portfolios p
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
GROUP BY p.portfolio_id, p.user_id, p.portfolio_name, p.total_value;

-- View for current advisory signals
CREATE VIEW current_advisory_signals AS
SELECT 
    s.signal_id,
    s.equity_id,
    e.symbol,
    e.company_name,
    sec.sector_name,
    s.signal_type,
    s.confidence_score,
    s.reasoning,
    s.generated_date,
    s.valid_until
FROM advisory_signals s
JOIN indian_equities e ON s.equity_id = e.equity_id
JOIN sectors sec ON e.sector_id = sec.sector_id
WHERE s.valid_until IS NULL OR s.valid_until >= CURRENT_DATE;

-- Stored procedures

-- Procedure to update portfolio total value
CREATE OR REPLACE PROCEDURE update_portfolio_value(portfolio_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE portfolios p
    SET total_value = (
        SELECT SUM(ph.quantity * e.current_price)
        FROM portfolio_holdings ph
        JOIN indian_equities e ON ph.equity_id = e.equity_id
        WHERE ph.portfolio_id = p.portfolio_id
    ),
    updated_at = CURRENT_TIMESTAMP
    WHERE p.portfolio_id = update_portfolio_value.portfolio_id;
END;
$$;

-- Procedure to generate advisory signal based on technical indicators
CREATE OR REPLACE PROCEDURE generate_advisory_signal(equity_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    rsi_val DECIMAL(10,4);
    macd_val DECIMAL(10,4);
    macd_signal_val DECIMAL(10,4);
    signal_type VARCHAR(10);
    confidence DECIMAL(5,4);
    reasoning_text TEXT;
BEGIN
    -- Get latest technical indicators
    SELECT rsi_14, macd, macd_signal 
    INTO rsi_val, macd_val, macd_signal_val
    FROM technical_indicators 
    WHERE equity_id = generate_advisory_signal.equity_id 
    ORDER BY calculated_date DESC 
    LIMIT 1;

    -- Determine signal based on technical analysis
    IF rsi_val < 30 AND macd_val > macd_signal_val THEN
        signal_type := 'BUY';
        confidence := 0.85;
        reasoning_text := 'Oversold condition with bullish MACD crossover';
    ELSIF rsi_val > 70 AND macd_val < macd_signal_val THEN
        signal_type := 'SELL';
        confidence := 0.80;
        reasoning_text := 'Overbought condition with bearish MACD crossover';
    ELSIF (rsi_val BETWEEN 40 AND 60) AND ABS(macd_val - macd_signal_val) < 0.5 THEN
        signal_type := 'HOLD';
        confidence := 0.75;
        reasoning_text := 'Neutral momentum indicators suggest holding position';
    ELSE
        signal_type := 'HOLD';
        confidence := 0.65;
        reasoning_text := 'Mixed signals across technical indicators';
    END IF;

    -- Insert the advisory signal
    INSERT INTO advisory_signals (
        equity_id, 
        signal_type, 
        confidence_score, 
        reasoning, 
        technical_indicators,
        generated_date,
        created_at
    ) VALUES (
        equity_id,
        signal_type,
        confidence,
        reasoning_text,
        jsonb_build_object(
            'rsi', rsi_val,
            'macd', macd_val,
            'macd_signal', macd_signal_val
        ),
        CURRENT_DATE,
        CURRENT_TIMESTAMP
    );
END;
$$;

-- Insert sample technical indicators data
INSERT INTO technical_indicators (equity_id, rsi_14, macd, macd_signal, macd_histogram, sma_20, sma_50, calculated_date) VALUES
(1, 45.25, 2.15, 1.85, 0.30, 1820.50, 1785.75, CURRENT_DATE),
(2, 62.30, -1.25, -0.85, -0.40, 3825.75, 3780.25, CURRENT_DATE),
(3, 28.75, 3.45, 2.95, 0.50, 1635.25, 1590.50, CURRENT_DATE),
(4, 71.80, -2.15, -1.75, -0.40, 945.25, 920.75, CURRENT_DATE),
(5, 55.40, 0.85, 0.95, -0.10, 2735.50, 2695.25, CURRENT_DATE);

-- Insert sample advisory signals
INSERT INTO advisory_signals (equity_id, signal_type, confidence_score, reasoning, technical_indicators, sector_sentiment, market_sentiment, generated_date) VALUES
(1, 'HOLD', 0.75, 'Neutral RSI with stable MACD', '{"rsi": 45.25, "macd": 2.15}', 'NEUTRAL', 'BULLISH', CURRENT_DATE),
(3, 'BUY', 0.85, 'Oversold RSI with bullish MACD crossover', '{"rsi": 28.75, "macd": 3.45}', 'BULLISH', 'NEUTRAL', CURRENT_DATE),
(4, 'SELL', 0.80, 'Overbought RSI with bearish MACD divergence', '{"rsi": 71.80, "macd": -2.15}', 'BEARISH', 'NEUTRAL', CURRENT_DATE);

-- Create comments on tables and columns for documentation
COMMENT ON TABLE users IS 'Stores user authentication and profile information';
COMMENT ON TABLE sectors IS 'Classification of Indian market sectors for equity analysis';
COMMENT ON TABLE indian_equities IS 'Dummy data for Indian stocks with current market information';
COMMENT ON TABLE portfolios IS 'User investment portfolios with metadata';
COMMENT ON TABLE portfolio_holdings IS 'Junction table linking portfolios to equity holdings';
COMMENT ON TABLE technical_indicators IS 'Calculated technical analysis indicators for equities';
COMMENT ON TABLE advisory_signals IS 'Buy/Hold/Sell recommendations based on technical analysis';

COMMENT ON COLUMN users.role IS 'User role: advisor or client';
COMMENT ON COLUMN indian_equities.current_price IS 'Current market price in INR';
COMMENT ON COLUMN advisory_signals.confidence_score IS 'Confidence level of the signal (0-1 scale)';
COMMENT ON COLUMN advisory_signals.technical_indicators IS 'JSON structure containing the technical indicators used for signal generation';