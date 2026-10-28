#!/bin/sh

[ -n "$MUOS_RUNTIME_LOADED" ] || . /opt/muos/script/var/runtime.sh
[ -n "$MUOS_SERVICE_LOADED" ] || . /opt/muos/script/var/service.sh

case "${1:-start}" in
	start | restart) IN_SAFE_MODE && exit 0 ;;
esac

HAS_NETWORK=$(GET_VAR "device" "board/network")
HAS_UDC=$(GET_VAR "device" "board/udc")

DO_START() {
	[ "${HAS_NETWORK:-0}" -eq 1 ] || [ -n "$HAS_UDC" ] || return 0

	LOG_INFO "$0" 0 "BOOTING" "Device Link Watcher"
	DIRECTLINK start
}

case "$1" in
	start)
		DO_START
		;;
	stop)
		DIRECTLINK stop
		;;
	restart)
		DIRECTLINK restart
		;;
	*)
		printf "Usage: %s {start|stop|restart}\n" "$0" >&2
		exit 1
		;;
esac
