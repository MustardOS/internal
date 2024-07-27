#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/battery.sh
. /opt/muos/script/var/device/cpu.sh
. /opt/muos/script/var/device/device.sh
. /opt/muos/script/var/device/storage.sh

. /opt/muos/script/var/global/boot.sh

if [ "$(cat "$DC_BAT_CHARGER")" -eq 1 ] && [ "$GC_BOO_FACTORY_RESET" -eq 0 ]; then
	/opt/muos/device/rg40xx/script/led_control.sh 1 0 0 0 0 0 0 0

	mount -t "$DC_STO_ROM_TYPE" -o rw,utf8,noatime,nofail /dev/"$DC_STO_ROM_DEV"p"$DC_STO_ROM_NUM" "$DC_STO_ROM_MOUNT"

	if [ "$DC_DEV_DEBUGFS" -eq 1 ]; then
		mount -t debugfs debugfs /sys/kernel/debug
	fi

	echo "powersave" >"$DC_CPU_GOVERNOR"

	/opt/muos/extra/muxcharge

	umount "$DC_STO_ROM_MOUNT"
fi
