#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/device.sh
. /opt/muos/script/var/device/screen.sh
. /opt/muos/script/var/device/storage.sh

. /opt/muos/script/var/global/setting_advanced.sh
. /opt/muos/script/var/global/setting_general.sh
. /opt/muos/script/var/global/web_service.sh

ACT_GO=/tmp/act_go
ROM_GO=/tmp/rom_go

SUSPEND_APP=muxplore

GPTOKEYB_BIN=gptokeyb2
GPTOKEYB_DIR="$DC_STO_ROM_MOUNT/MUOS/emulator/gptokeyb"
GPTOKEYB_CONTROLLERCONFIG="/usr/lib/gamecontrollerdb.txt"
GPTOKEYB_CONFDIR="/opt/muos/config/gptokeyb"

export EVSIEVE_BIN=evsieve
export EVSIEVE_DIR="/opt/muos/bin"
export EVSIEVE_CONFDIR="/opt/muos/config/evsieve"

LAST_PLAY="/opt/muos/config/lastplay.txt"
ROM_LAST=/tmp/rom_last

if [ "$GC_ADV_LOCK" -eq 1 ]; then
	nice --20 /opt/muos/extra/muxpass -t launch
	if [ "$?" = 2 ]; then
		rm "$ROM_GO"
		echo explore >"$ACT_GO"
		exit
	fi
fi

pkill -STOP "$SUSPEND_APP"

cat "$ROM_GO" >"$ROM_LAST"

NAME=$(sed -n '1p' "$ROM_GO")
CORE=$(sed -n '2p' "$ROM_GO" | tr -d '\n')
R_DIR=$(sed -n '5p' "$ROM_GO")$(sed -n '6p' "$ROM_GO")
ROM="$R_DIR"/$(sed -n '7p' "$ROM_GO")
VERSION=$(cat /opt/muos/config/version.txt)
PC_IP=$(cat /mnt/mmc/MUOS/discord/pc_ip.txt)

# Check if the pc_ip.txt file is not empty
if [ -s "/mnt/mmc/MUOS/discord/pc_ip.txt" ]; then
    python /mnt/mmc/MUOS/discord/discord_presence_handheld.py "$PC_IP" "On my $DC_DEV_NAME with muOS $VERSION!" "Playing $NAME"
fi

rm "$ROM_GO"

if [ -f "$GPTOKEYB_CONFDIR/$CORE.gptk" ]; then
	SDL_GAMECONTROLLERCONFIG_FILE="$GPTOKEYB_CONTROLLERCONFIG" \
		"$GPTOKEYB_DIR/$GPTOKEYB_BIN" -c "$GPTOKEYB_CONFDIR/$CORE.gptk" &
fi

if [ -f "$EVSIEVE_CONFDIR/$CORE.evs.sh" ]; then
	"$EVSIEVE_CONFDIR/$CORE.evs.sh"
fi

if pgrep -f "playbgm.sh" >/dev/null; then
	killall -q "playbgm.sh" "mpg123"
fi

echo "$GC_ADV_LED" >"$DC_DEV_LED"
echo "$GC_ADV_LED" >/tmp/work_led_state

cat "$ROM_LAST" >"$LAST_PLAY"

# External Script
if [ "$CORE" = external ]; then
	echo "$(/opt/muos/script/system/extract_process.sh $ROM)" >/tmp/fg_proc
	/opt/muos/script/launch/ext-general.sh "$NAME" "$CORE" "$ROM"
# Amiberry External
elif [ "$CORE" = ext-amiberry ]; then
	/opt/muos/script/launch/ext-amiberry.sh "$NAME" "$CORE" "$ROM"
# Flycast External
elif [ "$CORE" = ext-flycast ]; then
	/opt/muos/script/launch/ext-flycast.sh "$NAME" "$CORE" "$ROM"
# Video Player (ffplay)
elif [ "$CORE" = ext-ffplay ]; then
	/opt/muos/script/launch/ext-ffplay.sh "$NAME" "$CORE" "$ROM"
