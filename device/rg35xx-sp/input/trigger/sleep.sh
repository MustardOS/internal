#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/global/setting_general.sh

. /opt/muos/script/mux/close_game.sh

SLEEP_STATE="/tmp/sleep_state"
SLEEP_TIMER="/tmp/sleep_timer"
LOG_FILE="/tmp/mushutdown_log.txt"
MUSHUTDOWN_CMD="/opt/muos/bin/mushutdown"

echo "0" >"$SLEEP_TIMER"

while true; do
	SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
	SLEEP_TIMER_VAL=$(cat "$SLEEP_TIMER")

	if [ "$SLEEP_STATE_VAL" = "sleep-open" ] || [ "$SLEEP_STATE_VAL" = "sleep-closed" ]; then
		SLEEP_TIMER_VAL=$((SLEEP_TIMER_VAL + 1))
		echo "$SLEEP_TIMER_VAL" >"$SLEEP_TIMER"
	else
		echo "0" >"$SLEEP_TIMER"
		SLEEP_TIMER_VAL=0
	fi

	if [ "$SLEEP_TIMER_VAL" -eq "$GC_GEN_SHUTDOWN" ]; then
		echo "Attempting to shutdown at $(date)" >>"$LOG_FILE"
		CLOSE_CONTENT
		echo 1 >/sys/class/power_supply/axp2202-battery/moto && sleep 0.25 && echo 0 >/sys/class/power_supply/axp2202-battery/moto
		if [ "$FG_PROC_VAL" != "retroarch" ]; then
			echo "" >/opt/muos/config/lastplay.txt
		fi
		$MUSHUTDOWN_CMD >>"$LOG_FILE" 2>&1
		if [ $? -ne 0 ]; then
			echo "Shutdown failed at $(date)" >>"$LOG_FILE"
		fi
	fi

	sleep 1
done
