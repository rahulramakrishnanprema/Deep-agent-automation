const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');

const router = express.Router();

// In-memory user store (replace with database in production)
const users = new Map();
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRY = process.env.JWT_EXPIRY || '1h';

// AEP-2: Authentication API Implementation
const logger = {
    info: (message) => console.log(`[INFO] ${new Date().toISOString()}: ${message}`),
    error: (message) => console.error(`[ERROR] ${new Date().toISOString()}: ${message}`),
    warn: (message) => console.warn(`[WARN] ${new Date().toISOString()}: ${message}`)
};

// Input validation middleware
const validateRegistration = [
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 6 }),
    body('name').trim().isLength({ min: 1 })
];

const validateLogin = [
    body('email').isEmail().normalizeEmail(),
    body('password').exists()
];

// Registration API - AEP-2 Subtask #2
router.post('/register', validateRegistration, async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            logger.warn(`Registration validation failed: ${JSON.stringify(errors.array())}`);
            return res.status(400).json({ 
                success: false, 
                message: 'Invalid input data', 
                errors: errors.array() 
            });
        }

        const { email, password, name } = req.body;

        if (users.has(email)) {
            logger.warn(`Registration attempt with existing email: ${email}`);
            return res.status(409).json({
                success: false,
                message: 'User already exists'
            });
        }

        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(password, saltRounds);

        const user = {
            email,
            password: hashedPassword,
            name,
            createdAt: new Date()
        };

        users.set(email, user);
        logger.info(`User registered successfully: ${email}`);

        const token = jwt.sign(
            { email: user.email, name: user.name },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRY }
        );

        res.status(201).json({
            success: true,
            message: 'User registered successfully',
            token,
            user: { email: user.email, name: user.name }
        });

    } catch (error) {
        logger.error(`Registration error: ${error.message}`);
        res.status(500).json({
            success: false,
            message: 'Internal server error'
        });
    }
});

// Login API - AEP-2 Subtask #1
router.post('/login', validateLogin, async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            logger.warn(`Login validation failed: ${JSON.stringify(errors.array())}`);
            return res.status(400).json({ 
                success: false, 
                message: 'Invalid input data', 
                errors: errors.array() 
            });
        }

        const { email, password } = req.body;
        const user = users.get(email);

        if (!user) {
            logger.warn(`Login attempt with non-existent email: ${email}`);
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials'
            });
        }

        const isPasswordValid = await bcrypt.compare(password, user.password);
        if (!isPasswordValid) {
            logger.warn(`Invalid password attempt for email: ${email}`);
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials'
            });
        }

        const token = jwt.sign(
            { email: user.email, name: user.name },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRY }
        );

        logger.info(`User logged in successfully: ${email}`);
        res.json({
            success: true,
            message: 'Login successful',
            token,
            user: { email: user.email, name: user.name }
        });

    } catch (error) {
        logger.error(`Login error: ${error.message}`);
        res.status(500).json({
            success: false,
            message: 'Internal server error'
        });
    }
});

// Token verification middleware - AEP-2 Subtask #3
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({
            success: false,
            message: 'Access token required'
        });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            logger.warn(`Invalid token attempt: ${err.message}`);
            return res.status(403).json({
                success: false,
                message: 'Invalid or expired token'
            });
        }
        req.user = user;
        next();
    });
};

// Protected route example
router.get('/profile', authenticateToken, (req, res) => {
    res.json({
        success: true,
        user: req.user
    });
});

// Health check endpoint
router.get('/health', (req, res) => {
    res.json({ 
        success: true, 
        message: 'Authentication API is running',
        timestamp: new Date().toISOString()
    });
});

module.exports = router;