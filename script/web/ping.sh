#!/bin/sh

. /opt/muos/script/var/func.sh

P_COUNT=0

while true; do
	. /opt/muos/script/var/global/network.sh
	. /opt/muos/script/var/global/visual.sh

	if [ "$GC_NET_ENABLED" -eq 1 ] && [ "$GC_VIS_NETWORK" -eq 1 ]; then
		if [ "$P_COUNT" -eq 10 ]; then
			if ping -q -c 1 "$GC_NET_DNS" >/dev/null; then
				echo "1" >/tmp/mux_ping
			else
				echo "0" >/tmp/mux_ping
			fi
			P_COUNT=0
		fi
		P_COUNT=$((P_COUNT + 1))
	else
		echo "0" >/tmp/mux_ping
		P_COUNT=0
	fi

	sleep 2
done &
