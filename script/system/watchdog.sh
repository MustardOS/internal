#!/bin/sh

WATCH="muaudio mubright mushot musleep"

IS_RUNNING() {
	pgrep "$1" > /dev/null
}

START_PROCESS() {
	PROG_PATH="/opt/muos/bin/$1"
	ARGS=""
	case "$1" in
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

