-- AEP-3: Role-Based Access Control (RBAC) Implementation
-- This SQL file creates the necessary database structure for RBAC
-- Includes tables for roles, permissions, and user-role assignments

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create roles table to store different user roles
CREATE TABLE IF NOT EXISTS aep_3_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create permissions table to define specific actions
CREATE TABLE IF NOT EXISTS aep_3_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create role_permissions junction table
CREATE TABLE IF NOT EXISTS aep_3_role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES aep_3_roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES aep_3_permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role_id, permission_id)
);

-- Create user_roles table to assign roles to users
CREATE TABLE IF NOT EXISTS aep_3_user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES aep_3_roles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(user_id, role_id)
);

-- Insert default roles
INSERT INTO aep_3_roles (name, description) VALUES
('employee', 'Standard employee with basic access rights'),
('manager', 'Manager with elevated access to team resources'),
('admin', 'System administrator with full access rights')
ON CONFLICT (name) DO NOTHING;

-- Insert common permissions
INSERT INTO aep_3_permissions (code, name, description) VALUES
('user:read', 'Read User', 'Permission to read user information'),
('user:write', 'Write User', 'Permission to create/update user information'),
('user:delete', 'Delete User', 'Permission to delete users'),
('team:read', 'Read Team', 'Permission to read team information'),
('team:write', 'Write Team', 'Permission to create/update teams'),
('team:delete', 'Delete Team', 'Permission to delete teams'),
('report:read', 'Read Reports', 'Permission to view reports'),
('report:write', 'Write Reports', 'Permission to create reports'),
('report:delete', 'Delete Reports', 'Permission to delete reports'),
('system:admin', 'System Administration', 'Full system administration access')
ON CONFLICT (code) DO NOTHING;

-- Assign permissions to employee role
INSERT INTO aep_3_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM aep_3_roles r, aep_3_permissions p
WHERE r.name = 'employee' 
AND p.code IN ('user:read', 'team:read', 'report:read')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign permissions to manager role
INSERT INTO aep_3_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM aep_3_roles r, aep_3_permissions p
WHERE r.name = 'manager' 
AND p.code IN ('user:read', 'user:write', 'team:read', 'team:write', 'report:read', 'report:write')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign permissions to admin role
INSERT INTO aep_3_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM aep_3_roles r, aep_3_permissions p
WHERE r.name = 'admin' 
AND p.code IN ('user:read', 'user:write', 'user:delete', 'team:read', 'team:write', 'team:delete', 'report:read', 'report:write', 'report:delete', 'system:admin')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_aep_3_roles_name ON aep_3_roles(name);
CREATE INDEX IF NOT EXISTS idx_aep_3_roles_active ON aep_3_roles(is_active);
CREATE INDEX IF NOT EXISTS idx_aep_3_permissions_code ON aep_3_permissions(code);
CREATE INDEX IF NOT EXISTS idx_aep_3_permissions_active ON aep_3_permissions(is_active);
CREATE INDEX IF NOT EXISTS idx_aep_3_role_permissions_role ON aep_3_role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_aep_3_role_permissions_perm ON aep_3_role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_aep_3_user_roles_user ON aep_3_user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_aep_3_user_roles_role ON aep_3_user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_aep_3_user_roles_active ON aep_3_user_roles(is_active);

