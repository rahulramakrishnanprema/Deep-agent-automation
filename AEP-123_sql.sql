# Issue: AEP-123
# Generated: 2025-09-18T13:39:48.281279
# Thread: ff3c56e1
# Enhanced: LangChain structured generation
# AI Model: None
# Max Length: 10000 characters

-- Create table for users
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create table for tokens
CREATE TABLE IF NOT EXISTS tokens (
    token_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(user_id),
    token VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create table for logs
CREATE TABLE IF NOT EXISTS logs (
    log_id SERIAL PRIMARY KEY,
    level VARCHAR(10) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create function for logging
CREATE OR REPLACE FUNCTION log_message(level VARCHAR, message TEXT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO logs (level, message) VALUES (level, message);
END;
$$ LANGUAGE plpgsql;

-- Trigger for logging
CREATE TRIGGER log_trigger
AFTER INSERT ON logs
FOR EACH ROW
EXECUTE FUNCTION log_message(NEW.level, NEW.message);

-- Create function for user authentication
CREATE OR REPLACE FUNCTION authenticate_user(username VARCHAR, password VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    user_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM users WHERE username = username AND password = password) INTO user_exists;
    RETURN user_exists;
END;
$$ LANGUAGE plpgsql;

-- Create function for generating JWT token
CREATE OR REPLACE FUNCTION generate_token(user_id INT)
RETURNS VARCHAR AS $$
DECLARE
    token VARCHAR(255);
BEGIN
    token := MD5(user_id || now()::text);
    INSERT INTO tokens (user_id, token) VALUES (user_id, token);
    RETURN token;
END;
$$ LANGUAGE plpgsql;

-- Create function for verifying JWT token
CREATE OR REPLACE FUNCTION verify_token(token VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    token_valid BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM tokens WHERE token = token) INTO token_valid;
    RETURN token_valid;
END;
$$ LANGUAGE plpgsql;

-- Create function for deleting expired tokens
CREATE OR REPLACE FUNCTION delete_expired_tokens()
RETURNS VOID AS $$
BEGIN
    DELETE FROM tokens WHERE created_at < NOW() - INTERVAL '1 day';
END;
$$ LANGUAGE plpgsql;

-- Create function for handling errors
CREATE OR REPLACE FUNCTION handle_error(error_message TEXT)
RETURNS VOID AS $$
BEGIN
    PERFORM log_message('ERROR', error_message);
END;
$$ LANGUAGE plpgsql;

-- Trigger for error handling
CREATE TRIGGER error_trigger
AFTER INSERT ON logs
FOR EACH ROW
WHEN (NEW.level = 'ERROR')
EXECUTE FUNCTION handle_error(NEW.message);