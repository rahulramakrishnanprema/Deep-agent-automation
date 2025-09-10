// AEP-3: Role-Based Access Control (RBAC)

// Define roles in DB
const roles = {
  employee: 1,
  manager: 2,
  admin: 3
};

// Middleware for RBAC
const checkRole = (role) => {
  return (req, res, next) => {
    if (req.user.role >= roles[role]) {
      next();
    } else {
      res.status(403).json({ error: 'Unauthorized access' });
    }
  };
};

// Test endpoints with different roles
app.get('/employee', checkRole('employee'), (req, res) => {
  res.json({ message: 'Employee role access' });
});

app.get('/manager', checkRole('manager'), (req, res) => {
  res.json({ message: 'Manager role access' });
});

app.get('/admin', checkRole('admin'), (req, res) => {
  res.json({ message: 'Admin role access' });
});

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

// Logging
app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
});

// Enforce access based on role
app.use((req, res, next) => {
  if (req.url === '/employee') {
    checkRole('employee')(req, res, next);
  } else if (req.url === '/manager') {
    checkRole('manager')(req, res, next);
  } else if (req.url === '/admin') {
    checkRole('admin')(req, res, next);
  } else {
    next();
  }
});