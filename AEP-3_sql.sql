-- AEP-3: Role-Based Access Control (RBAC) SQL Implementation
-- This script creates the necessary database schema for RBAC functionality

-- Enable UUID extension for secure role identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table to store user roles
CREATE TABLE IF NOT EXISTS roles (
    role_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_name VARCHAR(50) NOT NULL UNIQUE,
    role_description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID
);

-- Table to store permissions
CREATE TABLE IF NOT EXISTS permissions (
    permission_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    permission_name VARCHAR(100) NOT NULL UNIQUE,
    permission_description TEXT,
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID,
    CONSTRAINT unique_resource_action UNIQUE (resource, action)
);

-- Junction table for role-permission relationships
CREATE TABLE IF NOT EXISTS role_permissions (
    role_permission_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL,
    permission_id UUID NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID,
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) 
        REFERENCES roles(role_id) ON DELETE CASCADE,
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) 
        REFERENCES permissions(permission_id) ON DELETE CASCADE,
    CONSTRAINT unique_role_permission UNIQUE (role_id, permission_id)
);

-- Table to store user-role relationships
CREATE TABLE IF NOT EXISTS user_roles (
    user_role_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    role_id UUID NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_by UUID,
    updated_by UUID,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) 
        REFERENCES roles(role_id) ON DELETE CASCADE,
    CONSTRAINT unique_user_role UNIQUE (user_id, role_id)
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_roles_name ON roles(role_name);
CREATE INDEX IF NOT EXISTS idx_roles_active ON roles(is_active);
CREATE INDEX IF NOT EXISTS idx_permissions_resource_action ON permissions(resource, action);
CREATE INDEX IF NOT EXISTS idx_permissions_active ON permissions(is_active);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission ON role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role_id);

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to automatically update updated_at
CREATE TRIGGER trigger_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_permissions_updated_at
    BEFORE UPDATE ON permissions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_role_permissions_updated_at
    BEFORE UPDATE ON role_permissions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_user_roles_updated_at
    BEFORE UPDATE ON user_roles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to check if a user has a specific permission
