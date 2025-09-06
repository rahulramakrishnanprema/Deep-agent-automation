-- AEP-3: Role-Based Access Control (RBAC) Implementation
-- This script creates the database structure for role-based permissions

-- Create roles table to store different user roles
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create user_roles table to assign roles to users
CREATE TABLE IF NOT EXISTS user_roles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    CONSTRAINT unique_user_role UNIQUE (user_id, role_id)
);

-- Create permissions table to define specific permissions
CREATE TABLE IF NOT EXISTS permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create role_permissions table to assign permissions to roles
CREATE TABLE IF NOT EXISTS role_permissions (
    id SERIAL PRIMARY KEY,
    role_id INTEGER NOT NULL,
    permission_id INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE,
    CONSTRAINT unique_role_permission UNIQUE (role_id, permission_id)
);

-- Insert default roles
INSERT INTO roles (name, description) VALUES
    ('employee', 'Standard employee with basic access'),
    ('manager', 'Manager with elevated permissions'),
    ('admin', 'System administrator with full access')
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    updated_at = CURRENT_TIMESTAMP;

-- Insert common permissions
INSERT INTO permissions (code, name, description) VALUES
    ('users:read', 'Read Users', 'Permission to view user information'),
    ('users:write', 'Write Users', 'Permission to create and update users'),
    ('users:delete', 'Delete Users', 'Permission to delete users'),
    ('reports:read', 'Read Reports', 'Permission to view reports'),
    ('reports:write', 'Write Reports', 'Permission to create and update reports'),
    ('reports:delete', 'Delete Reports', 'Permission to delete reports'),
    ('settings:read', 'Read Settings', 'Permission to view system settings'),
    ('settings:write', 'Write Settings', 'Permission to modify system settings'),
    ('audit:read', 'Read Audit Logs', 'Permission to view audit logs')
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
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
AND p.code IN ('users:read', 'users:write', 'reports:read', 'reports:write')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign permissions to admin role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.name = 'admin'
AND p.code IN ('users:read', 'users:write', 'users:delete', 'reports:read', 'reports:write', 'reports:delete', 'settings:read', 'settings:write', 'audit:read')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission_id ON role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_roles_name ON roles(name);
CREATE INDEX IF NOT EXISTS idx_permissions_code ON permissions(code);

-- Create function to get user permissions
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id INTEGER)
RETURNS TABLE(permission_code VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT p.code
    FROM user_roles ur
    JOIN role_permissions rp ON ur.role_id = rp.role_id
    JOIN permissions p ON rp.permission_id = p.id
    WHERE ur.user_id = p_user_id
    AND ur.is_active = TRUE
    AND rp.is_active = TRUE
    AND p.is_active = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user has permission
CREATE OR REPLACE FUNCTION has_permission(p_user_id INTEGER, p_permission_code VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_has_permission BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN role_permissions rp ON ur.role_id = rp.role_id
        JOIN permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = p_user_id
        AND p.code = p_permission_code
        AND ur.is_active = TRUE
        AND rp.is_active = TRUE
        AND p.is_active = TRUE
    ) INTO v_has_permission;
    
    RETURN v_has_permission;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get user roles
CREATE OR REPLACE FUNCTION get_user_roles(p_user_id INTEGER)
RETURNS TABLE(role_name VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT r.name
    FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = p_user_id
    AND ur.is_active = TRUE
    AND r.is_active = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user has role
CREATE OR REPLACE FUNCTION has_role(p_user_id INTEGER, p_role_name VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_has_role BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN roles r ON ur.role_id = r.id
        WHERE ur.user_id = p_user_id
        AND r.name = p_role_name
        AND ur.is_active = TRUE
        AND r.is_active = TRUE
    ) INTO v_has_role;
    
    RETURN v_has_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create audit log table for RBAC events
CREATE TABLE IF NOT EXISTS rbac_audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(100),
    resource_id INTEGER,
    status VARCHAR(50) NOT NULL,
    error_message TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rbac_audit_log_user FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Create index for audit log queries
CREATE INDEX IF NOT EXISTS idx_rbac_audit_log_user_id ON rbac_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_rbac_audit_log_action ON rbac_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_rbac_audit_log_created_at ON rbac_audit_log(created_at);

-- Create function to log RBAC events
CREATE OR REPLACE FUNCTION log_rbac_event(
    p_user_id INTEGER,
    p_action VARCHAR,
    p_resource VARCHAR,
    p_resource_id INTEGER,
    p_status VARCHAR,
    p_error_message TEXT,
    p_ip_address VARCHAR,
    p_user_agent TEXT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO rbac_audit_log (
        user_id, action, resource, resource_id, status, error_message, ip_address, user_agent
    ) VALUES (
        p_user_id, p_action, p_resource, p_resource_id, p_status, p_error_message, p_ip_address, p_user_agent
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create view for user permissions summary
CREATE OR REPLACE VIEW user_permissions_summary AS
SELECT 
    u.id as user_id,
    u.email,
    array_agg(DISTINCT r.name) as roles,
    array_agg(DISTINCT p.code) as permissions
FROM users u
LEFT JOIN user_roles ur ON u.id = ur.user_id AND ur.is_active = TRUE
LEFT JOIN roles r ON ur.role_id = r.id AND r.is_active = TRUE
LEFT JOIN role_permissions rp ON r.id = rp.role_id AND rp.is_active = TRUE
LEFT JOIN permissions p ON rp.permission_id = p.id AND p.is_active = TRUE
GROUP BY u.id, u.email;

-- Add comments for documentation
COMMENT ON TABLE roles IS 'Stores different user roles for RBAC system (AEP-3)';
COMMENT ON TABLE user_roles IS 'Maps users to their assigned roles (AEP-3)';
COMMENT ON TABLE permissions IS 'Defines specific permissions that can be assigned to roles (AEP-3)';
COMMENT ON TABLE role_permissions IS 'Maps permissions to roles (AEP-3)';
COMMENT ON TABLE rbac_audit_log IS 'Audit log for RBAC-related events and access attempts (AEP-3)';
COMMENT ON FUNCTION get_user_permissions IS 'Returns all permissions for a given user (AEP-3)';
COMMENT ON FUNCTION has_permission IS 'Checks if a user has a specific permission (AEP-3)';
COMMENT ON FUNCTION get_user_roles IS 'Returns all roles for a given user (AEP-3)';
COMMENT ON FUNCTION has_role IS 'Checks if a user has a specific role (AEP-3)';
COMMENT ON FUNCTION log_rbac_event IS 'Logs RBAC events to audit table (AEP-3)';
COMMENT ON VIEW user_permissions_summary IS 'Summary view showing users with their roles and permissions (AEP-3)';