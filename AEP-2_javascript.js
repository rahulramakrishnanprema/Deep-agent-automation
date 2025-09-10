const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');

const router = express.Router();

// In-memory storage for demo purposes (replace with database in production)
const users = new Map();
const loginAttempts = new Map();
const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_DURATION = 15 * 60 * 1000; // 15 minutes

// JWT configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRY = process.env.JWT_EXPIRY || '1h';

// AEP-2: Authentication API implementation
class AuthenticationService {
    static validateUserInput(req) {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return { valid: false, errors: errors.array() };
        }
        return { valid: true };
    }

    static checkLoginAttempts(email) {
        const attemptData = loginAttempts.get(email);
        if (attemptData && attemptData.lockedUntil > Date.now()) {
            return { locked: true, remainingTime: attemptData.lockedUntil - Date.now() };
        }
        return { locked: false };
    }

    static recordFailedAttempt(email) {
        const currentAttempts = loginAttempts.get(email) || { count: 0, lockedUntil: 0 };
        currentAttempts.count += 1;
        
        if (currentAttempts.count >= MAX_LOGIN_ATTEMPTS) {
            currentAttempts.lockedUntil = Date.now() + LOCKOUT_DURATION;
            currentAttempts.count = 0; // Reset count after lockout
        }
        
        loginAttempts.set(email, currentAttempts);
        return currentAttempts.count;
    }

    static resetLoginAttempts(email) {
        loginAttempts.delete(email);
    }

    static generateToken(user) {
        const payload = {
            userId: user.id,
            email: user.email,
            role: user.role || 'user'
        };
        
        return jwt.sign(payload, JWT_SECRET, { 
            expiresIn: JWT_EXPIRY,
            jwtid: uuidv4()
        });
    }

    static async hashPassword(password) {
        const saltRounds = 12;
        return await bcrypt.hash(password, saltRounds);
    }

    static async verifyPassword(plainPassword, hashedPassword) {
        return await bcrypt.compare(plainPassword, hashedPassword);
    }
}

// AEP-2: Registration API
router.post('/register', [
    body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
    body('password')
        .isLength({ min: 8 })
        .withMessage('Password must be at least 8 characters')
        .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
        .withMessage('Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'),
    body('firstName').trim().isLength({ min: 1, max: 50 }).withMessage('First name is required'),
    body('lastName').trim().isLength({ min: 1, max: 50 }).withMessage('Last name is required')
], async (req, res) => {
    try {
        console.log('Registration attempt:', { email: req.body.email });
        
        const validation = AuthenticationService.validateUserInput(req);
        if (!validation.valid) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: validation.errors
            });
        }

        const { email, password, firstName, lastName } = req.body;

        // Check if user already exists
        if (users.has(email)) {
            return res.status(409).json({
                success: false,
                message: 'User already exists'
            });
        }

        // Hash password
        const hashedPassword = await AuthenticationService.hashPassword(password);

        // Create user
        const user = {
            id: uuidv4(),
            email,
            password: hashedPassword,
            firstName: firstName.trim(),
            lastName: lastName.trim(),
            role: 'user',
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };

        users.set(email, user);
        console.log('User registered successfully:', { userId: user.id, email });

        // Generate token
        const token = AuthenticationService.generateToken(user);

        res.status(201).json({
            success: true,
            message: 'User registered successfully',
            data: {
                token,
                user: {
                    id: user.id,
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    role: user.role
                }
            }
        });

    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({
            success: false,
            message: 'Internal server error during registration'
        });
    }
});

// AEP-2: Login API
router.post('/login', [
    body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
    body('password').notEmpty().withMessage('Password is required')
], async (req, res) => {
    try {
        console.log('Login attempt:', { email: req.body.email });
        
        const validation = AuthenticationService.validateUserInput(req);
        if (!validation.valid) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: validation.errors
            });
        }

        const { email, password } = req.body;

        // Check login attempts
        const attemptCheck = AuthenticationService.checkLoginAttempts(email);
        if (attemptCheck.locked) {
            return res.status(429).json({
                success: false,
                message: 'Account temporarily locked due to too many failed attempts',
                retryAfter: Math.ceil(attemptCheck.remainingTime / 1000)
            });
        }

        // Find user
        const user = users.get(email);
        if (!user) {
            AuthenticationService.recordFailedAttempt(email);
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials'
            });
        }

        // Verify password
        const isValidPassword = await AuthenticationService.verifyPassword(password, user.password);
        if (!isValidPassword) {
            const remainingAttempts = MAX_LOGIN_ATTEMPTS - AuthenticationService.recordFailedAttempt(email);
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials',
                remainingAttempts
            });
        }

        // Reset login attempts on successful login
        AuthenticationService.resetLoginAttempts(email);

        // Generate token
        const token = AuthenticationService.generateToken(user);
        
        console.log('Login successful:', { userId: user.id, email });

        res.json({
            success: true,
            message: 'Login successful',
            data: {
                token,
                user: {
                    id: user.id,
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    role: user.role
                }
            }
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            success: false,
            message: 'Internal server error during login'
        });
    }
});

// AEP-2: Token verification middleware (for other routes)
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({
            success: false,
            message: 'Access token required'
        });
    }

    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) {
            return res.status(403).json({
                success: false,
                message: 'Invalid or expired token'
            });
        }
        
        const user = users.get(decoded.email);
        if (!user) {
            return res.status(403).json({
                success: false,
                message: 'User not found'
            });
        }

        req.user = user;
        next();
    });
};

// AEP-2: Health check endpoint
router.get('/health', (req, res) => {
    res.json({
        success: true,
        message: 'Authentication service is running',
        timestamp: new Date().toISOString()
    });
});

// AEP-2: Export router and authentication middleware
module.exports = {
    router,
    authenticateToken,
    AuthenticationService
};