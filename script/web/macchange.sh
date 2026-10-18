#!/bin/sh

. /opt/muos/script/var/config.sh

HAS_NETWORK=$(GET_VAR "device" "board/network")
[ "$HAS_NETWORK" -eq 0 ] && exit 0

IFCE=$(GET_VAR "device" "network/iface")

/opt/muos/script/init/async/S02network.sh stop
/opt/muos/script/init/async/S02network.sh start

WAIT_IFACE=20
while [ "$WAIT_IFACE" -gt 0 ]; do
	[ -d "/sys/class/net/$IFCE" ] && break

	sleep 1
	WAIT_IFACE=$((WAIT_IFACE - 1))
done

ip link set dev "$IFCE" down
NEW_MAC=$(/usr/bin/macchanger -r "$IFCE" | awk '/^New MAC:/{print $3}')

SET_VAR "config" "network/mac" "$NEW_MAC"
/opt/muos/script/init/async/S02network.sh stop
