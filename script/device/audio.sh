#!/bin/sh

. /opt/muos/script/var/func.sh

[ -z "$1" ] && exit 0

mkdir -p "$MUOS_RUN_DIR"
exec 9>"$MUOS_RUN_DIR/volume.lock"
flock -x 9

MIN=$(GET_VAR "device" "audio/min")
MAX=$(GET_VAR "device" "audio/max")

[ -n "$MIN" ] || MIN=0
[ -n "$MAX" ] || MAX=100

INC=$(GET_VAR "config" "settings/advanced/incvolume")
OVD=$(GET_VAR "config" "settings/advanced/overdrive")

[ -n "$INC" ] || INC=1
[ "$OVD" = "1" ] && MAX=200

GET_STATE() {
	wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null |
		awk '
			{
				for (i = 1; i <= NF; i++) {
					if (v == "" && $i ~ /^[0-9.]+$/) v = int(($i * 100) + 0.5)
				}
				m = /MUTED/ ? 1 : 0
			}
			END { if (v != "") print v, m }
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
	[ "${2:-1}" = "0" ] || wpctl set-mute @DEFAULT_AUDIO_SINK@ 0

	SET_SAVED_AUDIO_VOLUME "$VALUE"
	[ "${MUOS_VOLUME_RESTORE:-0}" = "1" ] || SAVE_SINK_VOLUME
}

STEP_CURRENT() {
	STATE=$(GET_STATE)

	if [ -n "$STATE" ]; then
		CUR=${STATE% *}
		MUTED=${STATE#* }
	else
		CUR=$(GET_SAVED_AUDIO_VOLUME)
		MUTED=1
	fi

	SET_CURRENT $((CUR + $1)) "$MUTED"
}

VOL_INFO() {
	STATE=$(GET_STATE)
	V=${STATE% *}
	[ -n "$V" ] || V=0
	printf "%s%%\n" "$V"
}

case "$1" in
	U) STEP_CURRENT "$INC" ;;
	D) STEP_CURRENT "-$INC" ;;
	I) VOL_INFO ;;
	[0-9]*) [ "$1" -eq "$1" ] 2>/dev/null && SET_CURRENT "$1" ;;
	*) ;;
esac
