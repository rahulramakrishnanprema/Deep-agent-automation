-- SQL Schema for Indian Portfolio Management MVP
-- This file creates the database structure for the stock portfolio management system

-- Portfolio table to store client portfolio data
CREATE TABLE IF NOT EXISTS portfolios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_name TEXT NOT NULL,
    stock_symbol TEXT NOT NULL,
    stock_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    purchase_price DECIMAL(10, 2) NOT NULL CHECK (purchase_price >= 0),
    purchase_date DATE NOT NULL,
    sector TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stocks table to store stock information and current market data
CREATE TABLE IF NOT EXISTS stocks (
    symbol TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    current_price DECIMAL(10, 2) NOT NULL CHECK (current_price >= 0),
    sector TEXT NOT NULL,
    market_cap DECIMAL(15, 2),
    pe_ratio DECIMAL(10, 2),
    dividend_yield DECIMAL(5, 2),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Advisory signals table for Buy/Hold/Sell recommendations
CREATE TABLE IF NOT EXISTS advisory_signals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_symbol TEXT NOT NULL,
    signal_type TEXT NOT NULL CHECK (signal_type IN ('BUY', 'HOLD', 'SELL')),
    confidence_score DECIMAL(5, 2) CHECK (confidence_score >= 0 AND confidence_score <= 100),
    reasoning TEXT,
    technical_indicator TEXT,
    sector_potential TEXT,
    market_buzz TEXT,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_symbol) REFERENCES stocks(symbol)
);

-- Users table for authentication and role management
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('ADVISOR', 'CLIENT')),
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Reports table for advisor-only visual reports and analytics
CREATE TABLE IF NOT EXISTS advisor_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_name TEXT NOT NULL,
    report_type TEXT NOT NULL CHECK (report_type IN ('PORTFOLIO_ANALYSIS', 'SECTOR_PERFORMANCE', 'SIGNAL_HISTORY')),
    generated_by INTEGER NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    report_data JSON,
    FOREIGN KEY (generated_by) REFERENCES users(id)
);

-- Portfolio performance history table
CREATE TABLE IF NOT EXISTS portfolio_performance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id INTEGER NOT NULL,
    total_value DECIMAL(12, 2) NOT NULL,
    daily_return DECIMAL(8, 4),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (portfolio_id) REFERENCES portfolios(id)
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_portfolios_client ON portfolios(client_name);
CREATE INDEX IF NOT EXISTS idx_portfolios_stock ON portfolios(stock_symbol);
CREATE INDEX IF NOT EXISTS idx_advisory_signals_symbol ON advisory_signals(stock_symbol);
CREATE INDEX IF NOT EXISTS idx_advisory_signals_type ON advisory_signals(signal_type);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_reports_type ON advisor_reports(report_type);

-- Insert dummy data for stocks
INSERT OR IGNORE INTO stocks (symbol, name, current_price, sector, market_cap, pe_ratio, dividend_yield) VALUES
('RELIANCE', 'Reliance Industries Ltd.', 2850.50, 'Energy', 1900000.00, 28.5, 0.45),
('TCS', 'Tata Consultancy Services Ltd.', 3850.75, 'IT', 1450000.00, 32.1, 1.20),
('HDFCBANK', 'HDFC Bank Ltd.', 1650.25, 'Banking', 900000.00, 22.8, 0.85),
('INFY', 'Infosys Ltd.', 1850.00, 'IT', 750000.00, 27.3, 1.05),
('ICICIBANK', 'ICICI Bank Ltd.', 1050.80, 'Banking', 650000.00, 19.2, 0.65),
('SBIN', 'State Bank of India', 650.40, 'Banking', 550000.00, 15.8, 0.95),
('HINDUNILVR', 'Hindustan Unilever Ltd.', 2650.90, 'FMCG', 600000.00, 65.2, 1.35),
('ITC', 'ITC Ltd.', 450.60, 'FMCG', 450000.00, 25.4, 2.10),
('BAJFINANCE', 'Bajaj Finance Ltd.', 7850.30, 'Financial Services', 470000.00, 38.7, 0.40),
('BHARTIARTL', 'Bharti Airtel Ltd.', 920.45, 'Telecom', 520000.00, 31.5, 0.55);

