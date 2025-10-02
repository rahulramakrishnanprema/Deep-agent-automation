-- IPM-55: Portfolio Management System Database Schema
-- MVP for managing client stock portfolios in Indian equity markets

-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS portfolio_holdings;
DROP TABLE IF EXISTS portfolios;
DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS advisory_signals;
DROP TABLE IF EXISTS users;

-- Users table for authentication and advisor-only access
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    user_type VARCHAR(20) CHECK (user_type IN ('advisor', 'client')) DEFAULT 'client',
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Stocks table for Indian equity market data
CREATE TABLE stocks (
    stock_id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    sector VARCHAR(100) NOT NULL,
    industry VARCHAR(100) NOT NULL,
    current_price DECIMAL(15,2) NOT NULL,
    previous_close DECIMAL(15,2) NOT NULL,
    market_cap DECIMAL(20,2),
    pe_ratio DECIMAL(10,2),
    dividend_yield DECIMAL(5,2),
    volume BIGINT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolios table for client portfolio management
CREATE TABLE portfolios (
    portfolio_id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL REFERENCES users(user_id),
    advisor_id INTEGER NOT NULL REFERENCES users(user_id),
    portfolio_name VARCHAR(100) NOT NULL,
    description TEXT,
    total_value DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_client FOREIGN KEY (client_id) REFERENCES users(user_id),
    CONSTRAINT fk_advisor FOREIGN KEY (advisor_id) REFERENCES users(user_id)
);

-- Portfolio holdings table for storing individual stock positions
CREATE TABLE portfolio_holdings (
    holding_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(portfolio_id),
    stock_id INTEGER NOT NULL REFERENCES stocks(stock_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    purchase_price DECIMAL(15,2) NOT NULL,
    purchase_date DATE NOT NULL,
    current_value DECIMAL(15,2) GENERATED ALWAYS AS (quantity * (SELECT current_price FROM stocks WHERE stock_id = portfolio_holdings.stock_id)) STORED,
    unrealized_gain_loss DECIMAL(15,2) GENERATED ALWAYS AS (quantity * ((SELECT current_price FROM stocks WHERE stock_id = portfolio_holdings.stock_id) - purchase_price)) STORED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Advisory signals table for Buy/Hold/Sell recommendations
CREATE TABLE advisory_signals (
    signal_id SERIAL PRIMARY KEY,
    stock_id INTEGER NOT NULL REFERENCES stocks(stock_id),
    signal_type VARCHAR(10) CHECK (signal_type IN ('BUY', 'HOLD', 'SELL')) NOT NULL,
    confidence_score DECIMAL(5,2) CHECK (confidence_score BETWEEN 0 AND 100),
    reasoning TEXT NOT NULL,
    target_price DECIMAL(15,2),
    stop_loss DECIMAL(15,2),
    generated_by INTEGER NOT NULL REFERENCES users(user_id),
    valid_until DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Indexes for performance optimization
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_stocks_symbol ON stocks(symbol);
CREATE INDEX idx_stocks_sector ON stocks(sector);
CREATE INDEX idx_portfolios_client ON portfolios(client_id);
CREATE INDEX idx_portfolios_advisor ON portfolios(advisor_id);
CREATE INDEX idx_holdings_portfolio ON portfolio_holdings(portfolio_id);
CREATE INDEX idx_holdings_stock ON portfolio_holdings(stock_id);
CREATE INDEX idx_signals_stock ON advisory_signals(stock_id);
CREATE INDEX idx_signals_type ON advisory_signals(signal_type);
CREATE INDEX idx_signals_validity ON advisory_signals(valid_until);

-- Insert dummy data for testing
-- Users (advisors and clients)
INSERT INTO users (username, email, password_hash, user_type, first_name, last_name) VALUES
('advisor1', 'advisor1@example.com', 'hashed_password_1', 'advisor', 'Rajesh', 'Sharma'),
('advisor2', 'advisor2@example.com', 'hashed_password_2', 'advisor', 'Priya', 'Patel'),
('client1', 'client1@example.com', 'hashed_password_3', 'client', 'Amit', 'Kumar'),
('client2', 'client2@example.com', 'hashed_password_4', 'client', 'Sneha', 'Singh');

-- Indian stocks data
INSERT INTO stocks (symbol, company_name, sector, industry, current_price, previous_close, market_cap, pe_ratio, dividend_yield, volume) VALUES
('RELIANCE', 'Reliance Industries Ltd', 'Energy', 'Oil & Gas', 2650.75, 2630.50, 1500000000000, 25.30, 0.45, 5000000),
('TCS', 'Tata Consultancy Services Ltd', 'IT', 'Software', 3450.25, 3420.75, 1200000000000, 30.15, 1.20, 3000000),
('HDFCBANK', 'HDFC Bank Ltd', 'Financial', 'Banking', 1650.50, 1635.25, 800000000000, 20.75, 1.50, 4000000),
('INFY', 'Infosys Ltd', 'IT', 'Software', 1850.00, 1835.50, 700000000000, 28.40, 2.10, 2500000),
('ICICIBANK', 'ICICI Bank Ltd', 'Financial', 'Banking', 950.75, 945.25, 500000000000, 18.90, 0.80, 3500000),
('SBIN', 'State Bank of India', 'Financial', 'Banking', 650.25, 645.75, 450000000000, 15.60, 1.10, 6000000);

-- Portfolios
INSERT INTO portfolios (client_id, advisor_id, portfolio_name, description, total_value) VALUES
(3, 1, 'Amit Kumar - Growth Portfolio', 'Long-term growth focused portfolio', 500000),
(4, 2, 'Sneha Singh - Balanced Portfolio', 'Balanced risk-return profile', 750000);

-- Portfolio holdings
INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, purchase_price, purchase_date) VALUES
(1, 1, 100, 2500.00, '2023-01-15'),
(1, 2, 50, 3200.00, '2023-02-20'),
(1, 3, 75, 1600.00, '2023-03-10'),
(2, 4, 100, 1800.00, '2023-01-20'),
(2, 5, 200, 900.00, '2023-02-25'),
(2, 6, 300, 600.00, '2023-03-15');

-- Advisory signals
INSERT INTO advisory_signals (stock_id, signal_type, confidence_score, reasoning, target_price, stop_loss, generated_by, valid_until) VALUES
(1, 'BUY', 85.5, 'Strong quarterly results, expanding retail business', 2800.00, 2500.00, 1, '2023-12-31'),
(2, 'HOLD', 75.0, 'Stable performance but facing margin pressure', 3500.00, 3300.00, 1, '2023-12-31'),
(3, 'BUY', 90.0, 'Strong loan growth, improving asset quality', 1800.00, 1550.00, 2, '2023-12-31'),
(4, 'SELL', 65.5, 'Valuation concerns, slowing growth in key markets', 1700.00, 1900.00, 2, '2023-12-31'),
(5, 'BUY', 80.0, 'Digital transformation driving efficiency, market share gains', 1100.00, 850.00, 1, '2023-12-31'),
(6, 'HOLD', 70.0, 'Government support but NPA concerns persist', 700.00, 600.00, 2, '2023-12-31');

-- Views for common queries
CREATE VIEW portfolio_summary AS
SELECT 
    p.portfolio_id,
    p.portfolio_name,
    u.first_name || ' ' || u.last_name AS client_name,
    a.first_name || ' ' || a.last_name AS advisor_name,
    p.total_value,
    COUNT(ph.holding_id) AS number_of_holdings,
    p.created_at
FROM portfolios p
JOIN users u ON p.client_id = u.user_id
JOIN users a ON p.advisor_id = a.user_id
LEFT JOIN portfolio_holdings ph ON p.portfolio_id = ph.portfolio_id
GROUP BY p.portfolio_id, u.first_name, u.last_name, a.first_name, a.last_name;

CREATE VIEW holding_details AS
SELECT 
    ph.holding_id,
    p.portfolio_name,
    s.symbol,
    s.company_name,
    ph.quantity,
    ph.purchase_price,
    s.current_price,
    ph.current_value,
    ph.unrealized_gain_loss,
    (ph.unrealized_gain_loss / (ph.quantity * ph.purchase_price)) * 100 AS gain_loss_percentage
FROM portfolio_holdings ph
JOIN portfolios p ON ph.portfolio_id = p.portfolio_id
JOIN stocks s ON ph.stock_id = s.stock_id;

CREATE VIEW active_advisory_signals AS
SELECT 
    asig.signal_id,
    s.symbol,
    s.company_name,
    asig.signal_type,
    asig.confidence_score,
    asig.reasoning,
    asig.target_price,
    asig.stop_loss,
    s.current_price,
    u.first_name || ' ' || u.last_name AS generated_by,
    asig.valid_until
FROM advisory_signals asig
JOIN stocks s ON asig.stock_id = s.stock_id
JOIN users u ON asig.generated_by = u.user_id
WHERE asig.is_active = TRUE AND asig.valid_until >= CURRENT_DATE;

-- Stored procedures for common operations
CREATE OR REPLACE PROCEDURE update_portfolio_value(portfolio_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE portfolios 
    SET total_value = (
        SELECT COALESCE(SUM(ph.current_value), 0)
        FROM portfolio_holdings ph
        WHERE ph.portfolio_id = portfolio_id
    ),
    last_updated = CURRENT_TIMESTAMP
    WHERE portfolio_id = portfolio_id;
END;
$$;

CREATE OR REPLACE PROCEDURE add_holding(
    p_portfolio_id INTEGER,
    p_stock_id INTEGER,
    p_quantity INTEGER,
    p_purchase_price DECIMAL,
    p_purchase_date DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO portfolio_holdings (portfolio_id, stock_id, quantity, purchase_price, purchase_date)
    VALUES (p_portfolio_id, p_stock_id, p_quantity, p_purchase_price, p_purchase_date);
    
    CALL update_portfolio_value(p_portfolio_id);
END;
$$;

-- Function to get portfolio performance
CREATE OR REPLACE FUNCTION get_portfolio_performance(p_portfolio_id INTEGER)
RETURNS TABLE (
    total_investment DECIMAL,
    current_value DECIMAL,
    total_gain_loss DECIMAL,
    gain_loss_percentage DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        SUM(ph.quantity * ph.purchase_price) AS total_investment,
        SUM(ph.current_value) AS current_value,
        SUM(ph.unrealized_gain_loss) AS total_gain_loss,
        (SUM(ph.unrealized_gain_loss) / NULLIF(SUM(ph.quantity * ph.purchase_price), 0)) * 100 AS gain_loss_percentage
    FROM portfolio_holdings ph
    WHERE ph.portfolio_id = p_portfolio_id;
END;
$$;

-- Triggers for automatic updates
CREATE OR REPLACE FUNCTION update_portfolio_on_holding_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        CALL update_portfolio_value(NEW.portfolio_id);
    ELSIF TG_OP = 'DELETE' THEN
        CALL update_portfolio_value(OLD.portfolio_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_portfolio_value
AFTER INSERT OR UPDATE OR DELETE ON portfolio_holdings
FOR EACH ROW
EXECUTE FUNCTION update_portfolio_on_holding_change();

-- Comments for documentation
COMMENT ON TABLE users IS 'Stores user information for authentication and authorization';
COMMENT ON TABLE stocks IS 'Contains Indian equity market stock data';
COMMENT ON TABLE portfolios IS 'Manages client investment portfolios';
COMMENT ON TABLE portfolio_holdings IS 'Tracks individual stock holdings within portfolios';
COMMENT ON TABLE advisory_signals IS 'Stores Buy/Hold/Sell recommendations for stocks';

COMMENT ON COLUMN users.user_type IS 'User role: advisor or client';
COMMENT ON COLUMN advisory_signals.confidence_score IS 'Confidence level of the signal (0-100)';
COMMENT ON COLUMN portfolio_holdings.current_value IS 'Automatically calculated current value of holding';
COMMENT ON COLUMN portfolio_holdings.unrealized_gain_loss IS 'Automatically calculated unrealized P&L';