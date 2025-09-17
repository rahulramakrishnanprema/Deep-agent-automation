-- AEP-123: SQL Schema and Initial Data Setup for AEP Project

-- Enable UUID extension for generating unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table for authentication and user management
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Refresh tokens table for JWT token management
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(512) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    revoked BOOLEAN DEFAULT FALSE
);

-- Core data table for AEP functionality
CREATE TABLE aep_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
    priority INTEGER DEFAULT 1 CHECK (priority BETWEEN 1 AND 5),
    due_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Audit log table for tracking changes
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL CHECK (action IN ('CREATE', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT
);

-- Indexes for performance optimization
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
CREATE INDEX idx_refresh_tokens_token ON refresh_tokens(token);
CREATE INDEX idx_aep_data_user_id ON aep_data(user_id);
CREATE INDEX idx_aep_data_status ON aep_data(status);
CREATE INDEX idx_aep_data_priority ON aep_data(priority);
CREATE INDEX idx_aep_data_due_date ON aep_data(due_date);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for automatic updated_at maintenance
CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_aep_data_updated_at
    BEFORE UPDATE ON aep_data
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function for audit logging
CREATE OR REPLACE FUNCTION log_audit_event()
RETURNS TRIGGER AS $$
DECLARE
    v_old_values JSONB;
    v_new_values JSONB;
    v_action VARCHAR(50);
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_action := 'CREATE';
        v_old_values := NULL;
        v_new_values := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'UPDATE';
        v_old_values := to_jsonb(OLD);
        v_new_values := to_jsonb(NEW);
    ELSIF TG_OP = 'DELETE' THEN
        v_action := 'DELETE';
        v_old_values := to_jsonb(OLD);
        v_new_values := NULL;
    END IF;

    INSERT INTO audit_logs (
        user_id,
        table_name,
        record_id,
        action,
        old_values,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        CASE 
            WHEN current_setting('app.current_user_id', TRUE) != '' THEN current_setting('app.current_user_id', TRUE)::UUID
            ELSE NULL
        END,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        v_action,
        v_old_values,
        v_new_values,
        current_setting('app.client_ip', TRUE),
        current_setting('app.user_agent', TRUE)
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Audit triggers for critical tables
CREATE TRIGGER trigger_audit_users
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW
    EXECUTE FUNCTION log_audit_event();

CREATE TRIGGER trigger_audit_aep_data
    AFTER INSERT OR UPDATE OR DELETE ON aep_data
    FOR EACH ROW
    EXECUTE FUNCTION log_audit_event();

-- Function to get user statistics
CREATE OR REPLACE FUNCTION get_user_stats(user_uuid UUID)
RETURNS TABLE(
    total_items BIGINT,
    pending_items BIGINT,
    completed_items BIGINT,
    avg_priority NUMERIC,
    overdue_items BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_items,
        COUNT(*) FILTER (WHERE status = 'pending')::BIGINT as pending_items,
        COUNT(*) FILTER (WHERE status = 'completed')::BIGINT as completed_items,
        COALESCE(AVG(priority)::NUMERIC(10,2), 0) as avg_priority,
        COUNT(*) FILTER (WHERE due_date < CURRENT_TIMESTAMP AND status NOT IN ('completed', 'cancelled'))::BIGINT as overdue_items
    FROM aep_data 
    WHERE user_id = user_uuid;
END;
$$ LANGUAGE plpgsql;

-- Insert initial admin user (password: admin123 - should be changed in production)
INSERT INTO users (email, password_hash, first_name, last_name, is_verified, is_active)
VALUES (
    'admin@aep.com',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', -- bcrypt hash for 'admin123'
    'Admin',
    'User',
    TRUE,
    TRUE
)
ON CONFLICT (email) DO NOTHING;

-- Insert sample data for testing
INSERT INTO aep_data (user_id, title, description, status, priority, due_date)
SELECT 
    id,
    'Sample Task ' || generate_series(1, 5),
    'This is a sample task description for testing purposes.',
    CASE 
        WHEN generate_series(1, 5) <= 2 THEN 'pending'
        WHEN generate_series(1, 5) <= 4 THEN 'in_progress'
        ELSE 'completed'
    END,
    (random() * 4 + 1)::integer,
    CURRENT_TIMESTAMP + (random() * interval '30 days')
FROM users 
WHERE email = 'admin@aep.com'
ON CONFLICT DO NOTHING;

-- Create read-only and read-write roles for security
CREATE ROLE aep_readonly;
CREATE ROLE aep_readwrite;

-- Grant permissions
GRANT CONNECT ON DATABASE CURRENT_DATABASE TO aep_readonly, aep_readwrite;

GRANT USAGE ON SCHEMA public TO aep_readonly, aep_readwrite;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO aep_readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO aep_readwrite;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO aep_readwrite;

-- Ensure proper permissions for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO aep_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO aep_readwrite;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE ON SEQUENCES TO aep_readwrite;