#!/bin/sh

ENTROPY_FILE="/proc/sys/kernel/random/entropy_avail"
ENTROPY_TARGET=256

ENTROPY_OK() {
	IFS= read -r CURRENT <"$ENTROPY_FILE" 2>/dev/null
	[ -n "$CURRENT" ] && [ "$CURRENT" -ge "$ENTROPY_TARGET" ]
}

START() {
	/opt/muos/bin/haveged -w 1024 -T 4 &
}

STOP() {
	killall -9 haveged 2>/dev/null
}

case "$1" in
	start) START ;;
	stop) STOP ;;
	restart)
		STOP
		START
		;;
	status)
		if ENTROPY_OK; then
			echo "Entropy OK"
			exit 0
		else
			echo "Entropy LOW"
			exit 1
		fi
		;;
	*)
		echo "Usage: $0 {start|stop|restart|status}"
		exit 1
		;;
esac

exit 0
