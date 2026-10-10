#!/bin/sh
# HELP: Input Event Test - Shows every button and stick event for 20 seconds so you can check each control works
# ICON: diagnostic
# EXECUTION_MODE: terminal
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh

DEVICE=""
for HANDLERS in $(sed -n 's/^H: Handlers=\(.*\)/\1/p' /proc/bus/input/devices | tr ' ' '_'); do
	case "$HANDLERS" in
		*js[0-9]*)
			EVENT=$(printf '%s' "$HANDLERS" | tr '_' '\n' | grep '^event' | head -n 1)
			[ -n "$EVENT" ] && DEVICE="/dev/input/$EVENT" && break
			;;
	esac
done

if [ -z "$DEVICE" ] || ! command -v evtest >/dev/null 2>&1; then
	printf 'No gamepad device or evtest found.\n'
	sleep 5
	exit 1
fi

printf 'Testing %s for 20 seconds. Press every button and move every stick.\n\n' "$DEVICE"
sleep 2
timeout 20 evtest "$DEVICE"
printf '\nTest finished.\n'
sleep 3
exit 0
