-- AEP-123: SQL Schema and Initial Data Setup for AEP Project

-- Create database and user
CREATE DATABASE aep_database;
CREATE USER aep_user WITH ENCRYPTED PASSWORD 'aep_password_123';
GRANT ALL PRIVILEGES ON DATABASE aep_database TO aep_user;

-- Connect to the database
\c aep_database;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table for authentication
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_superuser BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- User profiles table
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    phone_number VARCHAR(20),
    date_of_birth DATE,
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Refresh tokens table for JWT authentication
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_revoked BOOLEAN DEFAULT FALSE
);

-- API logs table for structured logging
CREATE TABLE api_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INTEGER,
    client_ip VARCHAR(45),
    user_id UUID REFERENCES users(id),
    request_body TEXT,
    response_body TEXT,
    processing_time_ms INTEGER,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Application data tables
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    is_available BOOLEAN DEFAULT TRUE,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
    shipping_address TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    total_price DECIMAL(10,2) NOT NULL CHECK (total_price >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token ON refresh_tokens(token);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
CREATE INDEX idx_api_logs_created_at ON api_logs(created_at);
CREATE INDEX idx_api_logs_endpoint ON api_logs(endpoint);
CREATE INDEX idx_items_created_by ON items(created_by);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_item_id ON order_items(item_id);

-- Insert initial admin user (password: admin123)
INSERT INTO users (username, email, hashed_password, is_superuser) VALUES 
('admin', 'admin@aep.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', TRUE);

-- Insert sample items
INSERT INTO items (name, description, price, quantity, created_by) VALUES
('Sample Item 1', 'Description for sample item 1', 19.99, 100, (SELECT id FROM users WHERE username = 'admin')),
('Sample Item 2', 'Description for sample item 2', 29.99, 50, (SELECT id FROM users WHERE username = 'admin')),
('Sample Item 3', 'Description for sample item 3', 39.99, 25, (SELECT id FROM users WHERE username = 'admin'));

-- Grant permissions to application user
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO aep_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO aep_user;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_items_updated_at BEFORE UPDATE ON items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to validate email format
CREATE OR REPLACE FUNCTION validate_email(email VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN email ~ '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$';
END;
$$ LANGUAGE plpgsql;

-- Add constraint for email validation
ALTER TABLE users ADD CONSTRAINT valid_email CHECK (validate_email(email));

-- Create function to get user orders with items
CREATE OR REPLACE FUNCTION get_user_orders(user_uuid UUID)
RETURNS TABLE (
    order_id UUID,
    total_amount DECIMAL(10,2),
    status VARCHAR(20),
    shipping_address TEXT,
    created_date TIMESTAMP WITH TIME ZONE,
    item_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.total_amount,
        o.status,
        o.shipping_address,
        o.created_at,
        COUNT(oi.id)::INTEGER
    FROM orders o
    LEFT JOIN order_items oi ON o.id = oi.order_id
    WHERE o.user_id = user_uuid
    GROUP BY o.id, o.total_amount, o.status, o.shipping_address, o.created_at
    ORDER BY o.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Create view for active users with profiles
CREATE VIEW active_users_with_profiles AS
SELECT 
    u.id,
    u.username,
    u.email,
    u.is_active,
    u.created_at,
    up.first_name,
    up.last_name,
    up.phone_number
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE u.is_active = TRUE;

-- Create materialized view for dashboard statistics (refresh periodically)
CREATE MATERIALIZED VIEW dashboard_stats AS
SELECT 
    COUNT(DISTINCT u.id) AS total_users,
    COUNT(DISTINCT o.id) AS total_orders,
    COUNT(DISTINCT i.id) AS total_items,
    COALESCE(SUM(o.total_amount), 0) AS total_revenue,
    MAX(o.created_at) AS last_order_date
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
CROSS JOIN items i;

-- Create index on materialized view for performance
CREATE UNIQUE INDEX idx_dashboard_stats ON dashboard_stats(total_users, total_orders, total_items);