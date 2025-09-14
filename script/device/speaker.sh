#!/bin/sh

. /opt/muos/script/var/func.sh

CARD="${CARD:-0}"

CHANNEL_SWITCH() {
	amixer -q -c "$CARD" set 'OutputL Mixer DACL' "$1"
	amixer -q -c "$CARD" set 'OutputL Mixer DACR' "$2"
	amixer -q -c "$CARD" set 'OutputR Mixer DACL' "$2"
	amixer -q -c "$CARD" set 'OutputR Mixer DACR' "$1"
}

while :; do
	STATE="$(cat "/sys/class/power_supply/axp2202-battery/spk_state")"

	if [ "$STATE" != "$LAST_STATE" ]; then
		case "$STATE" in
			0) # Headphones: L<-DACL, R<-DACR
				CHANNEL_SWITCH on off ;;
			1) # Speakers: reversed L/R (L<-DACR, R<-DACL)
				CHANNEL_SWITCH off on ;;
		esac
	fi

	LAST_STATE="$STATE"
	TBOX sleep 1
done
