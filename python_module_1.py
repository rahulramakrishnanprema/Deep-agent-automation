#!/usr/bin/env python3
"""
Main script for database schema setup and migration management.

This module provides the main entry point for creating and managing
the training database schema, running migrations, and inserting test data.
"""

import logging
import sys
from typing import Optional

from database.connection import DatabaseConnection
from database.migrations import MigrationManager
from database.seed import SeedDataManager
from utils.logger import setup_logging

# Configure logging
setup_logging()
logger = logging.getLogger(__name__)


def setup_database() -> bool:
    """
    Set up the complete database schema and insert sample data.
    
    Returns:
        bool: True if setup was successful, False otherwise
    """
    try:
        logger.info("Starting database setup process")
        
        # Initialize database connection
        db_connection = DatabaseConnection()
        
        # Create migration manager and run migrations
        migration_manager = MigrationManager(db_connection)
        
        logger.info("Running database migrations")
        if not migration_manager.run_all_migrations():
            logger.error("Failed to run database migrations")
            return False
        
        # Insert sample data
        logger.info("Inserting sample data")
        seed_manager = SeedDataManager(db_connection)
        if not seed_manager.insert_sample_data():
            logger.error("Failed to insert sample data")
            return False
        
        logger.info("Database setup completed successfully")
        return True
        
    except Exception as e:
        logger.error(f"Database setup failed: {str(e)}")
        return False


def run_migrations() -> bool:
    """
    Run only the database migrations without inserting sample data.
    
    Returns:
        bool: True if migrations were successful, False otherwise
    """
    try:
        logger.info("Running database migrations")
        
        db_connection = DatabaseConnection()
        migration_manager = MigrationManager(db_connection)
        
        return migration_manager.run_all_migrations()
        
    except Exception as e:
        logger.error(f"Migrations failed: {str(e)}")
        return False


def insert_sample_data() -> bool:
    """
    Insert only sample data into the database.
    
    Returns:
        bool: True if data insertion was successful, False otherwise
    """
    try:
        logger.info("Inserting sample data")
        
        db_connection = DatabaseConnection()
        seed_manager = SeedDataManager(db_connection)
        
        return seed_manager.insert_sample_data()
        
    except Exception as e:
        logger.error(f"Sample data insertion failed: {str(e)}")
        return False


def show_database_status() -> bool:
    """
    Display current database schema status and migration information.
    
    Returns:
        bool: True if status check was successful, False otherwise
    """
    try:
        logger.info("Checking database status")
        
        db_connection = DatabaseConnection()
        migration_manager = MigrationManager(db_connection)
        
        return migration_manager.show_migration_status()
        
    except Exception as e:
        logger.error(f"Status check failed: {str(e)}")
        return False


def main() -> int:
    """
    Main entry point for the database setup application.
    
    Returns:
        int: Exit code (0 for success, non-zero for failure)
    """
    import argparse
    
    parser = argparse.ArgumentParser(description="Database Schema Setup Tool")
    parser.add_argument(
        "--setup", 
        action="store_true", 
        help="Complete database setup (migrations + sample data)"
    )
    parser.add_argument(
        "--migrate", 
        action="store_true", 
        help="Run only database migrations"
    )
    parser.add_argument(
        "--seed", 
        action="store_true", 
        help="Insert only sample data"
    )
    parser.add_argument(
        "--status", 
        action="store_true", 
        help="Show database migration status"
    )
    
    args = parser.parse_args()
    
    # If no arguments provided, show help
    if not any(vars(args).values()):
        parser.print_help()
        return 1
    
    success = False
    
    if args.setup:
        success = setup_database()
    elif args.migrate:
        success = run_migrations()
    elif args.seed:
        success = insert_sample_data()
    elif args.status:
        success = show_database_status()
    
    if success:
        logger.info("Operation completed successfully")
        return 0
    else:
        logger.error("Operation failed")
        return 1


if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger.info("Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        sys.exit(1)