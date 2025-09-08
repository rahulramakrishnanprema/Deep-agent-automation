-- AEP-3: Role-Based Access Control (RBAC) SQL Implementation
-- Project: Web Application RBAC System
-- Description: Creates database schema for role-based access control with proper constraints and relationships

BEGIN TRANSACTION;

-- Create roles table to store different user roles
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create users table with role reference
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role_id INTEGER NOT NULL REFERENCES roles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_user_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT
);

-- Create permissions table to define specific access rights
CREATE TABLE IF NOT EXISTS permissions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_permission_resource_action UNIQUE (resource, action)
);

-- Create junction table for role-permission relationships
CREATE TABLE IF NOT EXISTS role_permissions (
    id SERIAL PRIMARY KEY,
    role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_role_permission UNIQUE (role_id, permission_id)
);

-- Create audit log table for tracking access attempts
CREATE TABLE IF NOT EXISTS access_audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    role_id INTEGER REFERENCES roles(id) ON DELETE SET NULL,
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    attempted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    success BOOLEAN NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    error_message TEXT
);

-- Insert default roles
INSERT INTO roles (name, description) VALUES 
('admin', 'System administrator with full access to all features and user management'),
('manager', 'Manager role with access to team management and reporting features'),
('employee', 'Basic employee role with limited access to specific features')
ON CONFLICT (name) DO NOTHING;

-- Insert common permissions
INSERT INTO permissions (name, description, resource, action) VALUES
-- User management permissions
('view_users', 'View user profiles and lists', 'users', 'read'),
('create_users', 'Create new user accounts', 'users', 'create'),
('update_users', 'Modify existing user accounts', 'users', 'update'),
('delete_users', 'Delete user accounts', 'users', 'delete'),

-- Role management permissions
('view_roles', 'View role definitions and assignments', 'roles', 'read'),
('assign_roles', 'Assign roles to users', 'roles', 'update'),

-- Content permissions
('view_content', 'View application content', 'content', 'read'),
('create_content', 'Create new content', 'content', 'create'),
('update_content', 'Modify existing content', 'content', 'update'),
('delete_content', 'Delete content', 'content', 'delete'),

-- Report permissions
('view_reports', 'Access reporting features', 'reports', 'read'),
('generate_reports', 'Generate new reports', 'reports', 'create')
ON CONFLICT (resource, action) DO NOTHING;

-- Assign permissions to admin role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'admin'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign permissions to manager role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'manager'
AND p.resource IN ('users', 'content', 'reports')
AND p.action IN ('read', 'create', 'update')
AND p.name != 'delete_users'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign permissions to employee role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'employee'
AND p.resource IN ('content')
AND p.action IN ('read', 'create')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_role_id ON users(role_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission_id ON role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_access_audit_log_user_id ON access_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_access_audit_log_role_id ON access_audit_log(role_id);
CREATE INDEX IF NOT EXISTS idx_access_audit_log_success ON access_audit_log(success);
CREATE INDEX IF NOT EXISTS idx_access_audit_log_attempted_at ON access_audit_log(attempted_at);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_permissions_updated_at
    BEFORE UPDATE ON permissions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create view for user permissions
CREATE OR REPLACE VIEW user_permissions AS
SELECT 
    u.id as user_id,
    u.username,
    u.email,
    r.id as role_id,
    r.name as role_name,
    p.id as permission_id,
    p.name as permission_name,
    p.resource,
    p.action
FROM users u
JOIN roles r ON u.role_id = r.id
JOIN role_permissions rp ON r.id = rp.role_id
JOIN permissions p ON rp.permission_id = p.id
WHERE u.is_active = TRUE AND r.is_active = TRUE;

-- Create function to check user permission
CREATE OR REPLACE FUNCTION check_user_permission(
    p_user_id INTEGER,
    p_resource VARCHAR,
    p_action VARCHAR
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM user_permissions
        WHERE user_id = p_user_id
        AND resource = p_resource
        AND action = p_action
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to log access attempts
CREATE OR REPLACE FUNCTION log_access_attempt(
    p_user_id INTEGER,
    p_role_id INTEGER,
    p_endpoint VARCHAR,
    p_method VARCHAR,
    p_success BOOLEAN,
    p_ip_address VARCHAR,
    p_user_agent TEXT,
    p_error_message TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO access_audit_log (
        user_id, role_id, endpoint, method, success, 
        ip_address, user_agent, error_message
    ) VALUES (
        p_user_id, p_role_id, p_endpoint, p_method, p_success,
        p_ip_address, p_user_agent, p_error_message
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get user role and permissions
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id INTEGER)
RETURNS TABLE (
    user_id INTEGER,
    username VARCHAR,
    role_id INTEGER,
    role_name VARCHAR,
    permission_id INTEGER,
    permission_name VARCHAR,
    resource VARCHAR,
    action VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.user_id,
        up.username,
        up.role_id,
        up.role_name,
        up.permission_id,
        up.permission_name,
        up.resource,
        up.action
    FROM user_permissions up
    WHERE up.user_id = p_user_id
    ORDER BY up.resource, up.action;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comments for documentation
COMMENT ON TABLE roles IS 'Stores user roles with their descriptions and active status';
COMMENT ON TABLE users IS 'Stores user accounts with role assignments and authentication details';
COMMENT ON TABLE permissions IS 'Defines specific access rights for different resources and actions';
COMMENT ON TABLE role_permissions IS 'Junction table linking roles to their assigned permissions';
COMMENT ON TABLE access_audit_log IS 'Audit trail for tracking access attempts and authorization results';

COMMENT ON COLUMN roles.name IS 'Unique role identifier name';
COMMENT ON COLUMN users.role_id IS 'Foreign key reference to roles table';
COMMENT ON COLUMN permissions.resource IS 'The resource/entity being accessed';
COMMENT ON COLUMN permissions.action IS 'The action being performed on the resource';

-- Create constraints for data integrity
ALTER TABLE users ADD CONSTRAINT chk_users_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
ALTER TABLE users ADD CONSTRAINT chk_users_username_length CHECK (LENGTH(username) BETWEEN 3 AND 100);
ALTER TABLE roles ADD CONSTRAINT chk_roles_name_length CHECK (LENGTH(name) BETWEEN 2 AND 50);
ALTER TABLE permissions ADD CONSTRAINT chk_permissions_name_length CHECK (LENGTH(name) BETWEEN 3 AND 100);

COMMIT TRANSACTION;