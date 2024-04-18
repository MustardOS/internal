#!/bin/sh

WATCH="muaudio mubright mushot musleep"

while true; do
	for PROG in $WATCH; do
		PROG_PATH="/opt/muos/bin/$PROG"
		if [ -x "$PROG_PATH" ]; then
			if [ "$PROG" = "mushot" ]; then
				ARGS="mmc"
			else
				ARGS=""
			fi
			if ! pgrep "$PROG" > /dev/null; then
				if [ "$PROG" = "musleep" ]; then
					sleep 10
				fi
				"$PROG_PATH" "$ARGS" &
			fi
		fi
	done
	sleep 10
done &

