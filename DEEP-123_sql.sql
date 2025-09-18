-- DEEP-123: SQL code for PostgreSQL database integration

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
    token VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create table for logs
CREATE TABLE IF NOT EXISTS logs (
    id SERIAL PRIMARY KEY,
    level VARCHAR(10) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Function to insert a new user
CREATE OR REPLACE FUNCTION insert_user(username VARCHAR, password VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    user_id INTEGER;
BEGIN
    INSERT INTO users (username, password)
    VALUES (username, password)
    RETURNING id INTO user_id;
    
    RETURN user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to retrieve user by username
CREATE OR REPLACE FUNCTION get_user_by_username(username VARCHAR)
RETURNS users AS $$
DECLARE
    user_record users;
BEGIN
    SELECT * INTO user_record
    FROM users
    WHERE username = username;
    
    RETURN user_record;
END;
$$ LANGUAGE plpgsql;

-- Function to insert a new token
CREATE OR REPLACE FUNCTION insert_token(user_id INTEGER, token VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    token_id INTEGER;
BEGIN
    INSERT INTO tokens (user_id, token)
    VALUES (user_id, token)
    RETURNING id INTO token_id;
    
    RETURN token_id;
END;
$$ LANGUAGE plpgsql;

-- Function to retrieve user by token
CREATE OR REPLACE FUNCTION get_user_by_token(token VARCHAR)
RETURNS users AS $$
DECLARE
    user_record users;
BEGIN
    SELECT u.*
    INTO user_record
    FROM users u
    JOIN tokens t ON u.id = t.user_id
    WHERE t.token = token;
    
    RETURN user_record;
END;
$$ LANGUAGE plpgsql;

-- Function to log a message
CREATE OR REPLACE FUNCTION log_message(level VARCHAR, message TEXT)
RETURNS INTEGER AS $$
BEGIN
    INSERT INTO logs (level, message)
    VALUES (level, message);
    
    RETURN 1;
END;
$$ LANGUAGE plpgsql;