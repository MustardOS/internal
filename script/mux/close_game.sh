#!/bin/sh

CLOSE_CONTENT() {
	FG_PROC_VAL="$(cat /tmp/fg_proc)"
	FG_PROC_PID="$(pidof "$FG_PROC_VAL")"
	if [ -n "$FG_PROC_PID" ]; then
		kill -CONT "$FG_PROC_PID"
		kill "$FG_PROC_PID"
		for TIMEOUT in $(seq 1 20); do
			if ! kill -0 "$FG_PROC_PID" 2>/dev/null; then
				break
			fi
			sleep .25
		done
	fi
}

CLOSE_CONTENT_AND_HALT() {
	CLOSE_CONTENT
	if [ "$FG_PROC_VAL" != "retroarch" ]; then
		: >/opt/muos/config/lastplay.txt
	fi
	/opt/muos/script/system/halt.sh "$1"
}
