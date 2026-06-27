#!/bin/sh

. /opt/muos/script/var/func.sh

[ -z "$1" ] && exit 0

MIN=$(GET_VAR "device" "audio/min")
MAX=$(GET_VAR "device" "audio/max")

[ -n "$MIN" ] || MIN=0
[ -n "$MAX" ] || MAX=100

INC=$(GET_VAR "config" "settings/advanced/incvolume")
OVD=$(GET_VAR "config" "settings/advanced/overdrive")

[ -n "$INC" ] || INC=1
[ "$OVD" = "1" ] && MAX=200

GET_CURRENT() {
	wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null |
		awk '
			{
				for (i = 1; i <= NF; i++) {
					if ($i ~ /^[0-9.]+$/) {
						print int(($i * 100) + 0.5)
						exit
					}
				}
			}
		'
}

NORMALISE_VALUE() {
	VALUE=$1

	[ -n "$VALUE" ] || VALUE=$MIN
	[ "$VALUE" -lt "$MIN" ] && VALUE=$MIN
	[ "$VALUE" -gt "$MAX" ] && VALUE=$MAX

	printf "%s\n" "$VALUE"
}

SET_CURRENT() {
	VALUE=$(NORMALISE_VALUE "$1")

	wpctl set-volume @DEFAULT_AUDIO_SINK@ "${VALUE}%"
	wpctl set-mute @DEFAULT_AUDIO_SINK@ 0

	SET_SAVED_AUDIO_VOLUME "$VALUE"
}

VOL_INFO() {
	V=$(GET_CURRENT)
	[ -n "$V" ] || V=0
	printf "%s%%\n" "$V"
}

case "$1" in
	U)
		CUR=$(GET_CURRENT)
		[ -n "$CUR" ] || CUR=0

		NEW_VL=$((CUR + INC))
		SET_CURRENT "$NEW_VL"
		;;
	D)
		CUR=$(GET_CURRENT)
		[ -n "$CUR" ] || CUR=0

		NEW_VL=$((CUR - INC))
		SET_CURRENT "$NEW_VL"
		;;
	I) VOL_INFO ;;
	[0-9]*) [ "$1" -eq "$1" ] 2>/dev/null && SET_CURRENT "$1" ;;
	*) ;;
esac
