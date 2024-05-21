#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

SLEEP_STATE="/tmp/sleep_state"
SLEEP_TIMER="/tmp/sleep_timer"

echo "0" > "$SLEEP_TIMER"

while true; do
	MUX_SLEEP=$(parse_ini "$CONFIG" "settings.general" "sleep")

	SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
	SLEEP_TIMER_VAL=$(cat "$SLEEP_TIMER")

	if [ "$SLEEP_STATE_VAL" = "sleep-open" ] || [ "$SLEEP_STATE_VAL" = "sleep-closed" ]; then
		echo $(($(cat $SLEEP_TIMER) + 1)) > "$SLEEP_TIMER"
	else
		echo "0" > "$SLEEP_TIMER"
	fi

	if [ "$SLEEP_TIMER_VAL" = "$MUX_SLEEP" ]; then
		mushutdown
	fi

	echo "SLEEPING ($SLEEP_TIMER_VAL of $MUX_SLEEP)"

	sleep 1
done &
