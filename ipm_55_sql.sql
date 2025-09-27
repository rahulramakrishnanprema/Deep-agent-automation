-- IPM-55: Portfolio Management System SQL Schema
-- This script creates the database schema for the Indian Portfolio Management system
-- Includes tables for user management, portfolio storage, market data, advisory signals, and dashboards

-- Enable UUID extension for unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table for authentication and authorization
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    user_type VARCHAR(20) CHECK (user_type IN ('advisor', 'client', 'admin')) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Roles table for authorization
CREATE TABLE roles (
    role_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- User roles junction table
CREATE TABLE user_roles (
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(role_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- Permissions table
CREATE TABLE permissions (
    permission_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    permission_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Role permissions junction table
CREATE TABLE role_permissions (
    role_id UUID REFERENCES roles(role_id) ON DELETE CASCADE,
    permission_id UUID REFERENCES permissions(permission_id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- Client profiles table
CREATE TABLE client_profiles (
    client_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    risk_profile VARCHAR(20) CHECK (risk_profile IN ('low', 'medium', 'high', 'very_high')),
    investment_horizon VARCHAR(20),
    total_investment_value DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Advisor-client relationships
CREATE TABLE advisor_clients (
    advisor_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    client_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    relationship_status VARCHAR(20) DEFAULT 'active' CHECK (relationship_status IN ('active', 'inactive', 'pending')),
    assigned_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (advisor_id, client_id)
);

-- Indian market securities master table
CREATE TABLE securities (
    security_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20) NOT NULL,
    name VARCHAR(255) NOT NULL,
    exchange VARCHAR(10) CHECK (exchange IN ('NSE', 'BSE')),
    sector VARCHAR(100),
    industry VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(symbol, exchange)
);

-- Portfolio table
CREATE TABLE portfolios (
    portfolio_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    portfolio_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio holdings table
CREATE TABLE portfolio_holdings (
    holding_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    security_id UUID REFERENCES securities(security_id),
    quantity DECIMAL(12,4) NOT NULL CHECK (quantity >= 0),
    average_buy_price DECIMAL(12,4) NOT NULL,
    acquisition_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Market data table for real-time prices
CREATE TABLE market_data (
    data_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    security_id UUID REFERENCES securities(security_id),
    price DECIMAL(12,4) NOT NULL,
    volume BIGINT,
    change_percent DECIMAL(8,4),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- News sources table
CREATE TABLE news_sources (
    source_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_name VARCHAR(255) NOT NULL,
    website_url VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Market news table
CREATE TABLE market_news (
    news_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID REFERENCES news_sources(source_id),
    title VARCHAR(500) NOT NULL,
    content TEXT,
    url VARCHAR(1000),
    published_at TIMESTAMP WITH TIME ZONE,
    sentiment_score DECIMAL(5,4) CHECK (sentiment_score BETWEEN -1 AND 1),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- News security mapping table
CREATE TABLE news_security_mapping (
    news_id UUID REFERENCES market_news(news_id) ON DELETE CASCADE,
    security_id UUID REFERENCES securities(security_id) ON DELETE CASCADE,
    relevance_score DECIMAL(5,4) DEFAULT 1.0,
    PRIMARY KEY (news_id, security_id)
);

-- Advisory signals table
CREATE TABLE advisory_signals (
    signal_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    security_id UUID REFERENCES securities(security_id),
    signal_type VARCHAR(10) CHECK (signal_type IN ('BUY', 'SELL', 'HOLD')) NOT NULL,
    reasoning TEXT NOT NULL,
    confidence_score DECIMAL(5,4) CHECK (confidence_score BETWEEN 0 AND 1) NOT NULL,
    target_price DECIMAL(12,4),
    stop_loss DECIMAL(12,4),
    time_horizon VARCHAR(20),
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- User signal preferences table
CREATE TABLE user_signal_preferences (
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    signal_type VARCHAR(10) CHECK (signal_type IN ('BUY', 'SELL', 'HOLD')),
    min_confidence_score DECIMAL(5,4) DEFAULT 0.7,
    PRIMARY KEY (user_id, signal_type)
);

-- Dashboard configurations table
CREATE TABLE dashboard_configs (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    dashboard_name VARCHAR(255) NOT NULL,
    config_json JSONB NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Audit table for portfolio changes
CREATE TABLE portfolio_audit (
    audit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID REFERENCES portfolios(portfolio_id),
    user_id UUID REFERENCES users(user_id),
    action_type VARCHAR(20) NOT NULL,
    action_details JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_securities_symbol ON securities(symbol);
CREATE INDEX idx_securities_exchange ON securities(exchange);
CREATE INDEX idx_market_data_security_id ON market_data(security_id);
CREATE INDEX idx_market_data_timestamp ON market_data(timestamp);
CREATE INDEX idx_portfolios_client_id ON portfolios(client_id);
CREATE INDEX idx_portfolio_holdings_portfolio_id ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_advisory_signals_security_id ON advisory_signals(security_id);
CREATE INDEX idx_advisory_signals_generated_at ON advisory_signals(generated_at);
CREATE INDEX idx_market_news_published_at ON market_news(published_at);
CREATE INDEX idx_market_news_sentiment ON market_news(sentiment_score);

-- Insert default roles
INSERT INTO roles (role_name, description) VALUES 
('admin', 'System administrator with full access'),
('advisor', 'Financial advisor with client management capabilities'),
('client', 'End client with portfolio access');

-- Insert default permissions
INSERT INTO permissions (permission_name, description) VALUES
('view_dashboard', 'View personal dashboard'),
('manage_portfolio', 'Create and manage investment portfolio'),
('view_advisory_signals', 'View AI-generated advisory signals'),
('view_market_data', 'Access real-time market data'),
('view_news', 'Access market news and analysis'),
('manage_clients', 'Manage client relationships and portfolios'),
('system_admin', 'Full system administration access');

-- Insert default role permissions
INSERT INTO role_permissions (role_id, permission_id) 
SELECT r.role_id, p.permission_id 
FROM roles r, permissions p 
WHERE r.role_name = 'admin';

INSERT INTO role_permissions (role_id, permission_id) 
SELECT r.role_id, p.permission_id 
FROM roles r, permissions p 
WHERE r.role_name = 'advisor' 
AND p.permission_name IN ('view_dashboard', 'view_advisory_signals', 'view_market_data', 'view_news', 'manage_clients');

INSERT INTO role_permissions (role_id, permission_id) 
SELECT r.role_id, p.permission_id 
FROM roles r, permissions p 
WHERE r.role_name = 'client' 
AND p.permission_name IN ('view_dashboard', 'manage_portfolio', 'view_advisory_signals', 'view_market_data', 'view_news');

-- Insert sample news sources
INSERT INTO news_sources (source_name, website_url) VALUES
('Economic Times', 'https://economictimes.indiatimes.com'),
('Moneycontrol', 'https://www.moneycontrol.com'),
('Business Standard', 'https://www.business-standard.com'),
('Bloomberg Quint', 'https://www.bloombergquint.com'
# Code truncated at 10000 characters