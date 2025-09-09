/**
 * AEP-2 Authentication API Implementation
 * Handles user registration, login, and JWT token management
 */

const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { validationResult } = require('express-validator');

// In production, use environment variables with proper fallbacks
const JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(64).toString('hex');
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';
const SALT_ROUNDS = parseInt(process.env.SALT_ROUNDS) || 12;

// Mock database - replace with actual database implementation
const users = new Map();
const loginAttempts = new Map();
const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_DURATION = 15 * 60 * 1000; // 15 minutes

class AuthenticationError extends Error {
    constructor(message, code = 'AUTH_ERROR') {
        super(message);
        this.name = 'AuthenticationError';
        this.code = code;
    }
}

/**
 * Generate JWT token for authenticated user
 */
const generateToken = (userId, email) => {
    return jwt.sign(
        { 
            userId, 
            email,
            iat: Math.floor(Date.now() / 1000)
        },
        JWT_SECRET,
        { expiresIn: JWT_EXPIRES_IN }
    );
};

/**
 * Validate user login attempts and prevent brute force attacks
 */
const validateLoginAttempts = (email) => {
    const attemptData = loginAttempts.get(email);
    
    if (attemptData) {
        const { count, lockedUntil } = attemptData;
        
        if (lockedUntil && Date.now() < lockedUntil) {
            const remainingTime = Math.ceil((lockedUntil - Date.now()) / 1000 / 60);
            throw new AuthenticationError(
                `Account temporarily locked. Try again in ${remainingTime} minutes.`,
                'ACCOUNT_LOCKED'
            );
        }
        
        if (count >= MAX_LOGIN_ATTEMPTS) {
            loginAttempts.set(email, {
                count,
                lockedUntil: Date.now() + LOCKOUT_DURATION
            });
            throw new AuthenticationError(
                'Too many failed attempts. Account locked for 15 minutes.',
                'ACCOUNT_LOCKED'
            );
        }
    }
};

/**
 * Increment failed login attempts
 */
const incrementFailedAttempts = (email) => {
    const currentAttempts = loginAttempts.get(email) || { count: 0 };
    const newCount = currentAttempts.count + 1;
    
    loginAttempts.set(email, {
        count: newCount,
        lockedUntil: currentAttempts.lockedUntil
    });
    
    return newCount;
};

/**
 * Reset login attempts on successful login
 */
const resetLoginAttempts = (email) => {
    loginAttempts.delete(email);
};

/**
 * User registration handler
 */
const register = async (req, res) => {
    try {
        // Validate request body
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                error: 'Validation failed',
                details: errors.array()
            });
        }

        const { email, password, firstName, lastName } = req.body;

        // Check if user already exists
        if (users.has(email)) {
            return res.status(409).json({
                success: false,
                error: 'User already exists with this email address'
            });
        }

        // Validate password strength
        if (password.length < 8) {
            return res.status(400).json({
                success: false,
                error: 'Password must be at least 8 characters long'
            });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);

        // Create user object
        const user = {
            id: crypto.randomUUID(),
            email,
            password: hashedPassword,
            firstName,
            lastName,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            isActive: true
        };

        // Store user (in production, use database)
        users.set(email, user);

        // Generate JWT token
        const token = generateToken(user.id, user.email);

        // Log successful registration
        console.log(`User registered successfully: ${email}`);

        res.status(201).json({
            success: true,
            message: 'User registered successfully',
            data: {
                token,
                user: {
                    id: user.id,
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName
                }
            }
        });

    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({
            success: false,
            error: 'Internal server error during registration'
        });
    }
};

/**
 * User login handler
 */
const login = async (req, res) => {
    try {
        // Validate request body
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                error: 'Validation failed',
                details: errors.array()
            });
        }

        const { email, password } = req.body;

        // Check login attempts
        try {
            validateLoginAttempts(email);
        } catch (error) {
            return res.status(429).json({
                success: false,
                error: error.message,
                code: error.code
            });
        }

        // Find user
        const user = users.get(email);
        if (!user) {
            incrementFailedAttempts(email);
            return res.status(401).json({
                success: false,
                error: 'Invalid email or password'
            });
        }

        // Check if user is active
        if (!user.isActive) {
            return res.status(403).json({
                success: false,
                error: 'Account is deactivated'
            });
        }

        // Verify password
        const isValidPassword = await bcrypt.compare(password, user.password);
        if (!isValidPassword) {
            const attemptsLeft = MAX_LOGIN_ATTEMPTS - incrementFailedAttempts(email);
            
            return res.status(401).json({
                success: false,
                error: 'Invalid email or password',
                attemptsLeft: attemptsLeft > 0 ? attemptsLeft : 0
            });
        }

        // Reset login attempts on success
        resetLoginAttempts(email);

        // Generate JWT token
        const token = generateToken(user.id, user.email);

        // Update last login
        user.lastLogin = new Date().toISOString();
        users.set(email, user);

        // Log successful login
        console.log(`User logged in successfully: ${email}`);

        res.json({
            success: true,
            message: 'Login successful',
            data: {
                token,
                user: {
                    id: user.id,
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName
                }
            }
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            success: false,
            error: 'Internal server error during login'
        });
    }
};

/**
 * Verify JWT token middleware
 */
const verifyToken = (req, res, next) => {
    try {
        const token = req.header('Authorization')?.replace('Bearer ', '');
        
        if (!token) {
            return res.status(401).json({
                success: false,
                error: 'Access denied. No token provided.'
            });
        }

        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (error) {
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({
                success: false,
                error: 'Token expired'
            });
        }
        
        if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({
                success: false,
                error: 'Invalid token'
            });
        }

        console.error('Token verification error:', error);
        res.status(500).json({
            success: false,
            error: 'Token verification failed'
        });
    }
};

/**
 * Get current user profile
 */
const getProfile = (req, res) => {
    try {
        const userEmail = req.user.email;
        const user = users.get(userEmail);
        
        if (!user) {
            return res.status(404).json({
                success: false,
                error: 'User not found'
            });
        }

        res.json({
            success: true,
            data: {
                user: {
                    id: user.id,
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    createdAt: user.createdAt,
                    lastLogin: user.lastLogin
                }
            }
        });

    } catch (error) {
        console.error('Profile fetch error:', error);
        res.status(500).json({
            success: false,
            error: 'Internal server error'
        });
    }
};

module.exports = {
    register,
    login,
    verifyToken,
    getProfile,
    AuthenticationError
};