import ipaddress
import argparse
import json

server_ip_address_dict = {
    "Frankfurt": "3.120.146.236", 
    "London": "13.40.224.77",
    "North Virginia": "54.205.30.146",
    "Doha": "3.29.242.12",
}

def check_ip_location(ip_address):
    """
    Check if IP address belongs to any Starlink subnet and return location info.
    Returns dict with location info if found, None if not found.
    """
    try:
        with open('starlink_ips.json', 'r') as f:
            networks = json.load(f)
    except Exception as e:
        print(f"Error reading JSON file: {e}")
        return None

    try:
        ip_obj = ipaddress.ip_address(ip_address)
    except ValueError as e:
        print(f"Invalid IP address: {e}")
        return None

    # Check each subnet
    for network in networks["ip_networks"]:
        try:
            if ip_obj in ipaddress.ip_network(network['ip_subnet']):
                return network
        except ValueError as e:
            print(f"Invalid subnet {network['ip_subnet']}: {e}")
            continue

    return None

def get_closest_server(location):
    """Find the closest server based on predefined regional mapping."""
    
    # Regional mapping to closest servers
    regional_mapping = {
        # North America
        "US": {
            "US-WA": "North Virginia",
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
        
        # Latin America
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
            return regional_mapping[country].get(state, "North Virginia")
        return regional_mapping[country]
    
    return "North Virginia"

def main():
    parser = argparse.ArgumentParser(description='Check Starlink IP location and find closest server')
    parser.add_argument('ip_address', help='IP address to check')
    args = parser.parse_args()
    
    current_ip = args.ip_address
    
    # Check if IP is in Starlink network
    result = check_ip_location(current_ip)
    
    if result:
        closest = get_closest_server(result)
        print(server_ip_address_dict[closest])
    else:
        exit(1)

if __name__ == "__main__":
    main() 