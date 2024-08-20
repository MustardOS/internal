#!/bin/sh

. /opt/muos/script/var/func.sh

if [ "$(cat "$(GET_VAR "device" "battery/charger")")" -eq 1 ] && [ "$(GET_VAR "global" "boot/factory_reset")" -eq 0 ]; then
	/opt/muos/device/rg40xx-h/script/led_control.sh 1 0 0 0 0 0 0 0

	mount -t "$(GET_VAR "device" "storage/rom/type")" -o rw,utf8,noatime,nofail /dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")" "$(GET_VAR "device" "storage/rom/mount")"

	if [ "$(GET_VAR "device" "board/debugfs")" -eq 1 ]; then
		mount -t debugfs debugfs /sys/kernel/debug
	fi

	echo "powersave" >"$(GET_VAR "device" "cpu/governor")"

	if ! /opt/muos/extra/muxcharge; then
		/opt/muos/script/system/halt.sh poweroff
	fi

	umount "$(GET_VAR "device" "storage/rom/mount")"
fi
