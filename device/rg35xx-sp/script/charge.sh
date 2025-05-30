#!/bin/sh

. /opt/muos/script/var/func.sh

BOOT_MODE=$(GET_VAR "device" "battery/boot_mode")
FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")
DEBUGFS=$(GET_VAR "device" "board/debugfs")
GOVERNOR=$(GET_VAR "device" "cpu/governor")
LED=$(GET_VAR "device" "led/normal")
EXIT_STATUS_FILE="/tmp/charger_exit"
QUIT_LID_PROC="/tmp/quit_lid_proc"

if read -r MODE <"$BOOT_MODE" && [ "$MODE" -eq 1 ] && [ "$FACTORY_RESET" -eq 0 ]; then
	[ "$DEBUGFS" -eq 1 ] && mount -t debugfs debugfs /sys/kernel/debug

	touch "$QUIT_LID_PROC"

	echo "powersave" >"$GOVERNOR"
	EXEC_MUX "" "muxcharge"

	[ "$(cat "$EXIT_STATUS_FILE")" -eq 1 ] && /opt/muos/script/system/halt.sh poweroff

	if [ -e "$QUIT_LID_PROC" ]; then
		rm "$QUIT_LID_PROC"
		/opt/muos/device/script/lid.sh &
	fi

	echo "performance" >"$GOVERNOR"
	echo 1 >"$LED"
fi
