""" 
A simple working example of accessing the ACAPS API in the Python programming language.

To use this code:
- Replace the credentials with the email and password you used to register/login to the ACAPS API.
- Replace the dataset URL with the specific API endpoint you wish to access (e.g., 'crises', 'entries', 'projects', etc.).
"""

import pandas as pd
import requests
from datetime import datetime
import time

# --- Step 1: Set your credentials ---
credentials = {
    "username": "timurkambarov250@gmail.com",  # Replace with your ACAPS email address
    "password": "eowjnfjop2341"   # Replace with your ACAPS password
}

# --- Step 2: Authenticate and get token ---
auth_token_response = requests.post(
    "https://api.acaps.org/api/v1/token-auth/",
    json=credentials
)

if auth_token_response.status_code != 200:
    raise Exception(f"Authentication failed: {auth_token_response.text}")

auth_token = auth_token_response.json()['token']

# --- Step 3: Set initial dataset URL ---
request_url = "https://api.acaps.org/api/v1/crises/"  # ACAPS endpoint for crisis data

# --- Step 4: Initialize DataFrame and timing ---
df = pd.DataFrame()
last_request_time = datetime.now()

# --- Step 5: Loop through paginated API responses ---
while True:
    # Respect a 1-second delay between requests to avoid throttling
    while (datetime.now() - last_request_time).total_seconds() < 1:
        time.sleep(0.1)

    # Make authenticated GET request
    response = requests.get(
        request_url,
        headers={"Authorization": f"Token {auth_token}"}
    )
    last_request_time = datetime.now()

    if response.status_code != 200:
        raise Exception(f"Data fetch failed: {response.text}")

    data = response.json()

    # Append results to DataFrame
    df = pd.concat([df, pd.DataFrame(data["results"])], ignore_index=True)

    # Check for next page; break if none
    if data.get("next"):
        request_url = data["next"]
    else:
        break

# --- Step 6: Display preview of downloaded data ---
print("Crisis data successfully retrieved. Here's a preview:")
print(df.head())