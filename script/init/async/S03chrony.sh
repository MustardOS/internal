#!/bin/sh

. /opt/muos/script/var/func.sh

DAEMON="/opt/muos/bin/chronyd"
CONF="/opt/muos/share/conf/chrony.conf"
PID_FILE="/run/chronyd.pid"

# For the H700 make sure we use "sunxi-rtc" which is on "rtc1"
# You can confirm correct RTC connection with: chronyc rtcdata
case "$(GET_VAR "device" "board/name")" in
	rg*) ln -sf "rtc1" "/dev/rtc" ;;
esac

IS_RUNNING() {
	[ -f "$PID_FILE" ] && IFS= read -r CHRONY_PID <"$PID_FILE" 2>/dev/null && kill -0 "$CHRONY_PID" 2>/dev/null && return 0
	pidof chronyd >/dev/null 2>&1
}

case "$1" in
	start)
		if IS_RUNNING; then
			echo "chronyd already running"
			exit 0
		fi

		echo "Starting chronyd"
		"$DAEMON" -f "$CONF" >/dev/null 2>&1 &
		printf "%s" "$!" >"$PID_FILE"
		;;

	stop)
		if IS_RUNNING; then
			echo "Stopping chronyd"
			[ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null
			rm -f "$PID_FILE"
			killall chronyd 2>/dev/null
		else
			echo "chronyd not running"
		fi
		;;

	restart | reload)
		"$0" stop
		"$0" start
		;;

	status)
		if IS_RUNNING; then
			echo "chronyd is running"
		else
			echo "chronyd is stopped"
			exit 1
		fi
		;;

	*)
		echo "Usage: $0 {start|stop|restart|status}"
		exit 1
		;;
esac

exit 0
