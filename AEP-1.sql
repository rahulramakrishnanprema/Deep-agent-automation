-- AEP-1: Database Schema Setup
-- Project: Training Management System
-- Database: PostgreSQL

-- Drop existing database if it exists and create new one
DROP DATABASE IF EXISTS training_db;
CREATE DATABASE training_db
    WITH 
    OWNER = admin
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- Connect to the newly created database
\c training_db;

-- Enable UUID extension for generating unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum types for consistent data validation
CREATE TYPE user_role AS ENUM ('admin', 'manager', 'employee', 'trainer');
CREATE TYPE training_status AS ENUM ('pending', 'approved', 'rejected', 'completed', 'in_progress');
CREATE TYPE skill_level AS ENUM ('beginner', 'intermediate', 'advanced', 'expert');

-- Table: users
-- Stores user information including roles and authentication
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role user_role NOT NULL DEFAULT 'employee',
    department VARCHAR(100),
    position VARCHAR(100),
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT chk_username_length CHECK (LENGTH(username) >= 3),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_password_length CHECK (LENGTH(password_hash) >= 60)
);

-- Table: skills
-- Master list of all available skills in the system
CREATE TABLE skills (
    skill_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    skill_name VARCHAR(100) NOT NULL,
    skill_description TEXT,
    category VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT unq_skill_name UNIQUE (skill_name),
    CONSTRAINT chk_skill_name_length CHECK (LENGTH(skill_name) >= 2)
);

-- Table: user_skills
-- Junction table linking users to their skills with proficiency levels
CREATE TABLE user_skills (
    user_skill_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    skill_id UUID NOT NULL,
    proficiency_level skill_level NOT NULL DEFAULT 'beginner',
    years_of_experience INTEGER DEFAULT 0,
    last_used DATE,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign keys
    CONSTRAINT fk_user_skills_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(user_id) 
        ON DELETE CASCADE,
    CONSTRAINT fk_user_skills_skill 
        FOREIGN KEY (skill_id) 
        REFERENCES skills(skill_id) 
        ON DELETE CASCADE,
    
    -- Constraints
    CONSTRAINT unq_user_skill UNIQUE (user_id, skill_id),
    CONSTRAINT chk_years_experience CHECK (years_of_experience >= 0)
);

-- Table: training_needs
-- Stores training requests and needs identified for users
CREATE TABLE training_needs (
    training_need_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    skill_id UUID NOT NULL,
    required_proficiency skill_level NOT NULL,
    reason TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    status training_status NOT NULL DEFAULT 'pending',
    requested_by UUID NOT NULL,
    approved_by UUID,
    approval_date TIMESTAMP WITH TIME ZONE,
    completion_deadline DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign keys
    CONSTRAINT fk_training_needs_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(user_id) 
        ON DELETE CASCADE,
    CONSTRAINT fk_training_needs_skill 
        FOREIGN KEY (skill_id) 
        REFERENCES skills(skill_id) 
        ON DELETE CASCADE,
    CONSTRAINT fk_training_needs_requested_by 
        FOREIGN KEY (requested_by) 
        REFERENCES users(user_id),
    CONSTRAINT fk_training_needs_approved_by 
        FOREIGN KEY (approved_by) 
        REFERENCES users(user_id),
    
    -- Constraints
    CONSTRAINT chk_completion_deadline CHECK (completion_deadline > CURRENT_DATE)
);

-- Table: courses
-- Master catalog of available training courses
CREATE TABLE courses (
    course_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_code VARCHAR(20) UNIQUE NOT NULL,
    course_name VARCHAR(200) NOT NULL,
    description TEXT,
    duration_hours INTEGER NOT NULL,
    provider VARCHAR(100) NOT NULL,
    cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    skill_id UUID NOT NULL,
    target_proficiency skill_level NOT NULL,
    is_online BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key
    CONSTRAINT fk_courses_skill 
        FOREIGN KEY (skill_id) 
        REFERENCES skills(skill_id) 
        ON DELETE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_duration_hours CHECK (duration_hours > 0),
    CONSTRAINT chk_cost CHECK (cost >= 0)
);

-- Table: user_training
-- Tracks user enrollment and progress in courses
CREATE TABLE user_training (
    user_training_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    course_id UUID NOT NULL,
    training_need_id UUID,
    enrollment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    start_date DATE,
    completion_date DATE,
    status training_status NOT NULL DEFAULT 'pending',
    grade DECIMAL(5,2),
    certificate_url VARCHAR(500),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign keys
    CONSTRAINT fk_user_training_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(user_id) 
        ON DELETE CASCADE,
    CONSTRAINT fk_user_training_course 
        FOREIGN KEY (course_id) 
        REFERENCES courses(course_id) 
        ON DELETE CASCADE,
    CONSTRAINT fk_user_training_need 
        FOREIGN KEY (training_need_id) 
        REFERENCES training_needs(training_need_id),
    
    -- Constraints
    CONSTRAINT chk_grade CHECK (grade IS NULL OR (grade >= 0 AND grade <= 100)),
    CONSTRAINT chk_dates CHECK (
        (start_date IS NULL AND completion_date IS NULL) OR
        (start_date IS NOT NULL AND completion_date IS NULL) OR
        (start_date IS NOT NULL AND completion_date IS NOT NULL AND completion_date >= start_date)
    )
);

