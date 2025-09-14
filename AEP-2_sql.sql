-- AEP-2: Authentication APIs SQL Schema Implementation

-- Create users table for authentication
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    failed_login_attempts INTEGER DEFAULT 0,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verification_token VARCHAR(255),
    reset_token VARCHAR(255),
    reset_token_expires TIMESTAMP
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_verification_token ON users(verification_token);
CREATE INDEX IF NOT EXISTS idx_users_reset_token ON users(reset_token);

-- Create refresh tokens table for JWT management
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    revoked BOOLEAN DEFAULT FALSE,
    device_info TEXT,
    ip_address VARCHAR(45)
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token ON refresh_tokens(token);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires ON refresh_tokens(expires_at);

-- Create login attempts table for security monitoring
CREATE TABLE IF NOT EXISTS login_attempts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    username VARCHAR(50),
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    failure_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_login_attempts_user_id ON login_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_login_attempts_ip ON login_attempts(ip_address);
CREATE INDEX IF NOT EXISTS idx_login_attempts_time ON login_attempts(attempted_at);

-- Create user roles table for authorization
CREATE TABLE IF NOT EXISTS user_roles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role);

-- Insert default roles
INSERT INTO user_roles (user_id, role) 
SELECT id, 'user' FROM users 
WHERE id NOT IN (SELECT user_id FROM user_roles WHERE role = 'user')
ON CONFLICT DO NOTHING;

-- Function to update user's last login timestamp
CREATE OR REPLACE FUNCTION update_user_last_login(user_id INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE users 
    SET last_login = CURRENT_TIMESTAMP, 
        failed_login_attempts = 0,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to increment failed login attempts
CREATE OR REPLACE FUNCTION increment_failed_login_attempts(user_id INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE users 
    SET failed_login_attempts = failed_login_attempts + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to check if user account is locked
CREATE OR REPLACE FUNCTION is_account_locked(user_id INTEGER, max_attempts INTEGER DEFAULT 5)
RETURNS BOOLEAN AS $$
DECLARE
    attempts INTEGER;
BEGIN
    SELECT failed_login_attempts INTO attempts 
    FROM users 
    WHERE id = user_id;
    
    RETURN attempts >= max_attempts;
END;
$$ LANGUAGE plpgsql;

-- Function to register new user
CREATE OR REPLACE FUNCTION register_user(
    p_username VARCHAR(50),
    p_email VARCHAR(255),
    p_password_hash VARCHAR(255),
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_verification_token VARCHAR(255)
) RETURNS TABLE(user_id INTEGER, username VARCHAR(50), email VARCHAR(255)) AS $$
DECLARE
    new_user_id INTEGER;
BEGIN
    -- Check if username or email already exists
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
        RAISE EXCEPTION 'Username already exists';
    END IF;
    
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email already exists';
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
    ) RETURNING id INTO new_user_id;
    
    -- Assign default user role
    INSERT INTO user_roles (user_id, role) VALUES (new_user_id, 'user');
    
    -- Return user data
    RETURN QUERY SELECT new_user_id, p_username, p_email;
END;
$$ LANGUAGE plpgsql;

-- Function to authenticate user
CREATE OR REPLACE FUNCTION authenticate_user(
    p_username VARCHAR(50),
    p_password_hash VARCHAR(255),
    p_ip_address VARCHAR(45),
    p_user_agent TEXT
) RETURNS TABLE(
    user_id INTEGER, 
    username VARCHAR(50), 
    email VARCHAR(255), 
    first_name VARCHAR(100), 
    last_name VARCHAR(100),
    is_verified BOOLEAN,
    roles TEXT[]
) AS $$
DECLARE
    v_user_id INTEGER;
    v_password_hash VARCHAR(255);
    v_is_active BOOLEAN;
    v_is_locked BOOLEAN;
BEGIN
    -- Get user data
    SELECT id, password_hash, is_active, is_account_locked(id)
    INTO v_user_id, v_password_hash, v_is_active, v_is_locked
    FROM users 
    WHERE username = p_username OR email = p_username;
    
    -- Record login attempt
    INSERT INTO login_attempts (user_id, username, ip_address, user_agent, success, failure_reason)
    VALUES (
        v_user_id, 
        p_username, 
        p_ip_address, 
        p_user_agent,
        FALSE,
        CASE 
            WHEN v_user_id IS NULL THEN 'User not found'
            WHEN NOT v_is_active THEN 'Account inactive'
            WHEN v_is_locked THEN 'Account locked'
            WHEN v_password_hash != p_password_hash THEN 'Invalid password'
            ELSE 'Unknown error'
        END
    );
    
    -- Validate user
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Invalid credentials';
    END IF;
    
    IF NOT v_is_active THEN
        RAISE EXCEPTION 'Account is inactive';
    END IF;
    
    IF v_is_locked THEN
        RAISE EXCEPTION 'Account is locked due to multiple failed attempts';
    END IF;
    
    IF v_password_hash != p_password_hash THEN
        PERFORM increment_failed_login_attempts(v_user_id);
        RAISE EXCEPTION 'Invalid credentials';
    END IF;
    
    -- Update successful login
    PERFORM update_user_last_login(v_user_id);
    
    -- Update login attempt as successful
    UPDATE login_attempts 
    SET success = TRUE, 
        failure_reason = NULL
    WHERE id = (SELECT MAX(id) FROM login_attempts WHERE username = p_username);
    
    -- Return user data with roles
    RETURN QUERY 
    SELECT 
        u.id,
        u.username,
        u.email,
        u.first_name,
        u.last_name,
        u.is_verified,
        ARRAY_AGG(ur.role) AS roles
    FROM users u
    LEFT JOIN user_roles ur ON u.id = ur.user_id
    WHERE u.id = v_user_id
    GROUP BY u.id, u.username, u.email, u.first_name, u.last_name, u.is_verified;
END;
$$ LANGUAGE plpgsql;

-- Function to store refresh token
CREATE OR REPLACE FUNCTION store_refresh_token(
    p_user_id INTEGER,
    p_token VARCHAR(255),
    p_expires_at TIMESTAMP,
    p_device_info TEXT,
    p_ip_address VARCHAR(45)
) RETURNS VOID AS $$
BEGIN
    INSERT INTO refresh_tokens (user_id, token, expires_at, device_info, ip_address)

# Code truncated at 7993 characters to meet length limit
# Full implementation available upon request
