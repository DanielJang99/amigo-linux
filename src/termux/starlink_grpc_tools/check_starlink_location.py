import requests
import pandas as pd
import ipaddress
import argparse

server_ip_address_dict = {
    "Frankfurt": "3.120.146.236", 
    "London": "13.40.224.77",
    "North Virginia": "54.205.30.146",
    "Doha": "3.29.242.12",
}

def get_public_ip():
    """Get the current public IP address."""
    try:
        response = requests.get('https://api.ipify.org')
        return response.text
    except requests.RequestException as e:
        print(f"Error getting public IP: {e}")
        return None

def check_ip_location(ip_address):
    """
    Check if IP address belongs to any Starlink subnet and return location info.
    Returns tuple of (country, city) if found, None if not found.
    """
    # Read the CSV file
    try:
        df = pd.read_csv('starlink_ips.csv')
    except Exception as e:
        print(f"Error reading CSV file: {e}")
        return None

    # Convert IP address to IPv4Address object for comparison
    try:
        ip_obj = ipaddress.ip_address(ip_address)
    except ValueError as e:
        print(f"Invalid IP address: {e}")
        return None

    # Check each subnet
    for _, row in df.iterrows():
        try:
            network = ipaddress.ip_network(row['ip_subnet'])
            if ip_obj in network:
                return {
                    'ip_subnet': row['ip_subnet'],
                    'country': row['country'],
                    'country_code': row['country_code'],
                    'city': row['city']
                }
        except ValueError as e:
            print(f"Invalid subnet {row['ip_subnet']}: {e}")
            continue

    return None

def get_closest_server(location):
    """Find the closest server based on predefined regional mapping."""
    
    # Server locations
    servers = {
        "Doha": "Doha, Qatar",
        "Frankfurt": "Frankfurt, Germany",
        "London": "London, UK",
        "North Virginia": "Ashburn, Virginia, USA"
    }
    
    # Regional mapping to closest servers
    # This is a simplified geographical approximation
    regional_mapping = {
        # North America
        "US": {
            "US-WA": "North Virginia",  # West coast but closer to N.Virginia than Doha
            "US-CA": "North Virginia",
            "US-TX": "North Virginia",
            "US-FL": "North Virginia",
            "US-NY": "North Virginia",
            "US-IL": "North Virginia",
            "US-VA": "North Virginia",
            "US-GA": "North Virginia",
            "US-MN": "North Virginia",
            "US-MT": "North Virginia",
            "US-UT": "North Virginia",
            "US-AZ": "North Virginia",
            "US-HI": "North Virginia",
            "US-AK": "North Virginia",
            "US-MD": "North Virginia",
        },
        "CA": "North Virginia",
        
        # Europe
        "GB": "London",
        "DE": "Frankfurt",
        "FR": "Frankfurt",
        "IT": "Frankfurt",
        "ES": "London",
        "NL": "Frankfurt",
        "BE": "Frankfurt",
        "PL": "Frankfurt",
        "CZ": "Frankfurt",
        "AT": "Frankfurt",
        "CH": "Frankfurt",
        "SE": "London",
        "NO": "London",
        "DK": "Frankfurt",
        "FI": "Frankfurt",
        "GR": "Frankfurt",
        "RO": "Frankfurt",
        "HU": "Frankfurt",
        "BG": "Frankfurt",
        "SK": "Frankfurt",
        "HR": "Frankfurt",
        "EE": "Frankfurt",
        "LV": "Frankfurt",
        "LT": "Frankfurt",
        "SI": "Frankfurt",
        "CY": "Frankfurt",
        "MT": "Frankfurt",
        
        # Middle East & Africa
        "AE": "Doha",
        "SA": "Doha",
        "QA": "Doha",
        "BH": "Doha",
        "KW": "Doha",
        "OM": "Doha",
        "EG": "Doha",
        "ZA": "Doha",
        "NG": "Doha",
        "KE": "Doha",
        "ET": "Doha",
        "TZ": "Doha",
        "UG": "Doha",
        "GH": "Doha",
        "MA": "Doha",
        
        # Asia Pacific
        "JP": "Doha",
        "KR": "Doha",
        "CN": "Doha",
        "HK": "Doha",
        "TW": "Doha",
        "SG": "Doha",
        "MY": "Doha",
        "ID": "Doha",
        "TH": "Doha",
        "VN": "Doha",
        "PH": "Doha",
        "AU": "Doha",
        "NZ": "Doha",
        "IN": "Doha",
        "PK": "Doha",
        
        # Latin America (generally closer to N.Virginia)
        "BR": "North Virginia",
        "MX": "North Virginia",
        "AR": "North Virginia",
        "CO": "North Virginia",
        "CL": "North Virginia",
        "PE": "North Virginia",
        "VE": "North Virginia",
        "EC": "North Virginia",
        "BO": "North Virginia",
        "PY": "North Virginia",
        "UY": "North Virginia",
        "CR": "North Virginia",
        "PA": "North Virginia",
        "DO": "North Virginia",
        "GT": "North Virginia",
        "HN": "North Virginia",
        "SV": "North Virginia",
        "NI": "North Virginia",
        "JM": "North Virginia",
        "BS": "North Virginia",
        "TT": "North Virginia",
    }

    country = location['country']
    state = None
    
    # Handle special case for US states
    if country == "US":
        state = location['country'] + "-" + location['city'].split(",")[0].strip()
        if state in regional_mapping["US"]:
            return regional_mapping["US"][state]
    
    # For all other countries
    if country in regional_mapping:
        if isinstance(regional_mapping[country], dict):
            return regional_mapping[country].get(state, "North Virginia")  # Default to N.Virginia if state not found
        return regional_mapping[country]
    
    # Default to closest major hub if country not in mapping
    return "North Virginia"

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Check Starlink IP location and find closest server')
    parser.add_argument('ip_address', help='IP address to check')
    args = parser.parse_args()
    
    current_ip = args.ip_address
    # print(f"\nChecking IP: {current_ip}")
    
    # Check if IP is in Starlink network
    result = check_ip_location(current_ip)
    
    if result:
        # print(f"IP belongs to Starlink network:")
        # print(f"Subnet: {result['ip_subnet']}")
        # print(f"Location: {result['city']}, {result['country']} ({result['country_code']})")
        
        # # Find closest server
        closest = get_closest_server(result)
        # print(f"Closest server: {closest}")
        # print(f"Server IP: {server_ip_address_dict[closest]}")
        print(server_ip_address_dict[closest])
    else:
        exit(1)

if __name__ == "__main__":
    main() 