-- AEP-2: Implement Authentication APIs - SQL Schema and Procedures

-- Create users table for authentication
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    failed_login_attempts INTEGER DEFAULT 0,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create refresh tokens table for JWT management
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    revoked BOOLEAN DEFAULT FALSE
);

-- Create login attempts table for security monitoring
CREATE TABLE IF NOT EXISTS login_attempts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    username VARCHAR(50) NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token ON refresh_tokens(token);
CREATE INDEX IF NOT EXISTS idx_login_attempts_user_id ON login_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_login_attempts_attempted_at ON login_attempts(attempted_at);

-- Function to register new user
CREATE OR REPLACE FUNCTION register_user(
    p_username VARCHAR(50),
    p_email VARCHAR(100),
    p_password_hash VARCHAR(255),
    p_first_name VARCHAR(50),
    p_last_name VARCHAR(50)
) RETURNS TABLE (
    user_id INTEGER,
    username VARCHAR(50),
    email VARCHAR(100),
    first_name VARCHAR(50),
    last_name VARCHAR(50)
) AS $$
DECLARE
    v_user_id INTEGER;
BEGIN
    -- Validate input parameters
    IF p_username IS NULL OR p_username = '' THEN
        RAISE EXCEPTION 'Username cannot be empty';
    END IF;
    
    IF p_email IS NULL OR p_email = '' THEN
        RAISE EXCEPTION 'Email cannot be empty';
    END IF;
    
    IF p_password_hash IS NULL OR p_password_hash = '' THEN
        RAISE EXCEPTION 'Password hash cannot be empty';
    END IF;
    
    -- Check if username already exists
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
        RAISE EXCEPTION 'Username already exists';
    END IF;
    
    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email already exists';
    END IF;
    
    -- Insert new user
    INSERT INTO users (username, email, password_hash, first_name, last_name)
    VALUES (p_username, p_email, p_password_hash, p_first_name, p_last_name)
    RETURNING id INTO v_user_id;
    
    -- Return user data
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.email,
        u.first_name,
        u.last_name
    FROM users u
    WHERE u.id = v_user_id;
    
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'User with this username or email already exists';
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to authenticate user and update login stats
CREATE OR REPLACE FUNCTION authenticate_user(
    p_username VARCHAR(50),
    p_password_hash VARCHAR(255),
    p_ip_address VARCHAR(45) DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS TABLE (
    user_id INTEGER,
    username VARCHAR(50),
    email VARCHAR(100),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    is_active BOOLEAN,
    is_verified BOOLEAN
) AS $$
DECLARE
    v_user_id INTEGER;
    v_failed_attempts INTEGER;
    v_is_active BOOLEAN;
    v_is_verified BOOLEAN;
BEGIN
    -- Validate input parameters
    IF p_username IS NULL OR p_username = '' THEN
        RAISE EXCEPTION 'Username cannot be empty';
    END IF;
    
    IF p_password_hash IS NULL OR p_password_hash = '' THEN
        RAISE EXCEPTION 'Password hash cannot be empty';
    END IF;
    
    -- Get user data
    SELECT id, failed_login_attempts, is_active, is_verified
    INTO v_user_id, v_failed_attempts, v_is_active, v_is_verified
    FROM users 
    WHERE username = p_username;
    
    -- Check if user exists
    IF v_user_id IS NULL THEN
        -- Log failed attempt for non-existent user
        INSERT INTO login_attempts (username, ip_address, user_agent, success)
        VALUES (p_username, p_ip_address, p_user_agent, FALSE);
        
        RAISE EXCEPTION 'Invalid username or password';
    END IF;
    
    -- Check if account is locked due to too many failed attempts
    IF v_failed_attempts >= 5 THEN
        -- Log failed attempt
        INSERT INTO login_attempts (user_id, username, ip_address, user_agent, success)
        VALUES (v_user_id, p_username, p_ip_address, p_user_agent, FALSE);
        
        RAISE EXCEPTION 'Account temporarily locked due to multiple failed login attempts';
    END IF;
    
    -- Check if account is active
    IF NOT v_is_active THEN
        -- Log failed attempt
        INSERT INTO login_attempts (user_id, username, ip_address, user_agent, success)
        VALUES (v_user_id, p_username, p_ip_address, p_user_agent, FALSE);
        
        RAISE EXCEPTION 'Account is deactivated';
    END IF;
    
    -- Verify password hash
    IF EXISTS (
        SELECT 1 
        FROM users 
        WHERE id = v_user_id 
        AND password_hash = p_password_hash
        AND is_active = TRUE
    ) THEN
        -- Successful login
        UPDATE users 
        SET 
            failed_login_attempts = 0,
            last_login = CURRENT_TIMESTAMP
        WHERE id = v_user_id;
        
        -- Log successful attempt
        INSERT INTO login_attempts (user_id, username, ip_address, user_agent, success)
        VALUES (v_user_id, p_username, p_ip_address, p_user_agent, TRUE);
        
        -- Return user data
        RETURN QUERY
        SELECT 
            u.id,
            u.username,
            u.email,
            u.first_name,
            u.last_name,
            u.is_active,
            u.is_verified
        FROM users u
        WHERE u.id = v_user_id;
    ELSE
        -- Failed login attempt
        UPDATE users 
        SET failed_login_attempts = failed_login_attempts + 1
        WHERE id = v_user_id;
        
        -- Log failed attempt
        INSERT INTO login_attempts (user_id, username, ip_address, user_agent, success)
        VALUES (v_user_id, p_username, p_ip_address, p_user_agent, FALSE);
        
        RAISE EXCEPTION 'Invalid username or password';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to store refresh token
CREATE OR REPLACE FUNCTION store_refresh_token(
    p_user_id INTEGER,
    p_token VARCHAR(500),
    p_expires_at TIMESTAMP
) RETURNS VOID AS $$
BEGIN
    -- Validate input parameters
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID cannot be null';
    END IF;
    
    IF p_token IS NULL OR p_token = '' THEN
        RAISE EXCEPTION 'Token cannot be empty';
    END IF;
    
    IF p_expires_at IS NULL THEN
        RAISE EXCEPTION 'Expiration time cannot be null';
    END IF;
    
    -- Insert refresh token
    INSERT INTO refresh_tokens (user_id, token, expires_at)
    VALUES (p_user_id, p_token, p_expires_at);
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate refresh token
CREATE OR REPLACE FUNCTION validate_refresh_token(
    p_token VARCHAR(500)
) RETURNS TABLE (
    user_id INTEGER,
    is_valid BOOLEAN,
    is_expired BOOLEAN
) AS $$
DECLARE
    v_user_id INTEGER;
    v_expires_at TIMESTAMP;
    v_revoked BOOLEAN;
BEGIN
    -- Validate input parameter
    IF p_token IS NULL OR p_token = '' THEN
        RAISE EXCEPTION 'Token cannot be empty';
    END IF;
    
    -- Get token data
    SELECT user_id, expires_at, revoked
    INTO v_user_id, v_expires_at, v_revoked
    FROM refresh_tokens
    WHERE token = p_token;
    
    -- Check if token exists and is valid
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT NULL::INTEGER, FALSE, FALSE;
    ELSIF v_revoked THEN
        RETURN QUERY SELECT v_user_id, FALSE, FALSE;
    ELSIF v_expires_at < CURRENT_TIMESTAMP THEN
        RETURN QUERY SELECT v_user_id, FALSE, TRUE;
    ELSE
        RETURN QUERY SELECT v_user_id, TRUE, FALSE;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to revoke refresh token
CREATE OR REPLACE FUNCTION revoke_refresh_token(
    p_token VARCHAR(500)
) RETURNS BOOLEAN AS $$
BEGIN
    -- Validate input parameter
    IF p_token IS NULL OR p_token = '' THEN
        RAISE EXCEPTION 'Token cannot be empty';
    END IF;
    
    -- Update token as revoked
    UPDATE refresh_tokens
    SET revoked = TRUE
    WHERE token = p_token;
    
    RETURN FOUND;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to revoke all refresh tokens for a user
CREATE OR REPLACE FUNCTION revoke_all_user_tokens(
    p_user_id INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_updated_count INTEGER;
BEGIN
    -- Validate input parameter
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID cannot be null';
    END IF;
    
    -- Revoke all tokens for the user
    UPDATE refresh_tokens
    SET revoked = TRUE
    WHERE user_id = p_user_id;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RETURN v_updated_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;

# Code truncated at 9984 characters to meet length limit
# Full implementation available upon request
