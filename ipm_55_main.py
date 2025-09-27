import sys
from typing import Dict, Any, Optional
import json
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class IPM55Processor:
    """
    Main processor class for IPM-55 project.
    Handles core business logic and data processing.
    """
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        """
        Initialize the IPM55Processor with optional configuration.
        
        Args:
            config: Dictionary containing configuration parameters
        """
        self.config = config or {}
        self._initialize_components()
    
    def _initialize_components(self) -> None:
        """Initialize internal components and state."""
        self.state = {
            'processed_items': 0,
            'errors': 0,
            'last_processed': None
        }
        logger.info("IPM55Processor initialized successfully")
    
    def process_data(self, input_data: Any) -> Dict[str, Any]:
        """
        Process input data according to IPM-55 requirements.
        
        Args:
            input_data: Data to be processed (can be various types)
            
        Returns:
            Dictionary containing processing results and metadata
            
        Raises:
            ValueError: If input data is invalid or malformed
        """
        try:
            logger.info(f"Processing data: {type(input_data)}")
            
            # Basic validation
            if input_data is None:
                raise ValueError("Input data cannot be None")
            
            # Core processing logic
            result = self._execute_processing(input_data)
            
            # Update state
            self.state['processed_items'] += 1
            self.state['last_processed'] = result.get('timestamp')
            
            logger.info(f"Data processed successfully. Total processed: {self.state['processed_items']}")
            return result
            
        except Exception as e:
            self.state['errors'] += 1
            logger.error(f"Error processing data: {str(e)}")
            raise
    
    def _execute_processing(self, data: Any) -> Dict[str, Any]:
        """
        Execute the actual data processing logic.
        
        Args:
            data: Input data to process
            
        Returns:
            Processing results with metadata
        """
        # Implement specific processing logic here
        processed_result = {
            'original_data': data,
            'processed_at': '2024-01-01T00:00:00Z',  # Should use actual timestamp
            'status': 'completed',
            'result': f"Processed: {str(data)}",
            'metadata': {
                'length': len(str(data)) if hasattr(data, '__len__') else None,
                'type': type(data).__name__
            }
        }
        
        return processed_result
    
    def get_status(self) -> Dict[str, Any]:
        """
        Get current processor status and statistics.
        
        Returns:
            Dictionary containing current state information
        """
        return {
            'total_processed': self.state['processed_items'],
            'total_errors': self.state['errors'],
            'last_processed': self.state['last_processed'],
            'config': self.config
        }
    
    def reset(self) -> None:
        """Reset processor state and statistics."""
        self.state = {
            'processed_items': 0,
            'errors': 0,
            'last_processed': None
        }
        logger.info("Processor state reset")


class IPM55Manager:
    """
    Manager class to coordinate IPM-55 operations and provide interface.
    """
    
    def __init__(self):
        """Initialize the IPM55 manager."""
        self.processor = IPM55Processor()
        logger.info("IPM55Manager initialized")
    
    def run_processing(self, input_data: Any) -> Dict[str, Any]:
        """
        Execute processing operation with error handling.
        
        Args:
            input_data: Data to be processed
            
        Returns:
            Processing results or error information
        """
        try:
            result = self.processor.process_data(input_data)
            return {
                'success': True,
                'data': result,
                'status': self.processor.get_status()
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'status': self.processor.get_status()
            }
    
    def get_system_info(self) -> Dict[str, Any]:
        """
        Get system information and status.
        
        Returns:
            Dictionary containing system information
        """
        return {
            'system': 'IPM-55 Processing System',
            'version': '1.0.0',
            'status': 'operational',
            'processor_status': self.processor.get_status()
        }


def main():
    """
    Main entry point for the IPM-55 application.
    Handles command line arguments and executes processing.
    """
    manager = IPM55Manager()
    
    # Example usage - process sample data
    sample_data = "Hello IPM-55"
    
    print("IPM-55 Processing System")
    print("=" * 40)
    
    # Process sample data
    result = manager.run_processing(sample_data)
    
    if result['success']:
        print("✓ Processing completed successfully")
        print(f"Result: {result['data']['result']}")
    else:
        print("✗ Processing failed")
        print(f"Error: {result['error']}")
    
    # Display system status
    status = manager.get_system_info()
    print(f"\nSystem Status:")
    print(f"Total processed: {status['processor_status']['total_processed']}")
    print(f"Total errors: {status['processor_status']['total_errors']}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())