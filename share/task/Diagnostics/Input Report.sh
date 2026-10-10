#!/bin/sh
# HELP: Input Report - Lists controllers, buttons and input services, then saves a report to SD1
# ICON: diagnostic
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/diag.sh

DIAG_BEGIN "input_report" "Input Report"

DIAG_SECTION "Input services"
for DAEMON in muinput muhotkey; do
	if DIAG_RUNNING "$DAEMON"; then
		DIAG_KV "$DAEMON" "running ($(pidof "$DAEMON"))"
	else
		DIAG_KV "$DAEMON" "not running"
		DIAG_FINDING "SERVICE" "$DAEMON is not running, so buttons and hotkeys may not respond."
	fi
done
DIAG_CONFIG "$MUOS_CONF_DEVICE/input"
DIAG_KV "Swap A/B" "$(GET_VAR "config" "settings/advanced/swap" 2>/dev/null)"

DIAG_SECTION "Input devices"
DIAG_FILE /proc/bus/input/devices
JOYSTICKS=$(grep -c "Handlers=.*js[0-9]" /proc/bus/input/devices 2>/dev/null)
DIAG_KV "Joystick devices" "${JOYSTICKS:-0}"
[ "${JOYSTICKS:-0}" -eq 0 ] && DIAG_FINDING "INPUT" "No joystick or gamepad device is registered. The controls driver did not load."
DUPLICATES=$(sed -n 's/^N: Name="\(.*\)"/\1/p' /proc/bus/input/devices 2>/dev/null | sort | uniq -d | tr '\n' ' ')
[ -n "$DUPLICATES" ] && DIAG_FINDING "INFO" "More than one input device shares a name: $DUPLICATES"

DIAG_SECTION "Device capabilities"
for EVENT in /dev/input/event*; do
	[ -e "$EVENT" ] || continue
	if command -v evemu-describe >/dev/null 2>&1; then
		DIAG_OUT "-- $EVENT"
		timeout 3 evemu-describe "$EVENT" 2>/dev/null | grep -E "^N:|^I:|^# +Event (type|code)" | head -n 80 | DIAG_APPEND
	fi
done

DIAG_SECTION "Kernel messages"
DIAG_DMESG "input|joystick|gamepad|gpio-keys|adc-keys|rumble|hall|touch" 60

DIAG_FINISH "Input report saved"
exit 0
