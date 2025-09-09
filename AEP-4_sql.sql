-- AEP-4: Basic User Profile API SQL Implementation
-- This file contains the SQL functions and procedures for retrieving user profile data

CREATE OR REPLACE FUNCTION get_user_profile(p_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    role VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Log the function call
    RAISE NOTICE 'AEP-4: Retrieving profile for user_id: %', p_user_id;
    
    -- Validate input parameter
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'AEP-4: User ID cannot be null' USING ERRCODE = 'null_value_not_allowed';
    END IF;
    
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'AEP-4: User not found with ID: %', p_user_id USING ERRCODE = 'no_data_found';
    END IF;
    
    -- Return user profile data
    RETURN QUERY
    SELECT 
        u.user_id,
        u.first_name,
        u.last_name,
        u.email,
        u.role,
        u.created_at,
        u.updated_at
    FROM users u
    WHERE u.user_id = p_user_id
    AND u.is_active = true;
    
EXCEPTION
    WHEN no_data_found THEN
        RAISE NOTICE 'AEP-4: No active user found with ID: %', p_user_id;
        RAISE;
    WHEN others THEN
        RAISE NOTICE 'AEP-4: Unexpected error retrieving profile for user_id: % - Error: %', p_user_id, SQLERRM;
        RAISE;
END;
$$;

-- Create index for better performance on user lookups
CREATE INDEX IF NOT EXISTS idx_users_active ON users(user_id) WHERE is_active = true;

-- Grant execute permissions to appropriate roles
GRANT EXECUTE ON FUNCTION get_user_profile(UUID) TO api_user;

-- Create a view for easy access to user profile data (optional)
CREATE OR REPLACE VIEW user_profile_view AS
SELECT 
    user_id,
    first_name,
    last_name,
    email,
    role,
    created_at,
    updated_at
FROM users
WHERE is_active = true;

-- Comment explaining the function
COMMENT ON FUNCTION get_user_profile(UUID) IS 'AEP-4: Retrieves basic user profile information (name, email, role) for authenticated users. Returns user details from the database for the specified user ID.';