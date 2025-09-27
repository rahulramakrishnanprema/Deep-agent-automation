-- IPM-55: Database Initialization Script for Portfolio Management System
-- This script creates the core database schema for the Indian Portfolio Management application

-- Enable UUID extension for unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table for authentication and authorization
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Clients table
CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pan_number VARCHAR(10) UNIQUE NOT NULL,
    phone_number VARCHAR(15),
    address TEXT,
    risk_profile VARCHAR(20) CHECK (risk_profile IN ('LOW', 'MEDIUM', 'HIGH')),
    investment_horizon VARCHAR(20) CHECK (investment_horizon IN ('SHORT', 'MEDIUM', 'LONG')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Portfolios table
CREATE TABLE portfolios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    total_value DECIMAL(15,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Stocks master table (NSE/BSE listed companies)
CREATE TABLE stocks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20) NOT NULL,
    name VARCHAR(255) NOT NULL,
    exchange VARCHAR(10) CHECK (exchange IN ('NSE', 'BSE')),
    sector VARCHAR(100),
    industry VARCHAR(100),
    isin_code VARCHAR(12) UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(symbol, exchange)
);

-- Holdings table
CREATE TABLE holdings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    stock_id UUID NOT NULL REFERENCES stocks(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    average_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    current_price DECIMAL(10,2),
    current_value DECIMAL(15,2) GENERATED ALWAYS AS (quantity * current_price) STORED,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Market data table for daily prices
CREATE TABLE market_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID NOT NULL REFERENCES stocks(id),
    date DATE NOT NULL,
    open_price DECIMAL(10,2),
    high_price DECIMAL(10,2),
    low_price DECIMAL(10,2),
    close_price DECIMAL(10,2),
    volume BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_id, date)
);

-- News articles table
CREATE TABLE news_articles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID REFERENCES stocks(id),
    title TEXT NOT NULL,
    content TEXT,
    source VARCHAR(100),
    published_at TIMESTAMP WITH TIME ZONE,
    sentiment_score DECIMAL(5,4) CHECK (sentiment_score BETWEEN -1 AND 1),
    url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sentiment data table
CREATE TABLE sentiment_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID NOT NULL REFERENCES stocks(id),
    date DATE NOT NULL,
    sentiment_score DECIMAL(5,4) CHECK (sentiment_score BETWEEN -1 AND 1),
    source VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_id, date, source)
);

-- Advisory signals table
CREATE TABLE advisory_signals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_id UUID NOT NULL REFERENCES stocks(id),
    signal_type VARCHAR(10) CHECK (signal_type IN ('BUY', 'SELL', 'HOLD')),
    confidence_score DECIMAL(5,4) CHECK (confidence_score BETWEEN 0 AND 1),
    reasoning TEXT,
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio signals junction table
CREATE TABLE portfolio_signals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    signal_id UUID NOT NULL REFERENCES advisory_signals(id) ON DELETE CASCADE,
    is_applied BOOLEAN DEFAULT FALSE,
    applied_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, signal_id)
);

-- Transactions table
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    stock_id UUID NOT NULL REFERENCES stocks(id),
    type VARCHAR(4) CHECK (type IN ('BUY', 'SELL')),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price DECIMAL(10,2) NOT NULL,
    transaction_date DATE NOT NULL,
    brokerage DECIMAL(10,2) DEFAULT 0.00,
    taxes DECIMAL(10,2) DEFAULT 0.00,
    total_amount DECIMAL(15,2) GENERATED ALWAYS AS (
        quantity * price + CASE WHEN type = 'BUY' THEN brokerage + taxes ELSE -brokerage - taxes END
    ) STORED,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- User sessions table for authentication
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Refresh tokens table
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_clients_user_id ON clients(user_id);
CREATE INDEX idx_portfolios_client_id ON portfolios(client_id);
CREATE INDEX idx_holdings_portfolio_id ON holdings(portfolio_id);
CREATE INDEX idx_holdings_stock_id ON holdings(stock_id);
CREATE INDEX idx_market_data_stock_id ON market_data(stock_id);
CREATE INDEX idx_market_data_date ON market_data(date);
CREATE INDEX idx_news_stock_id ON news_articles(stock_id);
CREATE INDEX idx_sentiment_stock_id ON sentiment_data(stock_id);
CREATE INDEX idx_advisory_signals_stock_id ON advisory_signals(stock_id);
CREATE INDEX idx_advisory_signals_generated_at ON advisory_signals(generated_at);
CREATE INDEX idx_transactions_portfolio_id ON transactions(portfolio_id);
CREATE INDEX idx_transactions_stock_id ON transactions(stock_id);
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON clients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_portfolios_updated_at BEFORE UPDATE ON portfolios FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_holdings_updated_at BEFORE UPDATE ON holdings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_stocks_updated_at BEFORE UPDATE ON stocks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data for demonstration
INSERT INTO users (email, password_hash, first_name, last_name, is_admin) VALUES
('admin@ipm.com', '$2b$10$examplehash', 'Admin', 'User', TRUE),
('client1@ipm.com', '$2b$10$examplehash2', 'Rahul', 'Sharma', FALSE);

INSERT INTO clients (user_id, pan_number, phone_number, risk_profile, investment_horizon) VALUES
((SELECT id FROM users WHERE email = 'client1@ipm.com'), 'ABCDE1234F', '+919876543210', 'MEDIUM', 'LONG');

INSERT INTO portfolios (client_id, name, description) VALUES
((SELECT id FROM clients LIMIT 1), 'Main Portfolio', 'Primary investment portfolio');

-- Insert sample Indian stocks
INSERT INTO stocks (symbol, name, exchange, sector, isin_code) VALUES
('RELIANCE', 'Reliance Industries Limited', 'NSE', 'Oil & Gas', 'INE002A01018'),
('TCS', 'Tata Consultancy Services Limited', 'NSE', 'Information Technology', 'INE467B01029'),
('HDFCBANK', 'HDFC Bank Limited', 'NSE', 'Banking', 'INE040A01034'),
('INFY', 'Infosys Limited', 'NSE', 'Information Technology', 'INE009A01021');

COMMENT ON TABLE users IS 'Stores user authentication information and profiles';
COMMENT ON TABLE clients IS 'Stores client details and investment preferences';
COMMENT ON TABLE portfolios IS 'Manages client investment portfolios';
COMMENT ON TABLE stocks IS 'Master list of Indian stocks with company information';
COMMENT ON TABLE holdings IS 'Tracks stock holdings within each portfolio';
COMMENT ON TABLE market_data IS 'Stores daily market price data for stocks';
COMMENT ON TABLE news_articles IS 'Contains news articles with sentiment analysis';
COMMENT ON TABLE sentiment_data IS 'Stores sentiment scores from various sources';
COMMENT ON TABLE adv
# Code truncated at 10000 characters