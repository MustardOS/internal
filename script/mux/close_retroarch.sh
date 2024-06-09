#!/bin/sh

close_retroarch() {
	# gracefully close retroarch
	if pidof "retroarch" > /dev/null; then
		pkill -CONT "retroarch"
		pkill retroarch
		TIMER=0
		# wait for retroarch to close or timer to run for 5 seconds
		while pidof "retroarch" > /dev/null && [ $TIMER -lt 20 ]; do
			TIMER=$(($TIMER + 1))
			sleep 0.25
		done
	fi
}
