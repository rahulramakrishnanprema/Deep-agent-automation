import pandas as pd

def read_data(file_path):
    """
    Read data from a CSV file.
    
    Args:
    file_path (str): Path to the CSV file
    
    Returns:
    pd.DataFrame: Dataframe containing the raw data
    """
    try:
        data = pd.read_csv(file_path)
        return data
    except Exception as e:
        print(f"Error reading data: {e}")
        return None

def clean_data(data):
    """
    Clean and normalize the data.
    
    Args:
    data (pd.DataFrame): Raw data
    
    Returns:
    pd.DataFrame: Cleaned data without duplicates and missing values
    """
    cleaned_data = data.drop_duplicates().dropna()
    # Additional data normalization steps can be added here
    return cleaned_data

def save_data(cleaned_data, output_file):
    """
    Save cleaned data to a new CSV file.
    
    Args:
    cleaned_data (pd.DataFrame): Cleaned data
    output_file (str): Path to save the cleaned data
    
    Returns:
    bool: True if data is saved successfully, False otherwise
    """
    try:
        cleaned_data.to_csv(output_file, index=False)
        return True
    except Exception as e:
        print(f"Error saving data: {e}")
        return False

# Usage example
raw_data = read_data("raw_data.csv")
if raw_data:
    cleaned_data = clean_data(raw_data)
    if cleaned_data is not None:
        save_data(cleaned_data, "cleaned_data.csv")