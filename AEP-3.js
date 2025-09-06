const { AEP3Role } = require('../models/AEP3Role');
const { AEP3User } = require('../models/AEP3User');
const logger = require('../utils/logger');

/**
 * AEP-3 Role-Based Access Control Middleware
 * 
 * This middleware enforces role-based permissions for API endpoints
 * based on user roles stored in the database.
 * 
 * @module AEP3RBAC
 */

class AEP3RBACError extends Error {
    constructor(message, code = 'AEP3_RBAC_ERROR') {
        super(message);
        this.name = 'AEP3RBACError';
        this.code = code;
        this.statusCode = 403;
    }
}

/**
 * RBAC Middleware for enforcing role-based access control
 * @param {Array} allowedRoles - Array of role names that are allowed to access the route
 * @returns {Function} Express middleware function
 */
const AEP3RBACMiddleware = (allowedRoles = []) => {
    return async (req, res, next) => {
        try {
            // Check if user is authenticated
            if (!req.user || !req.user.id) {
                logger.warn('AEP-3 RBAC: Unauthenticated access attempt', {
                    path: req.path,
                    method: req.method
                });
                throw new AEP3RBACError('Authentication required', 'AEP3_UNAUTHENTICATED');
            }

            // Get user with populated roles
            const user = await AEP3User.findById(req.user.id)
                .populate('roles')
                .select('+roles')
                .lean();

            if (!user) {
                logger.warn('AEP-3 RBAC: User not found', {
                    userId: req.user.id,
                    path: req.path
                });
                throw new AEP3RBACError('User not found', 'AEP3_USER_NOT_FOUND');
            }

            // Check if user has any of the allowed roles
            const userRoleNames = user.roles.map(role => role.name);
            const hasPermission = allowedRoles.some(allowedRole => 
                userRoleNames.includes(allowedRole)
            );

            if (!hasPermission) {
                logger.warn('AEP-3 RBAC: Insufficient permissions', {
                    userId: req.user.id,
                    userRoles: userRoleNames,
                    requiredRoles: allowedRoles,
                    path: req.path,
                    method: req.method
                });
                
                throw new AEP3RBACError(
                    `Insufficient permissions. Required roles: ${allowedRoles.join(', ')}`,
                    'AEP3_INSUFFICIENT_PERMISSIONS'
                );
            }

            // Add user roles to request object for downstream use
            req.userRoles = userRoleNames;
            
            logger.debug('AEP-3 RBAC: Access granted', {
                userId: req.user.id,
                userRoles: userRoleNames,
                path: req.path
            });

            next();
        } catch (error) {
            if (error instanceof AEP3RBACError) {
                return res.status(error.statusCode).json({
                    error: {
                        code: error.code,
                        message: error.message,
                        timestamp: new Date().toISOString()
                    }
                });
            }

            logger.error('AEP-3 RBAC: Internal server error', {
                error: error.message,
                stack: error.stack,
                userId: req.user?.id,
                path: req.path
            });

            res.status(500).json({
                error: {
                    code: 'AEP3_INTERNAL_ERROR',
                    message: 'Internal server error in RBAC middleware',
                    timestamp: new Date().toISOString()
                }
            });
        }
    };
};

/**
 * Utility function to check if a user has specific roles
 * @param {Object} user - User object with roles array
 * @param {Array} requiredRoles - Array of required role names
 * @returns {Boolean} True if user has all required roles
 */
const AEP3HasRoles = (user, requiredRoles) => {
    if (!user || !user.roles || !Array.isArray(user.roles)) {
        return false;
    }

    const userRoleNames = user.roles.map(role => role.name);
    return requiredRoles.every(requiredRole => 
        userRoleNames.includes(requiredRole)
    );
};

/**
 * Utility function to check if a user has at least one of the required roles
 * @param {Object} user - User object with roles array
 * @param {Array} requiredRoles - Array of required role names
 * @returns {Boolean} True if user has at least one required role
 */
