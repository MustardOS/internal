#!/bin/sh
# HELP: Battery Report - Checks the battery, charger and fuel gauge, then saves a report to SD1 for the MustardOS crew
# ICON: diagnostic
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/diag.sh

CONFIG_DIR="/opt/muos/device/config/battery"
RUN_DIR="$MUOS_RUN_DIR/battery"

DIAG_BEGIN "battery_report" "Battery Report"

CURVE_PERCENT() {
	MV=$1
	MIN=$(DIAG_READ "$CONFIG_DIR/volt_min")
	MAX=$(DIAG_READ "$CONFIG_DIR/volt_max")
	DIAG_IS_NUM "$MIN" || MIN=3300
	DIAG_IS_NUM "$MAX" || MAX=4100
	[ "$MV" -lt "$MIN" ] && MV=$MIN
	[ "$MV" -gt "$MAX" ] && MV=$MAX

	# shellcheck disable=SC2046
	set -- $(tr -s ' \n' ' ' <"$CONFIG_DIR/curve")
	[ $# -eq 10 ] || {
		printf '%s' "-1"
		return
	}
	[ "$MV" -ge "$1" ] && printf '100' && return
	[ "$MV" -le "${10}" ] && printf '0' && return
	I=0
	while [ $# -ge 2 ]; do
		if [ "$MV" -le "$1" ] && [ "$MV" -ge "$2" ]; then
			LOW=$((100 - (I + 1) * 10))
			SPAN=$(($1 - $2))
			[ "$SPAN" -le 0 ] && printf '%d' "$LOW" && return
			printf '%d' $((LOW + ((MV - $2) * 10 + SPAN / 2) / SPAN))
			return
		fi
		I=$((I + 1))
		shift
	done
	printf '0'
}

DIAG_SECTION "muOS battery configuration"
for FILE in "$CONFIG_DIR"/*; do
	[ -f "$FILE" ] || continue
	NAME=$(basename "$FILE")
	VALUE=$(tr '\n' ' ' <"$FILE")
	VALUE=${VALUE% }
	case "$VALUE" in
		/sys/*)
			if [ -r "$VALUE" ]; then
				DIAG_KV "$NAME" "$VALUE = $(DIAG_READ "$VALUE")"
			else
				DIAG_KV "$NAME" "$VALUE = MISSING"
				DIAG_FINDING "CONFIG" "The configured battery file '$NAME' ($VALUE) does not exist, so muOS cannot read it. Missing capacity or voltage files show as 0%. The kernel or device tree may not match this device."
			fi
			;;
		*) DIAG_KV "$NAME" "$VALUE" ;;
	esac
done
[ -f "$CONFIG_DIR/curve" ] || DIAG_FINDING "CONFIG" "There is no battery voltage curve, so muOS cannot fall back to voltage when the gauge misreports."

DIAG_SECTION "Kernel power supplies"
SUPPLIES=0
for DIR in /sys/class/power_supply/*; do
	[ -d "$DIR" ] || continue
	SUPPLIES=$((SUPPLIES + 1))
	DIAG_OUT "-- $(basename "$DIR")"
	DIAG_ATTRS "$DIR"
done
[ "$SUPPLIES" -eq 0 ] && DIAG_FINDING "KERNEL" "The kernel exposes no power supplies at all. The battery driver did not load."

CAPACITY_PATH=$(DIAG_READ "$CONFIG_DIR/capacity" | head -n 1)
VOLTAGE_PATH=$(DIAG_READ "$CONFIG_DIR/voltage" | head -n 1)
CHARGER_PATH=$(DIAG_READ "$CONFIG_DIR/charger" | head -n 1)
HEALTH_PATH=$(DIAG_READ "$CONFIG_DIR/health" | head -n 1)
SUPPLY_DIR=$(dirname "${CAPACITY_PATH:-/nonexistent/x}")

DIAG_SECTION "What muOS shows"
if [ -d "$RUN_DIR" ]; then
	for FILE in "$RUN_DIR"/*; do
		[ -f "$FILE" ] && DIAG_KV "$(basename "$FILE")" "$(DIAG_READ "$FILE")"
	done
else
	DIAG_OUT "$RUN_DIR is missing, so the battery daemon is not running"
	DIAG_FINDING "MUOS" "The muOS battery daemon is not running ($RUN_DIR is missing)."
fi
if [ -d "$MUOS_CONF_GLOBAL/battery_usage" ]; then
	DIAG_OUT "-- Battery usage history"
	for FILE in "$MUOS_CONF_GLOBAL/battery_usage"/*; do
		[ -f "$FILE" ] && DIAG_KV "   $(basename "$FILE")" "$(DIAG_READ "$FILE")"
	done
fi

DIAG_SECTION "Voltage check"
KERNEL_CAP=$(DIAG_READ "$CAPACITY_PATH")
STATUS=$(DIAG_READ "$SUPPLY_DIR/status")
SUM=0
COUNT=0
while [ "$COUNT" -lt 6 ]; do
	MV=$(DIAG_READ "$VOLTAGE_PATH")
	DIAG_IS_NUM "$MV" || MV=0
	[ "$MV" -gt 100000 ] && MV=$((MV / 1000))
	SUM=$((SUM + MV))
	COUNT=$((COUNT + 1))
	sleep 0.5
done
AVG_MV=$((SUM / COUNT))
COMPENSATED=$AVG_MV
[ "$STATUS" = "Discharging" ] && COMPENSATED=$((AVG_MV + 20))
CURVE_EST=-1
[ -f "$CONFIG_DIR/curve" ] && [ "$AVG_MV" -gt 0 ] && CURVE_EST=$(CURVE_PERCENT "$COMPENSATED")

DIAG_KV "Kernel capacity" "${KERNEL_CAP:-missing}%"
DIAG_KV "Status" "${STATUS:-unknown}"
DIAG_KV "Average voltage" "$AVG_MV mV"
DIAG_KV "muOS curve estimate" "${CURVE_EST}%"

if [ "$AVG_MV" -eq 0 ]; then
	DIAG_FINDING "KERNEL" "The battery voltage cannot be read ($VOLTAGE_PATH)."
elif DIAG_IS_NUM "$KERNEL_CAP" && [ "$CURVE_EST" -ge 0 ]; then
	GAP=$(DIAG_ABS $((KERNEL_CAP - CURVE_EST)))
	if [ "$KERNEL_CAP" -le 2 ] && [ "$CURVE_EST" -ge 20 ]; then
		DIAG_FINDING "BATTERY" "The kernel reports ${KERNEL_CAP}% while the voltage ($AVG_MV mV) suggests about ${CURVE_EST}%. The fuel gauge is wrong rather than the battery being flat."
	elif [ "$GAP" -ge 35 ]; then
		DIAG_FINDING "BATTERY" "The kernel reports ${KERNEL_CAP}% while the voltage suggests about ${CURVE_EST}%. One of them is badly off."
	fi
fi

RUN_CAP=$(DIAG_READ "$RUN_DIR/capacity")
if DIAG_IS_NUM "$RUN_CAP" && DIAG_IS_NUM "$KERNEL_CAP" && [ "$(DIAG_ABS $((RUN_CAP - KERNEL_CAP)))" -ge 5 ]; then
	DIAG_FINDING "INFO" "muOS shows ${RUN_CAP}% while the kernel reports ${KERNEL_CAP}%. The frontend is smoothing the value or using the voltage curve instead."
fi

HEALTH=$(DIAG_READ "$HEALTH_PATH")
[ -n "$HEALTH" ] && [ "$HEALTH" != "Good" ] && DIAG_FINDING "BATTERY" "The battery health is reported as '$HEALTH'."

if [ -n "$CHARGER_PATH" ]; then
	CHARGER=$(DIAG_READ "$CHARGER_PATH")
	ONLINE=""
	for DIR in /sys/class/power_supply/*; do
		[ "$(DIAG_READ "$DIR/online")" = "1" ] && ONLINE="$ONLINE $(basename "$DIR")"
	done
	DIAG_KV "Charger file" "$CHARGER_PATH = ${CHARGER:-missing}"
	DIAG_KV "Supplies online" "${ONLINE:- none}"
	if [ "$STATUS" = "Charging" ] && [ "$CHARGER" != "1" ]; then
		DIAG_FINDING "CONFIG" "The battery is charging but $CHARGER_PATH is not 1 (online:${ONLINE:- none}). muOS will not show that it is charging."
	fi
	if [ "$CHARGER" = "1" ] && [ "$STATUS" = "Discharging" ]; then
		DIAG_FINDING "BATTERY" "A charger is connected but the battery is discharging. The charger may be too weak or the cable may be faulty."
	fi
fi

DIAG_SECTION "Kernel messages"
DIAG_DMESG "battery|charger|fuel|gauge|rk817|rk809|axp|bq2|cw20|sy6970|power_supply" 80

GAUGE_SCRIPT=$(DEVICE_SCRIPT battery_gauge.sh) && . "$GAUGE_SCRIPT"
if command -v GAUGE_FIND >/dev/null 2>&1 && GAUGE_FIND; then
	GAUGE_REPORT
	GAUGE_ANALYSE
fi

DIAG_SECTION "Live readings over 10 seconds"
DIAG_OUT "   second  capacity  voltage  current  status        muOS"
SECOND=0
while [ "$SECOND" -lt 10 ]; do
	CURRENT=$(DIAG_READ "$SUPPLY_DIR/current_now")
	DIAG_IS_NUM "$CURRENT" && CURRENT=$((CURRENT / 1000)) || CURRENT="-"
	MV=$(DIAG_READ "$VOLTAGE_PATH")
	DIAG_IS_NUM "$MV" && [ "$MV" -gt 100000 ] && MV=$((MV / 1000))
	DIAG_OUT "$(printf '   %6s  %8s  %7s  %7s  %-12s  %s' "$SECOND" "$(DIAG_READ "$CAPACITY_PATH")" "$MV" "$CURRENT" \
		"$(DIAG_READ "$SUPPLY_DIR/status")" "$(DIAG_READ "$RUN_DIR/capacity")")"
	sleep 1
	SECOND=$((SECOND + 1))
done

DIAG_FINISH "Battery report saved"
exit 0
