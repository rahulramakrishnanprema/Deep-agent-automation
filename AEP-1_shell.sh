#!/bin/bash

# AEP-1: Setup Database Schema
# Database schema setup for a training management system

set -euo pipefail
IFS=$'\n\t'

# Configuration
DB_URL="postgresql://admin:admin@localhost:5432/training_db"
LOG_FILE="aep-1_migration.log"
MIGRATION_DIR="migrations"
BACKUP_DIR="backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if PostgreSQL client is installed
check_psql_installed() {
    if ! command -v psql &> /dev/null; then
        log_error "PostgreSQL client (psql) is not installed. Please install it first."
        exit 1
    fi
}

# Check database connection
check_db_connection() {
    if ! psql "$DB_URL" -c "\q" 2>/dev/null; then
        log_error "Cannot connect to database. Please check if PostgreSQL is running and credentials are correct."
        exit 1
    fi
}

# Create backup directory
create_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/backup_${timestamp}.sql"
    
    mkdir -p "$BACKUP_DIR"
    if pg_dump "$DB_URL" > "$backup_file" 2>/dev/null; then
        log_info "Database backup created: $backup_file"
    else
        log_warn "Failed to create database backup. Continuing without backup."
    fi
}

# Create migration directory
setup_migration_dir() {
    mkdir -p "$MIGRATION_DIR"
}

# Execute SQL file with error handling
execute_sql_file() {
    local sql_file="$1"
    local description="$2"
    
    if [ ! -f "$sql_file" ]; then
        log_error "SQL file not found: $sql_file"
        return 1
    fi
    
    log_info "Executing $description..."
    if psql "$DB_URL" -f "$sql_file" 2>> "$LOG_FILE"; then
        log_info "$description completed successfully"
        return 0
    else
        log_error "$description failed. Check $LOG_FILE for details."
        return 1
    fi
}

# Main migration function
run_migration() {
    local migration_file="$MIGRATION_DIR/aep-1_schema_setup.sql"
    
    # Create migration SQL file
    cat > "$migration_file" << 'EOF'
-- AEP-1: Database Schema Migration
-- Created: $(date '+%Y-%m-%d %H:%M:%S')

-- Create roles table
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role_id INTEGER REFERENCES roles(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create courses table
CREATE TABLE IF NOT EXISTS courses (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    duration_hours INTEGER,
    level VARCHAR(50),
    instructor VARCHAR(100),
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create training_needs table
CREATE TABLE IF NOT EXISTS training_needs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    course_id INTEGER REFERENCES courses(id),
    status VARCHAR(50) DEFAULT 'REQUESTED',
    priority VARCHAR(50) DEFAULT 'MEDIUM',
    requested_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_date TIMESTAMP,
    completed_date TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, course_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_role_id ON users(role_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_training_needs_user_id ON training_needs(user_id);
CREATE INDEX IF NOT EXISTS idx_training_needs_course_id ON training_needs(course_id);
CREATE INDEX IF NOT EXISTS idx_training_needs_status ON training_needs(status);

-- Insert sample roles
INSERT INTO roles (name, description) VALUES
('admin', 'System administrator with full access'),
('manager', 'Team manager who can approve training requests'),
('employee', 'Regular employee who can request training')
ON CONFLICT (name) DO NOTHING;

-- Insert sample courses
INSERT INTO courses (title, description, category, duration_hours, level, instructor) VALUES
('Introduction to Python', 'Basic Python programming course', 'Programming', 8, 'Beginner', 'John Doe'),
('Advanced SQL', 'Advanced SQL techniques and optimization', 'Database', 12, 'Advanced', 'Jane Smith'),
('Project Management', 'Fundamentals of project management', 'Management', 16, 'Intermediate', 'Mike Johnson'),
('Data Analysis with R', 'Data analysis techniques using R', 'Data Science', 10, 'Intermediate', 'Sarah Wilson')
ON CONFLICT (title) DO NOTHING;

-- Insert sample users
INSERT INTO users (username, email, password_hash, first_name, last_name, role_id) VALUES
('admin_user', 'admin@company.com', 'hashed_password_123', 'Admin', 'User', 1),
('manager_john', 'john.manager@company.com', 'hashed_password_456', 'John', 'Manager', 2),
('employee_mary', 'mary.employee@company.com', 'hashed_password_789', 'Mary', 'Employee', 3)
ON CONFLICT (email) DO NOTHING;

-- Insert sample training needs
INSERT INTO training_needs (user_id, course_id, status, priority, notes) VALUES
(3, 1, 'REQUESTED', 'HIGH', 'Need Python skills for upcoming project'),
(3, 2, 'APPROVED', 'MEDIUM', 'Required for database tasks'),
(2, 3, 'COMPLETED', 'LOW', 'Completed last quarter')
ON CONFLICT (user_id, course_id) DO NOTHING;

-- Create update trigger function
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS update_users_modtime ON users;
CREATE TRIGGER update_users_modtime
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();

DROP TRIGGER IF EXISTS update_roles_modtime ON roles;
CREATE TRIGGER update_roles_modtime
    BEFORE UPDATE ON roles
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();

DROP TRIGGER IF EXISTS update_courses_modtime ON courses;
CREATE TRIGGER update_courses_modtime
    BEFORE UPDATE ON courses
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();

DROP TRIGGER IF EXISTS update_training_needs_modtime ON training_needs;
CREATE TRIGGER update_training_needs_modtime
    BEFORE UPDATE ON training_needs
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();
EOF

    # Execute the migration
    execute_sql_file "$migration_file" "Schema migration"
}

# Validate schema with test data
validate_schema() {
    log_info "Validating schema with test data..."
    
    local validation_file="$MIGRATION_DIR/aep-1_validation.sql"
    
    cat > "$validation_file" << 'EOF'
-- AEP-1: Schema Validation
-- Validate table counts and sample data

SELECT 'roles' as table_name, COUNT(*) as record_count FROM roles
UNION ALL
SELECT 'users', COUNT(*) FROM users
UNION ALL
SELECT 'courses', COUNT(*) FROM courses
UNION ALL
SELECT 'training_needs', COUNT(*) FROM training_needs;

-- Check sample data
SELECT u.username, r.name as role, c.title as course, tn.status 
FROM training_needs tn
JOIN users u ON tn.user_id = u.id
JOIN courses c ON tn.course_id = c.id
JOIN roles r ON u.role_id = r.id
ORDER BY u.username;
EOF

    if psql "$DB_URL" -f "$validation_file" 2>> "$LOG_FILE"; then
        log_info "Schema validation completed successfully"
    else
        log_error "Schema validation failed"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting AEP-1 database schema migration"
    
    # Check prerequisites
    check_psql_installed
    check_db_connection
    
    # Setup directories
    setup_migration_dir
    create_backup
    
    # Run migration
    if run_migration; then
        if validate_schema; then
            log_info "AEP-1 migration completed successfully!"
            echo -e "${GREEN}Database schema has been setup successfully.${NC}"
            echo "Check $LOG_FILE for detailed logs."
        else
            log_error "Migration completed but validation failed"
            exit 1
        fi
    else
        log_error "Migration failed"
        exit 1
    fi
}

# Handle script termination
cleanup() {
    log_info "Script execution completed"
}

trap cleanup EXIT

# Run main function
main "$@"