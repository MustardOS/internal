#!/bin/sh

. /opt/muos/script/var/func.sh

printf "%s" "$1" >"$(GET_VAR "device" "screen/colour")"
SET_VAR "config" "settings/general/colour" "$1"
