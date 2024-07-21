#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/cpu.sh
. /opt/muos/script/var/device/device.sh

. /opt/muos/script/var/global/setting_advanced.sh

OG_GOV=$(cat "$DC_CPU_GOVERNOR")
echo "powersave" >"$DC_CPU_GOVERNOR"

for C in /sys/devices/system/cpu/cpu[1-3]/online; do
	echo 0 >"$C"
done

sleep 0.1
echo "$GC_ADV_POWER_STATE" >"/sys/power/state"
sleep 0.1

for C in /sys/devices/system/cpu/cpu[1-3]/online; do
	echo 1 >"$C"
done

echo "$OG_GOV" >"$DC_CPU_GOVERNOR"
