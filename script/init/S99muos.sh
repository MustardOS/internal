#!/bin/sh

[ -n "$MUOS_FUNC_LOADED" ] || . /opt/muos/script/var/func.sh

FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")

INIT_SELF="/opt/muos/script/init/S99muos.sh"

CAPTURE_G350_PSTORE() {
	[ "$(GET_VAR "device" "board/name")" = rk-g350-v ] || return 0
	[ -d /sys/fs/pstore ] || return 0

	if ! grep -qs ' /sys/fs/pstore pstore ' /proc/mounts; then
		mount -t pstore pstore /sys/fs/pstore 2>/dev/null || return 0
	fi

	G350_PSTORE_DIR=/opt/muos/config/g350-pstore
	mkdir -p "$G350_PSTORE_DIR"

	for G350_PSTORE_SOURCE in /sys/fs/pstore/*; do
		[ -f "$G350_PSTORE_SOURCE" ] || continue
		G350_PSTORE_NAME=${G350_PSTORE_SOURCE##*/}
		cp "$G350_PSTORE_SOURCE" "$G350_PSTORE_DIR/$G350_PSTORE_NAME"
	done
}

RUN_BOOT_MAINTENANCE() {
	ROM_MOUNT=$1
	FIRST_INIT=$2
	RA_CACHE=$3
	BOOT_RESULT=0

	/opt/muos/script/system/swap.sh &
	BOOT_SWAP=$!
	/opt/muos/script/system/irq.sh &
	BOOT_IRQ=$!
	/opt/muos/script/system/checkmsd.sh &
	BOOT_STORAGE=$!
	if [ "$FIRST_INIT" -eq 0 ]; then
		/opt/muos/script/device/control.sh FORCE_COPY &
	else
		/opt/muos/script/device/control.sh &
	fi
	BOOT_CONTROL=$!
	for BOOT_PID in "$BOOT_SWAP" "$BOOT_IRQ" "$BOOT_STORAGE" "$BOOT_CONTROL"; do
		wait "$BOOT_PID" || BOOT_RESULT=1
	done

	/opt/muos/script/mux/sdl_map.sh &
	BOOT_MAP=$!
	ionice -c idle /opt/muos/script/system/catalogue.sh &
	BOOT_CATALOGUE=$!
	LOG_CLEANER &
	BOOT_LOGS=$!
	for BOOT_PID in "$BOOT_MAP" "$BOOT_CATALOGUE" "$BOOT_LOGS"; do
		wait "$BOOT_PID" || BOOT_RESULT=1
	done

	if [ "$RA_CACHE" -eq 1 ]; then
		ionice -c idle /opt/muos/bin/vmtouch -tfb "$MUOS_SHARE_DIR/conf/preload.txt" &
		BOOT_CACHE=$!
	else
		BOOT_CACHE=
	fi
	ionice -c idle sh -c 'dmesg >"$1"' sh "$ROM_MOUNT/MUOS/log/dmesg/dmesg__$(date +"%Y_%m_%d__%H_%M_%S").log" &
	BOOT_DMESG=$!
	[ -z "$BOOT_CACHE" ] || wait "$BOOT_CACHE" || BOOT_RESULT=1
	wait "$BOOT_DMESG" || BOOT_RESULT=1

	return "$BOOT_RESULT"
}

RUN_FRONTEND_READY_MAINTENANCE() {
	ROM_MOUNT=$1
	FIRST_INIT=$2
	RA_CACHE=$3
	WAIT_COUNT=0

	while [ ! -e "$MUOS_RUN_DIR/first_paint" ] && [ "$WAIT_COUNT" -lt 200 ]; do
		sleep 0.1
		WAIT_COUNT=$((WAIT_COUNT + 1))
	done

	ionice -c idle nice -n 10 "$INIT_SELF" maintenance "$ROM_MOUNT" "$FIRST_INIT" "$RA_CACHE" ||
		LOG_WARN "$INIT_SELF" 0 "BOOTING" "Deferred background maintenance reported an error"
}

