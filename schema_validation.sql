-- schema_validation.sql
-- Validation script for training database schema
-- Validates table structure, constraints, and test data integrity

DO $$
DECLARE
    v_table_count INTEGER;
    v_column_count INTEGER;
    v_record_count INTEGER;
    v_constraint_count INTEGER;
    v_validation_passed BOOLEAN := TRUE;
    v_error_message TEXT;
BEGIN
    RAISE NOTICE 'Starting database schema validation...';

    -- Validate table existence
    RAISE NOTICE '1. Checking required tables exist...';
    
    -- Check users table
    SELECT COUNT(*) INTO v_table_count 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'users';
    
    IF v_table_count = 0 THEN
        RAISE EXCEPTION 'FAIL: users table does not exist';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ users table exists';
    END IF;

    -- Check roles table
    SELECT COUNT(*) INTO v_table_count 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'roles';
    
    IF v_table_count = 0 THEN
        RAISE EXCEPTION 'FAIL: roles table does not exist';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ roles table exists';
    END IF;

    -- Check training_needs table
    SELECT COUNT(*) INTO v_table_count 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'training_needs';
    
    IF v_table_count = 0 THEN
        RAISE EXCEPTION 'FAIL: training_needs table does not exist';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ training_needs table exists';
    END IF;

    -- Check courses table
    SELECT COUNT(*) INTO v_table_count 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'courses';
    
    IF v_table_count = 0 THEN
        RAISE EXCEPTION 'FAIL: courses table does not exist';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ courses table exists';
    END IF;

    -- Validate table structure
    RAISE NOTICE '2. Checking table column structure...';

    -- Validate users table columns
    SELECT COUNT(*) INTO v_column_count 
    FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'users';
    
    IF v_column_count < 6 THEN
        RAISE EXCEPTION 'FAIL: users table missing required columns';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ users table has correct column structure';
    END IF;

    -- Validate roles table columns
    SELECT COUNT(*) INTO v_column_count 
    FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'roles';
    
    IF v_column_count < 2 THEN
        RAISE EXCEPTION 'FAIL: roles table missing required columns';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ roles table has correct column structure';
    END IF;

    -- Validate foreign key constraints
    RAISE NOTICE '3. Checking foreign key constraints...';

    -- Check users.role_id foreign key
    SELECT COUNT(*) INTO v_constraint_count 
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
        ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'users' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'role_id';
    
    IF v_constraint_count = 0 THEN
        RAISE EXCEPTION 'FAIL: Missing foreign key constraint on users.role_id';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ users.role_id foreign key constraint exists';
    END IF;

    -- Check training_needs.user_id foreign key
    SELECT COUNT(*) INTO v_constraint_count 
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
        ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_schema = 'public' 
        AND tc.table_name = 'training_needs' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'user_id';
    
    IF v_constraint_count = 0 THEN
        RAISE EXCEPTION 'FAIL: Missing foreign key constraint on training_needs.user_id';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ training_needs.user_id foreign key constraint exists';
    END IF;

    -- Validate test data existence
    RAISE NOTICE '4. Checking test data integrity...';

    -- Check roles table has data
    SELECT COUNT(*) INTO v_record_count FROM roles;
    IF v_record_count = 0 THEN
        RAISE EXCEPTION 'FAIL: No test data found in roles table';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ roles table contains % records', v_record_count;
    END IF;

    -- Check users table has data
    SELECT COUNT(*) INTO v_record_count FROM users;
    IF v_record_count = 0 THEN
        RAISE EXCEPTION 'FAIL: No test data found in users table';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ users table contains % records', v_record_count;
    END IF;

    -- Check courses table has data
    SELECT COUNT(*) INTO v_record_count FROM courses;
    IF v_record_count = 0 THEN
        RAISE EXCEPTION 'FAIL: No test data found in courses table';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ courses table contains % records', v_record_count;
    END IF;

    -- Check training_needs table has data
    SELECT COUNT(*) INTO v_record_count FROM training_needs;
    IF v_record_count = 0 THEN
        RAISE EXCEPTION 'FAIL: No test data found in training_needs table';
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ training_needs table contains % records', v_record_count;
    END IF;

    -- Validate data relationships
    RAISE NOTICE '5. Checking data relationships...';

    -- Check if users have valid role references
    SELECT COUNT(*) INTO v_record_count 
    FROM users u
    LEFT JOIN roles r ON u.role_id = r.id
    WHERE r.id IS NULL;
    
    IF v_record_count > 0 THEN
        RAISE EXCEPTION 'FAIL: Found % users with invalid role references', v_record_count;
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ All users have valid role references';
    END IF;

    -- Check if training_needs have valid user references
    SELECT COUNT(*) INTO v_record_count 
    FROM training_needs tn
    LEFT JOIN users u ON tn.user_id = u.id
    WHERE u.id IS NULL;
    
    IF v_record_count > 0 THEN
        RAISE EXCEPTION 'FAIL: Found % training_needs with invalid user references', v_record_count;
        v_validation_passed := FALSE;
    ELSE
        RAISE NOTICE '✓ All training_needs have valid user references';
    END IF;

    -- Final validation result
    IF v_validation_passed THEN
        RAISE NOTICE '========================================';
        RAISE NOTICE '✅ SCHEMA VALIDATION PASSED';
        RAISE NOTICE '========================================';
        RAISE NOTICE 'All tables, constraints, and test data are properly configured.';
        RAISE NOTICE 'Database schema is ready for production use.';
    ELSE
        RAISE NOTICE '========================================';
        RAISE NOTICE '❌ SCHEMA VALIDATION FAILED';
        RAISE NOTICE '========================================';
        RAISE NOTICE 'Please check the error messages above and fix the issues.';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SQLERRM;
        RAISE NOTICE '========================================';
        RAISE NOTICE '❌ VALIDATION ERROR: %', v_error_message;
        RAISE NOTICE '========================================';
        RAISE NOTICE 'Schema validation failed due to the above error.';
        RAISE NOTICE 'Please check the database schema and migration scripts.';
END $$;