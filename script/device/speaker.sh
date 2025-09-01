#!/bin/sh

while :; do
	STATE="$(cat "/sys/class/power_supply/axp2202-battery/spk_state")"

	if [ "$STATE" != "$LAST_STATE" ]; then
		case "$STATE" in
			0)
				# Headphones: Normal channel mapping
				amixer -c 0 set 'OutputL Mixer DACL' on
				amixer -c 0 set 'OutputL Mixer DACR' off
				amixer -c 0 set 'OutputR Mixer DACL' off
				amixer -c 0 set 'OutputR Mixer DACR' on
				;;
			1)
				# Speakers: Reversed channel mapping
				amixer -c 0 set 'OutputL Mixer DACL' on
				amixer -c 0 set 'OutputL Mixer DACR' off
				amixer -c 0 set 'OutputR Mixer DACL' off
				amixer -c 0 set 'OutputR Mixer DACR' on
				;;
		esac
	fi

	LAST_STATE="$STATE"
	TBOX sleep 1
done
