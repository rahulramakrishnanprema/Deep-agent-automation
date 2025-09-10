-- AEP-3: Role-Based Access Control (RBAC) SQL Implementation
-- This file creates the database schema for RBAC functionality

BEGIN TRANSACTION;

-- Create roles table to store predefined roles
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create permissions table to define individual permissions
CREATE TABLE IF NOT EXISTS permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create junction table for role-permission relationships
CREATE TABLE IF NOT EXISTS role_permissions (
    id SERIAL PRIMARY KEY,
    role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role_id, permission_id)
);

-- Create user_roles table to assign roles to users
CREATE TABLE IF NOT EXISTS user_roles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, role_id)
);

-- Insert predefined roles
INSERT INTO roles (name, description) VALUES
('employee', 'Standard user with basic access rights'),
('manager', 'User with elevated permissions for managing resources'),
('admin', 'System administrator with full access rights')
ON CONFLICT (name) DO UPDATE SET
description = EXCLUDED.description,
updated_at = CURRENT_TIMESTAMP;

-- Insert common permissions
INSERT INTO permissions (code, description) VALUES
('users:read', 'Read access to user data'),
('users:write', 'Write access to user data'),
('users:delete', 'Delete access to user data'),
('reports:read', 'Read access to reports'),
('reports:write', 'Write access to reports'),
('settings:read', 'Read access to system settings'),
('settings:write', 'Write access to system settings'),
('admin:full', 'Full administrative access')
ON CONFLICT (code) DO UPDATE SET
description = EXCLUDED.description,
updated_at = CURRENT_TIMESTAMP;

-- Assign permissions to employee role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.name = 'employee'
AND p.code IN ('users:read', 'reports:read')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign permissions to manager role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.name = 'manager'
AND p.code IN ('users:read', 'users:write', 'reports:read', 'reports:write', 'settings:read')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign permissions to admin role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.name = 'admin'
AND p.code IN ('users:read', 'users:write', 'users:delete', 'reports:read', 'reports:write', 'settings:read', 'settings:write', 'admin:full')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission_id ON role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_roles_name ON roles(name);
CREATE INDEX IF NOT EXISTS idx_permissions_code ON permissions(code);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for automatic updated_at updates
CREATE TRIGGER update_roles_updated_at 
    BEFORE UPDATE ON roles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_permissions_updated_at 
    BEFORE UPDATE ON permissions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_roles_updated_at 
    BEFORE UPDATE ON user_roles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create view for user permissions
CREATE OR REPLACE VIEW user_permissions AS
SELECT 
    u.id as user_id,
    r.name as role_name,
    p.code as permission_code,
    p.description as permission_description
FROM users u
JOIN user_roles ur ON u.id = ur.user_id
JOIN roles r ON ur.role_id = r.id
JOIN role_permissions rp ON r.id = rp.role_id
JOIN permissions p ON rp.permission_id = p.id;

-- Create function to check if user has permission
CREATE OR REPLACE FUNCTION has_permission(user_id INTEGER, permission_code VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM user_permissions 
        WHERE user_id = $1 AND permission_code = $2
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get user roles
CREATE OR REPLACE FUNCTION get_user_roles(user_id INTEGER)
RETURNS TABLE(role_name VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT r.name
    FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = $1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create audit table for permission changes
CREATE TABLE IF NOT EXISTS role_audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(10) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id INTEGER,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create function to log role changes
CREATE OR REPLACE FUNCTION log_role_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO role_audit_log (user_id, action, table_name, record_id, old_values)
        VALUES (NULL, 'DELETE', TG_TABLE_NAME, OLD.id, row_to_json(OLD));
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO role_audit_log (user_id, action, table_name, record_id, old_values, new_values)
        VALUES (NULL, 'UPDATE', TG_TABLE_NAME, NEW.id, row_to_json(OLD), row_to_json(NEW));
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO role_audit_log (user_id, action, table_name, record_id, new_values)
        VALUES (NULL, 'INSERT', TG_TABLE_NAME, NEW.id, row_to_json(NEW));
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for auditing
CREATE TRIGGER audit_roles_changes
    AFTER INSERT OR UPDATE OR DELETE ON roles
    FOR EACH ROW EXECUTE FUNCTION log_role_changes();

CREATE TRIGGER audit_user_roles_changes
    AFTER INSERT OR UPDATE OR DELETE ON user_roles
    FOR EACH ROW EXECUTE FUNCTION log_role_changes();

CREATE TRIGGER audit_role_permissions_changes
    AFTER INSERT OR UPDATE OR DELETE ON role_permissions
    FOR EACH ROW EXECUTE FUNCTION log_role_changes();

-- Add comments for documentation
COMMENT ON TABLE roles IS 'Stores system roles for RBAC implementation';
COMMENT ON TABLE permissions IS 'Stores individual permission codes for RBAC';
COMMENT ON TABLE role_permissions IS 'Junction table linking roles to their permissions';
COMMENT ON TABLE user_roles IS 'Assigns roles to specific users';
COMMENT ON VIEW user_permissions IS 'View showing all permissions for each user';
COMMENT ON FUNCTION has_permission IS 'Checks if a user has a specific permission';
COMMENT ON FUNCTION get_user_roles IS 'Returns all roles assigned to a user';

COMMIT TRANSACTION;