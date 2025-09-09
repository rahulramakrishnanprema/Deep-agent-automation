const { AEP3Role } = require('../models/AEP3Role');
const { AEP3User } = require('../models/AEP3User');
const logger = require('../utils/logger');

/**
 * AEP-3 Role-Based Access Control Middleware
 * Provides role-based authorization for API endpoints
 */
class AEP3RBAC {
  /**
   * Create RBAC middleware for specific role requirements
   * @param {string|Array} requiredRoles - Single role or array of acceptable roles
   * @returns {Function} Express middleware function
   */
  static requireRole(requiredRoles) {
    // Validate requiredRoles parameter
    if (!requiredRoles || (Array.isArray(requiredRoles) && requiredRoles.length === 0)) {
      throw new Error('Required roles must be specified');
    }
    
    if ((typeof requiredRoles !== 'string' && !Array.isArray(requiredRoles)) ||
        (Array.isArray(requiredRoles) && requiredRoles.some(role => typeof role !== 'string'))) {
      throw new Error('Required roles must be a string or array of strings');
    }

    return async (req, res, next) => {
      try {
        // Normalize required roles to array
        const rolesArray = Array.isArray(requiredRoles) 
          ? requiredRoles 
          : [requiredRoles];
        
        // Check if user is authenticated
        if (!req.user || !req.user.id) {
          logger.warn('AEP-3: Unauthenticated access attempt', {
            userId: 'unknown',
            path: req.path,
            method: req.method,
            ip: req.ip,
            userAgent: req.get('User-Agent'),
            timestamp: new Date().toISOString()
          });
          return res.status(401).json({
            error: 'Authentication required',
            code: 'AEP3_UNAUTHORIZED'
          });
        }

        // Validate user ID format to prevent NoSQL injection
        if (!/^[a-f\d]{24}$/i.test(req.user.id)) {
          logger.warn('AEP-3: Invalid user ID format', {
            userId: req.user.id,
            path: req.path,
            ip: req.ip
          });
          return res.status(400).json({
            error: 'Invalid user identifier',
            code: 'AEP3_INVALID_USER_ID'
          });
        }

        // Get user with populated roles and permissions
        const user = await AEP3User.findById(req.user.id).populate({
          path: 'roles',
          populate: {
            path: 'permissions'
          }
        });
        
        if (!user) {
          logger.warn('AEP-3: User not found during authorization', {
            userId: req.user.id,
            path: req.path,
            ip: req.ip,
            userAgent: req.get('User-Agent'),
            timestamp: new Date().toISOString()
          });
          return res.status(401).json({
            error: 'Authentication failed',
            code: 'AEP3_AUTHENTICATION_FAILED'
          });
        }

        // Handle case where user has no roles assigned
        if (!user.roles || user.roles.length === 0) {
          logger.warn('AEP-3: User has no roles assigned', {
            userId: req.user.id,
            requiredRoles: rolesArray,
            path: req.path,
            method: req.method,
            ip: req.ip,
            userAgent: req.get('User-Agent'),
            timestamp: new Date().toISOString()
          });
          return res.status(403).json({
            error: 'Insufficient permissions',
            code: 'AEP3_FORBIDDEN'
          });
        }

        // Check if user has any of the required roles
        const userRoles = user.roles.map(role => role.name);
        const hasRequiredRole = rolesArray.some(requiredRole => 
          userRoles.includes(requiredRole)
        );

        if (!hasRequiredRole) {
          logger.warn('AEP-3: Insufficient permissions', {
            userId: req.user.id,
            userRoles,
            requiredRoles: rolesArray,
            path: req.path,
            method: req.method,
            ip: req.ip,
            userAgent: req.get('User-Agent'),
            timestamp: new Date().toISOString()
          });
          
          return res.status(403).json({
            error: 'Insufficient permissions',
            code: 'AEP3_FORBIDDEN'
          });
        }

        // Add user roles and permissions to request object for downstream use
        req.userRoles = userRoles;
        req.userPermissions = user.roles.flatMap(role => 
          role.permissions ? role.permissions.map(p => p.name) : []
        );
        
        logger.debug('AEP-3: Authorization successful', {
          userId: req.user.id,
          userRoles,
          requiredRoles: rolesArray
        });
        
        next();
      } catch (error) {
        logger.error('AEP-3: Authorization error', {
          error: error.message,
          stack: error.stack,
          userId: req.user?.id,
          path: req.path,
          ip: req.ip,
          userAgent: req.get('User-Agent'),
          timestamp: new Date().toISOString()
        });
        
        return res.status(500).json({
          error: 'Internal server error during authorization',
          code: 'AEP3_AUTHORIZATION_ERROR'
        });
      }
    };
  }

  /**
   * Check if user has specific role(s)
   * @param {Object} user - User object with roles
   * @param {string|Array} roles - Role or roles to check
   * @returns {boolean} True if user has required role(s)
   */
  static hasRole(user, roles) {
    if (!user || !user.roles) return false;
    
    const rolesArray = Array.isArray(roles) ? roles : [roles];
    const userRoles = user.roles.map(role => role.name);
    
    return rolesArray.some(role => userRoles.includes(role));
  }

  /**
   * Check if user has specific permission(s)
   * @param {Object} user - User object with roles and permissions
   * @param {string|Array} permissions - Permission or permissions to check
   * @returns {boolean} True if user has required permission(s)
   */
  static hasPermission(user, permissions) {
    if (!user || !user.roles) return false;
    
    const permissionsArray = Array.isArray(permissions) ? permissions : [permissions];
    const userPermissions = user.roles.flatMap(role => 
      role.permissions ? role.permissions.map(p => p.name) : []
    );
    
    return permissionsArray.some(permission => userPermissions.includes(permission));
  }

