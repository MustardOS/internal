#!/bin/sh

FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")
GOVERNOR=$(GET_VAR "device" "cpu/governor")
DEBUG_FS=$(GET_VAR "device" "board/debugfs")
WIDTH=$(GET_VAR "device" "screen/internal/width")
HEIGHT=$(GET_VAR "device" "screen/internal/height")

DO_START() {
	LOG_INFO "$0" 0 "BOOTING" "Creating Required Run Directory"
	mkdir -p "$MUOS_RUN_DIR"

	# Set console_loglevel to 0 unless debug mode is enabled
	[ "$(GET_DEBUG)" -eq 0 ] && printf "%d" 0 >/proc/sys/kernel/printk

	grep -qE "defaults\.(ctl|pcm)\.card [1-9]" /usr/share/alsa/alsa.conf 2>/dev/null && \
		sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf

	LOG_INFO "$0" 0 "BOOTING" "Setting 'performance' Governor"
	printf "performance" >"$GOVERNOR"

	LED_CONTROL_CHANGE off

	[ "$DEBUG_FS" -eq 1 ] && mount -t debugfs debugfs /sys/kernel/debug

	/opt/muos/script/device/module.sh load

	[ "$FACTORY_RESET" -eq 1 ] && /opt/muos/frontend/muwarn &

	mkdir -p "/tmp/muos"
	rm -rf "$MUOS_LOG_DIR"/*.log "/opt/muxtmp"

	IFS= read -r MU_UPTIME _ </proc/uptime

	SET_VAR "system" "resume_uptime" "$MU_UPTIME"
	SET_VAR "system" "idle_inhibit" "0"
	SET_VAR "config" "boot/device_mode" "0"
	SET_VAR "device" "audio/ready" "0"

	(
		SET_VAR "device" "screen/width" "$WIDTH"
		SET_VAR "device" "screen/height" "$HEIGHT"
		SET_VAR "device" "mux/width" "$WIDTH"
		SET_VAR "device" "mux/height" "$HEIGHT"
	) &

	LOG_INFO "$0" 0 "BOOTING" "Setting OS Release"
	/opt/muos/script/system/os_release.sh &

	printf "1" >"$MUOS_RUN_DIR/work_led_state"
	: >"$MUOS_RUN_DIR/net_start"

	LOG_INFO "$0" 0 "BOOTING" "Starting Battery Watchdog"
	BATTERY start

	LOG_INFO "$0" 0 "BOOTING" "Reset temporary screen rotation and zoom"
	rm -f "/opt/muos/device/config/screen/s_rotate" "/opt/muos/device/config/screen/s_zoom" &
}

DO_STOP() {
	timeout 5 sh -c 'BATTERY stop' 2>/dev/null
	[ "$DEBUG_FS" -eq 1 ] && umount /sys/kernel/debug 2>/dev/null

	if ! timeout 10 /opt/muos/script/device/module.sh unload; then
		LOG_WARN "$0" 0 "SHUTDOWN" "Module unload timed out or failed... continuing!"
	fi
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
