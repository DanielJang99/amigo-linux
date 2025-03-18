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

# Default global params
DEFAULT_HOST = '54.205.30.146'  # Default server IP address where the sender is running
DEFAULT_PORT = 12345            # Default port the sender is listening on
start_time = 0                  # Start time

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
    parser.add_argument('-ip', '--host', default=DEFAULT_HOST,
                        help=f'Server IP address (default: {DEFAULT_HOST})')
    parser.add_argument('-p', '--port', type=int, default=DEFAULT_PORT,
                        help=f'Server port (default: {DEFAULT_PORT})')
    
    # Parse arguments
    args = parser.parse_args()
    
    # Display connection info
    print(f"Connecting to: {args.host}:{args.port}")
    print(f"Output file: {args.output}")
    
    # Start receiving
    receive_file(args.output, args.host, args.port)