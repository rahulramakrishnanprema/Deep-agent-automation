-- SQL Schema for Indian Portfolio Management MVP
-- This file creates the database structure for storing portfolio data,
-- advisory signals, and user roles for advisor-only reports

-- Enable foreign key support
PRAGMA foreign_keys = ON;

-- Clients table to store client information
CREATE TABLE IF NOT EXISTS clients (
    client_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    risk_profile TEXT CHECK(risk_profile IN ('Low', 'Medium', 'High')) DEFAULT 'Medium',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Stocks table to store Indian equity market stock information
CREATE TABLE IF NOT EXISTS stocks (
    stock_id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    sector TEXT NOT NULL,
    exchange TEXT DEFAULT 'NSE',
    current_price DECIMAL(10,2) DEFAULT 0.00,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio holdings table to store client stock holdings
CREATE TABLE IF NOT EXISTS portfolio_holdings (
    holding_id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER NOT NULL,
    stock_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    purchase_price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE(client_id, stock_id, purchase_date)
);

-- Transactions table to track buy/sell activities
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER NOT NULL,
    stock_id INTEGER NOT NULL,
    type TEXT CHECK(type IN ('BUY', 'SELL')) NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    price DECIMAL(10,2) NOT NULL,
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    fees DECIMAL(10,2) DEFAULT 0.00,
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

-- Historical performance data for stocks
CREATE TABLE IF NOT EXISTS historical_performance (
    performance_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER NOT NULL,
    date DATE NOT NULL,
    open_price DECIMAL(10,2),
    high_price DECIMAL(10,2),
    low_price DECIMAL(10,2),
    close_price DECIMAL(10,2),
    volume INTEGER,
    moving_avg_50 DECIMAL(10,2),
    moving_avg_200 DECIMAL(10,2),
    rsi DECIMAL(5,2),
    macd DECIMAL(8,4),
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE,
    UNIQUE(stock_id, date)
);

-- Sector performance data
CREATE TABLE IF NOT EXISTS sector_performance (
    sector_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sector_name TEXT UNIQUE NOT NULL,
    growth_potential DECIMAL(5,2) DEFAULT 0.00,
    market_sentiment TEXT CHECK(market_sentiment IN ('Bullish', 'Neutral', 'Bearish')) DEFAULT 'Neutral',
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Market buzz and news data
CREATE TABLE IF NOT EXISTS market_buzz (
    buzz_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER,
    sector_id INTEGER,
    news_text TEXT NOT NULL,
    sentiment_score DECIMAL(3,2) CHECK(sentiment_score BETWEEN -1.0 AND 1.0),
    source TEXT,
    published_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE SET NULL,
    FOREIGN KEY (sector_id) REFERENCES sector_performance(sector_id) ON DELETE SET NULL
);

-- Advisory signals table
CREATE TABLE IF NOT EXISTS advisory_signals (
    signal_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER NOT NULL,
    signal_type TEXT CHECK(signal_type IN ('BUY', 'HOLD', 'SELL')) NOT NULL,
    confidence_score DECIMAL(3,2) CHECK(confidence_score BETWEEN 0.0 AND 1.0),
    reasoning TEXT,
    generated_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    valid_until DATETIME,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

-- Users table for role-based access (advisors vs regular users)
CREATE TABLE IF NOT EXISTS users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    role TEXT CHECK(role IN ('advisor', 'client')) DEFAULT 'client',
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Advisor reports access log
CREATE TABLE IF NOT EXISTS report_access_log (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    report_type TEXT NOT NULL,
    access_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Portfolio performance snapshots
CREATE TABLE IF NOT EXISTS portfolio_snapshots (
    snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER NOT NULL,
    total_value DECIMAL(12,2) NOT NULL,
    daily_change DECIMAL(10,2),
    daily_change_percent DECIMAL(5,2),
    snapshot_date DATE NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    UNIQUE(client_id, snapshot_date)
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_portfolio_client ON portfolio_holdings(client_id);
CREATE INDEX IF NOT EXISTS idx_transactions_client ON transactions(client_id);
CREATE INDEX IF NOT EXISTS idx_historical_stock_date ON historical_performance(stock_id, date);
CREATE INDEX IF NOT EXISTS idx_advisory_stock ON advisory_signals(stock_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_market_buzz_date ON market_buzz(published_date);
CREATE INDEX IF NOT EXISTS idx_portfolio_snapshot ON portfolio_snapshots(client_id, snapshot_date);

-- Insert dummy data for demonstration
INSERT OR IGNORE INTO clients (name, email, phone, risk_profile) VALUES 
('Rajesh Kumar', 'rajesh.kumar@email.com', '+91-9876543210', 'Medium'),
('Priya Sharma', 'priya.sharma@email.com', '+91-8765432109', 'High'),
('Amit Patel', 'amit.patel@email.com', '+91-7654321098', 'Low');

INSERT OR IGNORE INTO stocks (symbol, name, sector, exchange, current_price) VALUES 
('RELIANCE', 'Reliance Industries Ltd', 'Energy', 'NSE', 2456.75),
('INFY', 'Infosys Ltd', 'IT', 'NSE', 1520.30),
('HDFCBANK', 'HDFC Bank Ltd', 'Banking', 'NSE', 1425.80),
('TCS', 'Tata Consultancy Services Ltd', 'IT', 'NSE', 3250.45),
('ICICIBANK', 'ICICI Bank Ltd', 'Banking', 'NSE', 890.15);

INSERT OR IGNORE INTO sector_performance (sector_name, growth_potential, market_sentiment) VALUES 
('IT', 12.50, 'Bullish'),
('Banking', 8.75, 'Neutral'),
('Energy', 15.20, 'Bullish'),
('Pharma', 6.30, 'Bearish'),
('Auto', 4.80, 'Neutral');

INSERT OR IGNORE INTO portfolio_holdings (client_id, stock_id, quantity, purchase_price, purchase_date) VALUES 
(1, 1, 10, 2400.00, '2023-01-15'),
(1, 2, 15, 1500.00, '2023-02-20'),
(2, 3, 8, 1400.00, '2023-03-10'),
(2, 4, 5, 3200.00, '2023-04-05'),
(3, 5, 20, 850.00, '2023-05-12');

INSERT OR IGNORE INTO transactions (client_id, stock_id, type, quantity, price, transaction_date) VALUES 
(1, 1, 'BUY', 10, 2400.00, '2023-01-15 10:30:00'),
(1, 2, 'BUY', 15, 1500.00, '2023-02-20 11:15:00'),
(2, 3, 'BUY', 8, 1400.00, '2023-03-10 09:45:00'),
(2, 4, 'BUY', 5, 3200.00, '2023-04-05 14:20:00'),
(3, 5, 'BUY', 20, 850.00, '2023-05-12 13:10:00');

INSERT OR IGNORE INTO advisory_signals (stock_id, signal_type, confidence_score, reasoning, generated_date, valid_until) VALUES 
(1, 'BUY', 0.85, 'Strong sector performance and positive technical indicators', datetime('now'), datetime('now', '+7 days')),
(2, 'HOLD', 0.70, 'Stable performance with moderate growth potential', datetime('now'), datetime('now', '+7 days')),
(3, 'SELL', 0.60, 'Sector headwinds and declining technical indicators', datetime('now'), datetime('now', '+7 days'));

INSERT OR IGNORE INTO users (username, password_hash, email, role) VALUES 
('advisor1', 'hashed_password_1', 'advisor1@firm.com', 'advisor'),
('advisor2', 'hashed_password_2', 'advisor2@firm.com', 'advisor'),
('client_user', 'hashed_password_3', 'client@email.com', 'client');

-- Views for common queries
CREATE VIEW IF NOT EXISTS client_portfolio_summary AS
SELECT 
    c.client_id,
    c.name as client_name,
    SUM(p.quantity * s.current_price) as current_value,
    SUM(p.quantity * p.purchase_price) as invested_amount,
    (SUM(p.quantity * s.current_price) - SUM(p.quantity * p.purchase_price)) as unrealized_pnl
FROM clients c
JOIN portfolio_holdings p ON c.client_id = p.client_id
JOIN stocks s ON p.stock_id = s.stock_id
GROUP BY c.client_id, c.name;

CREATE VIEW IF NOT EXISTS stock_advisory_signals AS
SELECT 
    s.symbol,
    s.name,
    s.sector,
    a.signal_type,
    a.confidence_score,
    a.reasoning,
    a.generated_date,
    a.valid_until
FROM stocks s
JOIN advisory_signals a ON s.stock_id = a.stock_id
WHERE a.valid_until > datetime('now');

-- Triggers for maintaining data integrity
CREATE TRIGGER IF NOT EXISTS update_stock_timestamp
AFTER UPDATE ON stocks
FOR EACH ROW
BEGIN
    UPDATE stocks SET last_updated = CURRENT_TIMESTAMP WHERE stock_id = NEW.stock_id;
END;

CREATE TRIGGER IF NOT EXISTS update_client_timestamp
AFTER UPDATE ON clients
FOR EACH ROW
BEGIN
    UPDATE clients SET updated_at = CURRENT_TIMESTAMP WHERE client_id = NEW.client_id;
END;