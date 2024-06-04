#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

NAME="$STORE_ROM/MUOS/info/activity/$1.act"
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

printf "%s\n%.0f\n%.0f" "$PREV_SYS" "$TOTAL_TIME" "$LAUNCH_COUNT" > "$NAME"

