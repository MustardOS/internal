#!/bin/sh

. /opt/muos/script/var/func.sh

IFCE=$(GET_VAR "device" "network/iface")

case "$(GET_VAR "device" "board/name")" in
	tui*) /opt/muos/device/script/module.sh load-network ;;
	*) ;;
esac

/usr/bin/macchanger -r "$IFCE"

case "$(GET_VAR "device" "board/name")" in
	tui*) /opt/muos/device/script/module.sh unload-network ;;
	*) ;;
esac
