#!/bin/sh

TMP_POWER_LONG="/tmp/trigger/POWER_LONG"
echo "on" > $TMP_POWER_LONG

FG_PROC="/tmp/fg_proc"
DBG="/sys/kernel/debug/dispdbg"

while true; do
	if [ "$(cat $TMP_POWER_LONG)" = "off" ]; then
		echo disp0 > $DBG/name
		echo blank > $DBG/command
		echo 1 > $DBG/param
		echo 1 > $DBG/start

		if pidof "$(cat $FG_PROC)" >/dev/null; then pkill -STOP "$(cat $FG_PROC)"; fi
	else
		echo disp0 > $DBG/name
		echo blank > $DBG/command
		echo 0 > $DBG/param
		echo 1 > $DBG/start

		if pidof "$(cat $FG_PROC)" >/dev/null; then pkill -CONT "$(cat $FG_PROC)"; fi
	fi
	
	sleep 0.25
done &

