#!/bin/sh

. /opt/muos/script/var/func.sh

SCRIPT_DIR="/run/muos/storage/init"
INIT_LOG="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/user_init.log"

: >"$INIT_LOG"

# Collect and execute each script
for SCRIPT in "$SCRIPT_DIR"/*.sh; do
	[ -f "$SCRIPT" ] || continue

	# Log it using standard formatting
	TIME=$(date '+%Y-%m-%d %H:%M:%S')
	printf "[%s] [${CSI}33m*${ESC}[0m] [%s] %s\n" "$TIME" "$0" "$SCRIPT" >>"$INIT_LOG"

	# Start the script in the background regardless if it works or not
	sh "$SCRIPT" &
done &
