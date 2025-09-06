-- sample_data.sql
-- Inserts test data into the training_db database for validation and testing
-- This script should be run after the schema creation and migrations

-- Start transaction to ensure data integrity
BEGIN;

-- Insert sample data into roles table
INSERT INTO roles (name, description, created_at, updated_at) VALUES
('Administrator', 'System administrator with full access', NOW(), NOW()),
('Manager', 'Department manager who can approve training requests', NOW(), NOW()),
('Employee', 'Regular employee who can request training', NOW(), NOW()),
('Trainer', 'Training facilitator and instructor', NOW(), NOW())
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    updated_at = NOW();

-- Insert sample data into users table
INSERT INTO users (username, email, password_hash, first_name, last_name, role_id, department, created_at, updated_at) VALUES
('admin_user', 'admin@company.com', '$2b$10$examplehash1234567890abcdef', 'John', 'Admin', (SELECT id FROM roles WHERE name = 'Administrator'), 'IT', NOW(), NOW()),
('manager_jane', 'jane.manager@company.com', '$2b$10$examplehash1234567890abcdef', 'Jane', 'Smith', (SELECT id FROM roles WHERE name = 'Manager'), 'HR', NOW(), NOW()),
('employee_mike', 'mike.employee@company.com', '$2b$10$examplehash1234567890abcdef', 'Mike', 'Johnson', (SELECT id FROM roles WHERE name = 'Employee'), 'Sales', NOW(), NOW()),
('trainer_sarah', 'sarah.trainer@company.com', '$2b$10$examplehash1234567890abcdef', 'Sarah', 'Wilson', (SELECT id FROM roles WHERE name = 'Trainer'), 'Training', NOW(), NOW()),
('employee_lisa', 'lisa.employee@company.com', '$2b$10$examplehash1234567890abcdef', 'Lisa', 'Brown', (SELECT id FROM roles WHERE name = 'Employee'), 'Marketing', NOW(), NOW())
ON CONFLICT (username) DO UPDATE SET
    email = EXCLUDED.email,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    role_id = EXCLUDED.role_id,
    department = EXCLUDED.department,
    updated_at = NOW();

-- Insert sample data into skills table
INSERT INTO skills (name, description, category, created_at, updated_at) VALUES
('Python Programming', 'Proficiency in Python programming language', 'Technical', NOW(), NOW()),
('Project Management', 'Ability to manage projects effectively', 'Management', NOW(), NOW()),
('Data Analysis', 'Skills in analyzing and interpreting data', 'Analytical', NOW(), NOW()),
('Public Speaking', 'Ability to speak effectively in public settings', 'Communication', NOW(), NOW()),
('Team Leadership', 'Skills in leading and motivating teams', 'Leadership', NOW(), NOW())
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    updated_at = NOW();

-- Insert sample data into courses table
INSERT INTO courses (title, description, provider, duration_hours, level, category, created_at, updated_at) VALUES
('Python for Beginners', 'Introduction to Python programming', 'Internal Training', 16, 'Beginner', 'Technical', NOW(), NOW()),
('Advanced Project Management', 'Advanced techniques in project management', 'External Provider', 24, 'Advanced', 'Management', NOW(), NOW()),
('Data Analysis with Excel', 'Comprehensive data analysis using Excel', 'Internal Training', 12, 'Intermediate', 'Analytical', NOW(), NOW()),
('Effective Communication Skills', 'Improving communication in the workplace', 'Internal Training', 8, 'Beginner', 'Communication', NOW(), NOW()),
('Leadership Development Program', 'Developing leadership capabilities', 'External Provider', 40, 'Advanced', 'Leadership', NOW(), NOW())
ON CONFLICT (title) DO UPDATE SET
    description = EXCLUDED.description,
    provider = EXCLUDED.provider,
    duration_hours = EXCLUDED.duration_hours,
    level = EXCLUDED.level,
    category = EXCLUDED.category,
    updated_at = NOW();

-- Insert sample data into user_skills table (linking users to their skills)
INSERT INTO user_skills (user_id, skill_id, proficiency_level, years_experience, created_at, updated_at) VALUES
((SELECT id FROM users WHERE username = 'admin_user'), (SELECT id FROM skills WHERE name = 'Python Programming'), 'Advanced', 5, NOW(), NOW()),
((SELECT id FROM users WHERE username = 'manager_jane'), (SELECT id FROM skills WHERE name = 'Project Management'), 'Expert', 8, NOW(), NOW()),
((SELECT id FROM users WHERE username = 'employee_mike'), (SELECT id FROM skills WHERE name = 'Data Analysis'), 'Intermediate', 3, NOW(), NOW()),
((SELECT id FROM users WHERE username = 'trainer_sarah'), (SELECT id FROM skills WHERE name = 'Public Speaking'), 'Expert', 10, NOW(), NOW()),
((SELECT id FROM users WHERE username = 'employee_lisa'), (SELECT id FROM skills WHERE name = 'Team Leadership'), 'Beginner', 1, NOW(), NOW())
ON CONFLICT (user_id, skill_id) DO UPDATE SET
    proficiency_level = EXCLUDED.proficiency_level,
    years_experience = EXCLUDED.years_experience,
    updated_at = NOW();

