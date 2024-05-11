#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

NET_DNS=$(parse_ini "$CONFIG" "network" "dns")
NET_PORT="53"

WATCH="muaudio mubright muping mushot musleep"

IS_RUNNING() {
	pgrep "$1" > /dev/null
}

START_PROCESS() {
	PROG_PATH="/opt/muos/bin/$1"
	ARGS=""
	case "$1" in
		"muping")
			ARGS="-a $NET_DNS -p $NET_PORT"
			;;
		"mushot")
			ARGS="mmc"
			;;
	esac
	if ! IS_RUNNING "$1"; then
		if [ "$1" = "musleep" ]; then
			sleep 10
		fi

		"$PROG_PATH" $ARGS &
	fi
}

while true; do
	for PROG in $WATCH; do
		START_PROCESS "$PROG"
	done
	sleep 10
done &

