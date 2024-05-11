#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

NET_DNS=$(parse_ini "$CONFIG" "network" "dns")

while true; do
	if ping -q -c 1 "$NET_DNS" > /dev/null; then
		echo "1" > /tmp/mux_ping
	else
		echo "0" > /tmp/mux_ping
	fi

	sleep 10
done &

