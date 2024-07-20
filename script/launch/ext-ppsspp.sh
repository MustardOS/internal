#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/device.sh
. /opt/muos/script/var/device/screen.sh
. /opt/muos/script/var/device/sdl.sh
. /opt/muos/script/var/device/storage.sh

NAME=$1
CORE=$2
ROM=$3

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"

echo "PPSSPP" >/tmp/fg_proc

EMUDIR="$DC_STO_ROM_MOUNT/MUOS/emulator/ppsspp"

chmod +x "$EMUDIR"/ppsspp
cd "$EMUDIR" || exit

case "$DC_DEV_NAME" in
	RG28XX)
		FB_SWITCH 720 960 32
		;;
	*)
		FB_SWITCH 960 720 32
		;;
esac

sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' "$EMUDIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") ./PPSSPP "$ROM"

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
