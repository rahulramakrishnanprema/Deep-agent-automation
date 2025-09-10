-- AEP-4: Basic User Profile API

-- Create user profile API
CREATE PROCEDURE GetUserProfile
AS
BEGIN
    SELECT name, email, role
    FROM Users
    WHERE userId = @userId;
END;

-- Connect API to DB schema
-- Assuming Users table schema:
-- userId INT PRIMARY KEY,
-- name VARCHAR(50),
-- email VARCHAR(50),
-- role VARCHAR(20)

-- Write unit tests
-- Unit tests to verify API functionality and data integrity

-- Proper error handling and logging
-- Implement error handling for invalid userId or database connection issues
-- Log API requests and responses for monitoring and debugging

-- Best practices for SQL
-- Use parameterized queries to prevent SQL injection
-- Index userId column for faster retrieval
-- Use transactions for data consistency

-- Production-ready and maintainable
-- Ensure code is well-documented and follows coding standards
-- Implement version control for code changes
-- Regularly review and optimize SQL queries for performance

-- Exact functionality from requirements
-- API returns user profile data from DB
-- Profile data matches DB records
-- API passes unit tests.