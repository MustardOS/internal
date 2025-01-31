#!/bin/sh

. /opt/muos/script/var/func.sh

BOOT_MODE=$(GET_VAR "device" "battery/boot_mode")
FACTORY_RESET=$(GET_VAR "global" "boot/factory_reset")
DEBUGFS=$(GET_VAR "device" "board/debugfs")
GOVERNOR=$(GET_VAR "device" "cpu/governor")
LED=$(GET_VAR "device" "led/normal")
EXIT_STATUS="/tmp/charger_exit"

if read -r MODE <"$BOOT_MODE" && [ "$MODE" -eq 1 ] && [ "$FACTORY_RESET" -eq 0 ]; then
	[ "$DEBUGFS" -eq 1 ] && mount -t debugfs debugfs /sys/kernel/debug

	echo "powersave" >"$GOVERNOR"
	EXEC_MUX "" "muxcharge"

	[ "$(cat "$EXIT_STATUS")" -eq 1 ] && /opt/muos/script/system/halt.sh poweroff

	echo "performance" >"$GOVERNOR"
	echo 1 >"$LED"
fi