CREATE OR REPLACE FUNCTION check_user_permission(
    p_user_id UUID,
    p_resource VARCHAR,
    p_action VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE
    has_permission BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN role_permissions rp ON ur.role_id = rp.role_id
        JOIN permissions p ON rp.permission_id = p.permission_id
        WHERE ur.user_id = p_user_id
          AND ur.is_active = TRUE
          AND rp.is_active = TRUE
          AND p.is_active = TRUE
          AND p.resource = p_resource
          AND p.action = p_action
          AND (ur.expires_at IS NULL OR ur.expires_at > CURRENT_TIMESTAMP)
    ) INTO has_permission;
    
    RETURN has_permission;
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error checking permission for user %: %', p_user_id, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all permissions for a user
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id UUID)
RETURNS TABLE (
    permission_id UUID,
    permission_name VARCHAR,
    resource VARCHAR,
    action VARCHAR,
    permission_description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT 
        p.permission_id,
        p.permission_name,
        p.resource,
        p.action,
        p.permission_description
    FROM user_roles ur
    JOIN role_permissions rp ON ur.role_id = rp.role_id
    JOIN permissions p ON rp.permission_id = p.permission_id
    WHERE ur.user_id = p_user_id
      AND ur.is_active = TRUE
      AND rp.is_active = TRUE
      AND p.is_active = TRUE
      AND (ur.expires_at IS NULL OR ur.expires_at > CURRENT_TIMESTAMP)
    ORDER BY p.resource, p.action;
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error getting permissions for user %: %', p_user_id, SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all roles for a user
CREATE OR REPLACE FUNCTION get_user_roles(p_user_id UUID)
RETURNS TABLE (
    role_id UUID,
    role_name VARCHAR,
    role_description TEXT,
    assigned_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.role_id,
        r.role_name,
        r.role_description,
        ur.assigned_at,
        ur.expires_at
    FROM user_roles ur
    JOIN roles r ON ur.role_id = r.role_id
    WHERE ur.user_id = p_user_id
      AND ur.is_active = TRUE
      AND r.is_active = TRUE
      AND (ur.expires_at IS NULL OR ur.expires_at > CURRENT_TIMESTAMP)
    ORDER BY r.role_name;
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error getting roles for user %: %', p_user_id, SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert default roles
INSERT INTO roles (role_name, role_description) VALUES
    ('admin', 'System administrator with full access to all features and settings'),
    ('manager', 'Manager role with access to team management and reporting features'),
    ('employee', 'Basic employee role with access to standard user features')
ON CONFLICT (role_name) DO NOTHING;

-- Insert common permissions
INSERT INTO permissions (permission_name, permission_description, resource, action) VALUES
    -- User management permissions
    ('users:read', 'Read user information', 'users', 'read'),
    ('users:write', 'Create and update users', 'users', 'write'),
    ('users:delete', 'Delete users', 'users', 'delete'),
    
    -- Role management permissions
    ('roles:read', 'Read role information', 'roles', 'read'),
    ('roles:write', 'Create and update roles', 'roles', 'write'),
    ('roles:delete', 'Delete roles', 'roles', 'delete'),
    
    -- Permission management permissions
    ('permissions:read', 'Read permission information', 'permissions', 'read'),
    ('permissions:write', 'Create and update permissions', 'permissions', 'write'),
    ('permissions:delete', 'Delete permissions', 'permissions', 'delete'),
    
    -- Data access permissions
    ('data:read', 'Read application data', 'data', 'read'),
    ('data:write', 'Create and update application data', 'data', 'write'),
    ('data:delete', 'Delete application data', 'data', 'delete'),
    
    -- Reporting permissions
    ('reports:read', 'Access and view reports', 'reports', 'read'),
    ('reports:generate', 'Generate new reports', 'reports', 'generate'),
    
    -- System settings permissions
    ('settings:read', 'Read system settings', 'settings', 'read'),
    ('settings:write', 'Update system settings', 'settings', 'write')
ON CONFLICT (resource, action) DO NOTHING;

-- Assign permissions to admin role (all permissions)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
CROSS JOIN permissions p
WHERE r.role_name = 'admin'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign permissions to manager role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
CROSS JOIN permissions p
WHERE r.role_name = 'manager'
  AND p.permission_name IN (
    'users:read', 'data:read', 'data:write', 'reports:read', 'reports:generate'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign permissions to employee role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
CROSS JOIN permissions p
WHERE r.role_name = 'employee'
  AND p.permission_name IN (
    'data:read', 'data:write'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Audit table for role changes
CREATE TABLE IF NOT EXISTS role_audit_log (
    audit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    operation_type VARCHAR(10) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id UUID NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_by UUID,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT
);

-- Function to log role changes
CREATE OR REPLACE FUNCTION log_role_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_new_data = to_jsonb(NEW);
        INSERT INTO role_audit_log (operation_type, table_name, record_id, new_data, changed_by)
        VALUES ('INSERT', TG_TABLE_NAME, NEW.role_id, v_new_data, NEW.updated_by);
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_data = to_jsonb(OLD);
        v_new_data = to_jsonb(NEW);
        INSERT INTO role_audit_log (operation_type, table_name, record_id, old_data, new_data, changed_by)
        VALUES ('UPDATE', TG_TABLE_NAME, NEW.role_id, v_old_data, v_new_data, NEW.updated_by);
    ELSIF TG_OP = 'DELETE' THEN
        v_old_data = to_jsonb(OLD);
        INSERT INTO role_audit_log (operation_type, table_name, record_id, old_data, changed_by)
        VALUES ('DELETE', TG_TABLE_NAME, OLD.role_id, v_old_data, OLD.updated_by);
    END IF;
    
    RETURN COALESCE(NEW, OLD);
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error in role audit log: %', SQLERRM;
        RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Triggers for audit logging
CREATE TRIGGER trigger_roles_audit
    AFTER INSERT OR UPDATE OR DELETE ON roles
    FOR EACH ROW
    EXECUTE FUNCTION log_role_changes();

CREATE TRIGGER trigger_permissions_audit
    AFTER INSERT OR UPDATE OR DELETE ON permissions
    FOR EACH ROW
    EXECUTE FUNCTION log_role_changes();

CREATE TRIGGER trigger_role_permissions_audit
    AFTER INSERT OR UPDATE OR DELETE ON role_permissions
    FOR EACH ROW
    EXECUTE FUNCTION log_role_changes();

CREATE TRIGGER trigger_user_roles_audit
    AFTER INSERT OR UPDATE OR DELETE ON user_roles
    FOR EACH ROW
    EXECUTE FUNCTION log_role_changes();

-- Create views for easier querying
CREATE OR REPLACE VIEW user_permissions_view AS
SELECT 
    ur.user_id,
    r.role_id,
    r.role_name,
    p.permission_id,
    p.permission_name,
    p.resource,
    p.action,
    p.permission_description
FROM user_roles ur
JOIN roles r ON ur.role_id = r.role_id
JOIN role_permissions rp ON r.role_id = rp.role_id
JOIN permissions p ON rp.permission_id = p.permission_id
WHERE ur.is_active = TRUE
  AND r.is_active = TRUE
  AND rp.is_active = TRUE
  AND p.is_active = TRUE
  AND (ur.expires_at IS NULL OR ur.expires_at > CURRENT_TIMESTAMP);

-- Create view for active user roles
CREATE OR REPLACE VIEW active_user_roles_view AS
SELECT 
    ur.user_id,
    ur.role_id,
    r.role_name,
    r.role_description,
    ur.assigned_at,
    ur.expires_at,
    ur.created_by,
    ur.updated_by
FROM user_roles ur
JOIN roles r ON ur.role_id = r.role_id
WHERE ur.is_active = TRUE
  AND r.is_active = TRUE
  AND (ur.expires_at IS NULL OR ur.expires_at > CURRENT_TIMESTAMP);

-- Comments for documentation
COMMENT ON TABLE roles IS 'Stores user roles for RBAC system (AEP-3)';
COMMENT ON TABLE permissions IS 'Stores permissions that can be assigned to roles (AEP-3)';
COMMENT ON TABLE role_permissions IS 'Junction table linking roles to permissions (AEP-3)';
COMMENT ON TABLE user_roles IS 'Stores user-role assignments (AEP-3)';
COMMENT ON TABLE role_audit_log IS 'Audit log for RBAC changes (AEP-3)';

COMMENT ON FUNCTION check_user_permission IS 'Checks if a user has a specific permission (AEP-3)';
COMMENT ON FUNCTION get_user_permissions IS 'Returns all permissions for a user (AEP-3)';
COMMENT ON FUNCTION get_user_roles IS 'Returns all roles for a user (AEP-3)';

-- Grant necessary permissions (adjust based on your database user)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO application_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO application_user;