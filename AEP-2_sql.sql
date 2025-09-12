-- AEP-2: Authentication System SQL Schema
-- Creates tables for user authentication, registration, and JWT token management

-- Users table for authentication and registration
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    failed_login_attempts INTEGER DEFAULT 0,
    last_login_attempt TIMESTAMP,
    account_locked_until TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- JWT tokens table for session management
CREATE TABLE jwt_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) NOT NULL,
    refresh_token VARCHAR(500) NOT NULL,
    device_info TEXT,
    ip_address VARCHAR(45),
    expires_at TIMESTAMP NOT NULL,
    refresh_token_expires_at TIMESTAMP NOT NULL,
    is_revoked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(token, refresh_token)
);

-- Login attempts audit table
CREATE TABLE login_attempts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    username VARCHAR(50),
    ip_address VARCHAR(45),
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    attempt_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    failure_reason TEXT
);

-- Email verification tokens table
CREATE TABLE email_verification_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(100) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(token)
);

-- Password reset tokens table
CREATE TABLE password_reset_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(100) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(token)
);

-- Indexes for performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_jwt_tokens_user_id ON jwt_tokens(user_id);
CREATE INDEX idx_jwt_tokens_token ON jwt_tokens(token);
CREATE INDEX idx_jwt_tokens_refresh_token ON jwt_tokens(refresh_token);
CREATE INDEX idx_login_attempts_user_id ON login_attempts(user_id);
CREATE INDEX idx_login_attempts_time ON login_attempts(attempt_time);
CREATE INDEX idx_email_verification_user_id ON email_verification_tokens(user_id);
CREATE INDEX idx_password_reset_user_id ON password_reset_tokens(user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for users table
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to record login attempts
CREATE OR REPLACE FUNCTION record_login_attempt(
    p_user_id INTEGER,
    p_username VARCHAR,
    p_ip_address VARCHAR,
    p_user_agent TEXT,
    p_success BOOLEAN,
    p_failure_reason TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO login_attempts (user_id, username, ip_address, user_agent, success, failure_reason)
    VALUES (p_user_id, p_username, p_ip_address, p_user_agent, p_success, p_failure_reason);
END;
$$ LANGUAGE plpgsql;

-- Function to increment failed login attempts and lock account if necessary
CREATE OR REPLACE FUNCTION handle_failed_login(
    p_user_id INTEGER,
    p_max_attempts INTEGER DEFAULT 5,
    p_lockout_minutes INTEGER DEFAULT 30
) RETURNS VOID AS $$
BEGIN
    UPDATE users 
    SET 
        failed_login_attempts = failed_login_attempts + 1,
        last_login_attempt = CURRENT_TIMESTAMP,
        account_locked_until = CASE 
            WHEN failed_login_attempts + 1 >= p_max_attempts THEN 
                CURRENT_TIMESTAMP + (p_lockout_minutes * INTERVAL '1 minute')
            ELSE account_locked_until
        END
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to reset failed login attempts on successful login
CREATE OR REPLACE FUNCTION reset_failed_logins(p_user_id INTEGER) RETURNS VOID AS $$
BEGIN
    UPDATE users 
    SET 
        failed_login_attempts = 0,
        last_login_attempt = CURRENT_TIMESTAMP,
        account_locked_until = NULL
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to check if account is locked
CREATE OR REPLACE FUNCTION is_account_locked(p_user_id INTEGER) RETURNS BOOLEAN AS $$
DECLARE
    v_locked_until TIMESTAMP;
BEGIN
    SELECT account_locked_into v_locked_until FROM users WHERE id = p_user_id;
    
    IF v_locked_until IS NOT NULL AND v_locked_until > CURRENT_TIMESTAMP THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to create JWT token
CREATE OR REPLACE FUNCTION create_jwt_token(
    p_user_id INTEGER,
    p_token VARCHAR,
    p_refresh_token VARCHAR,
    p_device_info TEXT,
    p_ip_address VARCHAR,
    p_expires_at TIMESTAMP,
    p_refresh_expires_at TIMESTAMP
) RETURNS INTEGER AS $$
DECLARE
    v_token_id INTEGER;
BEGIN
    INSERT INTO jwt_tokens (user_id, token, refresh_token, device_info, ip_address, expires_at, refresh_token_expires_at)
    VALUES (p_user_id, p_token, p_refresh_token, p_device_info, p_ip_address, p_expires_at, p_refresh_expires_at)
    RETURNING id INTO v_token_id;
    
    RETURN v_token_id;
END;
$$ LANGUAGE plpgsql;

-- Function to revoke JWT token
CREATE OR REPLACE FUNCTION revoke_jwt_token(p_token VARCHAR) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE jwt_tokens SET is_revoked = TRUE WHERE token = p_token;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to revoke all user tokens
CREATE OR REPLACE FUNCTION revoke_all_user_tokens(p_user_id INTEGER) RETURNS INTEGER AS $$
DECLARE
    v_revoked_count INTEGER;
BEGIN
    UPDATE jwt_tokens SET is_revoked = TRUE WHERE user_id = p_user_id AND is_revoked = FALSE;
    GET DIAGNOSTICS v_revoked_count = ROW_COUNT;
    RETURN v_revoked_count;
END;
$$ LANGUAGE plpgsql;

-- Function to validate JWT token
CREATE OR REPLACE FUNCTION validate_jwt_token(p_token VARCHAR) RETURNS TABLE (
    is_valid BOOLEAN,
    user_id INTEGER,
    is_revoked BOOLEAN,
    expires_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (jt.expires_at > CURRENT_TIMESTAMP AND NOT jt.is_revoked) as is_valid,
        jt.user_id,
        jt.is_revoked,
        jt.expires_at
    FROM jwt_tokens jt
    WHERE jt.token = p_token;
END;
$$ LANGUAGE plpgsql;

-- Function to validate refresh token
CREATE OR REPLACE FUNCTION validate_refresh_token(p_refresh_token VARCHAR) RETURNS TABLE (
    is_valid BOOLEAN,
    user_id INTEGER,
    token_id INTEGER,
    is_revoked BOOLEAN,
    expires_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (jt.refresh_token_expires_at > CURRENT_TIMESTAMP AND NOT jt.is_revoked) as is_valid,
        jt.user_id,
        jt.id as token_id,
        jt.is_revoked,
        jt.refresh_token_expires_at
    FROM jwt_tokens jt
    WHERE jt.refresh_token = p_refresh_token;
END;
$$ LANGUAGE plpgsql;

-- Function to create email verification token
CREATE OR REPLACE FUNCTION create_email_verification_token(
    p_user_id INTEGER,
    p_token VARCHAR,
    p_expires_at TIMESTAMP
) RETURNS INTEGER AS $$
DECLARE
    v_token_id INTEGER;
BEGIN
    INSERT INTO email_verification_tokens (user_id, token, expires_at)
    VALUES (p_user_id, p_token, p_expires_at)
    RETURNING id INTO v_token_id;
    
    RETURN v_token_id;
END;
$$ LANGUAGE plpgsql;

-- Function to validate email verification token

# Code truncated at 7944 characters to meet length limit
# Full implementation available upon request
