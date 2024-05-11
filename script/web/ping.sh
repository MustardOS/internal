#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

while true; do
	NET_ENABLED=$(parse_ini "$CONFIG" "network" "enabled")
	NET_DNS=$(parse_ini "$CONFIG" "network" "dns")

	NET_VISUAL=$(parse_ini "$CONFIG" "visual" "network")
	
	if [ "$NET_ENABLED" -eq 1 ] && [ "$NET_VISUAL" -eq 1 ]; then
		if ping -q -c 1 "$NET_DNS" > /dev/null; then
			echo "1" > /tmp/mux_ping
		else
			echo "0" > /tmp/mux_ping
		fi
	fi

	sleep 10
done &

