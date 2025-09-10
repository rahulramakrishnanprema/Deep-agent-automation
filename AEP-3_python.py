# AEP-3: Role-Based Access Control (RBAC)

# Import necessary libraries
import logging

# Define roles in DB
roles = ['employee', 'manager', 'admin']

# Middleware for RBAC
def check_role(role):
    def decorator(func):
        def wrapper(*args, **kwargs):
            if role in roles:
                return func(*args, **kwargs)
            else:
                logging.error(f"Unauthorized access: {role} is not a valid role.")
                return "Unauthorized access", 403
        return wrapper
    return decorator

# Test endpoints with different roles
@check_role('employee')
def employee_endpoint():
    return "Employee endpoint accessed"

@check_role('manager')
def manager_endpoint():
    return "Manager endpoint accessed"

@check_role('admin')
def admin_endpoint():
    return "Admin endpoint accessed"

# Sample usage
print(employee_endpoint())
print(manager_endpoint())
print(admin_endpoint())