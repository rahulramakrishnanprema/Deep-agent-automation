-- AEP Database Schema Migration Script
-- File: aep_1_main.sql
-- Description: Main database schema creation script for AEP PostgreSQL database
-- Version: 1.0
-- Created: 2025-09-26
-- Author: AEP Development Team

-- This script creates the core database schema for the AEP application
-- including users, roles, training_needs, and courses tables with proper
-- foreign key relationships and constraints.

-- Enable UUID extension for unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS training_needs CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- Create roles table (reference table for user roles)
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_role_name_length CHECK (LENGTH(name) >= 2 AND LENGTH(name) <= 50)
);

-- Create users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    role_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_user_name_length CHECK (LENGTH(name) >= 2 AND LENGTH(name) <= 100),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT fk_user_role FOREIGN KEY (role_id) 
        REFERENCES roles(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE
);

-- Create courses table
CREATE TABLE courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    duration INTEGER NOT NULL CHECK (duration > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_course_title_length CHECK (LENGTH(title) >= 5 AND LENGTH(title) <= 200),
    CONSTRAINT chk_duration_positive CHECK (duration > 0)
);

-- Create training_needs table (junction table for user training requirements)
CREATE TABLE training_needs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    skill VARCHAR(150) NOT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_skill_length CHECK (LENGTH(skill) >= 3 AND LENGTH(skill) <= 150),
    CONSTRAINT chk_priority_value CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT fk_training_user FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
);

-- Create indexes for better query performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role_id ON users(role_id);
CREATE INDEX idx_training_needs_user_id ON training_needs(user_id);
CREATE INDEX idx_training_needs_priority ON training_needs(priority);
CREATE INDEX idx_courses_title ON courses(title);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at timestamps
CREATE TRIGGER update_roles_updated_at 
    BEFORE UPDATE ON roles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_courses_updated_at 
    BEFORE UPDATE ON courses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_training_needs_updated_at 
    BEFORE UPDATE ON training_needs 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data for testing
-- Sample roles
INSERT INTO roles (name, description) VALUES
('admin', 'System administrator with full access'),
('manager', 'Team manager with user management capabilities'),
('employee', 'Regular employee user'),
('trainer', 'Training instructor and content manager');

-- Sample users
INSERT INTO users (name, email, role_id) 
SELECT 
    'John Doe', 'john.doe@example.com', id 
FROM roles WHERE name = 'admin'
UNION ALL
SELECT 
    'Jane Smith', 'jane.smith@example.com', id 
FROM roles WHERE name = 'manager'
UNION ALL
SELECT 
    'Bob Johnson', 'bob.johnson@example.com', id 
FROM roles WHERE name = 'employee';

-- Sample courses
INSERT INTO courses (title, description, duration) VALUES
('Introduction to SQL', 'Fundamentals of SQL programming and database management', 8),
('Advanced Python Development', 'In-depth Python programming techniques and best practices', 16),
('Project Management Fundamentals', 'Essential project management skills and methodologies', 12),
('Data Analysis with Excel', 'Comprehensive Excel data analysis techniques', 6);

-- Sample training needs
INSERT INTO training_needs (user_id, skill, priority) 
SELECT 
    u.id, 'Advanced SQL Queries', 'high'
FROM users u WHERE u.email = 'john.doe@example.com'
UNION ALL
SELECT 
    u.id, 'Leadership Skills', 'medium'
FROM users u WHERE u.email = 'jane.smith@example.com'
UNION ALL
SELECT 
    u.id, 'Time Management', 'low'
FROM users u WHERE u.email = 'bob.johnson@example.com';

-- Create validation views for data integrity checks
CREATE VIEW schema_validation AS
SELECT 
    (SELECT COUNT(*) FROM roles) as roles_count,
    (SELECT COUNT(*) FROM users) as users_count,
    (SELECT COUNT(*) FROM courses) as courses_count,
    (SELECT COUNT(*) FROM training_needs) as training_needs_count,
    (SELECT COUNT(*) FROM users u LEFT JOIN roles r ON u.role_id = r.id WHERE r.id IS NULL) as orphaned_users,
    (SELECT COUNT(*) FROM training_needs tn LEFT JOIN users u ON tn.user_id = u.id WHERE u.id IS NULL) as orphaned_training_needs;

-- Display validation results
SELECT * FROM schema_validation;

-- Display sample data for verification
SELECT 'Roles' as table_name, id, name, description FROM roles
UNION ALL
SELECT 'Users' as table_name, id, name, email FROM users
UNION ALL
SELECT 'Courses' as table_name, id, title, description FROM courses
UNION ALL
SELECT 'Training Needs' as table_name, id, skill, priority FROM training_needs;

-- Create comments for documentation
COMMENT ON TABLE roles IS 'Stores user role definitions and permissions';
COMMENT ON TABLE users IS 'Stores user information and role associations';
COMMENT ON TABLE courses IS 'Stores training course information and details';
COMMENT ON TABLE training_needs IS 'Stores user training requirements and skill development needs';

COMMENT ON COLUMN roles.id IS 'Unique identifier for the role';
COMMENT ON COLUMN roles.name IS 'Role name (unique)';
COMMENT ON COLUMN roles.description IS 'Role description and permissions';

COMMENT ON COLUMN users.id IS 'Unique identifier for the user';
COMMENT ON COLUMN users.name IS 'User full name';
COMMENT ON COLUMN users.email IS 'User email address (unique)';
COMMENT ON COLUMN users.role_id IS 'Foreign key reference to roles table';

COMMENT ON COLUMN courses.id IS 'Unique identifier for the course';
COMMENT ON COLUMN courses.title IS 'Course title';
COMMENT ON COLUMN courses.description IS 'Course description and content';
COMMENT ON COLUMN courses.duration IS 'Course duration in hours';

COMMENT ON COLUMN training_needs.id IS 'Unique identifier for the training need';
COMMENT ON COLUMN training_needs.user_id IS 'Foreign key reference to users table';
COMMENT ON COLUMN training_needs.skill IS 'Required skill or competency';
COMMENT ON COLUMN training_needs.priority IS 'Priority level (low, medium, high, critical)';

-- Grant appropriate permissions (example - adjust based on your security requirements)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO aep_app_user;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO aep_app_user;

-- Display completion message
DO $$
BEGIN
    RAISE NOTICE 'AEP Database Schema successfully created and populated with sample data';
    RAISE NOTICE 'Total roles: %, Users: %, Courses: %, Training Needs: %', 
        (SELECT COUNT(*) FROM roles),
        (SELECT COUNT(*) FROM users),
        (SELECT COUNT(*) FROM courses),
        (SELECT COUNT(*) FROM training_needs);
END $$;