-- Insert sample data into training_needs table
INSERT INTO training_needs (user_id, skill_id, priority, status, notes, created_by, created_at, updated_at) VALUES
((SELECT id FROM users WHERE username = 'employee_mike'), (SELECT id FROM skills WHERE name = 'Python Programming'), 'High', 'Pending', 'Need Python skills for data automation tasks', (SELECT id FROM users WHERE username = 'employee_mike'), NOW(), NOW()),
((SELECT id FROM users WHERE username = 'employee_lisa'), (SELECT id FROM skills WHERE name = 'Public Speaking'), 'Medium', 'Approved', 'Required for upcoming conference presentations', (SELECT id FROM users WHERE username = 'manager_jane'), NOW(), NOW()),
((SELECT id FROM users WHERE username = 'admin_user'), (SELECT id FROM skills WHERE name = 'Project Management'), 'Low', 'Completed', 'Completed PM training last quarter', (SELECT id FROM users WHERE username = 'admin_user'), NOW(), NOW()),
((SELECT id FROM users WHERE username = 'employee_mike'), (SELECT id FROM skills WHERE name = 'Team Leadership'), 'High', 'In Progress', 'Preparing for team lead role', (SELECT id FROM users WHERE username = 'manager_jane'), NOW(), NOW())
ON CONFLICT DO NOTHING;

-- Insert sample data into course_skills table (linking courses to skills they teach)
INSERT INTO course_skills (course_id, skill_id, created_at) VALUES
((SELECT id FROM courses WHERE title = 'Python for Beginners'), (SELECT id FROM skills WHERE name = 'Python Programming'), NOW()),
((SELECT id FROM courses WHERE title = 'Advanced Project Management'), (SELECT id FROM skills WHERE name = 'Project Management'), NOW()),
((SELECT id FROM courses WHERE title = 'Data Analysis with Excel'), (SELECT id FROM skills WHERE name = 'Data Analysis'), NOW()),
((SELECT id FROM courses WHERE title = 'Effective Communication Skills'), (SELECT id FROM skills WHERE name = 'Public Speaking'), NOW()),
((SELECT id FROM courses WHERE title = 'Leadership Development Program'), (SELECT id FROM skills WHERE name = 'Team Leadership'), NOW())
ON CONFLICT (course_id, skill_id) DO NOTHING;

-- Insert sample data into user_training table (training records)
INSERT INTO user_training (user_id, course_id, training_date, status, completion_date, trainer_id, created_at, updated_at) VALUES
((SELECT id FROM users WHERE username = 'admin_user'), (SELECT id FROM courses WHERE title = 'Advanced Project Management'), '2023-05-15', 'Completed', '2023-05-20', (SELECT id FROM users WHERE username = 'trainer_sarah'), NOW(), NOW()),
((SELECT id FROM users WHERE username = 'employee_lisa'), (SELECT id FROM courses WHERE title = 'Effective Communication Skills'), '2023-10-10', 'Scheduled', NULL, (SELECT id FROM users WHERE username = 'trainer_sarah'), NOW(), NOW()),
((SELECT id FROM users WHERE username = 'employee_mike'), (SELECT id FROM courses WHERE title = 'Python for Beginners'), '2023-08-01', 'In Progress', NULL, (SELECT id FROM users WHERE username = 'admin_user'), NOW(), NOW()),
((SELECT id FROM users WHERE username = 'manager_jane'), (SELECT id FROM courses WHERE title = 'Leadership Development Program'), '2023-11-05', 'Scheduled', NULL, NULL, NOW(), NOW())
ON CONFLICT DO NOTHING;

-- Commit the transaction to save all changes
COMMIT;

-- Display summary of inserted data
DO $$
DECLARE
    roles_count INTEGER;
    users_count INTEGER;
    skills_count INTEGER;
    courses_count INTEGER;
    training_needs_count INTEGER;
    user_training_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO roles_count FROM roles;
    SELECT COUNT(*) INTO users_count FROM users;
    SELECT COUNT(*) INTO skills