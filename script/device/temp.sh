#!/bin/sh

. /opt/muos/script/var/func.sh

printf "%s" "$1" >"$(GET_VAR "device" "screen/temp")"
