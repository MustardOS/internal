#!/bin/sh

. /opt/muos/script/system/parse.sh
. /opt/muos/script/mux/close_retroarch.sh
CONFIG=/opt/muos/config/config.ini

SLEEP_STATE="/tmp/sleep_state"
SLEEP_TIMER="/tmp/sleep_timer"
LOG_FILE="/tmp/mushutdown_log.txt"
MUSHUTDOWN_CMD="/opt/muos/bin/mushutdown"

echo "0" > "$SLEEP_TIMER"

while true; do
	MUX_SLEEP=$(parse_ini "$CONFIG" "settings.general" "shutdown")

	SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
	SLEEP_TIMER_VAL=$(cat "$SLEEP_TIMER")

	if [ "$SLEEP_STATE_VAL" = "sleep-open" ] || [ "$SLEEP_STATE_VAL" = "sleep-closed" ]; then
		SLEEP_TIMER_VAL=$(($SLEEP_TIMER_VAL + 1))
		echo "$SLEEP_TIMER_VAL" > "$SLEEP_TIMER"
	else
		echo "0" > "$SLEEP_TIMER"
		SLEEP_TIMER_VAL=0
	fi

	if [ "$SLEEP_TIMER_VAL" -eq "$MUX_SLEEP" ]; then
		echo "Attempting to shutdown at $(date)" >> "$LOG_FILE"
		close_retroarch
		echo 1 > /sys/class/power_supply/axp2202-battery/moto && sleep 0.25 && echo 0 > /sys/class/power_supply/axp2202-battery/moto
		$MUSHUTDOWN_CMD >> "$LOG_FILE" 2>&1
		if [ $? -ne 0 ]; then
			echo "Shutdown failed at $(date)" >> "$LOG_FILE"
		fi
	fi

	echo "SLEEPING ($SLEEP_TIMER_VAL of $MUX_SLEEP)"

	sleep 1
done

