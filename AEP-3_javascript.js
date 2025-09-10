const express = require('express');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const winston = require('winston');

// AEP-3: Role-Based Access Control Implementation

// Configure logging
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.File({ filename: 'error.log', level: 'error' }),
        new winston.transports.File({ filename: 'combined.log' })
    ]
});

if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.simple()
    }));
}

// Database connection pool
const pool = new Pool({
    user: process.env.DB_USER || 'postgres',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'rbac_db',
    password: process.env.DB_PASSWORD || 'password',
    port: process.env.DB_PORT || 5432,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Role definitions
const ROLES = {
    EMPLOYEE: 'employee',
    MANAGER: 'manager',
    ADMIN: 'admin'
};

// Permission matrix
const PERMISSIONS = {
    [ROLES.EMPLOYEE]: [
        'read:own_profile',
        'update:own_profile',
        'read:own_tasks'
    ],
    [ROLES.MANAGER]: [
        'read:own_profile',
        'update:own_profile',
        'read:team_profiles',
        'create:tasks',
        'read:tasks',
        'update:tasks',
        'delete:tasks'
    ],
    [ROLES.ADMIN]: [
        'read:*',
        'update:*',
        'create:*',
        'delete:*',
        'manage:users',
        'manage:roles'
    ]
};

// Initialize database with roles
async function initializeRoles() {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        
        // Create roles table if not exists
        await client.query(`
            CREATE TABLE IF NOT EXISTS roles (
                id SERIAL PRIMARY KEY,
                name VARCHAR(50) UNIQUE NOT NULL,
                description TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        // Create user_roles junction table
        await client.query(`
            CREATE TABLE IF NOT EXISTS user_roles (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL,
                role_id INTEGER NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
                UNIQUE(user_id, role_id)
            )
        `);

        // Insert default roles if they don't exist
        for (const [roleKey, roleName] of Object.entries(ROLES)) {
            const result = await client.query(
                'SELECT id FROM roles WHERE name = $1',
                [roleName]
            );
            
            if (result.rows.length === 0) {
                await client.query(
                    'INSERT INTO roles (name, description) VALUES ($1, $2)',
                    [roleName, `${roleName} role`]
                );
                logger.info(`Created role: ${roleName}`);
            }
        }

        await client.query('COMMIT');
        logger.info('Database roles initialized successfully');
    } catch (error) {
        await client.query('ROLLBACK');
        logger.error('Failed to initialize roles:', error);
        throw error;
    } finally {
        client.release();
    }
}

// RBAC Middleware
function requireRole(allowedRoles) {
    return async (req, res, next) => {
        try {
            if (!Array.isArray(allowedRoles)) {
                allowedRoles = [allowedRoles];
            }

            const token = req.headers.authorization?.replace('Bearer ', '');
            if (!token) {
                logger.warn('Access attempt without token');
                return res.status(401).json({
                    error: 'Authentication required',
                    code: 'AUTH_REQUIRED'
                });
            }

            let decoded;
            try {
                decoded = jwt.verify(token, process.env.JWT_SECRET || 'fallback-secret');
            } catch (jwtError) {
                logger.warn('Invalid token provided');
                return res.status(401).json({
                    error: 'Invalid token',
                    code: 'INVALID_TOKEN'
                });
            }

            const userId = decoded.userId;
            if (!userId) {
                logger.warn('Token missing userId');
                return res.status(401).json({
                    error: 'Invalid token payload',
                    code: 'INVALID_TOKEN_PAYLOAD'
                });
            }

            const client = await pool.connect();
            try {
                const userRolesResult = await client.query(`
                    SELECT r.name 
                    FROM user_roles ur
                    JOIN roles r ON ur.role_id = r.id
                    WHERE ur.user_id = $1
                `, [userId]);

                const userRoles = userRolesResult.rows.map(row => row.name);
                
                if (userRoles.length === 0) {
                    logger.warn(`User ${userId} has no roles assigned`);
                    return res.status(403).json({
                        error: 'No roles assigned',
                        code: 'NO_ROLES'
                    });
                }

                const hasRequiredRole = userRoles.some(role => 
                    allowedRoles.includes(role) || role === ROLES.ADMIN
                );

                if (!hasRequiredRole) {
                    logger.warn(`User ${userId} with roles [${userRoles}] attempted to access ${req.method} ${req.path} requiring roles [${allowedRoles}]`);
                    return res.status(403).json({
                        error: 'Insufficient permissions',
                        code: 'INSUFFICIENT_PERMISSIONS',
                        requiredRoles: allowedRoles,
                        userRoles: userRoles
                    });
                }

                req.user = {
                    id: userId,
                    roles: userRoles
                };

                logger.info(`User ${userId} with roles [${userRoles}] authorized for ${req.method} ${req.path}`);
                next();
            } finally {
                client.release();
            }
        } catch (error) {
            logger.error('RBAC middleware error:', error);
            res.status(500).json({
                error: 'Internal server error',
                code: 'RBAC_ERROR'
            });
        }
    };
}

// Permission checker middleware
function requirePermission(requiredPermission) {
    return async (req, res, next) => {
        try {
            if (!req.user || !req.user.roles) {
                logger.warn('Permission check without user context');
                return res.status(401).json({
                    error: 'Authentication required',
                    code: 'AUTH_REQUIRED'
                });
            }

            const userPermissions = new Set();
            
            for (const role of req.user.roles) {
                if (PERMISSIONS[role]) {
                    PERMISSIONS[role].forEach(permission => userPermissions.add(permission));
                }
            }

            const hasPermission = userPermissions.has(requiredPermission) ||
                                userPermissions.has('*') ||
                                req.user.roles.includes(ROLES.ADMIN);

            if (!hasPermission) {
                logger.warn(`User ${req.user.id} missing permission ${requiredPermission} for ${req.method} ${req.path}`);
                return res.status(403).json({
                    error: 'Insufficient permissions',
                    code: 'INSUFFICIENT_PERMISSIONS',
                    requiredPermission: requiredPermission
                });
            }

            logger.info(`User ${req.user.id} authorized with permission ${requiredPermission} for ${req.method} ${req.path}`);
            next();
        } catch (error) {
            logger.error('Permission middleware error:', error);
            res.status(500).json({
                error: 'Internal server error',
                code: 'PERMISSION_ERROR'
            });
        }
    };
}

// Role management functions
async function assignRoleToUser(userId, roleName) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const roleResult = await client.query(
            'SELECT id FROM roles WHERE name = $1',
            [roleName]
        );

        if (roleResult.rows.length === 0) {
            throw new Error(`Role ${roleName} not found`);
        }

        const roleId = roleResult.rows[0].id;

        await client.query(
            'INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT (user_id, role_id) DO NOTHING',
            [userId, roleId]
        );

        await client.query('COMMIT');
        logger.info(`Assigned role ${roleName} to user ${userId}`);
        
        return { success: true, message: `Role ${roleName} assigned to user ${userId}` };
    } catch (error) {
        await client.query('ROLLBACK');
        logger.error(`Failed to assign role ${roleName} to user ${userId}:`, error);
        throw error;
    } finally {
        client.release();
    }
}

async function removeRoleFromUser(userId, roleName) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const roleResult = await client.query(
            'SELECT id FROM roles WHERE name = $1',
            [roleName]
        );

        if (roleResult.rows.length === 0) {
            throw new Error(`Role ${roleName} not found`);
        }

        const roleId = roleResult.rows[0].id;

        await client.query(
            'DELETE FROM user_roles WHERE user_id = $1 AND role_id = $2',
            [userId, roleId]
        );

        await client.query('COMMIT');
        logger.info(`Removed role ${roleName} from user ${userId}`);
        
        return { success: true, message: `Role ${roleName} removed from user ${userId}` };
    } catch (error) {
        await client.query('ROLLBACK');
        logger.error(`Failed to remove role ${roleName} from user ${userId}:`, error);
        throw error;
    } finally {
        client.release();
    }
}

async function getUserRoles(userId) {
    const client = await pool.connect();
    try {
        const result = await client.query(`
            SELECT r.name 
            FROM user_roles ur
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = $1
        `, [userId]);

        return result.rows.map(row => row.name);
    } catch (error) {
        logger.error(`Failed to get roles for user ${userId}:`, error);
        throw error;
    } finally {
        client.release();
    }
}

// Health check endpoint
function createHealthCheck() {
    return async (req, res) => {
        try {
            const client = await pool.connect();
            await client.query('SELECT 1');
            client.release();
            
            res.json({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                roles: Object.values(ROLES),
                db: 'connected'
            });
        } catch (error) {
            logger.error('Health check failed:', error);
            res.status(500).json({
                status: 'unhealthy',
                timestamp: new Date().toISOString(),
                error: 'Database connection failed'
            });
        }
    };
}

// Error handling middleware
function errorHandler(err, req, res, next) {
    logger.error('Unhandled error:', err);
    
    if (err.name === 'JsonWebTokenError') {
        return res.status(401).json({
            error: 'Invalid token',
            code: 'INVALID_TOKEN'
        });
    }

    if (err.name === 'TokenExpiredError') {
        return res.status(401).json({
            error: 'Token expired',
            code: 'TOKEN_EXPIRED'
        });
    }

    res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR'
    });
}

module.exports = {
    initializeRoles,
    requireRole,
    requirePermission,
    assignRoleToUser,
    removeRoleFromUser,
    getUserRoles,
    createHealthCheck,
    errorHandler,
    ROLES,
    PERMISSIONS,
    pool
};