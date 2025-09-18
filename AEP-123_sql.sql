# Issue: AEP-123
# Generated: 2025-09-18T17:12:27.292227
# Thread: 1c30ba36
# Enhanced: LangChain structured generation
# AI Model: None
# Max Length: 25000 characters

-- Create table for users
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create table for tokens
CREATE TABLE IF NOT EXISTS tokens (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    token VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data for testing
INSERT INTO users (username, password) VALUES ('test_user', 'hashed_password');

-- Create function for user authentication
CREATE OR REPLACE FUNCTION authenticate_user(p_username VARCHAR, p_password VARCHAR) RETURNS BOOLEAN AS $$
DECLARE
    v_user_id INT;
BEGIN
    SELECT id INTO v_user_id FROM users WHERE username = p_username AND password = p_password;
    IF FOUND THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create function for generating JWT token
CREATE OR REPLACE FUNCTION generate_token(p_user_id INT) RETURNS VARCHAR AS $$
DECLARE
    v_token VARCHAR;
BEGIN
    SELECT token INTO v_token FROM tokens WHERE user_id = p_user_id;
    IF FOUND THEN
        RETURN v_token;
    ELSE
        v_token := md5(random()::text);
        INSERT INTO tokens (user_id, token) VALUES (p_user_id, v_token);
        RETURN v_token;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create function for verifying JWT token
CREATE OR REPLACE FUNCTION verify_token(p_token VARCHAR) RETURNS BOOLEAN AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM tokens WHERE token = p_token) THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for logging user actions
CREATE OR REPLACE FUNCTION log_user_action() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_logs (user_id, action, created_at) VALUES (NEW.user_id, TG_OP, CURRENT_TIMESTAMP);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create table for user logs
CREATE TABLE IF NOT EXISTS user_logs (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    action VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create trigger for user authentication logging
CREATE TRIGGER user_auth_trigger AFTER INSERT ON tokens
    FOR EACH ROW EXECUTE FUNCTION log_user_action();