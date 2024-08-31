#!/bin/sh

. /opt/muos/script/var/func.sh

if [ "$(cat "$(GET_VAR "device" "battery/charger")")" -eq 1 ] && [ "$(GET_VAR "global" "boot/factory_reset")" -eq 0 ]; then
	SET_VAR "system" "foreground_process" "muxcharge"

	if [ "$(GET_VAR "device" "board/debugfs")" -eq 1 ]; then
		mount -t debugfs debugfs /sys/kernel/debug
	fi

	echo "powersave" >"$(GET_VAR "device" "cpu/governor")"

	if ! /opt/muos/extra/muxcharge; then
		/opt/muos/script/system/halt.sh poweroff
	fi

	echo "performance" >"$(GET_VAR "device" "cpu/governor")"
fi
