#!/bin/sh

# The RG40XX-H has swapped audio channels for speakers, but not for headphones.
#
# The new kernel in version 1.0.3 of the stock firmware resolves this bug, but
# we currently use a patched version of an older stock kernel (to fix cardinal
# snapping issues), and upgrading it isn't trivial.
#
# For now, poll spk_state (0 -> headphones plugged, 1 -> headphones unplugged)
# and swap DACL and DACR when the state changes.

while :; do
	STATE="$(cat /sys/class/power_supply/axp2202-battery/spk_state)"
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
				amixer -c 0 set 'OutputL Mixer DACL' off
				amixer -c 0 set 'OutputL Mixer DACR' on
				amixer -c 0 set 'OutputR Mixer DACL' on
				amixer -c 0 set 'OutputR Mixer DACR' off
				;;
		esac
	fi
	LAST_STATE="$STATE"
	sleep 1
done
