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

PPSSPP_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp"
HOME="$PPSSPP_DIR"
export HOME

case "$FILE" in
	*.psp)
		# Mechanism to launch PSP folder-style games
		GAME=$(basename "$FILE" | sed -e 's/\.[^.]*$//')
		GAMEDIR=$(dirname "$FILE")
		if [ -e "$PPSSPP_DIR/.config/ppsspp/PSP/GAME/$GAME/EBOOT.PBP" ]; then
			FILE="$PPSSPP_DIR/.config/ppsspp/PSP/GAME/$GAME/EBOOT.PBP"
		else
			GAMESUBDIR=$(find "$GAMEDIR" -maxdepth 2 -type d \( -iname "$GAME" -o -iname ".$GAME" \) )
			if [ -n "$GAMESUBDIR" ]; then
				if [ -e "$GAMESUBDIR/EBOOT.PBP" ]; then
					FILE="$GAMESUBDIR/EBOOT.PBP"
				else
					echo >&2 "Game folder $GAMESUBDIR exists, but no EBOOT.PBP found"
				fi
			else
				echo >&2 "Game folder not found for $GAME"
			fi
		fi
		;;
esac

if [ "$(GET_VAR "global" "boot/device_mode")" -eq 1 ]; then
	SDL_HQ_SCALER=2
	SDL_ROTATION=0
	SDL_BLITTER_DISABLED=1
else
	SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
	SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
	SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
fi

export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

cd "$PPSSPP_DIR" || exit

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

SET_VAR "system" "foreground_process" "PPSSPP"

sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/opt/muos/device/current/control/gamecontrollerdb_retro.txt") ./PPSSPP --pause-menu-exit "$FILE"

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
