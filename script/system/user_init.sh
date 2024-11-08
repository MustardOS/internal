#!/bin/sh

. /opt/muos/script/var/func.sh

SCRIPT_DIR="/run/muos/storage/init"
INIT_LOG="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/user_init.log"

: >"$INIT_LOG"

# Collect and execute the first line of each command file
for CMD_LINE in "$SCRIPT_DIR"/*.txt; do
	[ -f "$CMD_LINE" ] || continue

	# Just grab the first line and ignore the rest
	COMMAND=$(head -n 1 "$CMD_LINE")

	# Log it using standard formatting
	TIME=$(date '+%Y-%m-%d %H:%M:%S')
	printf "[%s] [${CSI}33m*${ESC}[0m] [%s] %s\n" "$TIME" "$0" "$COMMAND" >>"$INIT_LOG"

	# Start the script in the background regardless if it works or not
	sh -c "$COMMAND" &
done &
