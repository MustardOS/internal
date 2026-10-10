#!/bin/sh

# Battery gauge support for the Diagnostics tasks: the rk817 fuel gauge on the 4.4 BSP kernel.
# Any board can provide its own battery_gauge.sh with the same GAUGE_ functions.
#
# At boot the gauge restores its level from scratch registers in the PMIC instead of
# measuring.  If those hold 0 the battery reads 0% after every boot and only recovers
# after an uninterrupted full charge.  The driver rewrites the level only when it
# changes, so a corrected level survives until the next boot.
#
# Requires diag.sh to be sourced first.

GAUGE_BUS=0
GAUGE_ADDR=0x20
GAUGE_REGMAP=""
GAUGE_DT=""
GAUGE_CHG_DT=""
GAUGE_PS=""

GAUGE_RES_DIV=1
GAUGE_DESIGN=0
GAUGE_QMAX=0
GAUGE_BAT_RES=0
GAUGE_OCV=""

GAUGE_AVG_MV=0
GAUGE_AVG_MA=0

GAUGE_FIND_PS() {
	for GAUGE_DIR in /sys/class/power_supply/*; do
		[ "$(DIAG_READ "$GAUGE_DIR/type")" = "Battery" ] && GAUGE_PS=$GAUGE_DIR && return 0
	done
	return 1
}

# Returns success only when an rk817 or rk809 battery node exists and the PMIC answers
GAUGE_FIND() {
	for GAUGE_COMPAT in $(grep -l "rk817[-,]battery\|rk809[-,]battery" /proc/device-tree/*/*/*/compatible \
		/proc/device-tree/*/*/compatible 2>/dev/null); do
		GAUGE_DT=$(dirname "$GAUGE_COMPAT")
		break
	done
	for GAUGE_COMPAT in $(grep -l "rk817[-,]charger\|rk809[-,]charger" /proc/device-tree/*/*/*/compatible \
		/proc/device-tree/*/*/compatible 2>/dev/null); do
		GAUGE_CHG_DT=$(dirname "$GAUGE_COMPAT")
		break
	done
	[ -n "$GAUGE_DT" ] || return 1

	[ -d /sys/kernel/debug/regmap ] || mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
	for GAUGE_MAP in /sys/kernel/debug/regmap/*-0020; do
		[ -r "$GAUGE_MAP/registers" ] && GAUGE_REGMAP="$GAUGE_MAP/registers" && break
	done

	GAUGE_FIND_PS
	GAUGE_LOAD_PROFILE
	[ -n "$GAUGE_REGMAP" ] || [ -n "$(i2cget -f -y "$GAUGE_BUS" "$GAUGE_ADDR" 0x00 2>/dev/null)" ]
}

GAUGE_LOAD_PROFILE() {
	GAUGE_OCV=$(DIAG_DT_U32 "$GAUGE_DT/ocv_table")
	GAUGE_DESIGN=$(DIAG_DT_U32 "$GAUGE_DT/design_capacity")
	GAUGE_QMAX=$(DIAG_DT_U32 "$GAUGE_DT/design_qmax")
	GAUGE_BAT_RES=$(DIAG_DT_U32 "$GAUGE_DT/bat_res")
	[ "$(DIAG_DT_U32 "$GAUGE_DT/sample_res")" = "20" ] && GAUGE_RES_DIV=2
	DIAG_IS_NUM "$GAUGE_DESIGN" || GAUGE_DESIGN=0
	DIAG_IS_NUM "$GAUGE_QMAX" || GAUGE_QMAX=0
	DIAG_IS_NUM "$GAUGE_BAT_RES" || GAUGE_BAT_RES=0
}

# Hardware first through i2c, then the regmap cache
GAUGE_REG() {
	GAUGE_V=""
	command -v i2cget >/dev/null 2>&1 && GAUGE_V=$(i2cget -f -y "$GAUGE_BUS" "$GAUGE_ADDR" "$1" 2>/dev/null)
	if [ -z "$GAUGE_V" ] && [ -n "$GAUGE_REGMAP" ]; then
		GAUGE_V=$(grep "^$(printf '%02x' "$(($1))"):" "$GAUGE_REGMAP" | awk '{print $2}')
		[ -n "$GAUGE_V" ] && GAUGE_V="0x$GAUGE_V"
	fi
	[ -n "$GAUGE_V" ] && printf '%d' "$GAUGE_V"
}

GAUGE_REG24() {
	GA=$(GAUGE_REG "$1")
	GB=$(GAUGE_REG "$2")
	GC=$(GAUGE_REG "$3")
	DIAG_IS_NUM "$GA" && DIAG_IS_NUM "$GB" && DIAG_IS_NUM "$GC" && printf '%d' $(((GA << 16) | (GB << 8) | GC))
}

GAUGE_REG32() {
	GA=$(GAUGE_REG "$1")
	GB=$(GAUGE_REG "$2")
	GC=$(GAUGE_REG "$3")
	GD=$(GAUGE_REG "$4")
	DIAG_IS_NUM "$GA" && DIAG_IS_NUM "$GB" && DIAG_IS_NUM "$GC" && DIAG_IS_NUM "$GD" &&
		printf '%d' $(((GA << 24) | (GB << 16) | (GC << 8) | GD))
}

GAUGE_ADC_TO_MAH() {
	printf '%d' $(($1 / 1000 * 172 / 3600 / GAUGE_RES_DIV))
}

GAUGE_MAH_TO_ADC() {
	printf '%d' $(($1 * GAUGE_RES_DIV * 3600 / 172 * 1000))
}

# The device tree OCV table is evenly spaced from 0% to 100%
GAUGE_OCV_PERCENT() {
	GAUGE_MV=$1
	# shellcheck disable=SC2086
	set -- $GAUGE_OCV
	[ $# -ge 2 ] || {
		printf '%s' "-1"
		return
	}
	GAUGE_STEP=$((100000 / ($# - 1)))
	GAUGE_I=0
	GAUGE_PREV=""
	for GAUGE_P in "$@"; do
		if [ "$GAUGE_MV" -le "$GAUGE_P" ]; then
			[ -z "$GAUGE_PREV" ] && printf '0' && return
			printf '%d' $((((GAUGE_I - 1) * GAUGE_STEP + (GAUGE_MV - GAUGE_PREV) * GAUGE_STEP / (GAUGE_P - GAUGE_PREV)) / 1000))
			return
		fi
		GAUGE_PREV=$GAUGE_P
		GAUGE_I=$((GAUGE_I + 1))
	done
	printf '100'
}

GAUGE_SAMPLE() {
	GAUGE_SUM_V=0
	GAUGE_SUM_I=0
	GAUGE_N=0
	while [ "$GAUGE_N" -lt "${1:-10}" ]; do
		GAUGE_V=$(DIAG_READ "$GAUGE_PS/voltage_now")
		GAUGE_C=$(DIAG_READ "$GAUGE_PS/current_now")
		DIAG_IS_NUM "$GAUGE_V" || GAUGE_V=0
		DIAG_IS_NUM "$GAUGE_C" || GAUGE_C=0
		GAUGE_SUM_V=$((GAUGE_SUM_V + GAUGE_V / 1000))
		GAUGE_SUM_I=$((GAUGE_SUM_I + GAUGE_C / 1000))
		GAUGE_N=$((GAUGE_N + 1))
		sleep 0.5
	done
	GAUGE_AVG_MV=$((GAUGE_SUM_V / GAUGE_N))
	GAUGE_AVG_MA=$((GAUGE_SUM_I / GAUGE_N))
}

# Removes the voltage drop across the battery's internal resistance before the lookup
GAUGE_ESTIMATE() {
	GAUGE_OCV_MV=$((GAUGE_AVG_MV - GAUGE_AVG_MA * GAUGE_BAT_RES / 1000))
	GAUGE_OCV_PERCENT "$GAUGE_OCV_MV"
}

GAUGE_STATE() {
	GAUGE_GG_STS=$(GAUGE_REG 0x57)
	GAUGE_FG_INIT=$(GAUGE_REG 0xA5)
	GAUGE_SOC=$(GAUGE_REG24 0x9C 0x9B 0x9A)
	GAUGE_CAP=$(GAUGE_REG24 0x9F 0x9E 0x9D)
	GAUGE_FCC=$(GAUGE_REG24 0xA2 0xA1 0xA0)
	GAUGE_Q_PRES=$(GAUGE_REG32 0x74 0x75 0x76 0x77)
	GAUGE_Q_INIT=$(GAUGE_REG32 0x70 0x71 0x72 0x73)
	GAUGE_Q_MAX=$(GAUGE_REG32 0x82 0x83 0x84 0x85)
	GAUGE_HALT=$(GAUGE_REG 0xA6)
	GAUGE_OFF=$(GAUGE_REG 0x6F)

	GAUGE_Q_VALID=1
	GAUGE_Q_MAH=""
	if DIAG_IS_NUM "$GAUGE_Q_PRES"; then
		[ $(((GAUGE_Q_PRES >> 31) & 1)) -eq 1 ] && GAUGE_Q_VALID=0
		GAUGE_Q_MAH=$(GAUGE_ADC_TO_MAH "$GAUGE_Q_PRES")
	fi
}

GAUGE_REPORT() {
	DIAG_SECTION "rk817 fuel gauge"
	DIAG_KV "Device tree node" "$GAUGE_DT"
	DIAG_KV "OCV table (mV)" "$GAUGE_OCV"
	DIAG_KV "Design capacity" "$GAUGE_DESIGN mAh"
	DIAG_KV "Design qmax" "$GAUGE_QMAX mAh"
	DIAG_KV "Sample resistor" "$(DIAG_DT_U32 "$GAUGE_DT/sample_res") mOhm"
	DIAG_KV "Battery resistance" "$GAUGE_BAT_RES mOhm"
	DIAG_KV "Zero algorithm" "$(DIAG_DT_U32 "$GAUGE_DT/zero_algorithm_vol") mV"
	DIAG_KV "Power off threshold" "$(DIAG_DT_U32 "$GAUGE_DT/power_off_thresd") mV"
	DIAG_KV "Virtual power" "$(DIAG_DT_U32 "$GAUGE_DT/virtual_power")"
	if [ -n "$GAUGE_CHG_DT" ]; then
		DIAG_KV "Charge voltage" "$(DIAG_DT_U32 "$GAUGE_CHG_DT/max_chrg_voltage") mV"
		DIAG_KV "Charge current" "$(DIAG_DT_U32 "$GAUGE_CHG_DT/max_chrg_current") mA"
		DIAG_KV "Input current" "$(DIAG_DT_U32 "$GAUGE_CHG_DT/max_input_current") mA"
		DIAG_KV "Finish current" "$(DIAG_DT_U32 "$GAUGE_CHG_DT/chrg_finish_cur") mA"
	fi

	GAUGE_STATE
	DIAG_OUT ""
	DIAG_KV "Battery reconnected" "$(((GAUGE_GG_STS >> 4) & 1)) (GG_STS 0x57 = $GAUGE_GG_STS)"
	DIAG_KV "OCV valid" "$(((GAUGE_GG_STS >> 7) & 1))"
	DIAG_KV "Boot loader init" "$(((GAUGE_FG_INIT >> 7) & 1)) (FG_INIT 0xA5 = $GAUGE_FG_INIT)"
	DIAG_IS_NUM "$GAUGE_SOC" && DIAG_KV "Saved level" "$GAUGE_SOC ($((GAUGE_SOC / 1000)).$(((GAUGE_SOC % 1000) / 100))%)"
	DIAG_KV "Saved remaining" "$GAUGE_CAP mAh"
	DIAG_KV "Full charge capacity" "$GAUGE_FCC mAh"
	DIAG_KV "Coulomb counter" "$GAUGE_Q_PRES ($GAUGE_Q_MAH mAh, valid $GAUGE_Q_VALID)"
	DIAG_IS_NUM "$GAUGE_Q_INIT" && DIAG_KV "Counter start" "$GAUGE_Q_INIT ($(GAUGE_ADC_TO_MAH "$GAUGE_Q_INIT") mAh)"
	DIAG_IS_NUM "$GAUGE_Q_MAX" && DIAG_KV "Gauge qmax" "$(GAUGE_ADC_TO_MAH "$GAUGE_Q_MAX") mAh"
	DIAG_KV "Halt count" "$GAUGE_HALT"
	DIAG_KV "Power off counter" "$GAUGE_OFF"
	DIAG_KV "Driver debug level" "$(DIAG_READ /sys/module/rk817_battery/parameters/dbg_level)"

	if [ -n "$GAUGE_REGMAP" ]; then
		DIAG_OUT "-- Gauge registers 0x50 to 0xA7"
		awk -F: '$1 >= "50" && $1 <= "a7" { printf "%s:%s ", $1, $2 } END { print "" }' "$GAUGE_REGMAP" | DIAG_APPEND
	fi
}

GAUGE_ANALYSE() {
	GAUGE_SAMPLE 6
	GAUGE_EST=$(GAUGE_ESTIMATE)
	GAUGE_KERNEL=$(DIAG_READ "$GAUGE_PS/capacity")

	DIAG_SECTION "rk817 fuel gauge analysis"
	DIAG_KV "Kernel capacity" "${GAUGE_KERNEL:-missing}%"
	DIAG_KV "Average reading" "$GAUGE_AVG_MV mV at $GAUGE_AVG_MA mA"
	DIAG_KV "OCV estimate" "${GAUGE_EST}%"

	if DIAG_IS_NUM "$GAUGE_KERNEL" && [ "$GAUGE_EST" -ge 0 ]; then
		GAUGE_DIFF=$(DIAG_ABS $((GAUGE_KERNEL - GAUGE_EST)))
		if [ "$GAUGE_KERNEL" -le 2 ] && [ "$GAUGE_EST" -ge 15 ]; then
			DIAG_FINDING "GAUGE" "The fuel gauge reports ${GAUGE_KERNEL}% but the battery voltage says about ${GAUGE_EST}%. The gauge restores a stale level from the PMIC at every boot. Run Battery Gauge Repair with the charger unplugged, or charge to 100% without interruption."
		elif [ "$GAUGE_DIFF" -ge 30 ]; then
			DIAG_FINDING "GAUGE" "The fuel gauge reports ${GAUGE_KERNEL}% but the battery voltage says about ${GAUGE_EST}%. A full uninterrupted charge recalibrates the gauge, or run Battery Gauge Repair."
		fi
	fi

	DIAG_IS_NUM "$GAUGE_SOC" && [ "$GAUGE_SOC" -eq 0 ] && [ "$GAUGE_EST" -ge 15 ] &&
		DIAG_FINDING "GAUGE" "The level saved in the PMIC is 0, so every boot starts at 0%."
	[ "$GAUGE_Q_VALID" -eq 0 ] &&
		DIAG_FINDING "GAUGE" "The PMIC flags its coulomb counter as invalid, so the gauge cannot count charge."
	if DIAG_IS_NUM "$GAUGE_FCC"; then
		if [ "$GAUGE_FCC" -lt 500 ] || { [ "$GAUGE_QMAX" -gt 0 ] && [ "$GAUGE_FCC" -gt "$GAUGE_QMAX" ]; }; then
			DIAG_FINDING "GAUGE" "The saved full charge capacity ($GAUGE_FCC mAh) is outside 500 to $GAUGE_QMAX mAh. The driver falls back to the design capacity."
		fi
	fi
	if DIAG_IS_NUM "$GAUGE_Q_MAH" && DIAG_IS_NUM "$GAUGE_CAP" && DIAG_IS_NUM "$GAUGE_FCC" && [ "$GAUGE_FCC" -gt 0 ]; then
		[ "$(DIAG_ABS $((GAUGE_Q_MAH - GAUGE_CAP)))" -gt $((GAUGE_FCC / 10)) ] &&
			DIAG_FINDING "GAUGE" "The coulomb counter (${GAUGE_Q_MAH} mAh) and the saved remaining capacity ($GAUGE_CAP mAh) differ by more than 10%. The next boot will treat the last shutdown as a crash."
	fi
	[ "$(DIAG_DT_U32 "$GAUGE_DT/virtual_power")" = "1" ] &&
		DIAG_FINDING "KERNEL" "The battery node enables virtual_power, so the driver reports fixed fake values."

	GAUGE_PWROFF=$(DIAG_DT_U32 "$GAUGE_DT/power_off_thresd")
	if DIAG_IS_NUM "$GAUGE_PWROFF" && [ "$GAUGE_AVG_MV" -gt 0 ] && [ "$GAUGE_AVG_MV" -le "$GAUGE_PWROFF" ]; then
		DIAG_FINDING "BATTERY" "The battery voltage ($GAUGE_AVG_MV mV) is at or below the power off threshold ($GAUGE_PWROFF mV). The battery really is flat."
	fi
}

GAUGE_WRITE() {
	i2cset -f -y "$GAUGE_BUS" "$GAUGE_ADDR" "$1" "$2" 2>/dev/null
}

# Prepares a repair: sets GAUGE_EST, GAUGE_NEW_CAP, GAUGE_NEW_SOC and GAUGE_NEW_Q, or explains why not
GAUGE_PLAN_REPAIR() {
	if ! command -v i2cset >/dev/null 2>&1 || ! command -v i2cget >/dev/null 2>&1; then
		GAUGE_REASON="i2cget and i2cset are not available on this system"
		return 1
	fi
	if [ -z "$GAUGE_OCV" ]; then
		GAUGE_REASON="The device tree has no OCV table for the battery"
		return 1
	fi
	if [ -z "$(i2cget -f -y "$GAUGE_BUS" "$GAUGE_ADDR" 0x00 2>/dev/null)" ]; then
		GAUGE_REASON="The PMIC does not answer on i2c-$GAUGE_BUS at $GAUGE_ADDR"
		return 1
	fi
	if [ "$(DIAG_READ "$GAUGE_PS/status")" != "Discharging" ]; then
		GAUGE_REASON="The battery is not discharging. Unplug the charger and try again"
		return 1
	fi

	GAUGE_SAMPLE 20
	GAUGE_EST=$(GAUGE_ESTIMATE)
	if [ "$GAUGE_EST" -lt 1 ] || [ "$GAUGE_EST" -gt 100 ]; then
		GAUGE_REASON="The voltage estimate ($GAUGE_EST%) is not usable"
		return 1
	fi

	GAUGE_STATE
	GAUGE_USE_FCC=$GAUGE_FCC
	if ! DIAG_IS_NUM "$GAUGE_USE_FCC" || [ "$GAUGE_USE_FCC" -lt 500 ] ||
		{ [ "$GAUGE_QMAX" -gt 0 ] && [ "$GAUGE_USE_FCC" -gt "$GAUGE_QMAX" ]; }; then
		GAUGE_USE_FCC=$GAUGE_DESIGN
	fi
	GAUGE_NEW_CAP=$((GAUGE_USE_FCC * GAUGE_EST / 100))
	GAUGE_NEW_SOC=$((GAUGE_EST * 1000))
	GAUGE_NEW_Q=$(GAUGE_MAH_TO_ADC "$GAUGE_NEW_CAP")
	return 0
}

# Writes the coulomb counter first, then the remaining capacity, then the level, and checks them
GAUGE_APPLY_REPAIR() {
	GAUGE_WRITE 0x70 $(((GAUGE_NEW_Q >> 24) & 0xFF))
	GAUGE_WRITE 0x71 $(((GAUGE_NEW_Q >> 16) & 0xFF))
	GAUGE_WRITE 0x72 $(((GAUGE_NEW_Q >> 8) & 0xFF))
	GAUGE_WRITE 0x73 $((GAUGE_NEW_Q & 0xFF))
	GAUGE_WRITE 0x9D $((GAUGE_NEW_CAP & 0xFF))
	GAUGE_WRITE 0x9E $(((GAUGE_NEW_CAP >> 8) & 0xFF))
	GAUGE_WRITE 0x9F $(((GAUGE_NEW_CAP >> 16) & 0xFF))
	GAUGE_WRITE 0x9A $((GAUGE_NEW_SOC & 0xFF))
	GAUGE_WRITE 0x9B $(((GAUGE_NEW_SOC >> 8) & 0xFF))
	GAUGE_WRITE 0x9C $(((GAUGE_NEW_SOC >> 16) & 0xFF))
	sleep 1

	GAUGE_STATE
	[ "$GAUGE_SOC" = "$GAUGE_NEW_SOC" ] && [ "$GAUGE_CAP" = "$GAUGE_NEW_CAP" ]
}
