### Setting Up muSpy Discord Integration

#### Step 1: Create a Discord Application

1. **Visit the Discord Developer Portal:**
   - Go to [Discord Developer Portal](https://discord.com/developers/applications) and log in.

2. **Create a New Application:**
   - Click on "New Application."
   - Name your application **muSpy**.

3. **Configure OAuth2:**
   - Go to the "OAuth2" tab.
   - Select the following scopes:
     - `rpc`
     - `rpc.activities.write`
     - `identify`
   - Set the callback URL to: `https://127.0.0.1:5000/callback`.

4. **Retrieve Client ID and Secret:**
   - Copy your **Client ID**.
   - Generate and copy a new **Client Secret**.

5. **Update `discord_presence.py`:**
   - Open the `discord_presence.py` file.
   - Replace `'Your client id'` and `'Your client secret'` with your actual Client ID and Client Secret.

#### Step 2: Get IGDB API Credentials

1. **Visit IGDB:**
   - Go to [IGDB](https://www.igdb.com).

2. **Access API Section:**
   - Scroll to the bottom of the page and click on "API."

3. **Get Started:**
   - Click "Get Started Now" and follow the instructions to register.

4. **Retrieve IGDB Client ID and Secret:**
   - Copy your IGDB **Client ID** and **Client Secret**.

5. **Update `discord_presence.py`:**
   - Replace `'Your igdb client id'` and `'Your igdb client secret'` in the `discord_presence.py` file with your actual IGDB Client ID and Secret.

#### Step 3: Set Up Your Host PC

1. **Open `ip_pc.txt`:**
   - Navigate to `/mnt/mmc/MUOS/discord/`.
   - Open the `ip_pc.txt` file.

2. **Enter Your PC's IP Address:**
   - Type in the IP address of the PC that will host the Discord application.

#### Step 4: Copy `discord_presence.py` to Your Host PC

1. **Locate the File:**
   - Find `discord_presence.py` in the `/mnt/mmc/MUOS/discord/` directory on your device.

2. **Transfer the File:**
   - Copy `discord_presence.py` to your PC that will host the Discord application.

#### Step 5: Run the Application

1. **Run `discord_presence.py`:**
   - Open a terminal or command line on your host PC.
   - Navigate to the directory where you copied `discord_presence.py`.
   - Execute the command: `python3 discord_presence.py`.

2. **Authorize the Application:**
   - Open a web browser and go to: `http://localhost:5000`.
   - Sign in through Discord and authorize the application.

3. **Confirm RPC Connection:**
   - You should see a message saying "RPC is good."

Now, as long as your muOS device is connected to the internet, you'll be able to see what you’re playing, on what device, and what version of muOS you’re using.
