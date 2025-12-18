#!/bin/sh

. /opt/muos/script/var/func.sh

QUIT_LID_PROC="/tmp/quit_lid_proc"

while :; do
	[ -e "$QUIT_LID_PROC" ] && exit 0

	if [ "$(GET_VAR "config" "settings/advanced/lidswitch")" -eq 1 ]; then
		HALL_KEY="/sys/class/power_supply/axp2202-battery/hallkey"
		[ "$(cat "$HALL_KEY")" = "0" ] && /opt/muos/script/system/suspend.sh
	fi

	sleep 0.25
done &
