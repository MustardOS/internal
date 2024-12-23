import socket
import json
import argparse

def send_status(ip, state, details):
    """Send the current status to the PC server."""
    status_update = {
        "ip": ip,
        "state": state,
        "details": details
    }
    status_update_json = json.dumps(status_update)
    

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((ip, 65432))  # Replace with your PC's IP address
        s.sendall(status_update_json.encode('utf-8'))

def clear_status(ip):
    """Send a command to clear the status on the PC server."""
    clear_command = {
        "ip": ip,
        "command": "clear"
    }
    clear_command_json = json.dumps(clear_command)
    
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((ip, 65432))  # Replace with your PC's IP address
        s.sendall(clear_command_json.encode('utf-8'))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Send Discord Rich Presence status.')
    parser.add_argument('ip', type=str, help='The IP of your PC running Discord', nargs='?', default=None)
    parser.add_argument('state', type=str, help='The state to display', nargs='?', default=None)
    parser.add_argument('details', type=str, help='The details to display', nargs='?', default=None)
    parser.add_argument('--clear', action='store_true', help='Clear the status')

    args = parser.parse_args()
    
    if args.clear:
        clear_status(args.ip)
    else:
        send_status(args.ip, args.state, args.details)
