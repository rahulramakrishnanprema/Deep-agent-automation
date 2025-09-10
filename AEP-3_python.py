# AEP-3: Role-Based Access Control (RBAC)

# Define roles in DB
roles = ['employee', 'manager', 'admin']

# Middleware for RBAC
def check_role(role):
    def decorator(func):
        def wrapper(*args, **kwargs):
            if role in roles:
                return func(*args, **kwargs)
            else:
                raise Exception('Unauthorized access')
        return wrapper
    return decorator

# Test endpoints with different roles
@check_role('employee')
def employee_endpoint():
    return 'Employee endpoint'

@check_role('manager')
def manager_endpoint():
    return 'Manager endpoint'

@check_role('admin')
def admin_endpoint():
    return 'Admin endpoint'

# Sample usage
try:
    print(employee_endpoint())
    print(manager_endpoint())
    print(admin_endpoint())
except Exception as e:
    print(f'Error: {e}')