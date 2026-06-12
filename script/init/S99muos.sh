#!/bin/sh

. /opt/muos/script/var/func.sh

FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")

DO_START() {
	if [ "$FACTORY_RESET" -eq 1 ]; then
		LED_CONTROL_CHANGE off
		/opt/muos/script/system/factory.sh
		/opt/muos/script/system/halt.sh reboot

		exit 0
	fi

	ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount")

	LOG_INFO "$0" 0 "BOOTING" "Copying Root Home Files"
	if [ ! -f /root/.profile ] || find /opt/muos/share/root/.profile -prune -newer /root/.profile -print -quit 2>/dev/null | grep -q .; then
		cp -rf /opt/muos/share/root/. /root/
	fi

	USB_FUNCTION=$(GET_VAR "config" "settings/advanced/usb_function")
	FIRST_INIT=$(GET_VAR "config" "boot/first_init")
	RA_CACHE=$(GET_VAR "config" "settings/advanced/retrocache")

	LOG_INFO "$0" 0 "BOOTING" "Removing Existing Update Scripts"
	rm -rf "/opt/update.sh"

	LOG_INFO "$0" 0 "BOOTING" "Removing Temporary Downloads"
	rm -rf "/opt/muos/temp_dl"

	if [ "${CONSOLE_MODE:-0}" -eq 0 ]; then
		LOG_INFO "$0" 0 "BOOTING" "Detecting Charge Mode"
		LED_CONTROL_CHANGE off
		/opt/muos/script/device/charge.sh
	fi

	LOG_INFO "$0" 0 "BOOTING" "Starting Hotkey Daemon"
	HOTKEY start

	LOG_INFO "$0" 0 "BOOTING" "Starting muX Frontend"
	FRONTEND start

	LOG_INFO "$0" 0 "BOOTING" "Checking Swap Requirements"
	/opt/muos/script/system/swap.sh &

	LOG_INFO "$0" 0 "BOOTING" "Storage Authenticity Check"
	/opt/muos/script/system/checkmsd.sh &

	LOG_INFO "$0" 0 "BOOTING" "Purging Old Logs"
	LOG_CLEANER &

	LOG_INFO "$0" 0 "BOOTING" "Starting Low Power Indicator"
	/opt/muos/script/system/lowpower.sh &

	if [ "$USB_FUNCTION" -ne 0 ]; then
		LOG_INFO "$0" 0 "BOOTING" "Starting USB Function"
		/opt/muos/script/system/usb_gadget.sh start &
	fi

	LOG_INFO "$0" 0 "BOOTING" "Setting Device Controls"
	if [ "$FIRST_INIT" -eq 0 ]; then
		/opt/muos/script/device/control.sh FORCE_COPY &
	else
		/opt/muos/script/device/control.sh &
	fi

	LOG_INFO "$0" 0 "BOOTING" "Setting up SDL Controller Map"
	/opt/muos/script/mux/sdl_map.sh &

	LOG_INFO "$0" 0 "BOOTING" "Running Catalogue Generator"
	/opt/muos/script/system/catalogue.sh &

	if [ "${RA_CACHE:-0}" -eq 1 ]; then
		LOG_INFO "$0" 0 "BOOTING" "Precaching RetroArch System"
		ionice -c idle /opt/muos/bin/vmtouch -tfb "$MUOS_SHARE_DIR/conf/preload.txt" &
	fi

	LOG_INFO "$0" 0 "BOOTING" "Saving Kernel Boot Log"
	dmesg >"$ROM_MOUNT/MUOS/log/dmesg/dmesg__$(date +"%Y_%m_%d__%H_%M_%S").log" &

	[ "$FIRST_INIT" -eq 0 ] && SET_VAR "config" "boot/first_init" "1"
}

DO_STOP() {
	LOG_INFO "$0" 0 "SHUTDOWN" "Stopping USB Function"
	/opt/muos/script/system/usb_gadget.sh stop

	LOG_INFO "$0" 0 "SHUTDOWN" "Stopping muX Frontend"
	FRONTEND stop

	LOG_INFO "$0" 0 "SHUTDOWN" "Stopping Hotkey Daemon"
	HOTKEY stop
}

case "$1" in
	start)
		DO_START
		;;
	stop)
		DO_STOP
		;;
	restart)
		DO_STOP
		DO_START
		;;
	*)
		printf "Usage: %s {start|stop|restart}\n" "$0" >&2
		exit 1
		;;
esac
