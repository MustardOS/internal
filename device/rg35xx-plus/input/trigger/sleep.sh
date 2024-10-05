#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/mux/close_game.sh

SLEEP_STATE="/tmp/sleep_state"
SLEEP_TIMER="/tmp/sleep_timer"

echo "0" >"$SLEEP_TIMER"

while true; do
	SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
	SLEEP_TIMER_VAL=$(cat "$SLEEP_TIMER")

	if [ "$SLEEP_STATE_VAL" = "sleep" ]; then
		SLEEP_TIMER_VAL=$((SLEEP_TIMER_VAL + 1))
		echo "$SLEEP_TIMER_VAL" >"$SLEEP_TIMER"
	else
		echo "0" >"$SLEEP_TIMER"
		SLEEP_TIMER_VAL=0
	fi

	if [ "$SLEEP_TIMER_VAL" -eq "$(GET_VAR "global" "settings/power/shutdown")" ]; then
		/opt/muos/script/system/suspend.sh resume
		HALT_SYSTEM sleep poweroff
	fi

	sleep 1
done