  /**
   * Get all available roles from database
   * @returns {Promise<Array>} Array of role objects
   */
  static async getAllRoles() {
    try {
      return await AEP3Role.find({}).populate('permissions').sort({ name: 1 });
    } catch (error) {
      logger.error('AEP-3: Error fetching roles', {
        error: error.message,
        stack: error.stack,
        timestamp: new Date().toISOString()
      });
      throw new Error('Failed to fetch roles');
    }
  }

  /**
   * Create a new role
   * @param {string} roleName - Name of the role to create
   * @param {string} description - Description of the role
   * @returns {Promise<Object>} Created role object
   */
  static async createRole(roleName, description = '') {
    try {
      // Validate role name format
      if (!roleName || typeof roleName !== 'string' || !/^[a-z_]{3,50}$/.test(roleName)) {
        throw new Error('Invalid role name format');
      }

      const existingRole = await AEP3Role.findOne({ name: roleName });
      if (existingRole) {
        throw new Error(`Role '${roleName}' already exists`);
      }

      const role = new AEP3Role({
        name: roleName,
        description,
        createdAt: new Date(),
        updatedAt: new Date()
      });

      await role.save();
      
      logger.info('AEP-3: New role created', { 
        roleName,
        timestamp: new Date().toISOString()
      });
      
      return role;
    } catch (error) {
      logger.error('AEP-3: Error creating role', {
        roleName,
        error: error.message,
        stack: error.stack,
        timestamp: new Date().toISOString()
      });
      throw error;
    }
  }

  /**
   * Assign roles to a user
   * @param {string} userId - User ID
   * @param {Array} roleNames - Array of role names to assign
   * @returns {Promise<Object>} Updated user object
   */
  static async assignRolesToUser(userId, roleNames) {
    try {
      // Validate user ID format
      if (!/^[a-f\d]{24}$/i.test(userId)) {
        throw new Error('Invalid user ID format');
      }

      // Validate role names
      if (!Array.isArray(roleNames) || roleNames.some(name => !name || typeof name !== 'string')) {
        throw new Error('Invalid role names provided');
      }

      const roles = await AEP3Role.find({ name: { $in: roleNames } });
      
      if (roles.length !== roleNames.length) {
        const foundRoleNames = roles.map(role => role.name);
        const missingRoles = roleNames.filter(name => !foundRoleNames.includes(name));
        throw new Error(`Roles not found: ${missingRoles.join(', ')}`);
      }

      const roleIds = roles.map(role => role._id);
      const user = await AEP3User.findByIdAndUpdate(
        userId,
        { 
          $addToSet: { roles: { $each: roleIds } },
          updatedAt: new Date()
        },
        { new: true, runValidators: true }
      ).populate({
        path: 'roles',
        populate: {
          path: 'permissions'
        }
      });

      if (!user) {
        throw new Error('User not found');
      }

      logger.info('AEP-3: Roles assigned to user', {
        userId,
        roleNames,
        assignedRoles: user.roles.map(role => role.name),
        timestamp: new Date().toISOString()
      });

      return user;
    } catch (error) {
      logger.error('AEP-3: Error assigning roles to user', {
        userId,
        roleNames,
        error: error.message,
        stack: error.stack,
        timestamp: new Date().toISOString()
      });
      throw error;
    }
  }

  /**
   * Remove roles from a user
   * @param {string} userId - User ID
   * @param {Array} roleNames - Array of role names to remove
   * @returns {Promise<Object>} Updated user object
   */
  static async removeRolesFromUser(userId, roleNames) {
    try {
      // Validate user ID format
      if (!/^[a-f\d]{24}$/i.test(userId)) {
        throw new Error('Invalid user ID format');
      }

      // Validate role names
      if (!Array.isArray(roleNames) || roleNames.some(name => !name || typeof name !== 'string')) {
        throw new Error('Invalid role names provided');
      }

      const roles = await AEP3Role.find({ name: { $in: roleNames } });
      const roleIds = roles.map(role => role._id);

      const user = await AEP3User.findByIdAndUpdate(
        userId,
        { 
          $pull: { roles: { $in: roleIds } },
          updatedAt: new Date()
        },
        { new: true, runValidators: true }
      ).populate({
        path: 'roles',
        populate: {
          path: 'permissions'
        }
      });

      if (!user) {
        throw new Error('User not found');
      }

      logger.info('AEP-3: Roles removed from user', {
        userId,
        roleNames,
        remainingRoles: user.roles.map(role => role.name),
        timestamp: new Date().toISOString()
      });

      return user;
    } catch (error) {
      logger.error('AEP-3: Error removing roles from user', {
        userId,
        roleNames,
        error: error.message,
        stack: error.stack,
        timestamp: new Date().toISOString()
      });
      throw error;
    }
  }

  /**
   * Get user's roles with permissions
   * @param {string} userId - User ID
   * @returns {Promise<Array>} Array of user's roles with permissions
   */
  static async getUserRoles(userId) {
    try {
      // Validate user ID format
      if (!/^[a-f\d]{24}$/i.test(userId)) {
        throw new Error('Invalid user ID format');
      }

      const user = await AEP3User.findById(userId).populate({
        path: 'roles',
        populate: {
          path: 'permissions'
        }
      });
      
      if (!user) {
        throw new Error('User not found');
      }

      return user.roles;
    } catch (error) {
      logger.error('AEP-3: Error fetching user roles', {
        userId,
        error: error.message,
        stack: error.stack,
        timestamp: new Date().toISOString()
      });
      throw error;
    }
  }

  /**
   * Initialize default roles if they don't exist
   * @returns {Promise<void>}
   */
  static async initializeDefaultRoles() {
    try {
      const defaultRoles = [
        { name: 'employee', description: 'Standard employee