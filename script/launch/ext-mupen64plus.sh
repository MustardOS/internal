#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=$(GET_VAR "device" "board/home")

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

SET_VAR "system" "foreground_process" "mupen64plus"

case "$(GET_VAR "device" "board/name")" in
	RG28XX)
		FB_SWITCH 240 320 32
		;;
	*)
		FB_SWITCH 320 240 32
		;;
esac

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

# Decompress zipped ROMs since the emulator doesn't natively support them.
case "$ROM" in *.zip)
	TMPDIR="$(mktemp -d)"
	unzip -q "$ROM" -d "$TMPDIR"
	# Pick first file with a supported extension.
	for TMPFILE in "$TMPDIR"/*; do
		case "$TMPFILE" in *.n64|*.v64|*.z64)
			ROM="$TMPFILE"
			break
		;; esac
	done
;; esac

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./mupen64plus --corelib ./libmupen64plus.so.2.0.0 --configdir . "$ROM"

# Clean up temp files if we unzipped the ROM.
if [ -n "$TMPDIR" ]; then
	rm -r "$TMPDIR"
fi

case "$(GET_VAR "device" "board/name")" in
	RG*)
		echo 0 > "/sys/class/power_supply/axp2202-battery/nds_pwrkey"
		FB_SWITCH "$(GET_VAR "device" "screen/width")" "$(GET_VAR "device" "screen/height")" 32
		;;
	*)
		FB_SWITCH "$(GET_VAR "device" "screen/width")" "$(GET_VAR "device" "screen/height")" 32
		;;
esac

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
