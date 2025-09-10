-- AEP-4: Basic User Profile API SQL Implementation

-- Create users table if it doesn't exist
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT valid_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT valid_role CHECK (role IN ('admin', 'user', 'moderator'))
);

-- Create index for faster email lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active) WHERE is_active = TRUE;

-- Function to get user profile by user ID
CREATE OR REPLACE FUNCTION get_user_profile(p_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    email VARCHAR,
    first_name VARCHAR,
    last_name VARCHAR,
    role VARCHAR,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Input validation
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID cannot be null' USING ERRCODE = 'null_value_not_allowed';
    END IF;

    -- Check if user exists and is active
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_user_id AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'User not found or inactive' USING ERRCODE = 'no_data_found';
    END IF;

    -- Return user profile data
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.first_name,
        u.last_name,
        u.role,
        u.is_active,
        u.created_at,
        u.updated_at
    FROM users u
    WHERE u.id = p_user_id AND u.is_active = TRUE;

EXCEPTION
    WHEN no_data_found THEN
        RAISE EXCEPTION 'User profile not found' USING ERRCODE = 'no_data_found';
    WHEN others THEN
        RAISE EXCEPTION 'Error retrieving user profile: %', SQLERRM USING ERRCODE = 'internal_error';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user profile by email
CREATE OR REPLACE FUNCTION get_user_profile_by_email(p_email VARCHAR)
RETURNS TABLE (
    user_id UUID,
    email VARCHAR,
    first_name VARCHAR,
    last_name VARCHAR,
    role VARCHAR,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Input validation
    IF p_email IS NULL OR p_email = '' THEN
        RAISE EXCEPTION 'Email cannot be null or empty' USING ERRCODE = 'null_value_not_allowed';
    END IF;

    -- Validate email format
    IF p_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- Check if user exists and is active
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE email = p_email AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'User not found or inactive' USING ERRCODE = 'no_data_found';
    END IF;

    -- Return user profile data
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.first_name,
        u.last_name,
        u.role,
        u.is_active,
        u.created_at,
        u.updated_at
    FROM users u
    WHERE u.email = p_email AND u.is_active = TRUE;

EXCEPTION
    WHEN no_data_found THEN
        RAISE EXCEPTION 'User profile not found' USING ERRCODE = 'no_data_found';
    WHEN others THEN
        RAISE EXCEPTION 'Error retrieving user profile: %', SQLERRM USING ERRCODE = 'internal_error';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user profile
CREATE OR REPLACE FUNCTION update_user_profile(
    p_user_id UUID,
    p_first_name VARCHAR DEFAULT NULL,
    p_last_name VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_update_count INTEGER;
BEGIN
    -- Input validation
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID cannot be null' USING ERRCODE = 'null_value_not_allowed';
    END IF;

    -- Check if user exists and is active
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_user_id AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'User not found or inactive' USING ERRCODE = 'no_data_found';
    END IF;

    -- Validate email format if provided
    IF p_email IS NOT NULL AND p_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- Check email uniqueness if provided
    IF p_email IS NOT NULL AND EXISTS (
        SELECT 1 FROM users 
        WHERE email = p_email AND id != p_user_id
    ) THEN
        RAISE EXCEPTION 'Email already exists' USING ERRCODE = 'unique_violation';
    END IF;

    -- Update user profile
    UPDATE users
    SET 
        first_name = COALESCE(p_first_name, first_name),
        last_name = COALESCE(p_last_name, last_name),
        email = COALESCE(p_email, email),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_user_id AND is_active = TRUE;

    GET DIAGNOSTICS v_update_count = ROW_COUNT;

    RETURN v_update_count > 0;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Email already exists' USING ERRCODE = 'unique_violation';
    WHEN no_data_found THEN
        RAISE EXCEPTION 'User not found' USING ERRCODE = 'no_data_found';
    WHEN others THEN
        RAISE EXCEPTION 'Error updating user profile: %', SQLERRM USING ERRCODE = 'internal_error';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create audit log table for profile operations
CREATE TABLE IF NOT EXISTS user_profile_audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('VIEW', 'UPDATE')),
    operation_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT,
    details JSONB
);

CREATE INDEX IF NOT EXISTS idx_profile_audit_user_id ON user_profile_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_audit_timestamp ON user_profile_audit_log(operation_timestamp);

-- Function to log profile operations
CREATE OR REPLACE FUNCTION log_profile_operation(
    p_user_id UUID,
    p_operation_type VARCHAR,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_details JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO user_profile_audit_log (
        user_id,
        operation_type,
        ip_address,
        user_agent,
        details
    ) VALUES (
        p_user_id,
        p_operation_type,
        p_ip_address,
        p_user_agent,
        p_details
    );
EXCEPTION
    WHEN others THEN
        -- Log the error but don't fail the main operation
        NULL;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_user_profile(UUID) TO api_user;
GRANT EXECUTE ON FUNCTION get_user_profile_by_email(VARCHAR) TO api_user;
GRANT EXECUTE ON FUNCTION update_user_profile(UUID, VARCHAR, VARCHAR, VARCHAR) TO api_user;
GRANT EXECUTE ON FUNCTION log_profile_operation(UUID, VARCHAR, INET, TEXT, JSONB) TO api_user;

GRANT SELECT ON users TO api_user;
GRANT INSERT ON user_profile_audit_log TO api_user;