-- Create function to check user permissions
CREATE OR REPLACE FUNCTION aep_3_check_user_permission(
    p_user_id UUID,
    p_permission_code VARCHAR
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM aep_3_user_roles ur
        JOIN aep_3_roles r ON ur.role_id = r.id
        JOIN aep_3_role_permissions rp ON r.id = rp.role_id
        JOIN aep_3_permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = p_user_id
        AND ur.is_active = TRUE
        AND r.is_active = TRUE
        AND p.is_active = TRUE
        AND p.code = p_permission_code
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get user roles
CREATE OR REPLACE FUNCTION aep_3_get_user_roles(p_user_id UUID)
RETURNS TABLE(role_name VARCHAR, role_description TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT r.name, r.description
    FROM aep_3_user_roles ur
    JOIN aep_3_roles r ON ur.role_id = r.id
    WHERE ur.user_id = p_user_id
    AND ur.is_active = TRUE
    AND r.is_active = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get user permissions
CREATE OR REPLACE FUNCTION aep_3_get_user_permissions(p_user_id UUID)
RETURNS TABLE(permission_code VARCHAR, permission_name VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT p.code, p.name
    FROM aep_3_user_roles ur
    JOIN aep_3_roles r ON ur.role_id = r.id
    JOIN aep_3_role_permissions rp ON r.id = rp.role_id
    JOIN aep_3_permissions p ON rp.permission_id = p.id
    WHERE ur.user_id = p_user_id
    AND ur.is_active = TRUE
    AND r.is_active = TRUE
    AND p.is_active = TRUE
    ORDER BY p.code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create audit table for permission checks
CREATE TABLE IF NOT EXISTS aep_3_permission_audit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    permission_code VARCHAR(100) NOT NULL,
    was_granted BOOLEAN NOT NULL,
    attempted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    endpoint VARCHAR(255),
    ip_address VARCHAR(45),
    user_agent TEXT
);

-- Create function to log permission checks
CREATE OR REPLACE FUNCTION aep_3_log_permission_check(
    p_user_id UUID,
    p_permission_code VARCHAR,
    p_was_granted BOOLEAN,
    p_endpoint VARCHAR DEFAULT NULL,
    p_ip_address VARCHAR DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO aep_3_permission_audit (
        user_id, permission_code, was_granted, endpoint, ip_address, user_agent
    ) VALUES (
        p_user_id, p_permission_code, p_was_granted, p_endpoint, p_ip_address, p_user_agent
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create view for user role summary
CREATE OR REPLACE VIEW aep_3_user_role_summary AS
SELECT 
    ur.user_id,
    r.name as role_name,
    r.description as role_description,
    ur.created_at as role_assigned_at,
    ur.is_active as role_active
FROM aep_3_user_roles ur
JOIN aep_3_roles r ON ur.role_id = r.id
WHERE ur.is_active = TRUE AND r.is_active = TRUE;

-- Create view for user permission summary
CREATE OR REPLACE VIEW aep_3_user_permission_summary AS
SELECT 
    ur.user_id,
    p.code as permission_code,
    p.name as permission_name,
    p.description as permission_description
FROM aep_3_user_roles ur
JOIN aep_3_roles r ON ur.role_id = r.id
JOIN aep_3_role_permissions rp ON r.id = rp.role_id
JOIN aep_3_permissions p ON rp.permission_id = p.id
WHERE ur.is_active = TRUE AND r.is_active = TRUE AND p.is_active = TRUE;

-- Add comments to tables and columns
COMMENT ON TABLE aep_3_roles IS 'Stores user roles for RBAC system (AEP-3)';
COMMENT ON TABLE aep_3_permissions IS 'Stores permission definitions for RBAC system (AEP-3)';
COMMENT ON TABLE aep_3_role_permissions IS 'Junction table linking roles to permissions (AEP-3)';
COMMENT ON TABLE aep_3_user_roles IS 'Assigns roles to users (AEP-3)';
COMMENT ON TABLE aep_3_permission_audit IS 'Audit log for permission checks (AEP-3)';

COMMENT ON COLUMN aep_3_roles.name IS 'Unique role identifier (employee, manager, admin)';
COMMENT ON COLUMN aep_3_permissions.code IS 'Unique permission code for API enforcement';
COMMENT ON COLUMN aep_3_user_roles.user_id IS 'Reference to main users table';

-- Create trigger to update updated_at timestamps
CREATE OR REPLACE FUNCTION aep_3_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_aep_3_roles_updated
    BEFORE UPDATE ON aep_3_roles
    FOR EACH ROW EXECUTE FUNCTION aep_3_update_updated_at();

CREATE TRIGGER trigger_aep_3_permissions_updated
    BEFORE UPDATE ON aep_3_permissions
    FOR EACH ROW EXECUTE FUNCTION aep_3_update_updated_at();

CREATE TRIGGER trigger_aep_3_user_roles_updated
    BEFORE UPDATE ON aep_3_user_roles
    FOR EACH ROW EXECUTE FUNCTION aep_3_update_updated_at();

-- Create audit logging tables for role and permission changes
CREATE TABLE IF NOT EXISTS aep_3_role_audit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES aep_3_roles(id),
    changed_by UUID NOT NULL REFERENCES users(id),
    change_type VARCHAR(10) NOT NULL CHECK (change_type IN ('CREATE', 'UPDATE', 'DELETE')),
    change_details JSONB,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS aep_3_permission_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    permission_id UUID NOT NULL REFERENCES aep_3_permissions(id),
    changed_by UUID NOT NULL REFERENCES users(id),
    change_type VARCHAR(10) NOT NULL CHECK (change_type IN ('CREATE', 'UPDATE', 'DELETE')),
    change_details JSONB,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS aep_3_user_role_audit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_role_id UUID NOT NULL REFERENCES aep_3_user_roles(id),
    changed_by UUID NOT NULL REFERENCES users(id),
    change_type VARCHAR(10) NOT NULL CHECK (change_type IN ('CREATE', 'UPDATE', 'DELETE')),
    change_details JSONB,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for audit tables
CREATE INDEX IF NOT EXISTS idx_aep_3_role_audit_role ON aep_3_role