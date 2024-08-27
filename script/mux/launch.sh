#!/bin/sh

. /opt/muos/script/var/func.sh

ACT_GO=/tmp/act_go
ROM_GO=/tmp/rom_go

GPTOKEYB_BIN=gptokeyb2
GPTOKEYB_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb"
GPTOKEYB_CONTROLLERCONFIG="/usr/lib/gamecontrollerdb.txt"
GPTOKEYB_CONFDIR="/opt/muos/config/gptokeyb"

export EVSIEVE_BIN=evsieve
export EVSIEVE_DIR="/opt/muos/bin"
export EVSIEVE_CONFDIR="/opt/muos/config/evsieve"

LAST_PLAY="/opt/muos/config/lastplay.txt"
ROM_LAST=/tmp/rom_last

if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
	nice --20 /opt/muos/extra/muxpass -t launch
	if [ "$?" = 2 ]; then
		rm "$ROM_GO"
		echo explore >"$ACT_GO"
		exit
	fi
fi

cat "$ROM_GO" >"$ROM_LAST"

NAME=$(sed -n '1p' "$ROM_GO")
CORE=$(sed -n '2p' "$ROM_GO" | tr -d '\n')
R_DIR=$(sed -n '5p' "$ROM_GO")$(sed -n '6p' "$ROM_GO")
ROM="$R_DIR"/$(sed -n '7p' "$ROM_GO")
PC_IP="$(GET_VAR "device" "storage/rom/mount")/MUOS/discord/pc_ip.txt"

if [ -s "$PC_IP" ]; then
	python "$(GET_VAR "device" "storage/rom/mount")/MUOS/discord/discord_presence_handheld.py" "$(cat "$PC_IP")" \
		"On my $(GET_VAR "device" "board/name") with muOS $(cat /opt/muos/config/version.txt)!" "Playing $NAME"
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

GET_VAR "global" "settings/advanced/led" >"$(GET_VAR "device" "board/led")"
GET_VAR "global" "settings/advanced/led" >/tmp/work_led_state

cat "$ROM_LAST" >"$LAST_PLAY"

# External Script
if [ "$CORE" = external ]; then
	SET_VAR "system" "foreground_process" "$(/opt/muos/script/system/extract_process.sh "$ROM")"
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
# OpenBOR External
elif [ "${CORE#ext-openbor}" != "$CORE" ]; then
	/opt/muos/script/launch/ext-openbor.sh "$NAME" "$CORE" "$ROM"
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
# Flycast Extreme LibRetro
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

echo 1 >"$(GET_VAR "device" "board/led")"
echo 1 >/tmp/work_led_state

echo explore >"$ACT_GO"

cat /dev/zero >"$(GET_VAR "device" "screen/device")" 2>/dev/null

if [ "$(GET_VAR "global" "settings/general/startup")" = last ] || [ "$(GET_VAR "global" "settings/general/startup")" = resume ]; then
	if [ ! -e "/tmp/manual_launch" ]; then
		echo launcher >"$ACT_GO"
	fi
fi

killall -q "$GPTOKEYB_BIN" "$EVSIEVE_BIN"

echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey" 1>&2
FB_SWITCH "$(GET_VAR "device" "screen/width")" "$(GET_VAR "device" "screen/height")" 32

if [ "$(GET_VAR "global" "web/syncthing")" -eq 1 ] && [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ]; then
	SYNCTHING_ADDRESS=$(cat /opt/muos/config/address.txt)
	SYNCTHING_API=$(cat "$(GET_VAR "device" "storage/rom/mount")/MUOS/syncthing/api.txt")
	curl -X POST -H "X-API-Key: $SYNCTHING_API" "$SYNCTHING_ADDRESS:7070/rest/db/scan"
fi

if [ -s "$PC_IP" ]; then
	python "$(GET_VAR "device" "storage/rom/mount")/MUOS/discord/discord_presence_handheld.py" "$(cat "$PC_IP")" --clear
fi
