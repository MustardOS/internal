#!/bin/sh

. /opt/muos/script/var/config.sh

[ "$(GET_VAR "device" "led/rgb")" -eq 0 ] && return 0
"$MUOS_RGB_BIN" -b AUTO 1 76 128 0 255 128 0 255
