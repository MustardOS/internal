#!/bin/sh

. /opt/muos/script/var/func.sh

IDLE_OLD_BACKLIGHT=/tmp/idle_old_backlight
IDLE_DISPLAY_TIMEOUT=/tmp/idle_display_timeout
IDLE_SLEEP_TIMEOUT=/tmp/idle_sleep_timeout
IDLE_RESET=/tmp/idle_reset

printf "%s" "$(GET_VAR "global" "settings/general/idle_display")" >"$IDLE_DISPLAY_TIMEOUT"
printf "%s" "$(GET_VAR "global" "settings/general/idle_sleep")" >"$IDLE_SLEEP_TIMEOUT"

while true; do
	case "$(GET_VAR "system" "foreground_process")" in
		fbpad | muxcharge | muxstart) sleep 1 && continue ;;
		*) ;;
	esac

	if [ "$(GET_VAR "global" "settings/general/idle_display")" -gt 0 ] && [ "$(cat "/tmp/sleep_state")" = "awake" ]; then
		IDT=$(cat "$IDLE_DISPLAY_TIMEOUT")

		if [ "$IDT" -eq 0 ]; then
			CURRENT_BL=$(DISPLAY_READ lcd0 getbl)
			if [ "$(cat $IDLE_RESET)" -eq 0 ]; then
				printf "%s" "$CURRENT_BL" >$IDLE_OLD_BACKLIGHT
				printf 1 >$IDLE_RESET
			fi
			if [ "$CURRENT_BL" -gt 10 ]; then
				DISPLAY_WRITE lcd0 setbl "$((CURRENT_BL - 10))"
			fi
		else
			IDT=$((IDT - 1))
			printf "%d" "$IDT" >"$IDLE_DISPLAY_TIMEOUT"
		fi
	fi

	if [ "$(GET_VAR "global" "settings/general/idle_sleep")" -gt 0 ] && [ "$(cat "/tmp/sleep_state")" = "awake" ]; then
		IST=$(cat "$IDLE_SLEEP_TIMEOUT")

		if [ "$IST" -eq 0 ]; then
			if [ "$(GET_VAR "global" "settings/general/shutdown")" -eq -1 ]; then
				# Power: Sleep Suspend
				/opt/muos/script/system/suspend.sh power
			elif [ "$(GET_VAR "global" "settings/general/shutdown")" -eq 2 ]; then
				# Power: Instant Shutdown
				HALT_SYSTEM sleep poweroff
			else
				# Power: Sleep XXs + Shutdown
				echo off >"/tmp/trigger/POWER_LONG"
			fi
		else
			IST=$((IST - 1))
			printf "%d" "$IST" >"$IDLE_SLEEP_TIMEOUT"
		fi
	fi

	sleep 1
done &
