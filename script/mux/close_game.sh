#!/bin/sh

FG_PROC="/tmp/fg_proc"

CLOSE_CONTENT() {
	FG_PROC_VAL=$(cat "$FG_PROC")
	if pidof "$FG_PROC_VAL" >/dev/null; then
		pkill -CONT "$FG_PROC_VAL"
		pkill "$FG_PROC_VAL"
		TIMER=0
		while pidof "$FG_PROC_VAL" >/dev/null && [ $TIMER -lt 20 ]; do
			TIMER=$((TIMER + 1))
			sleep 0.25
		done
	fi
}
