-- AEP-6: DevOps & Environment Setup - Database Provisioning Script
-- Creates staging database structure and initial setup

-- Enable error handling and logging
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Create database for staging environment
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'StagingDB_AEP6')
BEGIN
    CREATE DATABASE StagingDB_AEP6;
    PRINT 'Database StagingDB_AEP6 created successfully.';
END
ELSE
BEGIN
    PRINT 'Database StagingDB_AEP6 already exists.';
END
GO

USE StagingDB_AEP6;
GO

-- Create schema for better organization
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'app')
BEGIN
    EXEC('CREATE SCHEMA app');
    PRINT 'Schema app created successfully.';
END
GO

-- Create version tracking table
IF OBJECT_ID('app.DatabaseVersion', 'U') IS NULL
BEGIN
    CREATE TABLE app.DatabaseVersion (
        VersionId INT IDENTITY(1,1) PRIMARY KEY,
        VersionNumber VARCHAR(20) NOT NULL,
        Description NVARCHAR(500),
        AppliedBy NVARCHAR(128) NOT NULL DEFAULT SYSTEM_USER,
        AppliedOn DATETIME2 NOT NULL DEFAULT GETDATE(),
        ScriptName NVARCHAR(256) NOT NULL
    );
    PRINT 'Table app.DatabaseVersion created successfully.';
END
GO

-- Create application configuration table
IF OBJECT_ID('app.Configuration', 'U') IS NULL
BEGIN
    CREATE TABLE app.Configuration (
        ConfigId INT IDENTITY(1,1) PRIMARY KEY,
        ConfigKey NVARCHAR(100) NOT NULL UNIQUE,
        ConfigValue NVARCHAR(500) NOT NULL,
        Description NVARCHAR(500),
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedBy NVARCHAR(128) NOT NULL DEFAULT SYSTEM_USER,
        CreatedOn DATETIME2 NOT NULL DEFAULT GETDATE(),
        ModifiedBy NVARCHAR(128),
        ModifiedOn DATETIME2
    );
    PRINT 'Table app.Configuration created successfully.';
END
GO

-- Create environment tracking table
IF OBJECT_ID('app.Environment', 'U') IS NULL
BEGIN
    CREATE TABLE app.Environment (
        EnvironmentId INT IDENTITY(1,1) PRIMARY KEY,
        EnvironmentName NVARCHAR(50) NOT NULL UNIQUE,
        Description NVARCHAR(500),
        IsActive BIT NOT NULL DEFAULT 1,
        ConnectionString NVARCHAR(500),
        CreatedBy NVARCHAR(128) NOT NULL DEFAULT SYSTEM_USER,
        CreatedOn DATETIME2 NOT NULL DEFAULT GETDATE()
    );
    PRINT 'Table app.Environment created successfully.';
END
GO

-- Create user access tracking table
IF OBJECT_ID('app.UserAccess', 'U') IS NULL
BEGIN
    CREATE TABLE app.UserAccess (
        AccessId INT IDENTITY(1,1) PRIMARY KEY,
        UserName NVARCHAR(128) NOT NULL,
        EnvironmentId INT NOT NULL,
        AccessLevel NVARCHAR(50) NOT NULL DEFAULT 'Read',
        IsActive BIT NOT NULL DEFAULT 1,
        GrantedBy NVARCHAR(128) NOT NULL DEFAULT SYSTEM_USER,
        GrantedOn DATETIME2 NOT NULL DEFAULT GETDATE(),
        RevokedBy NVARCHAR(128),
        RevokedOn DATETIME2,
        CONSTRAINT FK_UserAccess_Environment FOREIGN KEY (EnvironmentId) REFERENCES app.Environment(EnvironmentId)
    );
    PRINT 'Table app.UserAccess created successfully.';
END
GO

-- Insert initial environment configuration
IF NOT EXISTS (SELECT 1 FROM app.Environment WHERE EnvironmentName = 'Staging')
BEGIN
    INSERT INTO app.Environment (EnvironmentName, Description, ConnectionString)
    VALUES ('Staging', 'Staging environment for testing and collaboration', 
            'Server=.;Database=StagingDB_AEP6;Integrated Security=true;');
    PRINT 'Staging environment configuration inserted.';
END
GO

-- Insert initial configuration values
IF NOT EXISTS (SELECT 1 FROM app.Configuration WHERE ConfigKey = 'DatabaseVersion')
BEGIN
    INSERT INTO app.Configuration (ConfigKey, ConfigValue, Description)
    VALUES ('DatabaseVersion', '1.0.0', 'Current database schema version');
END
GO

