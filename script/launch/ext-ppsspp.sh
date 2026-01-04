#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

LOG_INFO "$0" 0 "Content Launch" "DETAIL"
LOG_INFO "$0" 0 "NAME" "$NAME"
LOG_INFO "$0" 0 "CORE" "$CORE"
LOG_INFO "$0" 0 "FILE" "$FILE"

PPSSPP_DIR="$MUOS_SHARE_DIR/emulator/ppsspp"

SETUP_SDL_ENVIRONMENT

case "$(GET_VAR "device" "board/name")" in
	rg*)
		sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' \
			"$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

		rm -f "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/FailedGraphicsBackends.txt"
		;;
	tui*)
		# Prevent blackscreen due to "an issue with the ordering of the RGBA 8888 or something like that" (acmeplus 2025)
		setalpha 0
		;;
esac

case "$FILE" in
	*.psp)
		# Mechanism to launch PSP folder-style games
		GAME=$(basename "$FILE" | sed -e 's/\.[^.]*$//')
		GAMEDIR=$(dirname "$FILE")
		if [ -e "$PPSSPP_DIR/.config/ppsspp/PSP/GAME/$GAME/EBOOT.PBP" ]; then
			FILE="$PPSSPP_DIR/.config/ppsspp/PSP/GAME/$GAME/EBOOT.PBP"
		else
			GAMESUBDIR=$(find "$GAMEDIR" -maxdepth 2 -type d \( -iname "$GAME" -o -iname ".$GAME" \))
			if [ -n "$GAMESUBDIR" ]; then
				if [ -e "$GAMESUBDIR/EBOOT.PBP" ]; then
					FILE="$GAMESUBDIR/EBOOT.PBP"
				fi
			fi
		fi
		;;
esac

HOME="$PPSSPP_DIR"
export HOME

XDG_CONFIG_HOME="$HOME/.config"
export XDG_CONFIG_HOME

rm -rf "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/CACHE/"*
cd "$PPSSPP_DIR" || exit

SET_VAR "system" "foreground_process" "PPSSPP"

LD_PRELOAD="/opt/muos/frontend/lib/libmustage.so" ./PPSSPP --pause-menu-exit "$FILE"
