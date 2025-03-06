#!/bin/sh

. /opt/muos/script/var/func.sh

while :; do
	HALL_KEY="/sys/class/power_supply/axp2202-battery/hallkey"
	if [ "$(cat "$HALL_KEY")" = "0" ]; then
		/opt/muos/script/system/suspend.sh
	fi
	sleep 0.25
done &