# PPSSPP External
elif [ "$CORE" = ext-ppsspp ]; then
	/opt/muos/script/launch/ext-ppsspp.sh "$NAME" "$CORE" "$ROM"
# PICO-8 External
elif [ "$CORE" = ext-pico8 ]; then
	/opt/muos/script/launch/ext-pico8.sh "$NAME" "$CORE" "$ROM"
# DraStic External
elif [ "$CORE" = ext-drastic ]; then
	/opt/muos/script/launch/ext-drastic.sh "$NAME" "$CORE" "$ROM"
# DraStic External - Steward
elif [ "$CORE" = ext-drastic-steward ]; then
	/opt/muos/script/launch/ext-drastic-steward.sh "$NAME" "$CORE" "$ROM"
# Mupen64Plus External
elif [ "${CORE#ext-mupen64plus}" != "$CORE" ]; then
	/opt/muos/script/launch/ext-mupen64plus.sh "$NAME" "$CORE" "$ROM"
# ScummVM External
elif [ "$CORE" = ext-scummvm ]; then
	/opt/muos/script/launch/ext-scummvm.sh "$NAME" "$CORE" "$ROM"
# Flycast Extreme armhf LibRetro
elif [ "$CORE" = flycast_xtreme_libretro.so ]; then
	/opt/muos/script/launch/lr-flycastx.sh "$NAME" "$CORE" "$ROM"
# ScummVM LibRetro
elif [ "$CORE" = scummvm_libretro.so ]; then
	/opt/muos/script/launch/lr-scummvm.sh "$NAME" "$CORE" "$ROM"
# PrBoom LibRetro
elif [ "$CORE" = prboom_libretro.so ]; then
	/opt/muos/script/launch/lr-prboom.sh "$NAME" "$CORE" "$ROM"
# EasyRPG LibRetro
elif [ "$CORE" = easyrpg_libretro.so ]; then
	/opt/muos/script/launch/lr-easyrpg.sh "$NAME" "$CORE" "$ROM"
# NX Engine (Cave Story)
elif [ "$CORE" = nxengine_libretro.so ]; then
	/opt/muos/script/launch/lr-nxengine.sh "$NAME" "$CORE" "$ROM"
# Standard Libretro
else
	/opt/muos/script/launch/lr-general.sh "$NAME" "$CORE" "$ROM"
fi

echo 1 >"$DC_DEV_LED"
echo 1 >/tmp/work_led_state

echo explore >"$ACT_GO"

cat /dev/zero >"$DC_SCR_DEVICE" 2>/dev/null

if [ "$GC_GEN_STARTUP" = last ] || [ "$GC_GEN_STARTUP" = resume ]; then
	if [ ! -e "/tmp/manual_launch" ]; then
		echo launcher >"$ACT_GO"
	fi
fi

killall -q "$GPTOKEYB_BIN" "$EVSIEVE_BIN"

case "$DC_DEV_NAME" in
	RG*)
		echo 0 > "/sys/class/power_supply/axp2202-battery/nds_pwrkey"
		FB_SWITCH "$DC_SCR_WIDTH" "$DC_SCR_HEIGHT" 32
		;;
	*)
		FB_SWITCH "$DC_SCR_WIDTH" "$DC_SCR_HEIGHT" 32
		;;
esac

if [ "$GC_WEB_SYNCTHING" -eq 1 ] && [ "$(cat "$DC_NET_STATE")" = "up" ]; then
	SYNCTHING_ADDRESS=$(cat /opt/muos/config/address.txt)
	SYNCTHING_API=$(cat /mnt/mmc/MUOS/syncthing/api.txt)
	curl -X POST -H "X-API-Key: $SYNCTHING_API" "$SYNCTHING_ADDRESS:7070/rest/db/scan"
fi

if [ -s "/mnt/mmc/MUOS/discord/pc_ip.txt" ]; then
	python /mnt/mmc/MUOS/discord/discord_presence_handheld.py "$PC_IP" --clear
fi

pkill -CONT "$SUSPEND_APP"