WAIT_FOR_PRIORITY_STORAGE() {
	WAIT_COUNT=0
	while [ ! -e "$MUOS_STORE_DIR/mount_ready" ] && [ "$WAIT_COUNT" -lt 150 ]; do
		sleep 0.1
		WAIT_COUNT=$((WAIT_COUNT + 1))
	done

	[ -e "$MUOS_STORE_DIR/mount_ready" ] && return 0
	LOG_ERROR "$0" 0 "BOOTING" "Priority storage did not become ready"
	CRITICAL_FAILURE mount "priority storage"
	return 1
}

DO_START() {
	CAPTURE_G350_PSTORE

	if [ "$FACTORY_RESET" -eq 1 ]; then
		LED_CONTROL_CHANGE off
		/opt/muos/script/system/factory.sh
		/opt/muos/script/system/halt.sh reboot

		exit 0
	fi

	ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount")

	LOG_INFO "$0" 0 "BOOTING" "Copying Root Home Files"
	ROOT_HOME_SOURCE=/opt/muos/share/conf/rootfs/root
	if [ ! -f /root/.profile ] || find "$ROOT_HOME_SOURCE" -type f -newer /root/.profile -print -quit 2>/dev/null | grep -q .; then
		cp -rf "$ROOT_HOME_SOURCE/." /root/
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
		/opt/muos/script/device/charge.sh
	fi

	if [ "$FIRST_INIT" -eq 0 ]; then
		LOG_INFO "$0" 0 "BOOTING" "Completing first-start maintenance"
		if ! RUN_BOOT_MAINTENANCE "$ROM_MOUNT" "$FIRST_INIT" "${RA_CACHE:-0}" >/dev/null 2>&1; then
			LOG_WARN "$0" 0 "BOOTING" "First-start maintenance completed with errors"
		fi
		SET_VAR "config" "boot/first_init" "1"
	fi

	WAIT_FOR_PRIORITY_STORAGE || exit 1

	LOG_INFO "$0" 0 "BOOTING" "Starting Hotkey Daemon"
	HOTKEY start

	LOG_INFO "$0" 0 "BOOTING" "Starting muX Frontend"
	FRONTEND start

	LOG_INFO "$0" 0 "BOOTING" "Starting deferred init scripts"
	/opt/muos/script/var/process.sh start init-deferred "$INIT_SELF" deferred-init "/opt/muos/script/init/async"

	LOG_INFO "$0" 0 "BOOTING" "Starting Low Power Indicator"
	/opt/muos/script/var/process.sh start lowpower /opt/muos/script/system/lowpower.sh

	if [ "$USB_FUNCTION" -ne 0 ]; then
		LOG_INFO "$0" 0 "BOOTING" "Starting USB Function"
		/opt/muos/script/system/usb_gadget.sh start &
	fi

	if [ "$FIRST_INIT" -ne 0 ]; then
		LOG_INFO "$0" 0 "BOOTING" "Starting deferred background maintenance"
		/opt/muos/script/var/process.sh start boot-maintenance "$INIT_SELF" maintenance-ready \
			"$ROM_MOUNT" "$FIRST_INIT" "${RA_CACHE:-0}"
	fi
}

DO_STOP() {
	/opt/muos/script/var/process.sh stop-group init-deferred >/dev/null 2>&1
	/opt/muos/script/var/process.sh stop-group boot-maintenance >/dev/null 2>&1
	/opt/muos/script/var/process.sh stop lowpower >/dev/null 2>&1

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
	maintenance)
		RUN_BOOT_MAINTENANCE "$2" "$3" "$4"
		;;
	maintenance-ready)
		RUN_FRONTEND_READY_MAINTENANCE "$2" "$3" "$4"
		;;
	deferred-init)
		RUN_INIT_DEFERRED "$2"
		;;
	*)
		printf "Usage: %s {start|stop|restart|maintenance|maintenance-ready|deferred-init}\n" "$0" >&2
		exit 1
		;;
esac