const AEP3HasAnyRole = (user, requiredRoles) => {
    if (!user || !user.roles || !Array.isArray(user.roles)) {
        return false;
    }

    const userRoleNames = user.roles.map(role => role.name);
    return requiredRoles.some(requiredRole => 
        userRoleNames.includes(requiredRole)
    );
};

/**
 * Predefined role constants for consistent usage
 */
const AEP3_ROLES = {
    EMPLOYEE: 'employee',
    MANAGER: 'manager',
    ADMIN: 'admin'
};

/**
 * Predefined role hierarchies for permission inheritance
 */
const AEP3_ROLE_HIERARCHY = {
    [AEP3_ROLES.ADMIN]: [AEP3_ROLES.MANAGER, AEP3_ROLES.EMPLOYEE],
    [AEP3_ROLES.MANAGER]: [AEP3_ROLES.EMPLOYEE],
    [AEP3_ROLES.EMPLOYEE]: []
};

/**
 * Check if a role has permission to access resources of another role
 * @param {String} userRole - The user's role name
 * @param {String} targetRole - The target role name to check access against
 * @returns {Boolean} True if user role can access target role resources
 */
const AEP3CanAccessRole = (userRole, targetRole) => {
    if (!AEP3_ROLE_HIERARCHY[userRole]) {
        return false;
    }

    // A role can always access its own level
    if (userRole === targetRole) {
        return true;
    }

    // Check if target role is in the hierarchy below user role
    return AEP3_ROLE_HIERARCHY[userRole].includes(targetRole);
};

/**
 * Middleware for checking if user can manage users of specific roles
 * @param {Array} manageableRoles - Array of role names that can be managed
 * @returns {Function} Express middleware function
 */
const AEP3RoleManagementMiddleware = (manageableRoles = []) => {
    return async (req, res, next) => {
        try {
            if (!req.user || !req.user.roles) {
                throw new AEP3RBACError('User roles not available', 'AEP3_ROLES_UNAVAILABLE');
            }

            const userRoles = req.user.roles;
            const targetRole = req.body.role || req.params.role;

            if (!targetRole) {
                throw new AEP3RBACError('Target role not specified', 'AEP3_TARGET_ROLE_MISSING');
            }

            // Check if user has any role that can manage the target role
            const canManage = userRoles.some(userRole => {
                const roleName = typeof userRole === 'object' ? userRole.name : userRole;
                return AEP3CanAccessRole(roleName, targetRole) && 
                       manageableRoles.includes(roleName);
            });

            if (!canManage) {
                logger.warn('AEP-3 Role Management: Insufficient management permissions', {
                    userId: req.user.id,
                    userRoles: userRoles.map(r => typeof r === 'object' ? r.name : r),
                    targetRole,
                    path: req.path
                });
                
                throw new AEP3RBACError(
                    `Cannot manage users with role: ${targetRole}`,
                    'AEP3_CANNOT_MANAGE_ROLE'
                );
            }

            next();
        } catch (error) {
            if (error instanceof AEP3RBACError) {
                return res.status(error.statusCode).json({
                    error: {
                        code: error.code,
                        message: error.message,
                        timestamp: new Date().toISOString()
                    }
                });
            }

            logger.error('AEP-3 Role Management: Internal error', {
                error: error.message,
                stack: error.stack
            });

            res.status(500).json({
                error: {
                    code: 'AEP3_ROLE_MANAGEMENT_ERROR',
                    message: 'Internal error in role management middleware',
                    timestamp: new Date().toISOString()
                }
            });
        }
    };
};

module.exports = {
    AEP3RBACMiddleware,
    AEP3HasRoles,
    AEP3HasAnyRole,
    AEP3_ROLES,
    AEP3RoleManagementMiddleware,
    AEP3CanAccessRole,
    AEP3RBACError
};