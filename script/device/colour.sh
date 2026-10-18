#!/bin/sh

. /opt/muos/script/var/config.sh

printf "%s" "$1" >"$(GET_VAR "device" "screen/colour")"
SET_VAR "config" "settings/colour/sunrise_temp" "$1"
