#!/bin/sh

. /opt/muos/script/var/func.sh

while :; do
	if [ "$(GET_VAR "config" "web/ntp")" -eq 1 ]; then
		nice -2 ntpdate -b "$(GET_VAR "config" "clock/pool")" >/dev/null &
		NTP_PID=$!
		wait $NTP_PID
		hwclock -w
	fi
	TBOX sleep 10
done &
