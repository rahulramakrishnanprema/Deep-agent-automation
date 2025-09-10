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
-- Log any errors or exceptions for troubleshooting

-- Best practices for SQL
-- Use parameterized queries to prevent SQL injection
-- Use appropriate data types and lengths for columns
-- Index columns used in WHERE clause for performance optimization

-- Production-ready and maintainable
-- Document the API usage and input parameters
-- Include version control for the SQL code
-- Regularly review and optimize the SQL queries for performance

-- Exact functionality from requirements
-- API returns user profile data from DB
-- Profile data matches DB records
-- API passes unit tests.