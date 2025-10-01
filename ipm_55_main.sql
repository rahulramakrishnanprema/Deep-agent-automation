-- IPM-55: Database Schema for Indian Equity Portfolio Management System
-- This SQL file creates the complete database schema for the MVP web application
-- Includes tables for portfolio storage, user management, Indian equities, advisory signals, and dummy data

-- Enable UUID extension for unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table for advisor-only access control
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'advisor' CHECK (role IN ('advisor', 'admin')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indian equities master table with market-specific data
CREATE TABLE indian_equities (
    equity_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20) NOT NULL,
    name VARCHAR(100) NOT NULL,
    sector VARCHAR(50) NOT NULL,
    industry VARCHAR(50) NOT NULL,
    market_cap DECIMAL(18,2),
    current_price DECIMAL(10,2) NOT NULL,
    pe_ratio DECIMAL(10,2),
    dividend_yield DECIMAL(5,2),
    volatility DECIMAL(5,2),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT unique_symbol UNIQUE (symbol)
);

-- Clients table for portfolio management
CREATE TABLE clients (
    client_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    risk_profile VARCHAR(20) CHECK (risk_profile IN ('low', 'medium', 'high')),
    investment_horizon INTEGER,
    created_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolios table for storing client portfolios
CREATE TABLE portfolios (
    portfolio_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(client_id) ON DELETE CASCADE,
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_portfolio_name UNIQUE (client_id, portfolio_name)
);

-- Portfolio holdings table with transaction history
CREATE TABLE portfolio_holdings (
    holding_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    equity_id UUID REFERENCES indian_equities(equity_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    average_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    transaction_type VARCHAR(10) CHECK (transaction_type IN ('buy', 'sell')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Advisory signals table for Buy/Hold/Sell recommendations
CREATE TABLE advisory_signals (
    signal_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    equity_id UUID REFERENCES indian_equities(equity_id),
    signal_type VARCHAR(10) NOT NULL CHECK (signal_type IN ('BUY', 'HOLD', 'SELL')),
    confidence_score DECIMAL(5,2) CHECK (confidence_score BETWEEN 0 AND 100),
    reasoning TEXT,
    generated_by UUID REFERENCES users(user_id),
    valid_until TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio signals junction table
CREATE TABLE portfolio_signals (
    portfolio_signal_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    signal_id UUID REFERENCES advisory_signals(signal_id) ON DELETE CASCADE,
    applied BOOLEAN DEFAULT FALSE,
    applied_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_portfolio_signal UNIQUE (portfolio_id, signal_id)
);

-- Dashboard reports table for visual data storage
CREATE TABLE dashboard_reports (
    report_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_type VARCHAR(50) NOT NULL,
    report_data JSONB NOT NULL,
    generated_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    period_start DATE,
    period_end DATE
);

-- Dummy data configuration table
CREATE TABLE dummy_data_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_name VARCHAR(100) NOT NULL,
    config_value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_indian_equities_symbol ON indian_equities(symbol);
CREATE INDEX idx_indian_equities_sector ON indian_equities(sector);
CREATE INDEX idx_clients_created_by ON clients(created_by);
CREATE INDEX idx_portfolios_client_id ON portfolios(client_id);
CREATE INDEX idx_portfolio_holdings_portfolio_id ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_portfolio_holdings_equity_id ON portfolio_holdings(equity_id);
CREATE INDEX idx_advisory_signals_equity_id ON advisory_signals(equity_id);
CREATE INDEX idx_advisory_signals_signal_type ON advisory_signals(signal_type);
CREATE INDEX idx_portfolio_signals_portfolio_id ON portfolio_signals(portfolio_id);
CREATE INDEX idx_dashboard_reports_report_type ON dashboard_reports(report_type);
CREATE INDEX idx_dashboard_reports_created_at ON dashboard_reports(created_at);

-- Insert initial dummy data for testing
INSERT INTO users (username, email, password_hash, role) VALUES
('admin', 'admin@portfoliomvp.com', 'hashed_password_1', 'admin'),
('advisor1', 'advisor1@portfoliomvp.com', 'hashed_password_2', 'advisor'),
('advisor2', 'advisor2@portfoliomvp.com', 'hashed_password_3', 'advisor');

INSERT INTO indian_equities (symbol, name, sector, industry, current_price, pe_ratio, dividend_yield, volatility) VALUES
('RELIANCE', 'Reliance Industries Ltd', 'Energy', 'Oil & Gas', 2650.75, 25.3, 0.85, 1.2),
('TCS', 'Tata Consultancy Services Ltd', 'IT', 'Software', 3450.20, 30.1, 1.2, 0.8),
('HDFCBANK', 'HDFC Bank Ltd', 'Financial', 'Banking', 1650.50, 20.5, 1.5, 1.0),
('INFY', 'Infosys Ltd', 'IT', 'Software', 1850.30, 28.7, 1.8, 0.9),
('ICICIBANK', 'ICICI Bank Ltd', 'Financial', 'Banking', 950.80, 18.9, 1.1, 1.3);

INSERT INTO clients (client_name, email, phone, risk_profile, investment_horizon, created_by) 
SELECT 
    'Client ' || generate_series(1, 5),
    'client' || generate_series(1, 5) || '@example.com',
    '+91-98765432' || generate_series(10, 14),
    CASE (random() * 2)::int 
        WHEN 0 THEN 'low' 
        WHEN 1 THEN 'medium' 
        ELSE 'high' 
    END,
    (random() * 10 + 1)::int,
    user_id 
FROM users WHERE role = 'advisor' LIMIT 5;

-- Insert sample portfolios
INSERT INTO portfolios (client_id, portfolio_name, description)
SELECT 
    client_id,
    'Primary Portfolio',
    'Main investment portfolio for ' || client_name
FROM clients;

-- Insert sample portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, equity_id, quantity, average_price, purchase_date, transaction_type)
SELECT 
    p.portfolio_id,
    e.equity_id,
    (random() * 100 + 10)::int,
    e.current_price * (0.9 + random() * 0.2),
    CURRENT_DATE - (random() * 365)::int,
    'buy'
FROM portfolios p
CROSS JOIN indian_equities e
LIMIT 20;

-- Insert sample advisory signals
INSERT INTO advisory_signals (equity_id, signal_type, confidence_score, reasoning, generated_by, valid_until)
SELECT 
    equity_id,
    CASE (random() * 2)::int 
        WHEN 0 THEN 'BUY' 
        WHEN 1 THEN 'HOLD' 
        ELSE 'SELL' 
    END,
    (random() * 30 + 70)::decimal(5,2),
    'Market analysis suggests ' || 
    CASE (random() * 2)::int 
        WHEN 0 THEN 'strong growth potential' 
        WHEN 1 THEN 'stable performance' 
        ELSE 'downward trend' 
    END,
    user_id,
    CURRENT_TIMESTAMP + INTERVAL '30 days'
FROM indian_equities
CROSS JOIN (SELECT user_id FROM users WHERE role = 'advisor' LIMIT 1) u
LIMIT 10;

-- Insert sample dashboard reports
INSERT INTO dashboard_reports (report_type, report_data, generated_by, period_start, period_end)
SELECT 
    'portfolio_performance',
    jsonb_build_object(
        'total_value', (random() * 1000000 + 500000)::decimal(12,2),
        'daily_change', (random() * 5000 - 2000)::decimal(10,2),
        'ytd_return', (random() * 20 + 5)::decimal(5,2)
    ),
    user_id,
    CURRENT_DATE - INTERVAL '1 month',
    CURRENT_DATE
FROM users WHERE role = 'advisor' LIMIT 3;

-- Create views for common queries
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    c.client_name,
    COUNT(ph.holding_id) as total_holdings,
    SUM(ph.quantity * e.current_price) as current_value,
    SUM(ph.quantity * ph.average_price) as invested_amount
FROM portfolios p
JOIN clients c ON p.client_id = c.client_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
LEFT JOIN indian_equities e ON ph.equity_id = e.equity_id
GROUP BY p.portfolio_id, p.portfolio_name, c.client_name;

CREATE VIEW equity_signals AS
SELECT 
    e.symbol,
    e.name,
    e.sector,
    e.current_price,
    s.signal_type,
    s.confidence_score,
    s.reasoning,
    s.valid_until,
    u.username as generated_by
FROM advisory_signals s
JOIN indian_equities e ON s.equity_id = e.equity_id
JOIN users u ON s.generated_by = u.user_id
WHERE s.valid_until > CURRENT_TIMESTAMP;

-- Create stored procedures for common operations
CREATE OR REPLACE PROCEDURE update_portfolio_value(portfolio_uuid UUID)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Procedure to update portfolio values (simplified example)
    UPDATE portfolios 
    SET updated_at = CURRENT_TIMESTAMP 
    WHERE portfolio_id = portfolio_uuid;
END;
$$;

-- Create triggers for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_modtime 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_clients_modtime 
    BEFORE UPDATE ON clients 
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_portfolios_modtime 
    BEFORE UPDATE ON portfolios 
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_portfolio_holdings_modtime 
    BEFORE UPDATE ON portfolio_holdings 
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_advisory_signals_modtime 
    BEFORE UPDATE ON advisory_signals 
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Comments for documentation
COMMENT ON TABLE users IS 'Stores advisor and admin user accounts for access control';
COMMENT ON TABLE indian_equities IS 'Master data for Indian equity securities with market-specific metrics';
COMMENT ON TABLE clients IS 'Client information for portfolio management';
COMMENT ON TABLE portfolios IS 'Portfolio containers for client investments';
COMMENT ON TABLE portfolio_holdings IS 'Individual equity holdings within portfolios with transaction history';
COMMENT ON TABLE advisory_signals IS 'Buy/Hold/Sell recommendations generated by advisors';
COMMENT ON TABLE portfolio_signals IS 'Junction table linking signals to specific portfolios';
COMMENT ON TABLE dashboard_reports IS 'Stores visual report data for dashboard displays';
COMMENT ON TABLE dummy_data_config IS 'Configuration for dummy data generation and management';

-- Grant necessary permissions (example - adjust based on actual deployment)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO portfolio_app;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO portfolio_app;