#!/bin/sh

. /opt/muos/script/var/func.sh

CARD="${CARD:-0}"
AUDIO_SWAP="/opt/muos/config/settings/advanced/audio_swap"

CHANNEL_SWITCH() {
	case "$(GET_VAR "device" "board/name")" in
		rg*)
			FV="off"
			SV="off"

			[ "$1" -eq 0 ] && FV="off" && SV="on"
			[ "$1" -eq 1 ] && FV="on" && SV="off"

			amixer -q -c "$CARD" set 'OutputL Mixer DACL' "$FV"
			amixer -q -c "$CARD" set 'OutputL Mixer DACR' "$SV"
			amixer -q -c "$CARD" set 'OutputR Mixer DACL' "$SV"
			amixer -q -c "$CARD" set 'OutputR Mixer DACR' "$FV"
			;;
		tui*)
			# $2 = 0 (off), 1 (on)
			amixer -q -c "$CARD" cset name='DAC Swap' "$2"
			;;
	esac
}

STATE="$(cat "$AUDIO_SWAP" 2>/dev/null)" || exit 0

case "$STATE" in
	0) CHANNEL_SWITCH 1 0 ;; # normal
	1) CHANNEL_SWITCH 0 1 ;; # swapped
esac

exit 0
