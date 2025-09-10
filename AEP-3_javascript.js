/**
 * AEP-3_javascript.js
 * Role-Based Access Control (RBAC) Middleware
 * 
 * This module provides middleware functions for enforcing role-based access control
 * in a web application. It checks user roles against required permissions for API routes.
 * 
 * ISSUE: AEP-3
 */

const logger = require('../utils/logger');
const { User, Role } = require('../models'); // Assuming Sequelize models

/**
 * RBAC Middleware - Checks if user has required role for the route
 * @param {Array} allowedRoles - Array of role names that are permitted
 * @returns {Function} Express middleware function
 */
const requireRole = (allowedRoles) => {
  return async (req, res, next) => {
    try {
      // Check if user is authenticated
      if (!req.user || !req.user.id) {
        logger.warn('RBAC: Unauthenticated access attempt', { path: req.path });
        return res.status(401).json({
          success: false,
          message: 'Authentication required',
          error: 'UNAUTHENTICATED'
        });
      }

      // Fetch user with role information
      const userWithRole = await User.findByPk(req.user.id, {
        include: [{
          model: Role,
          as: 'role',
          attributes: ['name', 'permissions']
        }],
        attributes: ['id', 'email', 'isActive']
      });

      if (!userWithRole) {
        logger.error('RBAC: User not found in database', { userId: req.user.id });
        return res.status(404).json({
          success: false,
          message: 'User not found',
          error: 'USER_NOT_FOUND'
        });
      }

      if (!userWithRole.isActive) {
        logger.warn('RBAC: Inactive user access attempt', { userId: req.user.id });
        return res.status(403).json({
          success: false,
          message: 'Account is deactivated',
          error: 'ACCOUNT_DEACTIVATED'
        });
      }

      // Check if user has a role
      if (!userWithRole.role) {
        logger.warn('RBAC: User without role access attempt', { userId: req.user.id });
        return res.status(403).json({
          success: false,
          message: 'Access denied - no role assigned',
          error: 'NO_ROLE_ASSIGNED'
        });
      }

      // Check if user's role is in allowed roles
      if (!allowedRoles.includes(userWithRole.role.name)) {
        logger.warn('RBAC: Insufficient permissions', {
          userId: req.user.id,
          userRole: userWithRole.role.name,
          requiredRoles: allowedRoles,
          path: req.path
        });
        
        return res.status(403).json({
          success: false,
          message: 'Insufficient permissions',
          error: 'INSUFFICIENT_PERMISSIONS',
          requiredRoles: allowedRoles,
          userRole: userWithRole.role.name
        });
      }

      // Attach role information to request for downstream use
      req.user.role = userWithRole.role.name;
      req.user.permissions = userWithRole.role.permissions;

      logger.debug('RBAC: Access granted', {
        userId: req.user.id,
        role: userWithRole.role.name,
        path: req.path
      });

      next();
    } catch (error) {
      logger.error('RBAC: Middleware error', {
        error: error.message,
        stack: error.stack,
        userId: req.user?.id,
        path: req.path
      });

      return res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: 'RBAC_CHECK_FAILED'
      });
    }
  };
};

/**
 * Permission-based middleware for fine-grained access control
 * @param {string} requiredPermission - The specific permission required
 * @returns {Function} Express middleware function
 */
const requirePermission = (requiredPermission) => {
  return async (req, res, next) => {
    try {
      if (!req.user || !req.user.permissions) {
        logger.warn('Permission check: User permissions not available', { path: req.path });
        return res.status(403).json({
          success: false,
          message: 'Permission check failed',
          error: 'PERMISSION_CHECK_FAILED'
        });
      }

      const userPermissions = Array.isArray(req.user.permissions) 
        ? req.user.permissions 
        : JSON.parse(req.user.permissions || '[]');

      if (!userPermissions.includes(requiredPermission)) {
        logger.warn('Permission check: Insufficient permissions', {
          userId: req.user.id,
          requiredPermission,
          userPermissions,
          path: req.path
        });

        return res.status(403).json({
          success: false,
          message: 'Insufficient permissions for this action',
          error: 'INSUFFICIENT_PERMISSIONS',
          requiredPermission
        });
      }

      logger.debug('Permission check: Access granted', {
        userId: req.user.id,
        permission: requiredPermission,
        path: req.path
      });

      next();
    } catch (error) {
      logger.error('Permission check: Middleware error', {
        error: error.message,
        stack: error.stack,
        userId: req.user?.id,
        path: req.path
      });

      return res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: 'PERMISSION_CHECK_FAILED'
      });
    }
  };
};

/**
 * Pre-defined role checkers for common role combinations
 */
const rbac = {
  // Admin only access
  requireAdmin: requireRole(['admin']),
  
  // Manager and Admin access
  requireManager: requireRole(['manager', 'admin']),
  
  // All authenticated users (employee, manager, admin)
  requireAuthenticated: requireRole(['employee', 'manager', 'admin']),
  
  // Custom role checker
  requireRole,
  
  // Permission-based checker
  requirePermission
};

/**
 * Utility function to validate roles exist in database
 * @returns {Promise<boolean>} True if all default roles exist
 */
const validateDefaultRoles = async () => {
  try {
    const defaultRoles = ['admin', 'manager', 'employee'];
    const existingRoles = await Role.findAll({
      where: { name: defaultRoles },
      attributes: ['name']
    });

    const existingRoleNames = existingRoles.map(role => role.name);
    const missingRoles = defaultRoles.filter(role => !existingRoleNames.includes(role));

    if (missingRoles.length > 0) {
      logger.error('RBAC: Missing default roles in database', { missingRoles });
      return false;
    }

    logger.info('RBAC: All default roles validated successfully');
    return true;
  } catch (error) {
    logger.error('RBAC: Role validation failed', {
      error: error.message,
      stack: error.stack
    });
    return false;
  }
};

module.exports = {
  rbac,
  requireRole,
  requirePermission,
  validateDefaultRoles
};