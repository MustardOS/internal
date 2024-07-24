#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/device.sh
. /opt/muos/script/var/device/screen.sh
. /opt/muos/script/var/device/sdl.sh
. /opt/muos/script/var/device/storage.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"

echo "mupen64plus" >/tmp/fg_proc

case "$DC_DEV_NAME" in
	RG28XX)
		FB_SWITCH 240 320 32
		;;
	*)
		FB_SWITCH 320 240 32
		;;
esac

EMUDIR="$DC_STO_ROM_MOUNT/MUOS/emulator/mupen64plus"
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

case "$DC_DEV_NAME" in
	RG*)
		echo 0 > "/sys/class/power_supply/axp2202-battery/nds_pwrkey"
		FB_SWITCH "$DC_SCR_WIDTH" "$DC_SCR_HEIGHT" 32
		;;
	*)
		FB_SWITCH "$DC_SCR_WIDTH" "$DC_SCR_HEIGHT" 32
		;;
esac

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
