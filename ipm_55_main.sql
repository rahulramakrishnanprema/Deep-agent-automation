-- IPM-55: Portfolio Management Database Schema
-- This SQL file creates the database schema for the Indian equity portfolio management system
-- Includes tables for users, portfolios, stocks, advisory signals, and visual reports

-- Drop existing tables to ensure clean creation (use with caution in production)
DROP TABLE IF EXISTS portfolio_stocks;
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS visual_reports;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS sectors;
DROP TABLE IF EXISTS users;

-- Users table with role-based access control
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('client', 'advisor', 'admin')) DEFAULT 'client',
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sectors table for Indian equity market sectors
CREATE TABLE sectors (
    sector_id SERIAL PRIMARY KEY,
    sector_name VARCHAR(100) UNIQUE NOT NULL,
    sector_description TEXT,
    growth_potential DECIMAL(5,2) DEFAULT 0.0, -- Percentage growth potential
    market_buzz_score DECIMAL(3,2) DEFAULT 0.0, -- Score from 0-1
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stocks table for Indian equity securities
CREATE TABLE stocks (
    stock_id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector_id INTEGER REFERENCES sectors(sector_id),
    current_price DECIMAL(10,2) NOT NULL,
    historical_performance JSONB, -- Stores historical price data as JSON
    technical_indicators JSONB, -- Stores RSI, MACD, moving averages etc.
    market_cap DECIMAL(15,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolios table for client investment portfolios
CREATE TABLE portfolios (
    portfolio_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    portfolio_name VARCHAR(100) NOT NULL,
    total_value DECIMAL(12,2) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Junction table for portfolio stocks with quantities
CREATE TABLE portfolio_stocks (
    portfolio_stock_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    stock_id INTEGER REFERENCES stocks(stock_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    purchase_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, stock_id)
);

-- Advisory signals table with Buy/Hold/Sell recommendations
CREATE TABLE advisory_signals (
    signal_id SERIAL PRIMARY KEY,
    stock_id INTEGER REFERENCES stocks(stock_id),
    signal_type VARCHAR(10) CHECK (signal_type IN ('BUY', 'HOLD', 'SELL')) NOT NULL,
    confidence_score DECIMAL(3,2) CHECK (confidence_score >= 0 AND confidence_score <= 1),
    reasoning TEXT NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Visual reports table for advisor-only analytics
CREATE TABLE visual_reports (
    report_id SERIAL PRIMARY KEY,
    report_name VARCHAR(200) NOT NULL,
    report_type VARCHAR(50) NOT NULL,
    generated_by INTEGER REFERENCES users(user_id),
    report_data JSONB NOT NULL, -- Stores chart data, analytics in JSON format
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_stocks_symbol ON stocks(symbol);
CREATE INDEX idx_portfolios_user ON portfolios(user_id);
CREATE INDEX idx_portfolio_stocks_composite ON portfolio_stocks(portfolio_id, stock_id);
CREATE INDEX idx_advisory_signals_stock ON advisory_signals(stock_id);
CREATE INDEX idx_advisory_signals_active ON advisory_signals(is_active);
CREATE INDEX idx_visual_reports_generated ON visual_reports(generated_by);

-- Insert dummy data for demonstration
INSERT INTO sectors (sector_name, sector_description, growth_potential, market_buzz_score) VALUES
('Information Technology', 'Software services and IT consulting', 15.50, 0.85),
('Banking', 'Public and private sector banks', 12.30, 0.78),
('Pharmaceuticals', 'Drug manufacturing and healthcare', 18.20, 0.92),
('Automobile', 'Vehicle manufacturing and components', 8.70, 0.65),
('Energy', 'Oil, gas, and renewable energy', 10.80, 0.72);

INSERT INTO stocks (symbol, company_name, sector_id, current_price, historical_performance, technical_indicators, market_cap) VALUES
('INFY', 'Infosys Limited', 1, 1850.75, 
 '{"1y_return": 22.5, "3y_return": 45.8, "volatility": 18.2}'::jsonb,
 '{"rsi": 62.3, "macd": 12.5, "moving_avg_50": 1780.2, "moving_avg_200": 1650.8}'::jsonb,
 7500000),
('HDFCBANK', 'HDFC Bank Limited', 2, 1650.30, 
 '{"1y_return": 18.7, "3y_return": 38.4, "volatility": 15.8}'::jsonb,
 '{"rsi": 58.9, "macd": 8.7, "moving_avg_50": 1620.5, "moving_avg_200": 1550.3}'::jsonb,
 9200000),
('SUNPHARMA', 'Sun Pharmaceutical Industries', 3, 1125.40, 
 '{"1y_return": 25.3, "3y_return": 52.1, "volatility": 20.5}'::jsonb,
 '{"rsi": 67.2, "macd": 15.3, "moving_avg_50": 1080.6, "moving_avg_200": 980.4}'::jsonb,
 2800000),
('TATAMOTORS', 'Tata Motors Limited', 4, 780.15, 
 '{"1y_return": 14.2, "3y_return": 28.9, "volatility": 22.7}'::jsonb,
 '{"rsi": 54.1, "macd": 6.8, "moving_avg_50": 760.2, "moving_avg_200": 720.6}'::jsonb,
 3200000),
('RELIANCE', 'Reliance Industries Limited', 5, 2750.90, 
 '{"1y_return": 20.8, "3y_return": 42.3, "volatility": 16.9}'::jsonb,
 '{"rsi": 65.8, "macd": 18.2, "moving_avg_50": 2680.4, "moving_avg_200": 2450.7}'::jsonb,
 18500000);

INSERT INTO users (username, email, password_hash, role, first_name, last_name) VALUES
('client1', 'client1@example.com', 'hashed_password_1', 'client', 'Raj', 'Sharma'),
('client2', 'client2@example.com', 'hashed_password_2', 'client', 'Priya', 'Patel'),
('advisor1', 'advisor1@example.com', 'hashed_password_3', 'advisor', 'Amit', 'Kumar'),
('admin1', 'admin1@example.com', 'hashed_password_4', 'admin', 'Neha', 'Singh');

INSERT INTO portfolios (user_id, portfolio_name, total_value) VALUES
(1, 'Raj Retirement Portfolio', 1250000.00),
(1, 'Raj Growth Portfolio', 850000.00),
(2, 'Priya Conservative Portfolio', 950000.00);

INSERT INTO portfolio_stocks (portfolio_id, stock_id, quantity, purchase_price, purchase_date) VALUES
(1, 1, 50, 1700.00, '2024-01-15'),
(1, 2, 30, 1550.00, '2024-02-20'),
(1, 3, 40, 950.00, '2024-03-10'),
(2, 4, 60, 700.00, '2024-01-25'),
(2, 5, 20, 2500.00, '2024-02-15'),
(3, 1, 25, 1750.00, '2024-03-05'),
(3, 3, 35, 1000.00, '2024-03-20');

INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, reasoning, valid_until) VALUES
(1, 'BUY', 0.85, 'Strong technical indicators and positive sector outlook', CURRENT_TIMESTAMP + INTERVAL '30 days'),
(2, 'HOLD', 0.72, 'Stable performance but limited upside potential', CURRENT_TIMESTAMP + INTERVAL '15 days'),
(3, 'BUY', 0.90, 'Excellent growth potential in pharmaceutical sector', CURRENT_TIMESTAMP + INTERVAL '45 days'),
(4, 'SELL', 0.68, 'Weakening technicals and sector headwinds', CURRENT_TIMESTAMP + INTERVAL '10 days'),
(5, 'HOLD', 0.78, 'Strong fundamentals but overbought conditions', CURRENT_TIMESTAMP + INTERVAL '20 days');

INSERT INTO visual_reports (report_name, report_type, generated_by, report_data, is_public) VALUES
('Portfolio Performance Q1 2024', 'performance_analysis', 3, 
 '{"charts": ["portfolio_growth", "sector_allocation"], "metrics": ["sharpe_ratio", "alpha", "beta"]}'::jsonb,
 FALSE),
('Market Sector Analysis', 'sector_report', 3, 
 '{"charts": ["sector_comparison", "growth_trends"], "metrics": ["sector_returns", "volatility"]}'::jsonb,
 TRUE);

-- Update portfolio total values based on current stock prices
UPDATE portfolios p
SET total_value = (
    SELECT SUM(ps.quantity * s.current_price)
    FROM portfolio_stocks ps
    JOIN stocks s ON ps.stock_id = s.stock_id
    WHERE ps.portfolio_id = p.portfolio_id
)
WHERE portfolio_id IN (1, 2, 3);

-- Create views for common queries
CREATE VIEW portfolio_details AS
SELECT 
    p.portfolio_id,
    u.username,
    p.portfolio_name,
    p.total_value,
    COUNT(ps.stock_id) as number_of_stocks,
    p.created_at
FROM portfolios p
JOIN users u ON p.user_id = u.user_id
LEFT JOIN portfolio_stocks ps ON p.portfolio_id = ps.portfolio_id
GROUP BY p.portfolio_id, u.username, p.portfolio_name, p.total_value, p.created_at;

CREATE VIEW stock_signals AS
SELECT 
    s.symbol,
    s.company_name,
    sec.sector_name,
    s.current_price,
    asig.signal_type,
    asig.confidence_score,
    asig.reasoning,
    asig.valid_until
FROM stocks s
JOIN sectors sec ON s.sector_id = sec.sector_id
JOIN advisory_signals asig ON s.stock_id = asig.stock_id
WHERE asig.is_active = TRUE;

-- Grant necessary permissions (adjust based on your security requirements)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO portfolio_app;
GRANT INSERT, UPDATE, DELETE ON portfolios, portfolio_stocks TO portfolio_app;
GRANT INSERT, UPDATE, DELETE ON advisory_signals, visual_reports TO advisor_role;

COMMENT ON TABLE users IS 'Stores user information with role-based access control';
COMMENT ON TABLE portfolios IS 'Client investment portfolios with total value tracking';
COMMENT ON TABLE portfolio_stocks IS 'Junction table linking portfolios to their constituent stocks';
COMMENT ON TABLE advisory_signals IS 'Buy/Hold/Sell recommendations with confidence scores';
COMMENT ON TABLE visual_reports IS 'Advisor-only analytics and visual report data';