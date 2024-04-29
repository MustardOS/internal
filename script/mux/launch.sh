#!/bin/sh
# shellcheck disable=1090,2002

ACT_GO=/tmp/act_go
ROM_GO=/tmp/rom_go

SUSPEND_APP=muxplore

GPTOKEYB_BIN=gptokeyb
GPTOKEYB_DIR=/mnt/mmc/MUOS/emulator/gptokeyb
GPTOKEYB_CONTROLLERCONFIG="$GPTOKEYB_DIR/gamecontrollerdb.txt"
GPTOKEYB_CONFDIR=/opt/muos/config/gptokeyb

export EVSIEVE_BIN=evsieve
export EVSIEVE_DIR=/opt/muos/bin
export EVSIEVE_CONFDIR=/opt/muos/config/evsieve

LAST_PLAY="/opt/muos/config/lastplay.txt"
ROM_LAST=/tmp/rom_last

BGM_PID=/tmp/playbgm.pid
SND_PIPE=/tmp/muplay_pipe

KILL_BGM() {
	if [ -n "$(cat "$BGM_PID")" ]; then
		kill "$(cat "$BGM_PID")"
		echo "" > "$BGM_PID"
	fi
	pkill -f "mp3play"
	pkill -f "playbgm.sh"
}

KILL_SND() {
	echo "quit" > "$SND_PIPE"
	pkill -f "muplay"
	rm "$SND_PIPE"
}

if [ -s "$ROM_GO" ]; then
	pkill -STOP "$SUSPEND_APP"
	
	sed -i '4 d' "$ROM_GO"
	cat "$ROM_GO" > "$ROM_LAST"

	NAME=$(sed -n '1p' "$ROM_GO")
	CORE=$(sed -n '2p' "$ROM_GO" | tr -d '\n')
	R_DIR=$(sed -n '4p' "$ROM_GO")$(sed -n '5p' "$ROM_GO")
	ROM="$R_DIR"/$(sed -n '6p' "$ROM_GO")

	rm "$ROM_GO"

	if [ -f "$GPTOKEYB_CONFDIR/$CORE.gptk" ]; then
		SDL_GAMECONTROLLERCONFIG_FILE="$GPTOKEYB_CONTROLLERCONFIG" \
		"$GPTOKEYB_DIR/$GPTOKEYB_BIN" -c "$GPTOKEYB_CONFDIR/$CORE.gptk" &
	fi

	if [ -f "$EVSIEVE_CONFDIR/$CORE.evs.sh" ]; then
		"$EVSIEVE_CONFDIR/$CORE.evs.sh"
	fi

	if [ "$MSOUND" -eq 1 ]; then
		KILL_BGM
	fi
	if [ "$MSOUND" -eq 2 ]; then
		KILL_SND
	fi

	echo 0 > /sys/class/power_supply/axp2202-battery/work_led

	# External Script
	if [ "$CORE" = external ]; then
		/opt/muos/script/launch/ext-general.sh "$NAME" "$CORE" "$ROM"
    	# Amiberry External
    	elif [ "$CORE" = ext-amiberry ]; then
    	    	/opt/muos/script/launch/ext-amiberry.sh "$NAME" "$CORE" "$ROM"
    	# Flycast External
    	elif [ "$CORE" = ext-flycast ]; then
    	    	/opt/muos/script/launch/ext-flycast.sh "$NAME" "$CORE" "$ROM"
    	# PPSSPP External
    	elif [ "$CORE" = ext-ppsspp ]; then
    	    	/opt/muos/script/launch/ext-ppsspp.sh "$NAME" "$CORE" "$ROM"
	# PICO-8 External
	elif [ "$CORE" = ext-pico8 ]; then
		/opt/muos/script/launch/ext-pico8.sh "$NAME" "$CORE" "$ROM"
	# DraStic External
	elif [ "$CORE" = ext-drastic ]; then
		/opt/muos/script/launch/ext-drastic.sh "$NAME" "$CORE" "$ROM"
	# Mupen64Plus External
	elif [[ "$CORE" == ext-mupen64plus* ]]; then
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

	echo 1 > /sys/class/power_supply/axp2202-battery/work_led

	echo explore > "$ACT_GO"

	cat "$ROM_LAST" > "$LAST_PLAY"
	[ "$(cat "$ACT_GO")" = last ] && echo launcher > "$ACT_GO"

	killall "$GPTOKEYB_BIN"
	killall "$EVSIEVE_BIN"

	if [ "$(cat "/opt/muos/config/device.txt")" != "RG28XX" ]; then
		fbset -fb /dev/fb0 -g 640 480 640 480 32
	fi

	pkill -CONT "$SUSPEND_APP"
fi

