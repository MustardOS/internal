#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

(
	LOG_INFO "$0" 0 "Content Launch" "DETAIL"
	LOG_INFO "$0" 0 "NAME" "$NAME"
	LOG_INFO "$0" 0 "CORE" "$CORE"
	LOG_INFO "$0" 0 "FILE" "$FILE"
) &

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "python3"

SDL_JOYSTICK_DEVICE="/dev/input/js0"
export SDL_JOYSTICK_DEVICE

# Check if "pyxel" is already installed
if ! /usr/bin/python3 -c "import pyxel" 2>/dev/null; then
	/opt/muos/extra/muxmessage 0 "$(printf "Installing Pyxel Libraries\n\nPlease wait...")"
	/usr/bin/python3 -m ensurepip --upgrade --user
	/usr/bin/python3 -m pip install -U pyxel pip --user
fi

# add gptokeyb2 to exit games
PM_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"
"$PM_DIR"/gptokeyb2 "python3" &

python3 -m pyxel play "$FILE"
