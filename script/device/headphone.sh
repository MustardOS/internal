#!/bin/sh

. /opt/muos/script/var/func.sh

SWITCH_OUTPUT_VOLUME() {
	WANT=$1
	FIRST=$2

	HAVE=0
	[ -e "$HEADPHONE_FLAG" ] && HAVE=1
	[ "$WANT" -eq "$HAVE" ] && [ "$FIRST" -eq 0 ] && return 0

	BUILTIN_NAME=$(cat "$AUDIO_BUILTIN_FILE" 2>/dev/null)
	ON_BUILTIN=0
	[ -n "$BUILTIN_NAME" ] && [ "$(CURRENT_SINK_NAME)" = "$BUILTIN_NAME" ] && ON_BUILTIN=1

	[ "$ON_BUILTIN" -eq 1 ] && [ "$FIRST" -eq 0 ] && SAVE_SINK_VOLUME

	if [ "$WANT" -eq 1 ]; then
		: >"$HEADPHONE_FLAG"
	else
		rm -f "$HEADPHONE_FLAG"
	fi

	[ "$ON_BUILTIN" -eq 1 ] || return 0

	if LOAD_SINK_VOLUME; then
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "$(GET_SAVED_AUDIO_VOLUME)%" >/dev/null 2>&1
	else
		SAVE_SINK_VOLUME
	fi
}

G350_FIRST=1

SET_G350_PATH() {
	JACK_STATE=$(amixer -c 0 cget iface=CARD,name='Headphone Jack' 2>/dev/null) || return 1

	case "$JACK_STATE" in
		*": values=on"*) OUTPUT=SPK ;;
		*": values=off"*) OUTPUT=HP ;;
		*) return 1 ;;
	esac

	HP_IN=0
	[ "$OUTPUT" = "HP" ] && HP_IN=1
	SWITCH_OUTPUT_VOLUME "$HP_IN" "$G350_FIRST"
	G350_FIRST=0

	CURRENT_PATH=$(amixer -c 0 sget 'Playback Path' 2>/dev/null) || return 1
	case "$CURRENT_PATH" in
		*"Item0: '$OUTPUT'"*) return 0 ;;
	esac

	amixer -q -c 0 sset 'Playback Path' "$OUTPUT" >/dev/null 2>&1 || return 1
}

case "$(GET_VAR "device" "board/name")" in
	rk-pixel-2)
		echo 86 > /sys/class/gpio/export 2>/dev/null
		LAST=""

		while true; do
			VAL=$(cat /sys/class/gpio/gpio86/value 2>/dev/null)
			if [ "$VAL" != "$LAST" ]; then
				FIRST=0
				[ -z "$LAST" ] && FIRST=1
				if [ "$VAL" = "1" ]; then
					SWITCH_OUTPUT_VOLUME 1 "$FIRST"
					amixer -c 0 sset 'Playback Path' HP_NO_MIC
				else
					SWITCH_OUTPUT_VOLUME 0 "$FIRST"
					amixer -c 0 sset 'Playback Path' SPK
				fi
				LAST="$VAL"
			fi
			sleep 0.3
		done
		;;
	rg28xx-h | rg34xx-h | rg34xx-sp | rg35xx-2024 | rg35xx-h | rg35xx-plus | rg35xx-pro | rg35xx-sp | rg40xx-h | rg40xx-v | rgcubexx-h | rgsp)
		HP_PLUGGED_LEVEL=hi
		LAST=""

		while true; do
			LEVEL=""
			while IFS= read -r LINE; do
				case "$LINE" in
					*"Headphone detection"*)
						LINE="${LINE%"${LINE##*[! ]}"}"
						LEVEL="${LINE##* }"
						break
						;;
				esac
			done </sys/kernel/debug/gpio 2>/dev/null

			if [ -z "$LEVEL" ]; then
				sleep 5
				continue
			fi

			if [ "$LEVEL" != "$LAST" ]; then
				FIRST=0
				[ -z "$LAST" ] && FIRST=1

				HP_IN=0
				[ "$LEVEL" = "$HP_PLUGGED_LEVEL" ] && HP_IN=1
				SWITCH_OUTPUT_VOLUME "$HP_IN" "$FIRST"

				LAST="$LEVEL"
			fi

			sleep 0.5
		done
		;;
	rk-g350-v)
		while true; do
			while ! SET_G350_PATH; do
				sleep 0.2
			done
			{
				alsactl monitor hw:0 2>/dev/null &
				while :; do
					sleep 5
					echo tick
				done
			} | while IFS= read -r _; do
				SET_G350_PATH
			done
			sleep 1
		done
		;;
esac
