#!/bin/sh

[ -n "$MUOS_LOG_LOADED" ] || . /opt/muos/script/var/log.sh
. /opt/muos/script/var/emulator.sh

FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")
[ "$FACTORY_RESET" -eq 1 ] && exit 0

OVERDRIVE=$(GET_VAR "config" "settings/advanced/overdrive")
THERMAL=$(GET_VAR "config" "settings/advanced/thermal")

BOARD_NAME=$(GET_VAR "device" "board/name")
HAS_TOUCH=$(GET_VAR "device" "board/touch")

INIT_SELF="/opt/muos/script/init/async/S05device.sh"

# Install a flat binary if its MD5 differs from the installed copy.
RUN_DEFERRED_EMULATOR_MAINTENANCE() {
	WAIT_COUNT=0
	while [ ! -e "$MUOS_RUN_DIR/first_paint" ] && [ "$WAIT_COUNT" -lt 200 ]; do
		sleep 0.1
		WAIT_COUNT=$((WAIT_COUNT + 1))
	done
	EMULATORS_CURRENT "$1" && return 0
	ionice -c 3 nice -n 10 "$INIT_SELF" maintenance "$1" ||
		LOG_WARN "$INIT_SELF" 0 "DEVICE" "Emulator maintenance reported an error"
}

DO_START() {
	(
		if [ "$OVERDRIVE" -eq 1 ]; then
			SET_VAR "device" "audio/max" "200"
		else
			SET_VAR "device" "audio/max" "100"
		fi
	) &

	(
		if [ "$THERMAL" -eq 0 ]; then
			for ZONE in /sys/class/thermal/thermal_zone*; do
				[ -e "$ZONE/mode" ] && printf "disabled" >"$ZONE/mode"
			done
		fi
	) &

	rfkill unblock all 2>/dev/null

	# Set up indicator LEDs for devices that drive bare GPIOs
	RUN_DEVICE_SCRIPT led.sh &

	/opt/muos/frontend/tool/muidle boot

	# Adjust headphone output for certain devices
	/opt/muos/script/device/headphone.sh watch &

	# Follow headphone jacks and USB-C headphones and earbuds as they come and go
	/opt/muos/script/var/process.sh start muaudio /opt/muos/frontend/daemon/muaudio "$(GET_VAR "device" "board/name")"

	# Swap the speaker audio if set
	/opt/muos/script/device/speaker.sh &

	# Calibrate user setting joystick values if set
	/opt/muos/script/device/joycal.sh &

	case "$BOARD_NAME" in
		rg-vita*)
			if [ "$HAS_TOUCH" -eq 1 ]; then
				# Initialise Touch Screen
				modprobe synaptics_dsx_core
				modprobe synaptics_dsx_i2c
			fi
			;;
		mgx* | tui*)
			# Modified GPU parameters
			echo 0 >/sys/module/pvrsrvkm/parameters/PVRDebugLevel

			# Some stupid TrimUI GPU shenanigans
			setalpha 0
			;;
	esac

	/opt/muos/script/var/process.sh start device-maintenance "$INIT_SELF" maintenance-ready "$(EMULATOR_VARIANT)"
}

case "$1" in
	start)
		DO_START
		;;
	stop)
		/opt/muos/script/var/process.sh stop-group device-maintenance >/dev/null 2>&1
		/opt/muos/script/var/process.sh stop muaudio >/dev/null 2>&1
		;;
	restart)
		DO_START
		;;
	maintenance)
		INSTALL_EMULATORS "$2"
		;;
	maintenance-ready)
		RUN_DEFERRED_EMULATOR_MAINTENANCE "$2"
		;;
	*)
		printf "Usage: %s {start|stop|restart|maintenance|maintenance-ready EMULATOR_VARIANT}\n" "$0" >&2
		exit 1
		;;
esac
