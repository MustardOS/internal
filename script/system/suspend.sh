#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/cpu.sh
. /opt/muos/script/var/device/device.sh

. /opt/muos/script/var/global/setting_advanced.sh

OG_GOV=$(cat "$DC_CPU_GOVERNOR")
echo "powersave" >"$DC_CPU_GOVERNOR"

for C in $(seq 1 $((DC_CPU_CORES - 1))); do
	echo 0 >"/sys/devices/system/cpu/cpu${C}/online"
done

sleep 0.1
echo "$GC_ADV_POWER_STATE" >"/sys/power/state"
sleep 0.1

for C in $(seq 1 $((DC_CPU_CORES - 1))); do
	echo 1 >"/sys/devices/system/cpu/cpu${C}/online"
done

echo "$OG_GOV" >"$DC_CPU_GOVERNOR"
