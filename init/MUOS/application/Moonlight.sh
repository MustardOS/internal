#!/bin/bash

# Function to safely stop background processes
stop_bg_processes() {
    if pgrep -f "playbgm.sh" >/dev/null; then
        killall -q "playbgm.sh" "mp3play"
    fi

    if pgrep -f "muplay" >/dev/null; then
        killall -q "muplay"
        [ -n "$SND_PIPE" ] && rm "$SND_PIPE"
    fi
}

# Stop background processes locally or remotely
stop_bg_processes

# Set activity to 'app'
echo app >/tmp/act_go

# Source necessary scripts
. /opt/muos/script/var/func.sh
. /opt/muos/script/var/device/sdl.sh
. /opt/muos/script/var/device/storage.sh

# Define paths and commands
LOVEDIR="$DC_STO_ROM_MOUNT/MUOS/application/.moonlight"
MOONDIR="$DC_STO_ROM_MOUNT/MUOS/application/.moonlight/moonlight"
GPTOKEYB="$DC_STO_ROM_MOUNT/MUOS/emulator/gptokeyb/gptokeyb2.armhf"

# Export environment variables
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"

# Launcher
cd "$LOVEDIR" || exit
echo "love" >/tmp/fg_proc
export LD_LIBRARY_PATH="$LOVEDIR/libs:$LD_LIBRARY_PATH"
$GPTOKEYB "love" &
./love gui
kill -9 "$(pidof gptokeyb2.armhf)"

# Moonlight
cd "$MOONDIR" || exit
COMMAND=$(cat command.txt)
eval "./moonlight $COMMAND"
rm -f "command.txt"
