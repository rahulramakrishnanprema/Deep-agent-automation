import logging
from typing import Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import sessionmaker

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database models (assuming these are defined elsewhere in the project)
# User model would typically be imported from another module
class User(BaseModel):
    id: int
    name: str
    email: EmailStr
    role: str

# Response model for user profile
class UserProfileResponse(BaseModel):
    name: str
    email: EmailStr
    role: str

# Database dependency (would be provided by the project's dependency setup)
async def get_db() -> AsyncSession:
    """Get database session dependency"""
    # This would typically come from the project's database setup
    # For this implementation, we'll assume it's provided elsewhere
    pass

# Authentication dependency (would be provided by the project's auth setup)
async def get_current_user() -> User:
    """Get current authenticated user dependency"""
    # This would typically come from the project's authentication setup
    # For this implementation, we'll assume it's provided elsewhere
    pass

# Create API router
router = APIRouter()

@router.get(
    "/profile",
    response_model=UserProfileResponse,
    summary="Get user profile information",
    description="Returns basic profile information (name, email, role) for the authenticated user",
    responses={
        200: {"description": "User profile retrieved successfully"},
        401: {"description": "Unauthorized - authentication required"},
        404: {"description": "User not found in database"},
        500: {"description": "Internal server error"}
    }
)
async def get_user_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> UserProfileResponse:
    """
    AEP-4: Basic User Profile API endpoint
    
    Fetches and returns the basic profile information for the authenticated user
    from the database.
    """
    try:
        logger.info(f"Fetching profile for user ID: {current_user.id}")
        
        # Query database for user profile
        # Assuming User model is mapped to a 'users' table
        query = select(User).where(User.id == current_user.id)
        result = await db.execute(query)
        user_record = result.scalar_one_or_none()
        
        if not user_record:
            logger.warning(f"User profile not found for ID: {current_user.id}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User profile not found"
            )
        
        # Validate that the retrieved data matches expected structure
        if not all(hasattr(user_record, attr) for attr in ['name', 'email', 'role']):
            logger.error(f"Invalid user record structure for ID: {current_user.id}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Invalid user data structure"
            )
        
        logger.info(f"Successfully retrieved profile for user: {user_record.email}")
        
        return UserProfileResponse(
            name=user_record.name,
            email=user_record.email,
            role=user_record.role
        )
        
    except HTTPException:
        # Re-raise known HTTP exceptions
        raise
        
    except Exception as e:
        logger.error(f"Unexpected error fetching user profile for ID {current_user.id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error while fetching user profile"
        )

# Unit tests would be implemented in a separate test file
# This is the main API implementation for AEP-4