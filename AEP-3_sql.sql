-- AEP-3: Role-Based Access Control (RBAC)

-- Define roles table in DB
CREATE TABLE roles (
    role_id INT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL
);

-- Insert roles data
INSERT INTO roles (role_id, role_name) VALUES (1, 'employee');
INSERT INTO roles (role_id, role_name) VALUES (2, 'manager');
INSERT INTO roles (role_id, role_name) VALUES (3, 'admin');

-- Add middleware for RBAC
CREATE FUNCTION check_role_access(role_id INT) RETURNS BOOLEAN AS $$
BEGIN
    IF role_id = 1 OR role_id = 2 OR role_id = 3 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Test endpoints with different roles
-- Example query to check role access
SELECT check_role_access(1); -- Should return TRUE for employee role

-- Error handling and logging can be added as needed

-- End of AEP-3 SQL code.