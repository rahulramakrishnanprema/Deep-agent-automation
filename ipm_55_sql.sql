-- IPM-55: Database Schema for Indian Portfolio Management System
-- This script creates the core database schema for the Indian Portfolio Management application
-- Includes tables for user authentication, portfolios, holdings, advisory signals, and market data

-- Enable UUID extension for secure primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table for authentication and authorization
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Portfolios table for storing client portfolios
CREATE TABLE portfolios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    initial_capital DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    risk_profile VARCHAR(20) CHECK (risk_profile IN ('LOW', 'MODERATE', 'HIGH', 'AGGRESSIVE')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indian stocks reference table
CREATE TABLE indian_stocks (
    symbol VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    sector VARCHAR(50),
    industry VARCHAR(50),
    exchange VARCHAR(10) CHECK (exchange IN ('NSE', 'BSE')),
    isin_code VARCHAR(12) UNIQUE,
    listing_date DATE,
    market_cap_category VARCHAR(20) CHECK (market_cap_category IN ('LARGE', 'MID', 'SMALL')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio holdings table
CREATE TABLE portfolio_holdings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    stock_symbol VARCHAR(20) NOT NULL REFERENCES indian_stocks(symbol),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    average_price DECIMAL(15,2) NOT NULL,
    purchase_date DATE NOT NULL,
    sector VARCHAR(50),
    investment_value DECIMAL(15,2) GENERATED ALWAYS AS (quantity * average_price) STORED,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, stock_symbol)
);

-- Market data table for storing daily prices
CREATE TABLE market_data_daily (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_symbol VARCHAR(20) NOT NULL REFERENCES indian_stocks(symbol),
    date DATE NOT NULL,
    open_price DECIMAL(15,2),
    high_price DECIMAL(15,2),
    low_price DECIMAL(15,2),
    close_price DECIMAL(15,2) NOT NULL,
    volume BIGINT,
    turnover DECIMAL(20,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_symbol, date)
);

-- Technical indicators table
CREATE TABLE technical_indicators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_symbol VARCHAR(20) NOT NULL REFERENCES indian_stocks(symbol),
    date DATE NOT NULL,
    sma_20 DECIMAL(15,2),
    sma_50 DECIMAL(15,2),
    sma_200 DECIMAL(15,2),
    rsi_14 DECIMAL(8,2),
    macd DECIMAL(8,2),
    macd_signal DECIMAL(8,2),
    macd_histogram DECIMAL(8,2),
    bollinger_upper DECIMAL(15,2),
    bollinger_lower DECIMAL(15,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_symbol, date)
);

-- News sources table
CREATE TABLE news_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    website_url VARCHAR(255),
    api_endpoint VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- News articles table for sentiment analysis
CREATE TABLE news_articles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID REFERENCES news_sources(id),
    stock_symbol VARCHAR(20) REFERENCES indian_stocks(symbol),
    title TEXT NOT NULL,
    content TEXT,
    published_at TIMESTAMP WITH TIME ZONE,
    url VARCHAR(500),
    sentiment_score DECIMAL(5,2) CHECK (sentiment_score BETWEEN -1 AND 1),
    sentiment_magnitude DECIMAL(5,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Advisory signals table
CREATE TABLE advisory_signals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    stock_symbol VARCHAR(20) NOT NULL REFERENCES indian_stocks(symbol),
    signal_type VARCHAR(10) CHECK (signal_type IN ('BUY', 'SELL', 'HOLD', 'STRONG_BUY', 'STRONG_SELL')),
    confidence_score DECIMAL(5,2) CHECK (confidence_score BETWEEN 0 AND 1),
    reasoning TEXT NOT NULL,
    target_price DECIMAL(15,2),
    stop_loss DECIMAL(15,2),
    time_horizon VARCHAR(20) CHECK (time_horizon IN ('SHORT', 'MEDIUM', 'LONG')),
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Signal factors table to track what influenced each signal
CREATE TABLE signal_factors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    signal_id UUID NOT NULL REFERENCES advisory_signals(id) ON DELETE CASCADE,
    factor_type VARCHAR(50) NOT NULL,
    factor_value DECIMAL(15,4),
    weight DECIMAL(5,2) CHECK (weight BETWEEN 0 AND 1),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio performance history
CREATE TABLE portfolio_performance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_value DECIMAL(15,2) NOT NULL,
    cash_balance DECIMAL(15,2) NOT NULL,
    daily_return DECIMAL(8,4),
    cumulative_return DECIMAL(8,4),
    volatility DECIMAL(8,4),
    sharpe_ratio DECIMAL(8,4),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, date)
);

-- Application configuration table
CREATE TABLE app_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    config_type VARCHAR(20) CHECK (config_type IN ('STRING', 'NUMBER', 'BOOLEAN', 'JSON')),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- API keys and credentials for market data integration
CREATE TABLE api_credentials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_name VARCHAR(100) NOT NULL,
    api_key VARCHAR(255) NOT NULL,
    secret_key VARCHAR(255),
    base_url VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    rate_limit INTEGER,
    last_used TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- User sessions for authentication
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX idx_portfolios_user_id ON portfolios(user_id);
CREATE INDEX idx_portfolio_holdings_portfolio_id ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_portfolio_holdings_stock_symbol ON portfolio_holdings(stock_symbol);
CREATE INDEX idx_market_data_daily_symbol_date ON market_data_daily(stock_symbol, date);
CREATE INDEX idx_technical_indicators_symbol_date ON technical_indicators(stock_symbol, date);
CREATE INDEX idx_advisory_signals_portfolio_id ON advisory_signals(portfolio_id);
CREATE INDEX idx_advisory_signals_stock_symbol ON advisory_signals(stock_symbol);
CREATE INDEX idx_news_articles_stock_symbol ON news_articles(stock_symbol);
CREATE INDEX idx_news_articles_published_at ON news_articles(published_at);
CREATE INDEX idx_portfolio_performance_portfolio_date ON portfolio_performance(portfolio_id, date);
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_session_token ON user_sessions(session_token);

-- Insert default configuration values
INSERT INTO app_configurations (config_key, config_value, config_type, description) VALUES
('MARKET_DATA_REFRESH_INTERVAL', '300', 'NUMBER', 'Interval in seconds for market data refresh'),
('SENTIMENT_ANALYSIS_ENABLED', 'true', 'BOOLEAN', 'Enable/disable sentiment analysis'),
('TECHNICAL_INDICATOR_DAYS', '50', 'NUMBER', 'Number of days to calculate technical indicators'),
('DEFAULT_RISK_PROFILE', 'MODERATE', 'STRING', 'Default risk profile for new portfolios'),
('MAX_PORTFOLIOS_PER_USER', '5', 'NUMBER', 'Maximum number of portfolios per user'),
('MIN_CONFIDENCE_SCORE', '0.6', 'NUMBER', 'Minimum confidence score for advisory signals'),
('DATA_RETENTION_DAYS', '365', 'NUMBER', 'Number of days to retain historical data');

-- Insert sample Indian stocks
INSERT INTO indian_stocks (symbol, name, sector, industry, exchange, isin_code, market_cap_category) VALUES
('RELIANCE', 'Reliance Industries Limited', 'Energy', 'Oil & Gas', 'NSE', 'INE002A01018', 'LARGE'),
('TCS', 'Tata Consultancy Services Limited', 'Information Technology', 'Software', 'NSE', 'INE467B01029', 'LARGE'),
('HDFCBANK', 'HDFC Bank Limited', 'Financial Se
# Code truncated at 10000 characters