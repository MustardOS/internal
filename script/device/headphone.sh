#!/bin/sh

. /opt/muos/script/var/func.sh

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
esac
