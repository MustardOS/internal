#!/bin/sh

. /opt/muos/script/var/func.sh

NAME="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/activity/$1.act"
shift
PROG="nice --20 $*"

PREV_SYS=$(sed -n '1p' "$NAME")
PREV_TIME=$(sed -n '2p' "$NAME")
PREV_LAUNCH=$(sed -n '3p' "$NAME")

START_TIME=$(date +%s)
eval "$PROG"
FINISH_TIME=$(date +%s)

ELAPSED_TIME=$(echo "$FINISH_TIME - $START_TIME" | bc)
TOTAL_TIME=$(echo "$ELAPSED_TIME + $PREV_TIME" | bc)

LAUNCH_COUNT=$(echo "$PREV_LAUNCH" + 1 | bc)

printf "%s\n%.0f\n%.0f" "$PREV_SYS" "$TOTAL_TIME" "$LAUNCH_COUNT" >"$NAME"
