#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/global/clock.sh
. /opt/muos/script/var/global/web_service.sh

while true; do
	if [ "$GC_WEB_NTP" -eq 1 ]; then
		nice -2 ntpdate -b "$GC_CLK_POOL" >/dev/null &
		NTP_PID=$!
		wait $NTP_PID
		hwclock -w
	fi
	sleep 10
done &
