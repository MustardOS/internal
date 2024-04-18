#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

COLOUR=$(parse_ini "$CONFIG" "settings.general" "colour")
echo $COLOUR > /sys/class/disp/disp/attr/color_temperature
