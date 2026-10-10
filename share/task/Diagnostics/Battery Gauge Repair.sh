#!/bin/sh
# HELP: Battery Gauge Repair - Resets a fuel gauge stuck at the wrong level using the battery voltage, then restarts. Unplug the charger first
# ICON: diagnostic
# EXECUTION_MODE: prompt
# CAN_CANCEL: 1
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/diag.sh

DIAG_BEGIN "battery_gauge_repair" "Battery Gauge Repair"

GAUGE_SCRIPT=$(DEVICE_SCRIPT battery_gauge.sh) && . "$GAUGE_SCRIPT"
if ! command -v GAUGE_FIND >/dev/null 2>&1 || ! GAUGE_FIND; then
	DIAG_OUT "This device has no supported fuel gauge."
	TASK_ERROR "unsupported" "This device has no supported fuel gauge"
	DIAG_FINISH "Nothing was changed"
	exit 1
fi

DIAG_SECTION "Measuring the battery"
if ! GAUGE_PLAN_REPAIR; then
	DIAG_OUT "$GAUGE_REASON. Nothing was changed."
	TASK_ERROR "not_ready" "$GAUGE_REASON"
	DIAG_FINISH "Nothing was changed"
	exit 1
fi

KERNEL_CAP=$(DIAG_READ "$GAUGE_PS/capacity")
DIAG_KV "Kernel capacity" "${KERNEL_CAP}%"
DIAG_KV "Average reading" "$GAUGE_AVG_MV mV at $GAUGE_AVG_MA mA"
DIAG_KV "Voltage estimate" "${GAUGE_EST}%"
DIAG_KV "Full charge capacity" "$GAUGE_USE_FCC mAh"
DIAG_KV "Before" "level $GAUGE_SOC, remaining $GAUGE_CAP mAh, counter $GAUGE_Q_PRES"
DIAG_KV "Planned" "level $GAUGE_NEW_SOC, remaining $GAUGE_NEW_CAP mAh, counter $GAUGE_NEW_Q"

if [ "${1:-}" != "--yes" ]; then
	CHOICE=$(TASK_PROMPT "gauge_repair" "confirm" "Battery Gauge Repair" \
		"The gauge reads ${KERNEL_CAP}% and the battery voltage suggests ${GAUGE_EST}%. Set the gauge to ${GAUGE_EST}% and restart?" \
		"Repair and Restart|Cancel" "Cancel") || CHOICE="Cancel"
	if [ "$CHOICE" != "Repair and Restart" ]; then
		DIAG_OUT "Cancelled. Nothing was changed."
		DIAG_FINISH "Repair cancelled"
		exit 0
	fi
fi

DIAG_SECTION "Writing the fuel gauge"
if ! GAUGE_APPLY_REPAIR; then
	DIAG_KV "After" "level $GAUGE_SOC, remaining $GAUGE_CAP mAh"
	DIAG_FINDING "GAUGE" "The new values did not read back correctly. Charge the device to 100% without interruption instead."
	TASK_ERROR "write_failed" "The fuel gauge did not accept the new values"
	DIAG_FINISH "Repair failed"
	exit 1
fi

DIAG_KV "After" "level $GAUGE_SOC, remaining $GAUGE_CAP mAh, counter $GAUGE_Q_PRES ($GAUGE_Q_MAH mAh)"
[ "$(DIAG_ABS $((GAUGE_Q_MAH - GAUGE_NEW_CAP)))" -gt $((GAUGE_USE_FCC / 20)) ] &&
	DIAG_OUT "The coulomb counter did not follow, but the saved level is used at the next boot."
DIAG_OUT "The gauge will start from ${GAUGE_EST}% after the restart."
DIAG_FINISH "Gauge set to ${GAUGE_EST}%, restarting"

sleep 3
/opt/muos/script/mux/quit.sh reboot frontend
exit 0
