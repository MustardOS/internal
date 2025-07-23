#!/bin/sh

. /opt/muos/script/var/func.sh

HAS_NETWORK=$(GET_VAR "device" "board/network")
IFCE=$(GET_VAR "device" "network/iface")

[ "$HAS_NETWORK" -eq 1 ] && /opt/muos/script/system/network.sh disconnect

case "$(GET_VAR "device" "board/name")" in
	tui*) /opt/muos/device/script/module.sh load-network ;;
	*) ;;
esac

WAIT_IFACE=20
while [ "$WAIT_IFACE" -gt 0 ]; do
	[ -d "/sys/class/net/$IFCE" ] && break

	/opt/muos/bin/toybox sleep 1
	WAIT_IFACE=$((WAIT_IFACE - 1))
done

ip link set dev "$IFCE" down
/usr/bin/macchanger -r "$IFCE"

SET_VAR "config" "network/mac" "$NEW_MAC"

case "$(GET_VAR "device" "board/name")" in
	tui*) /opt/muos/device/script/module.sh unload-network ;;
	*) ;;
esac
