# Issue: AEP-DESIGN-DOC
# Generated: 2025-09-14T02:03:46.072778
# Thread: 72a50c18
# Model: deepseek/deepseek-chat-v3.1:free

Frontend (React) → API Gateway (FastAPI) → Business Logic → Database (PostgreSQL)
        ↑                  ↑                    ↑                ↑
    JWT Validation    RBAC Middleware       SQLAlchemy ORM    Migration Scripts
```

### Database Schema Design

```sql
-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role_id INTEGER REFERENCES roles(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Roles table
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    permissions JSONB NOT NULL
);

-- Sample roles insertion
INSERT INTO roles (name, permissions) VALUES 
('employee', '{"read": true, "write": false, "admin": false}'),
('manager', '{"read": true, "write": true, "admin": false}'),
('admin', '{"read": true, "write": true, "admin": true}');
```

### API Specifications

**Authentication Endpoints:**
```python
# POST /api/auth/login
# Request: {"email": "user@example.com", "password": "securepassword"}
# Response: {"token": "jwt_token", "user": {"id": 1, "email": "user@example.com", "role": "employee"}}

# POST /api/auth/register
# Request: {"email": "new@example.com", "password": "password", "first_name": "John", "last_name": "Doe"}
# Response: {"token": "jwt_token", "user": {"id": 2, "email": "new@example.com", "role": "employee"}}
```

**User Profile Endpoint:**
```python
# GET /api/users/profile
# Headers: Authorization: Bearer <jwt_token>
# Response: {"id": 1, "email": "user@example.com", "first_name": "John", "last_name": "Doe", "role": "employee"}