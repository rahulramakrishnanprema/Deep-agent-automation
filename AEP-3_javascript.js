/**
 * AEP-3: Role-Based Access Control (RBAC) Middleware
 * 
 * This module provides role-based access control middleware for Express.js routes.
 * It validates user roles against required permissions for API endpoints.
 */

const logger = require('../utils/logger');
const { User, Role } = require('../models'); // Assuming Sequelize models

/**
 * RBAC Middleware Factory
 * Creates middleware that checks if user has required role(s)
 * @param {string|Array<string>} allowedRoles - Single role or array of roles that can access the route
 * @returns {Function} Express middleware function
 */
const requireRole = (allowedRoles) => {
    return async (req, res, next) => {
        try {
            // Ensure user is authenticated first
            if (!req.user || !req.user.id) {
                logger.warn('RBAC: Unauthenticated access attempt', { path: req.path });
                return res.status(401).json({
                    success: false,
                    error: 'Authentication required'
                });
            }

            // Convert single role to array for consistent handling
            const requiredRoles = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];
            
            // Get user with role information (assuming eager loading or separate query)
            const userWithRole = await User.findByPk(req.user.id, {
                include: [{
                    model: Role,
                    as: 'role',
                    attributes: ['name', 'permissions']
                }]
            });

            if (!userWithRole || !userWithRole.role) {
                logger.error('RBAC: User role not found', { userId: req.user.id });
                return res.status(403).json({
                    success: false,
                    error: 'Access denied: No role assigned'
                });
            }

            const userRole = userWithRole.role.name;

            // Check if user's role is in the allowed roles list
            if (!requiredRoles.includes(userRole)) {
                logger.warn('RBAC: Insufficient permissions', {
                    userId: req.user.id,
                    userRole,
                    requiredRoles,
                    path: req.path
                });
                
                return res.status(403).json({
                    success: false,
                    error: 'Access denied: Insufficient permissions'
                });
            }

            // Add role information to request object for downstream use
            req.user.role = userRole;
            req.user.permissions = userWithRole.role.permissions;

            logger.debug('RBAC: Access granted', {
                userId: req.user.id,
                userRole,
                path: req.path
            });

            next();
        } catch (error) {
            logger.error('RBAC: Middleware error', {
                error: error.message,
                stack: error.stack,
                userId: req.user?.id
            });
            
            return res.status(500).json({
                success: false,
                error: 'Internal server error during authorization check'
            });
        }
    };
};

/**
 * Permission-based middleware for fine-grained access control
 * @param {string} requiredPermission - Specific permission required
 * @returns {Function} Express middleware function
 */
const requirePermission = (requiredPermission) => {
    return async (req, res, next) => {
        try {
            if (!req.user || !req.user.permissions) {
                logger.warn('Permission check: No permissions found', { path: req.path });
                return res.status(403).json({
                    success: false,
                    error: 'Access denied: No permissions assigned'
                });
            }

            const userPermissions = req.user.permissions;

            if (!userPermissions.includes(requiredPermission)) {
                logger.warn('Permission check: Insufficient permissions', {
                    userId: req.user.id,
                    requiredPermission,
                    userPermissions,
                    path: req.path
                });
                
                return res.status(403).json({
                    success: false,
                    error: 'Access denied: Missing required permission'
                });
            }

            logger.debug('Permission check: Granted', {
                userId: req.user.id,
                permission: requiredPermission,
                path: req.path
            });

            next();
        } catch (error) {
            logger.error('Permission check: Error', {
                error: error.message,
                stack: error.stack,
                userId: req.user?.id
            });
            
            return res.status(500).json({
                success: false,
                error: 'Internal server error during permission check'
            });
        }
    };
};

/**
 * Pre-defined role checkers for common use cases
 */
const rbac = {
    // Role-specific middleware
    requireEmployee: requireRole('employee'),
    requireManager: requireRole('manager'),
    requireAdmin: requireRole('admin'),
    
    // Multi-role access
    requireManagerOrAdmin: requireRole(['manager', 'admin']),
    requireEmployeeOrManager: requireRole(['employee', 'manager']),
    
    // Permission-based access
    requirePermission,
    
    // Raw middleware for custom role configurations
    requireRole
};

module.exports = rbac;

/**
 * Usage examples in route definitions:
 * 
 * router.get('/admin/dashboard', rbac.requireAdmin, adminController.getDashboard);
 * router.post('/manager/reports', rbac.requireManager, reportsController.generateReport);
 * router.get('/employee/profile', rbac.requireEmployee, profileController.getProfile);
 * router.put('/user/:id', rbac.requireManagerOrAdmin, userController.updateUser);
 * router.delete('/data/:id', rbac.requirePermission('delete_data'), dataController.deleteData);
 */