#!/bin/sh
# shellcheck disable=1090,2002

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

ACT_GO=/tmp/act_go
ROM_GO=/tmp/rom_go

SUSPEND_APP=muxplore

GPTOKEYB_BIN=gptokeyb2
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
        if pgrep -f "playbgm.sh" > /dev/null; then
                if [ -n "$(cat "$BGM_PID")" ]; then
                        kill "$(cat "$BGM_PID")"
                        echo "" > "$BGM_PID"
                fi
                killall -q "mp3play"
                killall -q "playbgm.sh"
        fi
}

KILL_SND() {
        if pgrep -f "muplay" > /dev/null; then
                echo "quit" > "$SND_PIPE"
                killall -q "muplay"
                rm "$SND_PIPE"
        fi
}

if [ -s "$ROM_GO" ]; then
	LOCK=$(parse_ini "$CONFIG" "settings.advanced" "lock")
	if [ "$LOCK" -eq 1 ]; then
		nice --20 /opt/muos/extra/muxpass -t launch
		if [ "$?" = 2 ]; then
			rm "$ROM_GO"
			echo explore > "$ACT_GO"
			exit
		fi
	fi

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

	MSOUND=$(parse_ini "$CONFIG" "settings.general" "sound")
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

	# Do it twice, it's just as nice!
	cat /dev/zero > /dev/fb0 2>/dev/null
	cat /dev/zero > /dev/mali0 2>/dev/null

	cat "$ROM_LAST" > "$LAST_PLAY"
	[ "$(cat "$ACT_GO")" = last ] && echo launcher > "$ACT_GO"

	killall -q "$GPTOKEYB_BIN"
	killall -q "$EVSIEVE_BIN"

	if [ "$(cat /opt/muos/config/device.txt)" != "RG28XX" ]; then
		fbset -fb /dev/fb0 -g 640 480 640 960 32
	fi

	pkill -CONT "$SUSPEND_APP"
fi

