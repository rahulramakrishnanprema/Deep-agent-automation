-- AEP-2: Implement Authentication APIs SQL Schema
-- This file contains the database schema for user authentication system

-- Users table to store user credentials and authentication data
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER DEFAULT 0,
    account_locked_until TIMESTAMP WITH TIME ZONE,
    verification_token VARCHAR(255),
    reset_token VARCHAR(255),
    reset_token_expiry TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_verification_token ON users(verification_token);
CREATE INDEX IF NOT EXISTS idx_users_reset_token ON users(reset_token);

-- Refresh tokens table for JWT token management
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP WITH TIME ZONE,
    replaced_by_token VARCHAR(255),
    device_info TEXT,
    ip_address VARCHAR(45)
);

-- Indexes for refresh tokens
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token ON refresh_tokens(token);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- Login attempts audit table for security monitoring
CREATE TABLE IF NOT EXISTS login_attempts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    username VARCHAR(50),
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    failure_reason TEXT,
    attempted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for login attempts
CREATE INDEX IF NOT EXISTS idx_login_attempts_user_id ON login_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_login_attempts_username ON login_attempts(username);
CREATE INDEX IF NOT EXISTS idx_login_attempts_attempted_at ON login_attempts(attempted_at);
CREATE INDEX IF NOT EXISTS idx_login_attempts_success ON login_attempts(success);

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to automatically update updated_at
CREATE OR REPLACE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to handle user registration
CREATE OR REPLACE FUNCTION register_user(
    p_username VARCHAR(50),
    p_email VARCHAR(255),
    p_password_hash VARCHAR(255),
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_verification_token VARCHAR(255)
)
RETURNS TABLE (
    user_id INTEGER,
    username VARCHAR(50),
    email VARCHAR(255),
    is_verified BOOLEAN
) AS $$
DECLARE
    v_user_id INTEGER;
BEGIN
    -- Check if username or email already exists
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
        RAISE EXCEPTION 'Username already exists' USING ERRCODE = '23505';
    END IF;

    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email already exists' USING ERRCODE = '23505';
    END IF;

    -- Insert new user
    INSERT INTO users (
        username, 
        email, 
        password_hash, 
        first_name, 
        last_name, 
        verification_token
    ) VALUES (
        p_username,
        p_email,
        p_password_hash,
        p_first_name,
        p_last_name,
        p_verification_token
    ) RETURNING id INTO v_user_id;

    -- Return user data
    RETURN QUERY
    SELECT 
        v_user_id,
        p_username,
        p_email,
        FALSE as is_verified;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'User with this username or email already exists';
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle user login with security measures
CREATE OR REPLACE FUNCTION authenticate_user(
    p_identifier VARCHAR(255),
    p_password_hash VARCHAR(255),
    p_ip_address VARCHAR(45),
    p_user_agent TEXT
)
RETURNS TABLE (
    user_id INTEGER,
    username VARCHAR(50),
    email VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_verified BOOLEAN,
    requires_verification BOOLEAN
) AS $$
DECLARE
    v_user_id INTEGER;
    v_username VARCHAR(50);
    v_email VARCHAR(255);
    v_first_name VARCHAR(100);
    v_last_name VARCHAR(100);
    v_is_verified BOOLEAN;
    v_is_active BOOLEAN;
    v_account_locked_until TIMESTAMP WITH TIME ZONE;
    v_failed_attempts INTEGER;
    v_stored_password_hash VARCHAR(255);
