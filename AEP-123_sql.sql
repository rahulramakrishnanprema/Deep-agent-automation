# Issue: AEP-123
# Generated: 2025-09-18T16:43:57.652285
# Thread: f7a92f8a
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
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create table for logs
CREATE TABLE IF NOT EXISTS logs (
    id SERIAL PRIMARY KEY,
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

-- Create trigger for logging
CREATE TRIGGER log_trigger
AFTER INSERT ON logs
FOR EACH ROW
EXECUTE FUNCTION log_message(NEW.level, NEW.message);

-- Create function for user authentication
CREATE OR REPLACE FUNCTION authenticate_user(username VARCHAR, password VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    user_id INTEGER;
BEGIN
    SELECT id INTO user_id FROM users WHERE username = username AND password = password;
    IF user_id IS NOT NULL THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create function for generating JWT token
CREATE OR REPLACE FUNCTION generate_token(user_id INTEGER)
RETURNS VARCHAR AS $$
DECLARE
    token VARCHAR;
BEGIN
    token := md5(random()::text || clock_timestamp()::text) || md5(user_id::text);
    INSERT INTO tokens (user_id, token) VALUES (user_id, token);
    RETURN token;
END;
$$ LANGUAGE plpgsql;

-- Create function for verifying JWT token
CREATE OR REPLACE FUNCTION verify_token(token VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    valid_token BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM tokens WHERE token = token) INTO valid_token;
    RETURN valid_token;
END;
$$ LANGUAGE plpgsql;

-- Create function for deleting expired tokens
CREATE OR REPLACE FUNCTION delete_expired_tokens()
RETURNS VOID AS $$
BEGIN
    DELETE FROM tokens WHERE created_at < NOW() - INTERVAL '1 day';
END;
$$ LANGUAGE plpgsql;

-- Create index on tokens table for user_id
CREATE INDEX IF NOT EXISTS idx_user_id ON tokens(user_id);