# AEP-4: Basic User Profile API
import logging
from typing import Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class UserProfileResponse(BaseModel):
    """Response model for user profile data"""
    name: str
    email: str
    role: str

class UserProfileAPI:
    def __init__(self, db_session: callable):
        """
        Initialize User Profile API
        
        Args:
            db_session: Database session dependency callable
        """
        self.router = APIRouter(prefix="/api/profile", tags=["profile"])
        self.db_session = db_session
        self._setup_routes()
    
    def _setup_routes(self):
        """Setup API routes"""
        self.router.add_api_route(
            "/me",
            self.get_user_profile,
            methods=["GET"],
            response_model=UserProfileResponse,
            summary="Get current user profile",
            description="Retrieve basic profile information for the authenticated user"
        )
    
    async def get_user_profile(
        self,
        db: Session = Depends(self.db_session),
        current_user: Dict[str, Any] = Depends(get_current_user)  # Assuming auth dependency exists
    ) -> UserProfileResponse:
        """
        Get user profile information
        
        Args:
            db: Database session
            current_user: Authenticated user data from dependency
            
        Returns:
            UserProfileResponse: User profile data
            
        Raises:
            HTTPException: If user not found or database error occurs
        """
        try:
            logger.info(f"Fetching profile for user ID: {current_user['id']}")
            
            # Fetch user from database
            user = self._get_user_from_db(db, current_user['id'])
            
            if not user:
                logger.warning(f"User not found in database: {current_user['id']}")
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User not found"
                )
            
            # Validate profile data matches database records
            self._validate_profile_data(user, current_user)
            
            logger.info(f"Successfully retrieved profile for user: {current_user['id']}")
            return UserProfileResponse(
                name=user.name,
                email=user.email,
                role=user.role
            )
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error fetching user profile: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Internal server error while fetching profile"
            )
    
    def _get_user_from_db(self, db: Session, user_id: str) -> Optional[Any]:
        """
        Fetch user from database
        
        Args:
            db: Database session
            user_id: User identifier
            
        Returns:
            User object or None if not found
        """
        # Assuming User model exists with appropriate schema
        # Replace with actual ORM model and query
        try:
            # Example: return db.query(User).filter(User.id == user_id).first()
            # For now, returning mock data - replace with actual database query
            from models import User  # Assuming User model exists
            return db.query(User).filter(User.id == user_id).first()
            
        except Exception as e:
            logger.error(f"Database error fetching user {user_id}: {str(e)}")
            raise
    
    def _validate_profile_data(self, db_user: Any, current_user: Dict[str, Any]) -> None:
        """
        Validate that database user data matches authenticated user data
        
        Args:
            db_user: User object from database
            current_user: Authenticated user data
            
        Raises:
            HTTPException: If data inconsistency is detected
        """
        try:
            # Basic validation to ensure data consistency
            if (db_user.email != current_user.get('email') or 
                db_user.id != current_user.get('id')):
                logger.error(
                    f"Data inconsistency detected for user {current_user['id']}. "
                    f"DB email: {db_user.email}, Auth email: {current_user.get('email')}"
                )
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Data inconsistency detected"
                )
                
        except Exception as e:
            logger.error(f"Validation error for user {current_user['id']}: {str(e)}")
            raise

# Unit tests would be in a separate test file, but here's a basic structure:
"""
import pytest
from unittest.mock import Mock, AsyncMock
from fastapi.testclient import TestClient

class TestUserProfileAPI:
    @pytest.fixture
    def mock_db(self):
        return Mock()
    
    @pytest.fixture
    def mock_current_user(self):
        return {"id": "test-user", "email": "test@example.com"}
    
    @pytest.fixture
    def user_profile_api(self, mock_db):
        return UserProfileAPI(mock_db)
    
    async def test_get_user_profile_success(self, user_profile_api, mock_db, mock_current_user):
        # Mock database response
        mock_user = Mock()
        mock_user.name = "Test User"
        mock_user.email = "test@example.com"
        mock_user.role = "user"
        mock_db.query.return_value.filter.return_value.first.return_value = mock_user
        
        # Test the method
        response = await user_profile_api.get_user_profile(mock_db, mock_current_user)
        
        assert response.name == "Test User"
        assert response.email == "test@example.com"
        assert response.role == "user"
    
    async def test_get_user_profile_not_found(self, user_profile_api, mock_db, mock_current_user):
        # Mock database response - user not found
        mock_db.query.return_value.filter.return_value.first.return_value = None
        
        with pytest.raises(HTTPException) as exc_info:
            await user_profile_api.get_user_profile(mock_db, mock_current_user)
        
        assert exc_info.value.status_code == 404
"""

# Factory function to create and include the router in FastAPI app
def include_user_profile_routes(app, db_session_dependency):
    """
    Include user profile routes in FastAPI application
    
    Args:
        app: FastAPI application instance
        db_session_dependency: Database session dependency function
    """
    user_profile_api = UserProfileAPI(db_session_dependency)
    app.include_router(user_profile_api.router)