BEGIN
    -- Find user by username or email
    SELECT 
        id, 
        username, 
        email, 
        first_name, 
        last_name, 
        is_verified, 
        is_active, 
        account_locked_until,
        failed_login_attempts,
        password_hash
    INTO 
        v_user_id,
        v_username,
        v_email,
        v_first_name,
        v_last_name,
        v_is_verified,
        v_is_active,
        v_account_locked_until,
        v_failed_attempts,
        v_stored_password_hash
    FROM users 
    WHERE (username = p_identifier OR email = p_identifier) 
    AND is_active = TRUE;

    -- Check if user exists
    IF v_user_id IS NULL THEN
        -- Log failed attempt for non-existent user
        INSERT INTO login_attempts (username, ip_address, user_agent, success, failure_reason)
        VALUES (p_identifier, p_ip_address, p_user_agent, FALSE, 'User not found');
        
        RAISE EXCEPTION 'Invalid credentials' USING ERRCODE = 'invalid_credentials';
    END IF;

    -- Check if account is locked
    IF v_account_locked_until IS NOT NULL AND v_account_locked_until > CURRENT_TIMESTAMP THEN
        -- Log locked account attempt
        INSERT INTO login_attempts (user_id, username, ip_address, user_agent, success, failure_reason)
        VALUES (v_user_id, v_username, p_ip_address, p_user_agent, FALSE, 'Account locked');
        
        RAISE EXCEPTION 'Account locked until %', v_account_locked_until 
        USING ERRCODE = 'account_locked';
    END IF;

    -- Verify password
    IF v_stored_password_hash != p_password_hash THEN
        -- Increment failed login attempts
        UPDATE users 
        SET failed_login_attempts = failed_login_attempts + 1,
            account_locked_until = CASE 
                WHEN failed_login_attempts + 1 >= 5 THEN CURRENT_TIMESTAMP + INTERVAL '15 minutes'
                ELSE account_locked_until
            END
        WHERE id = v_user_id;

        -- Log failed attempt
        INSERT INTO login_attempts (user_id, username, ip_address, user_agent, success, failure_reason)
        VALUES (v_user_id, v_username, p_ip_address, p_user_agent, FALSE, 'Invalid password');

        RAISE EXCEPTION 'Invalid credentials' USING ERRCODE = 'invalid_credentials';
    END IF;

    -- Successful login - reset failed attempts and update last login
    UPDATE users 
    SET failed_login_attempts = 0,
        account_locked_until = NULL,
        last_login = CURRENT_TIMESTAMP
    WHERE id = v_user_id;

    -- Log successful attempt
    INSERT INTO login_attempts (user_id, username, ip_address, user_agent, success)
    VALUES (v_user_id, v_username, p_ip_address, p_user_agent, TRUE);

    -- Return user data
    RETURN QUERY
    SELECT 
        v_user_id,
        v_username,
        v_email,
        v_first_name,
        v_last_name,
        v_is_verified,
        NOT v_is_verified as requires_verification;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to store refresh token
