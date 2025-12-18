#!/bin/sh

. /opt/muos/script/var/func.sh

while :; do
	if [ "$(GET_VAR "config" "web/ntp")" -eq 1 ]; then
		ntpdate -b "$(GET_VAR "config" "clock/pool")" >/dev/null &
		NTP_PID=$!
		wait $NTP_PID
		hwclock -w
	fi
	sleep 10
done &
