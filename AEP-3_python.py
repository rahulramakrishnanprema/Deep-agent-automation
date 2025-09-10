# AEP-3: Role-Based Access Control (RBAC)

# Define roles in DB
roles = {
    'employee': ['read'],
    'manager': ['read', 'write'],
    'admin': ['read', 'write', 'delete']
}

# Middleware for RBAC
def check_permission(role, action):
    if role in roles and action in roles[role]:
        return True
    else:
        return False

# Test endpoints with different roles
def test_endpoints():
    user_role = 'employee'
    action = 'write'
    if check_permission(user_role, action):
        print(f"User with role {user_role} can perform action {action}")
    else:
        print(f"User with role {user_role} cannot perform action {action}")

# Sample usage
test_endpoints()