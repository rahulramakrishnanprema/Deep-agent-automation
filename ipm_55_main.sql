-- IPM-55: Portfolio Management System Database Schema
-- MVP for Indian Equity Markets Portfolio Management with Advisory Signals

-- Drop existing tables to ensure clean creation
DROP TABLE IF EXISTS portfolio_holdings;
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS sectors;
DROP TABLE IF EXISTS users;

-- Users table for authentication and role-based access
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('advisor', 'client')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sectors table for Indian market sectors
CREATE TABLE sectors (
    sector_id SERIAL PRIMARY KEY,
    sector_name VARCHAR(100) NOT NULL,
    sector_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stocks table for Indian equity market data
CREATE TABLE stocks (
    stock_id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector_id INTEGER REFERENCES sectors(sector_id),
    current_price DECIMAL(15,2) NOT NULL,
    market_cap DECIMAL(20,2),
    pe_ratio DECIMAL(10,2),
    dividend_yield DECIMAL(8,4),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(symbol)
);

-- Portfolios table for client portfolio management
CREATE TABLE portfolios (
    portfolio_id SERIAL PRIMARY KEY,
    portfolio_name VARCHAR(100) NOT NULL,
    client_user_id INTEGER REFERENCES users(user_id),
    advisor_user_id INTEGER REFERENCES users(user_id),
    total_value DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio holdings table for individual stock positions
CREATE TABLE portfolio_holdings (
    holding_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    stock_id INTEGER REFERENCES stocks(stock_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    purchase_price DECIMAL(15,2) NOT NULL,
    purchase_date DATE NOT NULL,
    current_value DECIMAL(15,2) GENERATED ALWAYS AS (quantity * (SELECT current_price FROM stocks WHERE stocks.stock_id = portfolio_holdings.stock_id)) STORED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, stock_id)
);

-- Advisory signals table for Buy/Hold/Sell recommendations
CREATE TABLE advisory_signals (
    signal_id SERIAL PRIMARY KEY,
    stock_id INTEGER REFERENCES stocks(stock_id),
    signal_type VARCHAR(10) NOT NULL CHECK (signal_type IN ('BUY', 'HOLD', 'SELL')),
    confidence_score DECIMAL(5,4) CHECK (confidence_score >= 0 AND confidence_score <= 1),
    reasoning TEXT NOT NULL,
    historical_performance_score DECIMAL(5,4),
    technical_indicators_score DECIMAL(5,4),
    sector_potential_score DECIMAL(5,4),
    market_buzz_score DECIMAL(5,4),
    generated_by INTEGER REFERENCES users(user_id),
    valid_until TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_stocks_symbol ON stocks(symbol);
CREATE INDEX idx_stocks_sector ON stocks(sector_id);
CREATE INDEX idx_portfolios_client ON portfolios(client_user_id);
CREATE INDEX idx_portfolios_advisor ON portfolios(advisor_user_id);
CREATE INDEX idx_holdings_portfolio ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_holdings_stock ON portfolio_holdings(stock_id);
CREATE INDEX idx_signals_stock ON advisory_signals(stock_id);
CREATE INDEX idx_signals_validity ON advisory_signals(valid_until);

-- Insert dummy data for sectors (Indian market focus)
INSERT INTO sectors (sector_name, sector_description) VALUES
('Information Technology', 'Software services, IT consulting, and technology solutions'),
('Banking', 'Public and private sector banks, financial services'),
('Pharmaceuticals', 'Drug manufacturers and healthcare products'),
('Automobile', 'Automotive manufacturers and components'),
('Energy', 'Oil, gas, and renewable energy companies'),
('FMCG', 'Fast-moving consumer goods and retail'),
('Telecommunications', 'Telecom services and infrastructure'),
('Infrastructure', 'Construction and infrastructure development');

-- Insert dummy data for stocks (Indian equity markets)
INSERT INTO stocks (symbol, company_name, sector_id, current_price, market_cap, pe_ratio, dividend_yield) VALUES
('INFY', 'Infosys Limited', 1, 1850.75, 7500000000000, 28.5, 0.0215),
('TCS', 'Tata Consultancy Services', 1, 3850.25, 14500000000000, 32.1, 0.0189),
('HDFCBANK', 'HDFC Bank Limited', 2, 1650.50, 9000000000000, 22.8, 0.0156),
('ICICIBANK', 'ICICI Bank Limited', 2, 980.75, 6500000000000, 19.3, 0.0128),
('SUNPHARMA', 'Sun Pharmaceutical Industries', 3, 1250.00, 3000000000000, 25.6, 0.0089),
('DRREDDY', 'Dr. Reddy''s Laboratories', 3, 5800.25, 950000000000, 31.2, 0.0075),
('TATAMOTORS', 'Tata Motors Limited', 4, 850.50, 2800000000000, 15.8, 0.0112),
('M&M', 'Mahindra & Mahindra Limited', 4, 1750.75, 1800000000000, 20.4, 0.0136),
('RELIANCE', 'Reliance Industries Limited', 5, 2850.00, 17000000000000, 27.9, 0.0098),
('ONGC', 'Oil and Natural Gas Corporation', 5, 220.25, 2800000000000, 8.7, 0.0321),
('HINDUNILVR', 'Hindustan Unilever Limited', 6, 2450.50, 5800000000000, 65.3, 0.0142),
('ITC', 'ITC Limited', 6, 430.75, 3500000000000, 23.8, 0.0289),
('BHARTIARTL', 'Bharti Airtel Limited', 7, 1150.00, 4200000000000, 45.6, 0.0056),
('LT', 'Larsen & Toubro Limited', 8, 3250.25, 3200000000000, 28.7, 0.0123);

-- Insert dummy users (advisors and clients)
INSERT INTO users (username, email, password_hash, role) VALUES
('advisor1', 'advisor1@example.com', 'hashed_password_1', 'advisor'),
('advisor2', 'advisor2@example.com', 'hashed_password_2', 'advisor'),
('client1', 'client1@example.com', 'hashed_password_3', 'client'),
('client2', 'client2@example.com', 'hashed_password_4', 'client'),
('client3', 'client3@example.com', 'hashed_password_5', 'client');

-- Insert dummy portfolios
INSERT INTO portfolios (portfolio_name, client_user_id, advisor_user_id, total_value) VALUES
('Growth Portfolio', 3, 1, 1500000.00),
('Conservative Portfolio', 4, 1, 850000.00),
('Balanced Portfolio', 5, 2, 1200000.00);

-- Insert dummy portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, purchase_price, purchase_date) VALUES
(1, 1, 100, 1700.00, '2024-01-15'),
(1, 3, 200, 1500.00, '2024-02-10'),
(1, 5, 150, 1100.00, '2024-03-05'),
(2, 2, 50, 3500.00, '2024-01-20'),
(2, 4, 300, 900.00, '2024-02-25'),
(2, 6, 75, 5500.00, '2024-03-15'),
(3, 7, 200, 800.00, '2024-01-30'),
(3, 9, 100, 2700.00, '2024-02-20'),
(3, 11, 80, 2300.00, '2024-03-10');

-- Insert dummy advisory signals
INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, reasoning, historical_performance_score, technical_indicators_score, sector_potential_score, market_buzz_score, generated_by, valid_until) VALUES
(1, 'BUY', 0.85, 'Strong quarterly results and positive guidance', 0.88, 0.82, 0.79, 0.86, 1, CURRENT_TIMESTAMP + INTERVAL '30 days'),
(2, 'HOLD', 0.72, 'Stable performance but limited upside potential', 0.75, 0.68, 0.71, 0.74, 1, CURRENT_TIMESTAMP + INTERVAL '30 days'),
(3, 'BUY', 0.91, 'Excellent asset quality and growth prospects', 0.92, 0.89, 0.85, 0.88, 2, CURRENT_TIMESTAMP + INTERVAL '30 days'),
(4, 'SELL', 0.68, 'Increasing NPA concerns and margin pressure', 0.62, 0.71, 0.65, 0.69, 2, CURRENT_TIMESTAMP + INTERVAL '30 days'),
(5, 'BUY', 0.79, 'Strong pipeline and regulatory approvals', 0.81, 0.76, 0.75, 0.78, 1, CURRENT_TIMESTAMP + INTERVAL '30 days');

-- View for portfolio performance analysis
CREATE VIEW portfolio_performance AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    u.username as client_name,
    a.username as advisor_name,
    SUM(ph.current_value) as current_total_value,
    SUM(ph.quantity * ph.purchase_price) as initial_investment,
    (SUM(ph.current_value) - SUM(ph.quantity * ph.purchase_price)) as total_gain_loss,
    (SUM(ph.current_value) / SUM(ph.quantity * ph.purchase_price) - 1) * 100 as return_percentage
FROM portfolios p
JOIN users u ON p.client_user_id = u.user_id
JOIN users a ON p.advisor_user_id = a.user_id
JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
GROUP BY p.portfolio_id, p.portfolio_name, u.username, a.username;

-- View for stock performance with sector information
CREATE VIEW stock_performance AS
SELECT 
    s.stock_id,
    s.symbol,
    s.company_name,
    sec.sector_name,
    s.current_price,
    s.market_cap,
    s.pe_ratio,
    s.dividend_yield,
    COALESCE(asig.signal_type, 'HOLD') as latest_signal,
    COALESCE(asig.confidence_score, 0.5) as signal_confidence
FROM stocks s
JOIN sectors sec ON s.sector_id = sec.sector_id
LEFT JOIN (
    SELECT DISTINCT ON (stock_id) *
    FROM advisory_signals
    ORDER BY stock_id, created_at DESC
) asig ON s.stock_id = asig.stock_id;

-- Function to update portfolio total value
CREATE OR REPLACE FUNCTION update_portfolio_value()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE portfolios
    SET total_value = (
        SELECT COALESCE(SUM(current_value), 0)
        FROM portfolio_holdings
        WHERE portfolio_id = NEW.portfolio_id
    ),
    updated_at = CURRENT_TIMESTAMP
    WHERE portfolio_id = NEW.portfolio_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update portfolio value when holdings change
CREATE TRIGGER trigger_update_portfolio_value
AFTER INSERT OR UPDATE OR DELETE ON portfolio_holdings
FOR EACH ROW
EXECUTE FUNCTION update_portfolio_value();

-- Function to get advisory signals for a specific portfolio
CREATE OR REPLACE FUNCTION get_portfolio_signals(portfolio_id_param INTEGER)
RETURNS TABLE (
    stock_symbol VARCHAR,
    company_name VARCHAR,
    current_holdings INTEGER,
    current_value DECIMAL,
    signal_type VARCHAR,
    confidence_score DECIMAL,
    reasoning TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.symbol,
        s.company_name,
        COALESCE(ph.quantity, 0) as current_holdings,
        COALESCE(ph.current_value, 0) as current_value,
        asig.signal_type,
        asig.confidence_score,
        asig.reasoning
    FROM stocks s
    LEFT JOIN portfolio_holdings ph ON s.stock_id = ph.stock_id AND ph.portfolio_id = portfolio_id_param
    LEFT JOIN (
        SELECT DISTINCT ON (stock_id) *
        FROM advisory_signals
        WHERE valid_until > CURRENT_TIMESTAMP
        ORDER BY stock_id, created_at DESC
    ) asig ON s.stock_id = asig.stock_id
    ORDER BY asig.confidence_score DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate sector allocation for a portfolio
CREATE OR REPLACE FUNCTION get_portfolio_sector_allocation(portfolio_id_param INTEGER)
RETURNS TABLE (
    sector_name VARCHAR,
    sector_value DECIMAL,
    allocation_percentage DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sec.sector_name,
        SUM(ph.current_value) as sector_value,
        (SUM(ph.current_value) / NULLIF(p.total_value, 0)) * 100 as allocation_percentage
    FROM portfolio_holdings ph
    JOIN stocks s ON ph.stock_id = s.stock_id
    JOIN sectors sec ON s.sector_id = sec.sector_id
    JOIN portfolios p ON ph.portfolio_id = p.portfolio_id
    WHERE ph.portfolio_id = portfolio_id_param
    GROUP BY sec.sector_name, p.total_value
    ORDER BY sector_value DESC;
END;
$$ LANGUAGE plpgsql;

-- Comments for documentation
COMMENT ON TABLE users IS 'Stores user accounts for advisors and clients with role-based access control';
COMMENT ON TABLE sectors IS 'Indian market sectors for classification and sector analysis';
COMMENT ON TABLE stocks IS 'Indian equity market stocks with current pricing and fundamental data';
COMMENT ON TABLE portfolios IS 'Client investment portfolios managed by advisors';
COMMENT ON TABLE portfolio_holdings IS 'Individual stock positions within client portfolios';
COMMENT ON TABLE advisory_signals IS 'Buy/Hold/Sell recommendations generated by analysis modules';
COMMENT ON VIEW portfolio_performance IS 'Aggregated portfolio performance metrics for reporting';
COMMENT ON VIEW stock_performance IS 'Comprehensive stock data with latest advisory signals';
COMMENT ON FUNCTION get_portfolio_signals IS 'Returns advisory signals for all stocks in a specific portfolio';
COMMENT ON FUNCTION get_portfolio_sector_allocation IS 'Calculates sector allocation percentages for a portfolio';