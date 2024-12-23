#!/bin/sh

. /opt/muos/script/var/func.sh

while :; do
	if [ "$(GET_VAR "global" "web/ntp")" -eq 1 ]; then
		nice -2 ntpdate -b "$(GET_VAR "global" "clock/pool")" >/dev/null &
		NTP_PID=$!
		wait $NTP_PID
		hwclock -w
	fi
	sleep 10
done &
