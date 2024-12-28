#!/bin/sh

. /opt/muos/script/var/func.sh

killall -q "hdmi_start.sh"

DISPLAY_WRITE disp0 switch "1 0"
XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_internal")"

FB_SWITCH "$(GET_VAR "device" "screen/internal/width")" "$(GET_VAR "device" "screen/internal/height")" 32