CREATE OR REPLACE FUNCTION store_refresh_token(
    p_user_id INTEGER,
    p_token VARCHAR(255),
    p_expires_at TIMESTAMP WITH TIME ZONE,
    p_device_info TEXT,
    p_ip_address VARCHAR(45)
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO refresh_tokens (user_id, token, expires_at, device_info, ip_address)
    VALUES (p_user_id, p_token, p_expires_at, p_device_info, p_ip_address);
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate refresh token
CREATE OR REPLACE FUNCTION validate_refresh_token(
    p_token VARCHAR(255)
)
RETURNS TABLE (
    user_id INTEGER,
    is_valid BOOLEAN,
    reason TEXT
) AS $$
DECLARE
    v_user_id INTEGER;
    v_expires_at TIMESTAMP WITH TIME ZONE;
    v_revoked_at TIMESTAMP WITH TIME ZONE;
BEGIN
    SELECT user_id, expires_at, revoked_at
    INTO v_user_id, v_expires_at, v_revoked_at
    FROM refresh_tokens
    WHERE token = p_token;

    -- Check if token exists
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT NULL::INTEGER, FALSE, 'Token not found';
        RETURN;
    END IF;

    -- Check if token is revoked
    IF v_revoked_at IS NOT NULL THEN
        RETURN QUERY SELECT v_user_id, FALSE, 'Token revoked';
        RETURN;
    END IF;

    -- Check if token is expired
    IF v_expires_at < CURRENT_TIMESTAMP THEN
        RETURN QUERY SELECT v_user_id, FALSE, 'Token expired';
        RETURN;
    END IF;

    -- Token is valid
    RETURN QUERY SELECT v_user_id, TRUE, 'Valid token';
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to revoke refresh token
CREATE OR REPLACE FUNCTION revoke_refresh_token(
    p_token VARCHAR(255),
    p_replaced_by_token VARCHAR(255) DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE refresh_tokens
    SET revoked_at = CURRENT_TIMESTAMP,
        replaced_by_token = p_replaced_by_token
    WHERE token = p_token;
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user by ID
CREATE OR REPLACE FUNCTION get_user_by_id(p_user_id INTEGER)
RETURNS TABLE (
    id INTEGER,
    username VARCHAR(50),
    email VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_verified BOOLEAN,
    is_active BOOLEAN,
    last_login TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.email,
        u.first_name,
        u.last_name,
        u.is_verified,
        u.is_active,
        u.last_login
    FROM users u
    WHERE u.id = p_user_id AND u.is_active = TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify user account
CREATE OR REPLACE FUNCTION verify_user_account(p_verification_token VARCHAR(255))
RETURNS TABLE (
    user_id INTEGER,
    username VARCHAR(50),
    email VARCHAR(255),
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_user_id INTEGER;
    v_username VARCHAR(50);
    v_email VARCHAR(255);
BEGIN
    -- Find user by verification token
    SELECT id, username, email
    INTO v_user_id, v_username, v_email
    FROM users
    WHERE verification_token = p_verification_token
    AND is_verified = FALSE
    AND is_active = TRUE;

    -- Check if user exists with this token
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, FALSE, 'Invalid or expired verification token';
        RETURN;
    END IF;

    -- Verify the user account
    UPDATE users
    SET is_verified = TRUE,
        verification_token = NULL,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_user_id;

    RETURN QUERY SELECT v_user_id, v_username, v_email, TRUE, 'Account verified successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create custom error codes
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'auth_error_code') THEN
        CREATE TYPE auth_error_code AS ENUM (
            'invalid_credentials',
            'account_locked',
            'user_not_found',
            'token_expired',
            'token_revoked',
            'verification_failed'
        );
    END IF;
END $$;

-- Comments for documentation
COMMENT ON TABLE users IS 'Stores user authentication information and account status';
COMMENT ON TABLE refresh_tokens IS 'Stores JWT refresh tokens for session management';
COMMENT ON TABLE login_attempts IS 'Audit trail for login attempts for security monitoring';

COMMENT ON COLUMN users.failed_login_attempts IS 'Number of consecutive failed login attempts';
COMMENT ON COLUMN users.account_locked_until IS 'Timestamp until which account is locked due to too many failed attempts';
COMMENT ON COLUMN users.verification_token IS 'Token for email verification during registration';
COMMENT ON COLUMN users.reset_token IS 'Token for password reset functionality';

-- Grant necessary permissions (adjust based on your security requirements)
GRANT EXECUTE ON FUNCTION register_user TO authenticated_user;
GRANT EXECUTE ON FUNCTION authenticate_user TO authenticated_user;
GRANT EXECUTE ON FUNCTION store_refresh_token TO authenticated_user;
GRANT EXECUTE ON FUNCTION validate_refresh_token TO authenticated_user;
GRANT EXECUTE ON FUNCTION revoke_refresh_token TO authenticated_user;
GRANT EXECUTE ON FUNCTION get_user_by_id TO authenticated_user;
GRANT EXECUTE ON FUNCTION verify_user_account TO authenticated_user;

GRANT SELECT, INSERT, UPDATE ON users TO authenticated_user;
GRANT SELECT, INSERT, UPDATE ON refresh_tokens TO authenticated_user;
GRANT INSERT ON login_attempts TO authenticated_user;