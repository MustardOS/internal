#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

LOG_INFO "$0" 0 "Content Launch" "DETAIL"
LOG_INFO "$0" 0 "NAME" "$NAME"
LOG_INFO "$0" 0 "CORE" "$CORE"
LOG_INFO "$0" 0 "FILE" "$FILE"

HOME="$(GET_VAR "device" "board/home")"
export HOME

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

SET_VAR "system" "foreground_process" "mupen64plus"

FB_SWITCH 320 240 32

EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/mupen64plus"
MP64_CFG="$EMUDIR/mupen64plus.cfg"

RICE_CFG="$EMUDIR/mupen64plus-rice.cfg"
GL64_CFG="$EMUDIR/mupen64plus-gl64.cfg"

if [ "$CORE" = "ext-mupen64plus-gliden64" ]; then
	cp -f "$GL64_CFG" "$MP64_CFG"
elif [ "$CORE" = "ext-mupen64plus-rice" ]; then
	echo "We need rice!" >>"$LOG"
	cp -f "$RICE_CFG" "$MP64_CFG"
fi

chmod +x "$EMUDIR"/mupen64plus
cd "$EMUDIR" || exit

# Decompress zipped files since the emulator doesn't natively support them.
case "$FILE" in *.zip)
	TMPDIR="$(mktemp -d)"
	unzip -q "$FILE" -d "$TMPDIR"
	# Pick first file with a supported extension.
	for TMPFILE in "$TMPDIR"/*; do
		case "$TMPFILE" in *.n64 | *.v64 | *.z64)
			FILE="$TMPFILE"
			break
			;;
		esac
	done
	;;
esac

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./mupen64plus --corelib ./libmupen64plus.so.2.0.0 --configdir . "$FILE"

# Clean up temp files if we unzipped the file
[ -n "$TMPDIR" ] && rm -r "$TMPDIR"

[ "$(GET_VAR "global" "settings/hdmi/enabled")" -eq 1 ] && SCREEN_TYPE="external" || SCREEN_TYPE="internal"
FB_SWITCH "$(GET_VAR "device" "screen/$SCREEN_TYPE/width")" "$(GET_VAR "device" "screen/$SCREEN_TYPE/height")" 32

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