IF NOT EXISTS (SELECT 1 FROM app.Configuration WHERE ConfigKey = 'MaintenanceMode')
BEGIN
    INSERT INTO app.Configuration (ConfigKey, ConfigValue, Description)
    VALUES ('MaintenanceMode', 'false', 'Indicates if database is in maintenance mode');
END
GO

IF NOT EXISTS (SELECT 1 FROM app.Configuration WHERE ConfigKey = 'MaxConnections')
BEGIN
    INSERT INTO app.Configuration (ConfigKey, ConfigValue, Description)
    VALUES ('MaxConnections', '100', 'Maximum allowed concurrent connections');
END
GO

-- Record initial version
IF NOT EXISTS (SELECT 1 FROM app.DatabaseVersion WHERE VersionNumber = '1.0.0')
BEGIN
    INSERT INTO app.DatabaseVersion (VersionNumber, Description, ScriptName)
    VALUES ('1.0.0', 'Initial database setup for AEP-6 staging environment', 'AEP-6_sql.sql');
    PRINT 'Initial database version recorded.';
END
GO

-- Create indexes for better performance
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Environment_IsActive' AND object_id = OBJECT_ID('app.Environment'))
BEGIN
    CREATE INDEX IX_Environment_IsActive ON app.Environment(IsActive);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Configuration_ConfigKey' AND object_id = OBJECT_ID('app.Configuration'))
BEGIN
    CREATE INDEX IX_Configuration_ConfigKey ON app.Configuration(ConfigKey);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UserAccess_UserName' AND object_id = OBJECT_ID('app.UserAccess'))
BEGIN
    CREATE INDEX IX_UserAccess_UserName ON app.UserAccess(UserName);
END
GO

-- Create stored procedure for configuration management
IF OBJECT_ID('app.sp_GetConfiguration', 'P') IS NULL
BEGIN
    EXEC('
    CREATE PROCEDURE app.sp_GetConfiguration
        @ConfigKey NVARCHAR(100) = NULL
    AS
    BEGIN
        SET NOCOUNT ON;
        
        IF @ConfigKey IS NULL
            SELECT ConfigKey, ConfigValue, Description 
            FROM app.Configuration 
            WHERE IsActive = 1
            ORDER BY ConfigKey;
        ELSE
            SELECT ConfigKey, ConfigValue, Description 
            FROM app.Configuration 
            WHERE ConfigKey = @ConfigKey AND IsActive = 1;
    END');
    PRINT 'Stored procedure app.sp_GetConfiguration created successfully.';
END
GO

-- Create stored procedure for environment information
IF OBJECT_ID('app.sp_GetEnvironmentInfo', 'P') IS NULL
BEGIN
    EXEC('
    CREATE PROCEDURE app.sp_GetEnvironmentInfo
        @EnvironmentName NVARCHAR(50) = NULL
    AS
    BEGIN
        SET NOCOUNT ON;
        
        IF @EnvironmentName IS NULL
            SELECT EnvironmentId, EnvironmentName, Description, ConnectionString
            FROM app.Environment 
            WHERE IsActive = 1
            ORDER BY EnvironmentName;
        ELSE
            SELECT EnvironmentId, EnvironmentName, Description, ConnectionString
            FROM app.Environment 
            WHERE EnvironmentName = @EnvironmentName AND IsActive = 1;
    END');
    PRINT 'Stored procedure app.sp_GetEnvironmentInfo created successfully.';
END
GO

-- Create view for active configuration
IF OBJECT_ID('app.vw_ActiveConfiguration', 'V') IS NULL
BEGIN
    EXEC('
    CREATE VIEW app.vw_ActiveConfiguration AS
    SELECT ConfigKey, ConfigValue, Description, CreatedOn, ModifiedOn
    FROM app.Configuration
    WHERE IsActive = 1');
    PRINT 'View app.vw_ActiveConfiguration created successfully.';
END
GO

-- Create view for environment summary
IF OBJECT_ID('app.vw_EnvironmentSummary', 'V') IS NULL
BEGIN
    EXEC('
    CREATE VIEW app.vw_EnvironmentSummary AS
    SELECT e.EnvironmentName, e.Description, COUNT(ua.UserName) AS ActiveUsers
    FROM app.Environment e
    LEFT JOIN app.UserAccess ua ON e.EnvironmentId = ua.EnvironmentId AND ua.IsActive = 1
    WHERE e.IsActive = 1
    GROUP BY e.EnvironmentName, e.Description');
    PRINT 'View app.vw_EnvironmentSummary created successfully.';
END
GO

-- Verify database setup completion
PRINT 'AEP-6 Staging database setup completed successfully.';
PRINT 'Database: StagingDB_AEP6';
PRINT 'Schema version: 1.0.0';
PRINT 'Environment: Staging configuration ready for use';