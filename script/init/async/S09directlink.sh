#!/bin/sh

[ -n "$MUOS_FUNC_LOADED" ] || . /opt/muos/script/var/func.sh

HAS_NETWORK=$(GET_VAR "device" "board/network")

DO_START() {
	# No networking hardware means there is nothing a cable could join
	[ "$HAS_NETWORK" -eq 1 ] || return 0

	LOG_INFO "$0" 0 "BOOTING" "Direct Link Watcher"
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