-- Insert dummy advisory signals
INSERT OR IGNORE INTO advisory_signals (stock_symbol, signal_type, confidence_score, reasoning, technical_indicator, sector_potential, market_buzz) VALUES
('RELIANCE', 'BUY', 85.5, 'Strong quarterly results and expansion plans', 'RSI: 45, MACD: Bullish', 'Energy sector showing growth potential', 'Positive analyst coverage'),
('TCS', 'HOLD', 72.3, 'Stable performance but limited upside', 'RSI: 55, MACD: Neutral', 'IT sector facing headwinds', 'Mixed market sentiment'),
('HDFCBANK', 'BUY', 91.2, 'Strong fundamentals and growth trajectory', 'RSI: 40, MACD: Bullish', 'Banking sector recovery', 'Institutional buying interest'),
('INFY', 'SELL', 68.7, 'Valuation concerns and margin pressure', 'RSI: 65, MACD: Bearish', 'IT sector consolidation', 'Negative earnings revision'),
('ICICIBANK', 'BUY', 88.9, 'Improving asset quality and growth', 'RSI: 42, MACD: Bullish', 'Banking sector strength', 'Positive management guidance');

-- Insert dummy portfolio data
INSERT OR IGNORE INTO portfolios (client_name, stock_symbol, stock_name, quantity, purchase_price, purchase_date, sector) VALUES
('Rahul Sharma', 'RELIANCE', 'Reliance Industries Ltd.', 50, 2700.00, '2023-01-15', 'Energy'),
('Rahul Sharma', 'TCS', 'Tata Consultancy Services Ltd.', 25, 3600.00, '2023-02-20', 'IT'),
('Priya Patel', 'HDFCBANK', 'HDFC Bank Ltd.', 100, 1500.00, '2023-03-10', 'Banking'),
('Priya Patel', 'INFY', 'Infosys Ltd.', 60, 1700.00, '2023-04-05', 'IT'),
('Amit Kumar', 'ICICIBANK', 'ICICI Bank Ltd.', 150, 950.00, '2023-05-12', 'Banking'),
('Amit Kumar', 'ITC', 'ITC Ltd.', 200, 400.00, '2023-06-18', 'FMCG');

-- Insert dummy users
INSERT OR IGNORE INTO users (username, password_hash, role, email) VALUES
('advisor1', 'hashed_password_1', 'ADVISOR', 'advisor1@example.com'),
('advisor2', 'hashed_password_2', 'ADVISOR', 'advisor2@example.com'),
('client_rahul', 'hashed_password_3', 'CLIENT', 'rahul@example.com'),
('client_priya', 'hashed_password_4', 'CLIENT', 'priya@example.com');

-- Insert dummy portfolio performance data
INSERT OR IGNORE INTO portfolio_performance (portfolio_id, total_value, daily_return) VALUES
(1, 142525.00, 1.25),
(2, 96268.75, 0.85),
(3, 165025.00, 1.10),
(4, 111000.00, -0.45),
(5, 157620.00, 2.15),
(6, 90120.00, 0.60);

-- Create triggers for automatic updated_at timestamps
CREATE TRIGGER IF NOT EXISTS update_portfolios_timestamp
AFTER UPDATE ON portfolios
FOR EACH ROW
BEGIN
    UPDATE portfolios SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS update_stocks_timestamp
AFTER UPDATE ON stocks
FOR EACH ROW
BEGIN
    UPDATE stocks SET last_updated = CURRENT_TIMESTAMP WHERE symbol = OLD.symbol;
END;

-- Views for common queries
CREATE VIEW IF NOT EXISTS portfolio_summary AS
SELECT 
    p.client_name,
    p.stock_symbol,
    p.quantity,
    p.purchase_price,
    s.current_price,
    (s.current_price * p.quantity) AS current_value,
    ((s.current_price - p.purchase_price) * p.quantity) AS unrealized_pnl,
    ((s.current_price - p.purchase_price) / p.purchase_price * 100) AS pnl_percentage
FROM portfolios p
JOIN stocks s ON p.stock_symbol = s.symbol;

CREATE VIEW IF NOT EXISTS client_portfolio_totals AS
SELECT 
    client_name,
    SUM(quantity * purchase_price) AS total_investment,
    SUM(quantity * s.current_price) AS current_value,
    SUM((s.current_price - purchase_price) * quantity) AS total_pnl
FROM portfolios p
JOIN stocks s ON p.stock_symbol = s.symbol
GROUP BY client_name;

-- Print confirmation message
SELECT 'Database schema created successfully with dummy data' AS status;