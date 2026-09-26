#!/bin/sh

. /opt/muos/script/var/func.sh

SET_G350_PATH() {
	JACK_STATE=$(amixer -c 0 cget name='Headphone Jack' 2>/dev/null) || return 1
	case "$JACK_STATE" in
		*"values=on"*) OUTPUT=HP ;;
		*"values=off"*) OUTPUT=SPK ;;
		*) return 1 ;;
	esac

	CURRENT_PATH=$(amixer -c 0 cget name='Playback Path' 2>/dev/null) || return 1
	case "$CURRENT_PATH" in
		*"values=$OUTPUT"*) return 0 ;;
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
                if [ "$VAL" = "1" ]; then
                    amixer -c 0 sset 'Playback Path' HP_NO_MIC
                else
                    amixer -c 0 sset 'Playback Path' SPK
                fi
                LAST="$VAL"
            fi
            sleep 0.3
        done
		;;
	rk-g350-v)
		while true; do
			while ! SET_G350_PATH; do
				sleep 0.2
			done
			alsactl monitor 0 2>/dev/null | while IFS= read -r _; do
				SET_G350_PATH
			done
			sleep 1
		done
		;;
esac