-- Indexes for performance optimization
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_department ON users(department);

CREATE INDEX idx_skills_category ON skills(category);
CREATE INDEX idx_skills_name ON skills(skill_name);

CREATE INDEX idx_user_skills_user ON user_skills(user_id);
CREATE INDEX idx_user_skills_skill ON user_skills(skill_id);
CREATE INDEX idx_user_skills_proficiency ON user_skills(proficiency_level);

CREATE INDEX idx_training_needs_user ON training_needs(user_id);
CREATE INDEX idx_training_needs_status ON training_needs(status);
CREATE INDEX idx_training_needs_priority ON training_needs(priority);
CREATE INDEX idx_training_needs_skill ON training_needs(skill_id);

CREATE INDEX idx_courses_skill ON courses(skill_id);
CREATE INDEX idx_courses_provider ON courses(provider);
CREATE INDEX idx_courses_proficiency ON courses(target_proficiency);

CREATE INDEX idx_user_training_user ON user_training(user_id);
CREATE INDEX idx_user_training_course ON user_training(course_id);
CREATE INDEX idx_user_training_status ON user_training(status);
CREATE INDEX idx_user_training_dates ON user_training(start_date, completion_date);

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for automatic updated_at maintenance
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_skills_updated_at 
    BEFORE UPDATE ON skills 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_skills_updated_at 
    BEFORE UPDATE ON user_skills 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_training_needs_updated_at 
    BEFORE UPDATE ON training_needs 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_courses_updated_at 
    BEFORE UPDATE ON courses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_training_updated_at 
    BEFORE UPDATE ON user_training 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data for testing
-- Sample users
INSERT INTO users (username, email, password_hash, first_name, last_name, role, department, position) VALUES
('admin_user', 'admin@company.com', '$2b$10$examplehash1234567890abcdefgh', 'Admin', 'User', 'admin', 'IT', 'System Administrator'),
('manager_john', 'john.manager@company.com', '$2b$10$examplehash1234567890abcdefgh', 'John', 'Manager', 'manager', 'HR', 'HR Manager'),
('employee_sarah', 'sarah.employee@company.com', '$2b$10$examplehash1234567890abcdefgh', 'Sarah', 'Employee', 'employee', 'Marketing', 'Marketing Specialist'),
('trainer_mike', 'mike.trainer@company.com', '$2b$10$examplehash1234567890abcdefgh', 'Mike', 'Trainer', 'trainer', 'Training', 'Senior Trainer');

-- Sample skills
INSERT INTO skills (skill_name, skill_description, category) VALUES
('Python Programming', 'Programming using Python language', 'Technical'),
('Project Management', 'Managing projects using various methodologies', 'Management'),
('Data Analysis', 'Analyzing data using statistical methods', 'Analytical'),
('Public Speaking', 'Effective communication and presentation skills', 'Soft Skills'),
('SQL Database', 'Database management using SQL', 'Technical');

-- Sample user skills
INSERT INTO user_skills (user_id, skill_id, proficiency_level, years_of_experience, is_current)
SELECT u.user_id, s.skill_id, 'intermediate', 2, TRUE
FROM users u, skills s 
WHERE u.username = 'employee_sarah' AND s.skill_name = 'Python Programming';

INSERT INTO user_skills (user_id, skill_id, proficiency_level, years_of_experience, is_current)
SELECT u.user_id, s.skill_id, 'beginner', 1, TRUE
FROM users u, skills s 
WHERE u.username = 'employee_sarah' AND s.skill_name = 'Data Analysis';

-- Sample training needs
INSERT INTO training_needs (user_id, skill_id, required_proficiency, reason, priority, requested_by)
SELECT u.user_id, s.skill_id, 'advanced', 'Required for upcoming AI project', 1, m.user_id
FROM users u, skills s, users m
WHERE u.username = 'employee_sarah' 
AND s.skill_name = 'Python Programming'
AND m.username = 'manager_john';

-- Sample courses
INSERT INTO courses (course_code, course_name, description, duration_hours, provider, cost, skill_id, target_proficiency)
SELECT 'PYT-101', 'Advanced Python Programming', 'Comprehensive advanced Python course', 40, 'Tech Training Inc', 499.99, s.skill_id, 'advanced'
FROM skills s WHERE s.skill_name = 'Python Programming';

INSERT INTO courses (course_code, course_name, description, duration_hours, provider, cost, skill_id, target_proficiency)
SELECT 'SQL-201', 'SQL Mastery', 'Advanced database management course', 30, 'Data Experts', 399.99, s.skill_id, 'advanced'
FROM skills s WHERE s.skill_name = 'SQL Database';

-- Sample user training
INSERT INTO user_training (user_id, course_id, training_need_id, status, start_date)
SELECT u.user_id, c.course_id, tn.training_need_id, 'approved',