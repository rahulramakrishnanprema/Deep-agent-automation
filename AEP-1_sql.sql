-- AEP-1: Setup Database Schema

-- Create users table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    role_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create roles table
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL
);

-- Create training_needs table
CREATE TABLE training_needs (
    need_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    skill_needed VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create courses table
CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL,
    instructor VARCHAR(50) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL
);

-- Insert sample data into roles table
INSERT INTO roles (role_name) VALUES ('Admin'), ('User'), ('Trainer');

-- Insert sample data into users table
INSERT INTO users (username, email, role_id) VALUES ('john_doe', 'john.doe@example.com', 1), ('jane_smith', 'jane.smith@example.com', 2);

-- Insert sample data into training_needs table
INSERT INTO training_needs (user_id, skill_needed) VALUES (1, 'Database Design'), (2, 'Web Development');

-- Insert sample data into courses table
INSERT INTO courses (course_name, instructor, start_date, end_date) VALUES ('SQL Fundamentals', 'Alice Johnson', '2022-01-15', '2022-02-15'), ('Web Development Basics', 'Bob Smith', '2022-03-01', '2022-04-01');