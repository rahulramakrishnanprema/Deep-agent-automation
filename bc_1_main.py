"""
Main module for BC-1 project - Basic Calculator Implementation
This module provides a simple addition function with proper validation and error handling.
"""

import logging
from typing import Union, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class CalculatorError(Exception):
    """Custom exception for calculator-related errors."""
    pass


def add_numbers(a: Union[int, float], b: Union[int, float]) -> Union[int, float]:
    """
    Add two numbers together with proper validation and error handling.
    
    This function performs basic addition operation on two numeric inputs
    with comprehensive input validation and error handling.
    
    Args:
        a (int | float): First number to add
        b (int | float): Second number to add
        
    Returns:
        int | float: The sum of a and b
        
    Raises:
        CalculatorError: If inputs are not numeric or if addition fails
        TypeError: If inputs are not of supported numeric types
        
    Examples:
        >>> add_numbers(2, 3)
        5
        >>> add_numbers(2.5, 3.1)
        5.6
        >>> add_numbers(-1, 5)
        4
    """
    try:
        # Validate input types
        if not isinstance(a, (int, float)):
            raise TypeError(f"First argument must be numeric, got {type(a).__name__}")
        if not isinstance(b, (int, float)):
            raise TypeError(f"Second argument must be numeric, got {type(b).__name__}")
        
        logger.info(f"Adding numbers: {a} + {b}")
        
        # Perform addition
        result = a + b
        
        # Check for potential overflow (though Python handles this well)
        if isinstance(result, int) and abs(result) > 10**18:
            logger.warning(f"Large integer result: {result}")
        
        logger.info(f"Addition result: {result}")
        return result
        
    except TypeError as e:
        logger.error(f"Type error in addition: {e}")
        raise CalculatorError(f"Invalid input types: {e}") from e
    except Exception as e:
        logger.error(f"Unexpected error during addition: {e}")
        raise CalculatorError(f"Addition failed: {e}") from e


def validate_numeric_input(value: any, param_name: str = "input") -> Optional[Union[int, float]]:
    """
    Validate and convert input to numeric type if possible.
    
    Args:
        value: Input value to validate
        param_name: Name of the parameter for error messages
        
    Returns:
        int | float | None: Converted numeric value or None if invalid
        
    Raises:
        CalculatorError: If value cannot be converted to numeric
    """
    try:
        if isinstance(value, (int, float)):
            return value
        
        # Try to convert string to numeric
        if isinstance(value, str):
            # Remove whitespace and check if it's a number
            cleaned_value = value.strip()
            if cleaned_value.replace('.', '', 1).replace('-', '', 1).isdigit():
                if '.' in cleaned_value:
                    return float(cleaned_value)
                else:
                    return int(cleaned_value)
        
        logger.warning(f"Invalid numeric input for {param_name}: {value} (type: {type(value).__name__})")
        return None
        
    except (ValueError, TypeError) as e:
        logger.error(f"Validation error for {param_name}: {e}")
        raise CalculatorError(f"Invalid numeric input for {param_name}: {value}") from e


def main():
    """
    Main function to demonstrate the addition functionality.
    
    Provides examples and handles user input for interactive testing.
    """
    print("BC-1 Calculator - Addition Function")
    print("=" * 40)
    
    # Example usage
    examples = [
        (2, 3),
        (2.5, 3.1),
        (-1, 5),
        (0, 0),
        (1000000, 2000000)
    ]
    
    print("\nExample additions:")
    for a, b in examples:
        try:
            result = add_numbers(a, b)
            print(f"{a} + {b} = {result}")
        except CalculatorError as e:
            print(f"Error adding {a} + {b}: {e}")
    
    # Interactive mode
    print("\nInteractive mode (type 'quit' to exit):")
    while True:
        try:
            user_input = input("\nEnter two numbers separated by space: ").strip()
            
            if user_input.lower() in ['quit', 'exit', 'q']:
                print("Goodbye!")
                break
            
            parts = user_input.split()
            if len(parts) != 2:
                print("Please enter exactly two numbers separated by space")
                continue
            
            # Validate and convert inputs
            num1 = validate_numeric_input(parts[0], "first number")
            num2 = validate_numeric_input(parts[1], "second number")
            
            if num1 is None or num2 is None:
                print("Please enter valid numbers")
                continue
            
            # Perform addition
            result = add_numbers(num1, num2)
            print(f"Result: {num1} + {num2} = {result}")
            
        except CalculatorError as e:
            print(f"Calculation error: {e}")
        except KeyboardInterrupt:
            print("\n\nOperation cancelled by user")
            break
        except Exception as e:
            print(f"Unexpected error: {e}")
            logger.exception("Unexpected error in main function")


if __name__ == "__main__":
    main()