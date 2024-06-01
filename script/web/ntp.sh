#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

while true; do
	SRV_NTP=$(parse_ini "$CONFIG" "web" "ntp")
	NTP_POOL=$(parse_ini "$CONFIG" "clock" "pool")

	if [ "$SRV_NTP" -eq 1 ]; then
		nice -2 ntpdate -b "$NTP_POOL" > /dev/null &
		NTP_PID=$!
		wait $NTP_PID
		hwclock -w
	fi

    sleep 10
done &

