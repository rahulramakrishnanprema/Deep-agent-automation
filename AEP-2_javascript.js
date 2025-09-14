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
const LOCKOUT_TIME = 15 * 60 * 1000; // 15 minutes

// JWT configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRY = '24h';

// Input validation middleware
const validateRegistration = [
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters long'),
    body('firstName').trim().isLength({ min: 1 }).withMessage('First name is required'),
    body('lastName').trim().isLength({ min: 1 }).withMessage('Last name is required')
];

const validateLogin = [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty().withMessage('Password is required')
];

// Error handling middleware
const handleValidationErrors = (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            success: false,
            message: 'Validation failed',
            errors: errors.array()
        });
    }
    next();
};

// Rate limiting and lockout check
const checkLoginAttempts = (req, res, next) => {
    const { email } = req.body;
    const attemptKey = `attempt_${email}`;
    const lockoutKey = `lockout_${email}`;
    
    const currentAttempts = loginAttempts.get(attemptKey) || 0;
    const lockoutUntil = loginAttempts.get(lockoutKey);
    
    if (lockoutUntil && Date.now() < lockoutUntil) {
        const remainingTime = Math.ceil((lockoutUntil - Date.now()) / 60000);
        return res.status(429).json({
            success: false,
            message: `Account temporarily locked. Try again in ${remainingTime} minutes`
        });
    }
    
    if (currentAttempts >= MAX_LOGIN_ATTEMPTS) {
        loginAttempts.set(lockoutKey, Date.now() + LOCKOUT_TIME);
        loginAttempts.delete(attemptKey);
        return res.status(429).json({
            success: false,
            message: 'Too many failed attempts. Account locked for 15 minutes'
        });
    }
    
    req.loginAttempts = { attemptKey, currentAttempts };
    next();
};

// AEP-2: Registration API
router.post('/register', validateRegistration, handleValidationErrors, async (req, res) => {
    try {
        const { email, password, firstName, lastName } = req.body;
        
        if (users.has(email)) {
            return res.status(409).json({
                success: false,
                message: 'User already exists'
            });
        }
        
        const hashedPassword = await bcrypt.hash(password, 12);
        const userId = uuidv4();
        
        const user = {
            id: userId,
            email,
            password: hashedPassword,
            firstName: firstName.trim(),
            lastName: lastName.trim(),
            createdAt: new Date().toISOString()
        };
        
        users.set(email, user);
        
        console.log(`User registered: ${email}`);
        
        res.status(201).json({
            success: true,
            message: 'User registered successfully',
            userId
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
router.post('/login', validateLogin, handleValidationErrors, checkLoginAttempts, async (req, res) => {
    try {
        const { email, password } = req.body;
        const { attemptKey, currentAttempts } = req.loginAttempts;
        
        const user = users.get(email);
        if (!user) {
            loginAttempts.set(attemptKey, currentAttempts + 1);
            return res.status(401).json({
                success: false,
                message: 'Invalid email or password'
            });
        }
        
        const isValidPassword = await bcrypt.compare(password, user.password);
        if (!isValidPassword) {
            loginAttempts.set(attemptKey, currentAttempts + 1);
            return res.status(401).json({
                success: false,
                message: 'Invalid email or password'
            });
        }
        
        // Reset login attempts on successful login
        loginAttempts.delete(attemptKey);
        loginAttempts.delete(`lockout_${email}`);
        
        const token = jwt.sign(
            { userId: user.id, email: user.email },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRY }
        );
        
        console.log(`User logged in: ${email}`);
        
        res.json({
            success: true,
            message: 'Login successful',
            token,
            user: {
                id: user.id,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName
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
        
        req.user = decoded;
        next();
    });
};

// Health check endpoint
router.get('/health', (req, res) => {
    res.json({
        success: true,
        message: 'Authentication service is running',
        timestamp: new Date().toISOString()
    });
});

module.exports = { router, authenticateToken };