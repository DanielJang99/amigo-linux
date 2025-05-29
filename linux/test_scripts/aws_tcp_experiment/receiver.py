# receiver_client.py
import socket
import time
import sys
import os
import signal
import argparse
    
# Helper to handle ctrl-c
def handle_keyboard_interrupt():
    duration = float(time.time() - start_time)
    print(f"Operation interrupted by user (keyboard) - Duration:{duration}")
    sys.exit(-1)

# Helper to handle remote kill and log test duration
def handle_interrupt(signum, frame):  
    duration = float(time.time() - start_time)
    print(f"Operation interrupted (Signal {signum}) - Duration: {duration}")
    sys.exit(-1)

# Register signal handlers for SIGINT (Ctrl-C) and SIGTERM (kill)
signal.signal(signal.SIGINT, handle_interrupt)
signal.signal(signal.SIGTERM, handle_interrupt)

# Read server locations from file
SERVER_LOCATIONS = {}
try:
    with open('aws_servers.txt', 'r') as f:
        for line in f:
            line = line.strip()
            if line:  # Skip empty lines
                fields = line.split(',')
                SERVER_LOCATIONS[fields[0]] = fields[2]
except FileNotFoundError:
    print("Error: aws_servers.txt not found")
    sys.exit(1)

DEFAULT_SERVER_LOC = 'us-east-1'
DEFAULT_HOST = SERVER_LOCATIONS.get(DEFAULT_SERVER_LOC)  # Use .get() in case file is missing the default location
if DEFAULT_HOST is None:
    print(f"Error: Default server location '{DEFAULT_SERVER_LOC}' not found in aws_servers.txt")
    sys.exit(1)

DEFAULT_PORT = 12345            # Default port the sender is listening on
start_time = 0                 # Start time

# Helper to receive a file
def receive_file(output_filename='received_file.txt', host=DEFAULT_HOST, port=DEFAULT_PORT):
    # Update value of start time
    global start_time
    
    print(f"Initiating connection to sender at {host}:{port}")
    
    # Create a TCP/IP socket
    client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client_socket.connect((host, port))
    print(f"Connected to sender at {host}:{port}")
    
    # Signal we're ready to receive
    client_socket.sendall(b'READY_TO_RECEIVE')
    
    # Open a file to write the incoming data
    start_time = time.time()
    file_size = 0
    
    try:
        with open(output_filename, 'wb') as file:
            while True:
                data = client_socket.recv(1024)  # Receive data in chunks of 1024 bytes
                if not data or data == b'TRANSFER_COMPLETE':
                    break
                file.write(data)  # Write the data to the file
                file_size += len(data)
    except KeyboardInterrupt:
        handle_keyboard_interrupt()
    
    # All done
    duration = float(time.time() - start_time)
    rate = float(file_size * 8)/duration if duration > 0 else 0
    print(f"File received successfully - Size:{file_size} bytes - Duration:{duration:.2f}s - Rate:{rate:.2f} bits/s")
    
    client_socket.close()

# main goes here
if __name__ == '__main__':
    
    # Set up command line argument parsing
    parser = argparse.ArgumentParser(description='Receive a file from a sender server')
    parser.add_argument('-o', '--output', default='received_file.txt', 
                        help='Output filename (default: received_file.txt)')
    parser.add_argument('-ip', '--host', default=None,
                        help='Server IP address (overrides server location if provided)')
    parser.add_argument('-p', '--port', type=int, default=DEFAULT_PORT,
                        help=f'Server port (default: {DEFAULT_PORT})')
    parser.add_argument('-s', '--server-loc', default=DEFAULT_SERVER_LOC,
                        choices=SERVER_LOCATIONS.keys(),
                        help=f'Server location (default: {DEFAULT_SERVER_LOC})')
    
    # Parse arguments
    args = parser.parse_args()

    # Determine host based on server location or explicit IP
    host = args.host if args.host else SERVER_LOCATIONS[args.server_loc]
    
    # Display connection info
    print(f"Server location: {args.server_loc}")
    print(f"Connecting to: {host}:{args.port}")
    print(f"Output file: {args.output}")
    
    # Start receiving
    receive_file(args.output, host, args.port)