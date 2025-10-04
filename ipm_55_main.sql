-- Portfolio Management System Database Schema for Indian Equity Market
-- This SQL file creates the necessary tables for an MVP web application
-- that manages Indian equity portfolios with advisory signals and reporting

-- Securities table to store Indian equity instruments
CREATE TABLE IF NOT EXISTS securities (
    id SERIAL PRIMARY KEY,
    isin_code VARCHAR(12) UNIQUE NOT NULL,  -- ISIN code for Indian securities
    bse_code VARCHAR(10),                   -- BSE security code
    nse_symbol VARCHAR(20),                 -- NSE trading symbol
    company_name VARCHAR(255) NOT NULL,
    sector VARCHAR(100) NOT NULL,
    industry VARCHAR(100),
    market_cap_category VARCHAR(20) CHECK (market_cap_category IN ('Large Cap', 'Mid Cap', 'Small Cap')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for faster queries on Indian market codes
CREATE INDEX IF NOT EXISTS idx_securities_isin ON securities(isin_code);
CREATE INDEX IF NOT EXISTS idx_securities_bse ON securities(bse_code);
CREATE INDEX IF NOT EXISTS idx_securities_nse ON securities(nse_symbol);
CREATE INDEX IF NOT EXISTS idx_securities_sector ON securities(sector);

-- Portfolios table to store client portfolio information
CREATE TABLE IF NOT EXISTS portfolios (
    id SERIAL PRIMARY KEY,
    portfolio_name VARCHAR(255) NOT NULL,
    client_name VARCHAR(255) NOT NULL,
    client_email VARCHAR(255),
    total_value DECIMAL(15,2) DEFAULT 0.00,
    risk_profile VARCHAR(20) CHECK (risk_profile IN ('Low', 'Medium', 'High')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Transactions table to record all portfolio transactions
CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    security_id INTEGER NOT NULL REFERENCES securities(id),
    transaction_type VARCHAR(4) CHECK (transaction_type IN ('BUY', 'SELL')) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price DECIMAL(10,2) NOT NULL CHECK (price > 0),
    transaction_date DATE NOT NULL,
    exchange VARCHAR(3) CHECK (exchange IN ('BSE', 'NSE')) NOT NULL,
    brokerages DECIMAL(10,2) DEFAULT 0.00,
    taxes DECIMAL(10,2) DEFAULT 0.00,
    total_amount DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for transaction queries
CREATE INDEX IF NOT EXISTS idx_transactions_portfolio ON transactions(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_transactions_security ON transactions(security_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);

-- Holdings table to track current portfolio positions
CREATE TABLE IF NOT EXISTS holdings (
    id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    security_id INTEGER NOT NULL REFERENCES securities(id),
    quantity INTEGER NOT NULL DEFAULT 0,
    average_buy_price DECIMAL(10,2) NOT NULL,
    total_investment DECIMAL(15,2) NOT NULL,
    current_value DECIMAL(15,2) DEFAULT 0.00,
    unrealized_pnl DECIMAL(15,2) DEFAULT 0.00,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, security_id)
);

-- Index for holdings queries
CREATE INDEX IF NOT EXISTS idx_holdings_portfolio ON holdings(portfolio_id);

-- Market data table for storing current and historical prices
CREATE TABLE IF NOT EXISTS market_data (
    id SERIAL PRIMARY KEY,
    security_id INTEGER NOT NULL REFERENCES securities(id),
    price_date DATE NOT NULL,
    open_price DECIMAL(10,2),
    high_price DECIMAL(10,2),
    low_price DECIMAL(10,2),
    close_price DECIMAL(10,2) NOT NULL,
    volume BIGINT,
    exchange VARCHAR(3) CHECK (exchange IN ('BSE', 'NSE')) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(security_id, price_date, exchange)
);

-- Index for market data queries
CREATE INDEX IF NOT EXISTS idx_market_data_security ON market_data(security_id);
CREATE INDEX IF NOT EXISTS idx_market_data_date ON market_data(price_date);

-- Advisory signals table for storing Buy/Hold/Sell recommendations
CREATE TABLE IF NOT EXISTS advisory_signals (
    id SERIAL PRIMARY KEY,
    security_id INTEGER NOT NULL REFERENCES securities(id),
    signal_type VARCHAR(10) CHECK (signal_type IN ('BUY', 'HOLD', 'SELL')) NOT NULL,
    confidence_score DECIMAL(5,2) CHECK (confidence_score BETWEEN 0 AND 100),
    rationale TEXT NOT NULL,
    target_price DECIMAL(10,2),
    stop_loss DECIMAL(10,2),
    time_horizon VARCHAR(20) CHECK (time_horizon IN ('Short Term', 'Medium Term', 'Long Term')),
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Index for advisory signals queries
CREATE INDEX IF NOT EXISTS idx_advisory_signals_security ON advisory_signals(security_id);
CREATE INDEX IF NOT EXISTS idx_advisory_signals_active ON advisory_signals(is_active);
CREATE INDEX IF NOT EXISTS idx_advisory_signals_type ON advisory_signals(signal_type);

-- Portfolio signals table linking signals to specific portfolios
CREATE TABLE IF NOT EXISTS portfolio_signals (
    id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    advisory_signal_id INTEGER NOT NULL REFERENCES advisory_signals(id),
    action_taken VARCHAR(20) CHECK (action_taken IN ('FOLLOWED', 'IGNORED', 'PENDING')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dashboard reports table for storing visual report configurations
CREATE TABLE IF NOT EXISTS dashboard_reports (
    id SERIAL PRIMARY KEY,
    report_name VARCHAR(255) NOT NULL,
    report_type VARCHAR(50) CHECK (report_type IN ('Portfolio Performance', 'Sector Allocation', 'Risk Analysis', 'Advisory Summary')),
    portfolio_id INTEGER REFERENCES portfolios(id) ON DELETE CASCADE,
    config_json JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Function to update portfolio total value
CREATE OR REPLACE FUNCTION update_portfolio_value()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE portfolios 
        SET total_value = (
            SELECT COALESCE(SUM(current_value), 0)
            FROM holdings 
            WHERE portfolio_id = NEW.portfolio_id
        ),
        updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.portfolio_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE portfolios 
        SET total_value = (
            SELECT COALESCE(SUM(current_value), 0)
            FROM holdings 
            WHERE portfolio_id = OLD.portfolio_id
        ),
        updated_at = CURRENT_TIMESTAMP
        WHERE id = OLD.portfolio_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update portfolio value when holdings change
CREATE TRIGGER trigger_update_portfolio_value
    AFTER INSERT OR UPDATE OR DELETE ON holdings
    FOR EACH ROW
    EXECUTE FUNCTION update_portfolio_value();

-- Function to update holding when transaction occurs
CREATE OR REPLACE FUNCTION update_holding_on_transaction()
RETURNS TRIGGER AS $$
DECLARE
    current_quantity INTEGER;
    current_avg_price DECIMAL(10,2);
    new_avg_price DECIMAL(10,2);
BEGIN
    -- Get current holding if exists
    SELECT quantity, average_buy_price INTO current_quantity, current_avg_price
    FROM holdings 
    WHERE portfolio_id = NEW.portfolio_id AND security_id = NEW.security_id;
    
    IF NOT FOUND THEN
        current_quantity := 0;
        current_avg_price := 0;
    END IF;
    
    IF NEW.transaction_type = 'BUY' THEN
        -- Calculate new average price for BUY
        new_avg_price := ((current_quantity * current_avg_price) + (NEW.quantity * NEW.price)) / 
                         (current_quantity + NEW.quantity);
        
        INSERT INTO holdings (portfolio_id, security_id, quantity, average_buy_price, total_investment)
        VALUES (NEW.portfolio_id, NEW.security_id, current_quantity + NEW.quantity, 
                new_avg_price, (current_quantity + NEW.quantity) * new_avg_price)
        ON CONFLICT (portfolio_id, security_id) 
        DO UPDATE SET 
            quantity = EXCLUDED.quantity,
            average_buy_price = EXCLUDED.average_buy_price,
            total_investment = EXCLUDED.total_investment,
            last_updated = CURRENT_TIMESTAMP;
            
    ELSIF NEW.transaction_type = 'SELL' THEN
        IF current_quantity < NEW.quantity THEN
            RAISE EXCEPTION 'Insufficient holdings for sell transaction';
        END IF;
        
        -- For SELL, we reduce quantity but keep average buy price unchanged
        INSERT INTO holdings (portfolio_id, security_id, quantity, average_buy_price, total_investment)
        VALUES (NEW.portfolio_id, NEW.security_id, current_quantity - NEW.quantity, 
                current_avg_price, (current_quantity - NEW.quantity) * current_avg_price)
        ON CONFLICT (portfolio_id, security_id) 
        DO UPDATE SET 
            quantity = EXCLUDED.quantity,
            total_investment = EXCLUDED.total_investment,
            last_updated = CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update holdings after transaction insertion
CREATE TRIGGER trigger_update_holding
    AFTER INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_holding_on_transaction();

-- View for portfolio performance summary
CREATE OR REPLACE VIEW portfolio_performance AS
SELECT 
    p.id as portfolio_id,
    p.portfolio_name,
    p.client_name,
    p.total_value,
    COUNT(DISTINCT h.security_id) as number_of_holdings,
    COALESCE(SUM(h.unrealized_pnl), 0) as total_unrealized_pnl,
    COALESCE(SUM(h.total_investment), 0) as total_investment,
    p.created_at
FROM portfolios p
LEFT JOIN holdings h ON p.id = h.portfolio_id
GROUP BY p.id, p.portfolio_name, p.client_name, p.total_value, p.created_at;

-- View for sector allocation
CREATE OR REPLACE VIEW sector_allocation AS
SELECT 
    p.id as portfolio_id,
    s.sector,
    SUM(h.current_value) as sector_value,
    ROUND((SUM(h.current_value) / NULLIF(p.total_value, 0)) * 100, 2) as allocation_percentage
FROM portfolios p
JOIN holdings h ON p.id = h.portfolio_id
JOIN securities s ON h.security_id = s.id
GROUP BY p.id, s.sector, p.total_value;

-- Insert sample Indian securities data
INSERT INTO securities (isin_code, bse_code, nse_symbol, company_name, sector, industry, market_cap_category) VALUES
('INE009A01021', '500325', 'RELIANCE', 'Reliance Industries Limited', 'Energy', 'Oil & Gas Refining', 'Large Cap'),
('INE002A01018', '500112', 'TCS', 'Tata Consultancy Services Limited', 'Information Technology', 'Software', 'Large Cap'),
('INE101A01026', '532540', 'HDFCBANK', 'HDFC Bank Limited', 'Financial Services', 'Banking', 'Large Cap'),
('INE238A01034', '500510', 'LT', 'Larsen & Toubro Limited', 'Industrials', 'Construction', 'Large Cap'),
('INE154A01025', '500209', 'INFY', 'Infosys Limited', 'Information Technology', 'Software', 'Large Cap'),
('INE018A01026', '532555', 'ITC', 'ITC Limited', 'Consumer Goods', 'Tobacco', 'Large Cap'),
('INE079A01024', '500696', 'HINDUNILVR', 'Hindustan Unilever Limited', 'Consumer Goods', 'FMCG', 'Large Cap'),
('INE040A01034', '500520', 'WIPRO', 'Wipro Limited', 'Information Technology', 'Software', 'Large Cap'),
('INE319A01026', '532281', 'HINDALCO', 'Hindalco Industries Limited', 'Materials', 'Metals', 'Large Cap'),
('INE002A01018', '500180', 'HDFC', 'Housing Development Finance Corporation Limited', 'Financial Services', 'NBFC', 'Large Cap');

-- Insert sample portfolio data
INSERT INTO portfolios (portfolio_name, client_name, client_email, risk_profile) VALUES
('Growth Portfolio', 'Rajesh Kumar', 'rajesh.kumar@email.com', 'High'),
('Conservative Portfolio', 'Priya Sharma', 'priya.sharma@email.com', 'Low'),
('Balanced Portfolio', 'Amit Patel', 'amit.patel@email.com', 'Medium');

-- Insert sample market data
INSERT INTO market_data (security_id, price_date, open_price, high_price, low_price, close_price, volume, exchange) VALUES
(1, CURRENT_DATE, 2750.00, 2780.00, 2745.00, 2775.00, 5000000, 'NSE'),
(2, CURRENT_DATE, 3850.00, 3880.00, 3830.00, 3865.00, 3000000, 'NSE'),
(3, CURRENT_DATE, 1650.00, 1670.00, 1640.00, 1665.00, 4000000, 'NSE');

-- Insert sample advisory signals
INSERT INTO advisory_signals (security_id, signal_type, confidence_score, rationale, target_price, stop_loss, time_horizon, valid_until) VALUES
(1, 'BUY', 85.00, 'Strong quarterly results and expanding market share', 3000.00, 2600.00, 'Medium Term', CURRENT_DATE + INTERVAL '30 days'),
(2, 'HOLD', 70.00, 'Stable performance but facing margin pressures', 4000.00, 3700.00, 'Short Term', CURRENT_DATE + INTERVAL '15 days'),
(3, 'SELL', 60.00, 'Valuation concerns and regulatory headwinds', 1500.00, 1700.00, 'Short Term', CURRENT_DATE + INTERVAL '15 days');

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_transactions_portfolio_date ON transactions(portfolio_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_market_data_recent ON market_data(price_date DESC);
CREATE INDEX IF NOT EXISTS idx_advisory_signals_validity ON advisory_signals(valid_until, is_active);

-- Comments for documentation
COMMENT ON TABLE securities IS 'Stores metadata for Indian equity securities with BSE/NSE codes';
COMMENT ON TABLE portfolios IS 'Client portfolio information with risk profiling';
COMMENT ON TABLE transactions IS 'Records all buy/sell transactions with Indian market specifics';
COMMENT ON TABLE holdings IS 'Current portfolio positions with valuation data';
COMMENT ON TABLE market_data IS 'Historical and current market prices for Indian securities';
COMMENT ON TABLE advisory_signals IS 'Buy/Hold/Sell recommendations with rationale and targets';
COMMENT ON TABLE portfolio_signals IS 'Links advisory signals to specific client portfolios';
COMMENT ON TABLE dashboard_reports IS 'Stores configuration for visual reports and dashboards';

-- Grant necessary permissions (adjust based on your deployment setup)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO application_user;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO application_user;