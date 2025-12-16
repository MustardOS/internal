#!/bin/sh

. /opt/muos/script/var/func.sh

HAS_NETWORK=$(GET_VAR "device" "board/network")
[ "$HAS_NETWORK" -eq 0 ] && exit 0

IFCE=$(GET_VAR "device" "network/iface")

/opt/muos/script/system/network.sh disconnect
/opt/muos/script/device/network.sh load

WAIT_IFACE=20
while [ "$WAIT_IFACE" -gt 0 ]; do
	[ -d "/sys/class/net/$IFCE" ] && break

	sleep 1
	WAIT_IFACE=$((WAIT_IFACE - 1))
done

ip link set dev "$IFCE" down
/usr/bin/macchanger -r "$IFCE"

SET_VAR "config" "network/mac" "$NEW_MAC"
/opt/muos/script/device/network.sh unload
