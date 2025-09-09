-- AEP-1: Setup Database Schema for Training Management System
-- Database: PostgreSQL
-- Connection: postgresql://admin:admin@localhost:5432/training_db

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS user_courses CASCADE;
DROP TABLE IF EXISTS training_needs CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- Create roles table
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    role_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create users table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    role_id INTEGER NOT NULL REFERENCES roles(role_id),
    department VARCHAR(100),
    position VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Create courses table
CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    course_code VARCHAR(20) NOT NULL UNIQUE,
    course_name VARCHAR(200) NOT NULL,
    course_description TEXT,
    category VARCHAR(100),
    duration_hours INTEGER,
    difficulty_level VARCHAR(20) CHECK (difficulty_level IN ('Beginner', 'Intermediate', 'Advanced')),
    provider VARCHAR(100),
    cost DECIMAL(10,2) DEFAULT 0.00,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create training_needs table
CREATE TABLE training_needs (
    need_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    skill_required VARCHAR(100) NOT NULL,
    priority_level VARCHAR(20) CHECK (priority_level IN ('Low', 'Medium', 'High', 'Critical')),
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Completed')),
    required_by_date DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(user_id)
);

-- Create user_courses junction table
CREATE TABLE user_courses (
    user_course_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    course_id INTEGER NOT NULL REFERENCES courses(course_id),
    enrollment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completion_date TIMESTAMP,
    status VARCHAR(20) DEFAULT 'Enrolled' CHECK (status IN ('Enrolled', 'In Progress', 'Completed', 'Dropped')),
    progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage BETWEEN 0 AND 100),
    grade VARCHAR(5),
    certificate_issued BOOLEAN DEFAULT FALSE,
    notes TEXT,
    UNIQUE(user_id, course_id)
);

-- Create indexes for better performance
CREATE INDEX idx_users_role_id ON users(role_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_training_needs_user_id ON training_needs(user_id);
CREATE INDEX idx_training_needs_status ON training_needs(status);
CREATE INDEX idx_user_courses_user_id ON user_courses(user_id);
CREATE INDEX idx_user_courses_course_id ON user_courses(course_id);
CREATE INDEX idx_user_courses_status ON user_courses(status);
CREATE INDEX idx_courses_category ON courses(category);
CREATE INDEX idx_courses_difficulty ON courses(difficulty_level);

-- Insert sample roles
INSERT INTO roles (role_name, role_description) VALUES
('Administrator', 'System administrator with full access'),
('Manager', 'Department manager who can approve training requests'),
('Employee', 'Regular employee who can request training'),
('Trainer', 'Training instructor who delivers courses');

-- Insert sample users
INSERT INTO users (username, email, password_hash, first_name, last_name, role_id, department, position) VALUES
('admin', 'admin@company.com', '$2b$10$examplehash', 'System', 'Administrator', 1, 'IT', 'System Admin'),
('jdoe', 'jdoe@company.com', '$2b$10$examplehash', 'John', 'Doe', 2, 'Sales', 'Sales Manager'),
('jsmith', 'jsmith@company.com', '$2b$10$examplehash', 'Jane', 'Smith', 3, 'Marketing', 'Marketing Specialist'),
('trainer1', 'trainer@company.com', '$2b$10$examplehash', 'Mike', 'Trainer', 4, 'Training', 'Senior Trainer');

-- Insert sample courses
INSERT INTO courses (course_code, course_name, course_description, category, duration_hours, difficulty_level, provider, cost) VALUES
('DEV-101', 'Introduction to Programming', 'Basic programming concepts and fundamentals', 'Development', 40, 'Beginner', 'Internal', 0.00),
('MGMT-201', 'Leadership Skills', 'Developing leadership and management capabilities', 'Management', 24, 'Intermediate', 'External', 500.00),
('DATA-301', 'Advanced Data Analysis', 'Advanced techniques for data analysis and visualization', 'Data Science', 60, 'Advanced', 'Internal', 0.00),
('COMM-102', 'Effective Communication', 'Improving workplace communication skills', 'Soft Skills', 16, 'Beginner', 'External', 250.00);

-- Insert sample training needs
INSERT INTO training_needs (user_id, skill_required, priority_level, status, required_by_date, notes, created_by) VALUES
(3, 'Data Analysis', 'High', 'Approved', '2024-06-30', 'Required for upcoming project', 2),
(3, 'Public Speaking', 'Medium', 'Pending', '2024-12-31', 'Personal development goal', 3),
(2, 'Project Management', 'Critical', 'Approved', '2024-03-31', 'Required for new role', 1);

-- Insert sample user course enrollments
INSERT INTO user_courses (user_id, course_id, enrollment_date, completion_date, status, progress_percentage, grade, certificate_issued) VALUES
(3, 3, '2024-01-15', NULL, 'In Progress', 75, NULL, FALSE),
(2, 2, '2024-01-10', '2024-01-20', 'Completed', 100, 'A', TRUE),
(3, 1, '2023-12-01', '2023-12-20', 'Completed', 100, 'B+', TRUE);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for automatic updated_at maintenance
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON roles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_courses_updated_at BEFORE UPDATE ON courses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_training_needs_updated_at BEFORE UPDATE ON training_needs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create view for user training overview
CREATE VIEW user_training_overview AS
SELECT 
    u.user_id,
    u.username,
    u.first_name,
    u.last_name,
    u.department,
    r.role_name,
    COUNT(uc.user_course_id) AS total_courses,
    COUNT(uc.user_course_id) FILTER (WHERE uc.status = 'Completed') AS completed_courses,
    COUNT(tn.need_id) AS pending_training_needs
FROM users u
JOIN roles r ON u.role_id = r.role_id
LEFT JOIN user_courses uc ON u.user_id = uc.user_id
LEFT JOIN training_needs tn ON u.user_id = tn.user_id AND tn.status = 'Pending'
GROUP BY u.user_id, r.role_name;

-- Create view for course enrollment statistics
CREATE VIEW course_enrollment_stats AS
SELECT 
    c.course_id,
    c.course_code,
    c.course_name,
    c.category,
    c.difficulty_level,
    COUNT(uc.user_course_id) AS total_enrollments,
    COUNT(uc.user_course_id) FILTER (WHERE uc.status = 'Completed') AS completions,
    COUNT(uc.user_course_id) FILTER (WHERE uc.status IN ('Enrolled', 'In Progress')) AS active_enrollments,
    AVG(uc.progress_percentage)::DECIMAL(5,2) AS avg_progress
FROM courses c
LEFT JOIN user_courses uc ON c.course_id = uc.course_id
GROUP BY c.course_id, c.course_code, c.course_name, c.category, c.difficulty_level;

-- Add comments to tables for documentation
COMMENT ON TABLE roles IS 'Stores user roles and permissions';
COMMENT ON TABLE users IS 'Stores user information and authentication details';
COMMENT ON TABLE courses IS 'Stores available training courses and their details';
COMMENT ON TABLE training_needs IS 'Stores training requirements identified for users';
COMMENT ON TABLE user_courses IS 'Tracks user enrollments and progress in courses';

-- Log completion of schema setup
DO $$
BEGIN
    RAISE NOTICE 'AEP-1: Database schema setup completed successfully';
    RAISE NOTICE 'Created tables: roles, users, courses, training_needs, user_courses';
    RAISE NOTICE 'Inserted sample data for testing';
    RAISE NOTICE 'Created indexes and views for performance optimization';
END $$;