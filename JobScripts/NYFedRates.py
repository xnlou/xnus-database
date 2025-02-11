import requests
import json
from datetime import datetime

def save_json_data(data, output_dir, base_filename='data'):
    """
    Saves JSON data to a file with a timestamp in the filename.
    
    :param data: Data to save as JSON
    :param output_dir: Directory to save the file
    :param base_filename: Base name of the file before the timestamp
    """
    import os
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    timestamp = datetime.now().strftime('%Y%m%dT%H%M%S')
    filename = f"{base_filename}_{timestamp}.json"
    filepath = os.path.join(output_dir, filename)
    
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=4)
    
    print(f"Data saved to: {filepath}")

def fetch_ny_fed_data(url):
    """
    Fetches data from the NY Fed API.
    
    :param url: URL of the NY Fed API endpoint
    :return: JSON data from the API or None if the request fails
    """
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Failed to retrieve data: {e}")
        return None

if __name__ == "__main__":
    # URL for the NY Fed API
    url = 'https://markets.newyorkfed.org/api/rates/all/latest.json'
    
    # Fetch data from NY Fed API
    ny_fed_data = fetch_ny_fed_data(url)
    
    if ny_fed_data:
        # Save the data
        save_json_data(ny_fed_data, 'C:/Users/xnlou/Documents/github-repos/', 'ny_fed_rates')
    else:
        print("No data was fetched from the NY Fed API.")