#!/bin/sh

PIDFILE="/run/messagebus.pid"
LOCKFILE="/var/lock/subsys/dbus-daemon"

mkdir -p "/run/dbus" "/var/lock/subsys" "/tmp/dbus"

RET_VAL=0

start() {
	printf "Starting system message bus: "

	dbus-uuidgen --ensure
	if dbus-daemon --system; then
		echo "done"
		touch "$LOCKFILE"
		RET_VAL=0
	else
		echo "failed"
		RET_VAL=1
	fi
}

stop() {
	printf "Stopping system message bus: "

	if [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null; then
		echo "done"
		rm -f "$PIDFILE" "$LOCKFILE"
		RET_VAL=0
	else
		echo "failed"
		RET_VAL=1
	fi
}

case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		stop
		start
		;;
	condrestart)
		if [ -f "$LOCKFILE" ]; then
			stop
			start
		fi
		;;
	reload)
		echo "Message bus can't reload its configuration, you have to restart it"
		RET_VAL=1
		;;
	*)
		echo "Usage: $0 {start|stop|restart|condrestart|reload}"
		RET_VAL=1
		;;
esac

exit "$RET_VAL"
