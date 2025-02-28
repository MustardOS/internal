import socket
import json
import requests
from flask import Flask, redirect, request, session
from pypresence import Presence
from urllib.parse import urlencode

app = Flask(__name__)

client_id = 'Your client ID'  # Replace with your actual client ID
client_secret = 'Your client secret'  # Replace with your actual client secret
redirect_uri = 'http://127.0.0.1:5000/callback'  # Redirect URI for local hosting

igdb_client_id = 'Your igdb client id'  # Replace with your IGDB client ID
igdb_client_secret = 'Your igdb client secret'
igdb_access_token = None

RPC = None

def get_igdb_access_token():
    response = requests.post('https://id.twitch.tv/oauth2/token', data={
        'client_id': igdb_client_id,
        'client_secret': igdb_client_secret,
        'grant_type': 'client_credentials'
    })
    response_data = response.json()
    print(f"IGDB access token response: {response_data}")
    return response_data['access_token']

def fetch_box_art(game_name):
    global igdb_access_token
    if igdb_access_token is None:
        igdb_access_token = get_igdb_access_token()
    
    # Strip 'Playing' from game name if it exists
    if game_name.lower().startswith('playing'):
        game_name = game_name[8:].strip()
    
    # Remove region tag
    if '(' in game_name and ')' in game_name:
        game_name = game_name.split('(')[0].strip()
    
    headers = {
        'Client-ID': igdb_client_id,
        'Authorization': f'Bearer {igdb_access_token}'
    }
    url = 'https://api.igdb.com/v4/games'
    data = f'search "{game_name}"; fields slug, cover.url;'
    print(f"Sending request to IGDB: {data}")
    response = requests.post(url, headers=headers, data=data)
    print(f"IGDB response status: {response.status_code}")
    if response.status_code == 200:
        results = response.json()
        print(f"IGDB response data: {results}")
        if results:
            # Assuming the first result is the most relevant one
            game_data = results[0]
            game_slug = game_data.get('slug', '')
            box_art_url = game_data.get('cover', {}).get('url', '').replace('t_thumb', 't_cover_big')
            if game_slug:
                print(f"Box art found: {box_art_url}")
                print(f"Game URL: https://www.igdb.com/games/{game_slug}")
                return f"https:{box_art_url}"
    print(f"Box art not found for {game_name}")
    return None

@app.route('/')
def login():
    params = {
        'client_id': client_id,
        'redirect_uri': redirect_uri,
        'response_type': 'code',
        'scope': 'rpc rpc.activities.write identify'
    }
    return redirect(f'https://discord.com/api/oauth2/authorize?{urlencode(params)}')

@app.route('/callback')
def callback():
    code = request.args.get('code')

    if not code:
        return "Error: No code returned from Discord", 400

    data = {
        'client_id': client_id,
        'client_secret': client_secret,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirect_uri
    }
    headers = {
        'Content-Type': 'application/x-www-form-urlencoded'
    }

    # Debugging information
    print("Request Data:", data)
    print("Request Headers:", headers)

    response = requests.post('https://discord.com/api/oauth2/token', data=data, headers=headers)
    
    # Check for rate limits
    rate_limit_remaining = response.headers.get('X-RateLimit-Remaining')
    rate_limit_reset = response.headers.get('X-RateLimit-Reset')
    print("Rate Limit Remaining:", rate_limit_remaining)
    print("Rate Limit Reset:", rate_limit_reset)

    response_data = response.json()

    # Debugging information
    print("Response Data:", response_data)

    if 'access_token' not in response_data:
        return f"Error: {response_data.get('error_description', 'Unknown error')}"

    access_token = response_data['access_token']
    global RPC
    RPC = Presence(client_id, token=access_token)
    RPC.connect()
    return "Logged in and RPC connected!"

def update_presence(data):
    game_name = data.get('details', 'Unknown Game')
    box_art_url = fetch_box_art(game_name)
    if RPC:
        print(f"Updating presence with state: {data.get('state', 'Playing')}, details: {data['details']}, large_image: {box_art_url}, large_text: {data.get('large_text', 'Playing a Game')}")
        RPC.update(
            state=data.get('state', 'Playing'),
            details=data['details'],
            large_image=box_art_url if box_art_url else 'default_image',  # URL of the online image or fallback to a default image
            large_text=data.get('large_text', 'Playing a Game')  # Text to display when hovering over the image
        )
        print("Presence updated successfully.")

def clear_presence():
    if RPC:
        RPC.clear()
        print("Presence cleared successfully.")

def start_server():
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind(('0.0.0.0', 65432))
    server_socket.listen(1)
    print("Server listening on port 65432")

    while True:
        client_socket, addr = server_socket.accept()
        print(f"Connection from {addr}")
        data = client_socket.recv(1024).decode('utf-8')
        status_update = json.loads(data)
        
        if status_update.get("command") == "clear":
            clear_presence()
        else:
            update_presence(status_update)
        
        client_socket.close()

if __name__ == "__main__":
    igdb_access_token = get_igdb_access_token()
    import threading
    threading.Thread(target=lambda: app.run(port=5000)).start()
    start_server()
