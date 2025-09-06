-- Migration Scripts for Training Database
-- Version: 1.0
-- Description: Initial database schema creation for training management system

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS user_courses CASCADE;
DROP TABLE IF EXISTS course_skills CASCADE;
DROP TABLE IF EXISTS user_skills CASCADE;
DROP TABLE IF EXISTS training_needs CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS skills CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- Create roles table
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role_id INTEGER NOT NULL REFERENCES roles(id),
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create skills table
CREATE TABLE skills (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    category VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create courses table
CREATE TABLE courses (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    duration_hours INTEGER,
    provider VARCHAR(100),
    level VARCHAR(50) CHECK (level IN ('Beginner', 'Intermediate', 'Advanced')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create training_needs table
CREATE TABLE training_needs (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    priority VARCHAR(20) CHECK (priority IN ('Low', 'Medium', 'High')),
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'In Progress', 'Completed', 'Cancelled')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, skill_id)
);

-- Create user_skills table (skills that users already possess)
CREATE TABLE user_skills (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    proficiency_level VARCHAR(20) CHECK (proficiency_level IN ('Beginner', 'Intermediate', 'Advanced', 'Expert')),
    years_of_experience INTEGER,
    verified BOOLEAN DEFAULT FALSE,
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, skill_id)
);

-- Create course_skills table (skills taught by courses)
CREATE TABLE course_skills (
    id SERIAL PRIMARY KEY,
    course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    coverage_level VARCHAR(20) CHECK (coverage_level IN ('Introduction', 'Comprehensive', 'Advanced')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(course_id, skill_id)
);

-- Create user_courses table (courses taken by users)
CREATE TABLE user_courses (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    enrollment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completion_date TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'Enrolled' CHECK (status IN ('Enrolled', 'In Progress', 'Completed', 'Dropped')),
    grade VARCHAR(10),
    certificate_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, course_id)
);

-- Create indexes for better performance
CREATE INDEX idx_users_role_id ON users(role_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_training_needs_user_id ON training_needs(user_id);
CREATE INDEX idx_training_needs_skill_id ON training_needs(skill_id);
CREATE INDEX idx_user_skills_user_id ON user_skills(user_id);
CREATE INDEX idx_user_skills_skill_id ON user_skills(skill_id);
CREATE INDEX idx_course_skills_course_id ON course_skills(course_id);
CREATE INDEX idx_course_skills_skill_id ON course_skills(skill_id);
CREATE INDEX idx_user_courses_user_id ON user_courses(user_id);
CREATE INDEX idx_user_courses_course_id ON user_courses(course_id);

-- Insert sample roles
INSERT INTO roles (name, description) VALUES
('Admin', 'System administrator with full access'),
('Manager', 'Can manage team training needs and view reports'),
('Employee', 'Regular employee who can view and request training');

-- Insert sample skills
INSERT INTO skills (name, description, category) VALUES
('Python Programming', 'Python language programming skills', 'Technical'),
('Project Management', 'Managing projects effectively', 'Management'),
('Data Analysis', 'Analyzing and interpreting data', 'Analytical'),
('Communication', 'Effective communication skills', 'Soft Skills'),
('JavaScript', 'JavaScript programming language', 'Technical'),
('Leadership', 'Leading teams and initiatives', 'Management');

-- Insert sample courses
INSERT INTO courses (title, description, duration_hours, provider, level, is_active) VALUES
('Python for Beginners', 'Introduction to Python programming', 40, 'Tech Academy', 'Beginner', TRUE),
('Advanced Project Management', 'Advanced techniques for project management', 60, 'Management Institute', 'Advanced', TRUE),
('Data Analysis with Python', 'Using Python for data analysis', 50, 'Data Science School', 'Intermediate', TRUE),
('Effective Communication Workshop', 'Improving communication skills', 20, 'Soft Skills Inc', 'Beginner', TRUE),
('JavaScript Fundamentals', 'Core JavaScript concepts', 35, 'Web Dev Academy', 'Beginner', TRUE);

-- Insert sample users (passwords are hashed 'password123')
INSERT INTO users (username, email, first_name, last_name, password_hash, role_id) VALUES
('admin1', 'admin1@company.com', 'John', 'Admin', '$2b$10$examplehashforadmin1', 1),
('manager1', 'manager1@company.com', 'Jane', 'Manager', '$2b$10$examplehashformanager1', 2),
('employee1', 'employee1@company.com', 'Bob', 'Employee', '$2b$10$examplehashforemployee1', 3),
('employee2', 'employee2@company.com', 'Alice', 'Developer', '$2b$10$examplehashforemployee2', 3);

-- Insert sample user skills
INSERT INTO user_skills (user_id, skill_id, proficiency_level, years_of_experience, verified) VALUES
((SELECT id FROM users WHERE username = 'employee1'), (SELECT id FROM skills WHERE name = 'Python Programming'), 'Intermediate', 3, TRUE),
((SELECT id FROM users WHERE username = 'employee2'), (SELECT id FROM skills WHERE name = 'JavaScript'), 'Advanced', 5, TRUE),
((SELECT id FROM users WHERE username = 'manager1'), (SELECT id FROM skills WHERE name = 'Project Management'), 'Expert', 8, TRUE);

-- Insert sample course skills relationships
INSERT INTO course_skills (course_id, skill_id, coverage_level) VALUES
((SELECT id FROM courses WHERE title = 'Python for Beginners'), (SELECT id FROM skills WHERE name = 'Python Programming'), 'Introduction'),
((SELECT id FROM courses WHERE title = 'Advanced Project Management'), (SELECT id FROM skills WHERE name = 'Project Management'), 'Advanced'),
((SELECT id FROM courses WHERE title = 'Data Analysis with Python'), (SELECT id FROM skills WHERE name = 'Python Programming'), 'Comprehensive'),
((SELECT id FROM courses WHERE title = 'Data Analysis with Python'), (SELECT id FROM skills WHERE name = 'Data Analysis'), 'Comprehensive'),
((SELECT id FROM courses WHERE title = 'JavaScript Fundamentals'), (SELECT id FROM skills WHERE name = 'JavaScript'), 'Introduction');

-- Insert sample training needs
INSERT INTO training_needs (user_id, skill_id, priority, status) VALUES
((SELECT id FROM users WHERE