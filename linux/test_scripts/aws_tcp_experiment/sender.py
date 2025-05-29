# sender_server.py
import os
import socket
import time
import sys
import signal

# Helper to handle ctrl-c
def handle_keyboard_interrupt():
    duration = float(time.time() - start_time)
    print(f"Operation interrupted by user (keyboard) - Duration:{duration}")    
    
    # Stop socket monitoring 
    print("Stopping socket monitoring...")
    os.system("./stop.sh")

    # Exit
    sys.exit(-1)

# Helper to handle remote kill and log test duration
def handle_interrupt(signum, frame):  
    duration = float(time.time() - start_time)
    print(f"Operation interrupted (Signal {signum}) - Duration: {duration}")    
    
    # Stop socket monitoring 
    print("Stopping socket monitoring...")
    os.system("./stop.sh")

    # Exit
    sys.exit(-1)

# Register signal handlers for SIGINT (Ctrl-C) and SIGTERM (kill)
signal.signal(signal.SIGINT, handle_interrupt)
signal.signal(signal.SIGTERM, handle_interrupt)

# Global params
HOST = '0.0.0.0'        # Listen on all interfaces
PORT = 12345            # Port to listen on
start_time = 0          # Start time

def start_server(filename):
    # Create a TCP/IP socket
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((HOST, PORT))
    server_socket.listen(1)
    print(f"Server listening on {HOST}:{PORT}")

    # Wait for a connection from the receiver
    conn, addr = server_socket.accept()
    print(f"Connected by {addr}")
    
    # Wait for the receiver to signal it's ready
    data = conn.recv(1024)
    if data != b'READY_TO_RECEIVE':
        print(f"Unexpected initial message: {data}")
        conn.close()
        server_socket.close()
        return
    
    # Send the file data
    chunk_size = 10240
    global start_time
    start_time = time.time()
    
    try:
        file_size = os.path.getsize(filename)
        with open(filename, 'rb') as file:
            bytes_sent = 0
            while True:
                data = file.read(chunk_size)
                if not data:
                    break
                conn.sendall(data)
                bytes_sent += len(data)
                
                # Optional: Print progress
                progress = (bytes_sent / file_size) * 100
                print(f"\rProgress: {progress:.2f}%", end="")
                
        # Signal end of transfer
        conn.sendall(b'TRANSFER_COMPLETE')
        print("\n")  # New line after progress
    except KeyboardInterrupt:
        handle_keyboard_interrupt()
    except Exception as e:
        print(f"Error sending file: {e}")
    
    # All done
    file_size = float(os.path.getsize(filename))
    duration = float(time.time() - start_time)
    rate = float(file_size * 8)/duration if duration > 0 else 0
    print(f"File:{filename} sent successfully - Duration:{duration:.2f}s - Rate:{rate:.2f} bits/s - Size:{file_size} bytes")
    
    conn.close()
    server_socket.close()

if __name__ == '__main__':
    # Start socket monitoring 
    print("Start socket monitoring...")
    os.system("(./socket-monitoring.sh 300000 ss-log &)")
    time.sleep(1)
    
    # Read input if passed 
    target_file = 'samplefile.bin'    
    if len(sys.argv) > 1:
        target_file = sys.argv[1]
    
    # Start server to wait for receiver connection
    start_server(target_file)
    
    # Stop socket monitoring 
    os.system("./stop.sh")