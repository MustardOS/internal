#!/bin/sh

ENTROPY_FILE="/proc/sys/kernel/random/entropy_avail"
ENTROPY_TARGET=256

ENTROPY_OK() {
	IFS= read -r CURRENT <"$ENTROPY_FILE" 2>/dev/null
	[ -n "$CURRENT" ] && [ "$CURRENT" -ge "$ENTROPY_TARGET" ]
}

SEED_DIR="/var/lib/seedrng"

START() {
	mkdir -p "$SEED_DIR"
	SEED_CREDITED=0
	[ -s "$SEED_DIR/seed.credit" ] && SEED_CREDITED=1
	seedrng -d "$SEED_DIR" >/dev/null 2>&1 || SEED_CREDITED=0
	[ "$SEED_CREDITED" -eq 1 ] && return 0
	ENTROPY_OK && return 0
	nice -n 19 /usr/sbin/haveged -w 1024 -T 4 &
	(
		sleep 30
		seedrng -d "$SEED_DIR" >/dev/null 2>&1
	) &
}

STOP() {
	seedrng -d "$SEED_DIR" >/dev/null 2>&1
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
