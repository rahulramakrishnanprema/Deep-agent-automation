-- Database Schema Setup Script for Training Management System
-- This script creates the necessary tables and relationships for storing user, role, training needs, and course data

-- Start transaction to ensure all operations succeed or fail together
BEGIN;

-- Drop tables if they exist (for clean setup during development)
-- Note: In production, you might want to use migration scripts instead of DROP statements
DROP TABLE IF EXISTS training_needs CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- Create users table to store user information
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    department VARCHAR(100),
    position VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT chk_username_length CHECK (LENGTH(username) >= 3),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

COMMENT ON TABLE users IS 'Stores user account information and profile details';
COMMENT ON COLUMN users.user_id IS 'Unique identifier for each user';
COMMENT ON COLUMN users.username IS 'Unique username for login';
COMMENT ON COLUMN users.email IS 'User email address, must be unique';
COMMENT ON COLUMN users.password_hash IS 'Hashed password for security';
COMMENT ON COLUMN users.is_active IS 'Indicates if the user account is active';

-- Create roles table to define different user permissions/access levels
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) UNIQUE NOT NULL,
    role_description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_role_name_length CHECK (LENGTH(role_name) >= 2)
);

COMMENT ON TABLE roles IS 'Defines different user roles and permissions';
COMMENT ON COLUMN roles.role_id IS 'Unique identifier for each role';
COMMENT ON COLUMN roles.role_name IS 'Name of the role (e.g., admin, manager, employee)';

-- Create junction table for user-roles many-to-many relationship
CREATE TABLE user_roles (
    user_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    assigned_by INTEGER,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_assigner FOREIGN KEY (assigned_by) REFERENCES users(user_id)
);

COMMENT ON TABLE user_roles IS 'Links users to their assigned roles';
COMMENT ON COLUMN user_roles.assigned_by IS 'User who assigned this role';

-- Create courses table to store training course information
CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    course_code VARCHAR(20) UNIQUE NOT NULL,
    course_name VARCHAR(200) NOT NULL,
    course_description TEXT,
    category VARCHAR(100) NOT NULL,
    duration_hours INTEGER NOT NULL,
    difficulty_level VARCHAR(20) CHECK (difficulty_level IN ('Beginner', 'Intermediate', 'Advanced', 'Expert')),
    provider VARCHAR(150),
    cost DECIMAL(10,2) DEFAULT 0.00,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(user_id),
    CONSTRAINT chk_duration_positive CHECK (duration_hours > 0),
    CONSTRAINT chk_cost_non_negative CHECK (cost >= 0)
);

COMMENT ON TABLE courses IS 'Stores information about available training courses';
COMMENT ON COLUMN courses.course_code IS 'Unique code identifier for the course';
COMMENT ON COLUMN courses.difficulty_level IS 'Difficulty level of the course';
COMMENT ON COLUMN courses.cost IS 'Cost of the course in local currency';

-- Create training_needs table to track user training requirements
CREATE TABLE training_needs (
    training_need_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    status VARCHAR(20) DEFAULT 'Requested' CHECK (status IN ('Requested', 'Approved', 'Rejected', 'Completed', 'In Progress')),
    priority VARCHAR(20) DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Critical')),
    requested_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    target_completion_date DATE,
    approved_date TIMESTAMP WITH TIME ZONE,
    approved_by INTEGER,
    completion_date TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    CONSTRAINT fk_training_needs_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_training_needs_course FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE,
    CONSTRAINT fk_training_needs_approver FOREIGN KEY (approved_by) REFERENCES users(user_id),
    CONSTRAINT chk_dates_valid CHECK (target_completion_date IS NULL OR target_completion_date > requested_date::DATE)
);

COMMENT ON TABLE training_needs IS 'Tracks training requirements and their status for users';
COMMENT ON COLUMN training_needs.status IS 'Current status of the training need';
COMMENT ON COLUMN training_needs.priority IS 'Priority level of the training need';

-- Create indexes for better query performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_department ON users(department);
CREATE INDEX idx_courses_category ON courses(category);
CREATE INDEX idx_courses_difficulty ON courses(difficulty_level);
CREATE INDEX idx_training_needs_user ON training_needs(user_id);
CREATE INDEX idx_training_needs_status ON training_needs(status);
CREATE INDEX idx_training_needs_priority ON training_needs(priority);
CREATE INDEX idx_training_needs_completion_date ON training_needs(target_completion_date);

-- Insert sample roles
INSERT INTO roles (role_name, role_description) VALUES
('Administrator', 'Full system access including user management and configuration'),
('Manager', 'Can approve training requests and view team training status'),
('Employee', 'Standard user who can request training and view own progress'),
('Trainer', 'Can manage course content and track participant progress');

-- Insert sample admin user (password: admin123 - hash for demonstration)
INSERT INTO users (username, email, first_name, last_name, password_hash, department, position) VALUES
('admin', 'admin@company.com', 'System', 'Administrator', '$2b$10$examplehashforadmin123', 'IT', 'System Administrator');

-- Assign admin role to admin user
INSERT INTO user_roles (user_id, role_id, assigned_by) 
SELECT u.user_id, r.role_id, u.user_id 
FROM users u, roles r 
WHERE u.username = 'admin' AND r.role_name = 'Administrator';

-- Insert sample courses
INSERT INTO courses (course_code, course_name, course_description, category, duration_hours, difficulty_level, provider, cost, created_by) 
SELECT 
    'PYTHON-101', 
    'Python Programming Fundamentals', 
    'Learn basic Python syntax, data structures, and programming concepts', 
    'Programming', 
    16, 
    'Beginner', 
    'Internal Training', 
    0.00, 
    user_id 
FROM users 
WHERE username = 'admin';

INSERT INTO courses (course_code, course_name, course_description, category, duration_hours, difficulty_level, provider, cost, created_by) 
SELECT 
    'DEVOPS-201', 
    'Advanced DevOps Practices', 
    'Advanced techniques in CI/CD, containerization, and infrastructure as code', 
    'DevOps', 
    24, 
    'Advanced', 
    'External Provider', 
    499.99, 
    user_id 
FROM users 
WHERE username = 'admin';

INSERT INTO courses (course_code, course_name, course_description, category, duration_hours, difficulty_level, provider, cost, created_by) 
SELECT 
    'MGMT-301', 
    'Leadership and Team Management', 
    'Develop leadership skills and learn effective team management strategies', 
    'Management', 
    12, 
    'Intermediate', 
    'Internal Training', 
    0.00, 
    user_id 
FROM users 
WHERE username = 'admin';

-- Insert sample users
INSERT INTO users (username, email, first_name, last_name, password_hash, department, position) VALUES
('jdoe', 'jdoe@company.com', 'John', 'Doe', '$2b$10$examplehashforuser123', 'Engineering', 'Software