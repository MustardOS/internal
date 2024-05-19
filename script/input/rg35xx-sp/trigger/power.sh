#!/bin/sh

TMP_POWER_LONG="/tmp/trigger/POWER_LONG"
echo "on" > $TMP_POWER_LONG

FG_PROC="/tmp/fg_proc"
DBG="/sys/kernel/debug/dispdbg"

HALL_KEY=/sys/devices/platform/soc/twi5/i2c-5/5-0034/axp2202-bat-power-supply.0/power_supply/axp2202-battery/hallkey
STATE="/tmp/sleep_state"

#while true; do
#	if [ "$(cat $HALL_KEY)" = "0" ]; then
#		echo "off" > $TMP_POWER_LONG
#	else
#		echo "on" > $TMP_POWER_LONG
#	fi
#
#	sleep 0.25
#done &

while true; do
	if [ "$(cat $TMP_POWER_LONG)" = "off" ] || [ "$(cat $HALL_KEY)" = "0" ]; then
		if [ "$(cat $STATE)" = "awake" ]; then
			echo "off" > $TMP_POWER_LONG

			case $(cat "$FG_PROC") in
				"retroarch")
					if pidof "$(cat $FG_PROC)" >/dev/null; then
						evemu-play /dev/input/event1 < /opt/muos/script/input/rg35xx-sp/emu/ra-savestate
						sleep 0.5
						pkill -STOP "$(cat $FG_PROC)"
					fi
				;;
			esac

			echo "off" > $TMP_POWER_LONG

			echo disp0 > $DBG/name
			echo blank > $DBG/command
			echo 1 > $DBG/param
			echo 1 > $DBG/start

			if [ "$(cat $HALL_KEY)" = "0" ]; then
				echo "sleep-closed" > $STATE
			else
				echo "sleep-open" > $STATE
			fi
		fi
	fi

	if [ "$(cat $TMP_POWER_LONG)" = "on" ]; then
		if [ "$(cat $HALL_KEY)" = "1" ]; then
			echo "on" > $TMP_POWER_LONG

			if pidof "$(cat $FG_PROC)" >/dev/null; then pkill -CONT "$(cat $FG_PROC)"; fi

			echo "on" > $TMP_POWER_LONG

			echo disp0 > $DBG/name
			echo blank > $DBG/command
			echo 0 > $DBG/param
			echo 1 > $DBG/start

			echo "awake" > $STATE
		fi
	fi

	if [ "$(cat $HALL_KEY)" = "1" ]; then
		if [ "$STATE" = "sleep-closed" ]; then
			echo "on" > $TMP_POWER_LONG

			if pidof "$(cat $FG_PROC)" >/dev/null; then pkill -CONT "$(cat $FG_PROC)"; fi

			echo "on" > $TMP_POWER_LONG

			echo disp0 > $DBG/name
			echo blank > $DBG/command
			echo 0 > $DBG/param
			echo 1 > $DBG/start

			echo "awake" > $STATE			
		fi
	fi
	
	sleep 0.25
done &
