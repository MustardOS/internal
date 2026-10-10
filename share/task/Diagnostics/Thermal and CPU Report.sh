#!/bin/sh
# HELP: Thermal and CPU Report - Checks temperatures, CPU and GPU clocks, memory and the busiest processes, then saves a report to SD1
# ICON: diagnostic
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/diag.sh

DIAG_BEGIN "thermal_cpu_report" "Thermal and CPU Report"

DIAG_SECTION "muOS CPU configuration"
DIAG_CONFIG "$MUOS_CONF_DEVICE/cpu"
DIAG_KV "Default governor" "$(GET_VAR "device" "cpu/default" 2>/dev/null)"

DIAG_SECTION "CPU cores"
DIAG_KV "Possible" "$(DIAG_READ /sys/devices/system/cpu/possible)"
DIAG_KV "Online" "$(DIAG_READ /sys/devices/system/cpu/online)"
DIAG_KV "Offline" "$(DIAG_READ /sys/devices/system/cpu/offline)"
DIAG_KV "Load average" "$(DIAG_READ /proc/loadavg)"
for POLICY in /sys/devices/system/cpu/cpufreq/policy* /sys/devices/system/cpu/cpu0/cpufreq; do
	[ -d "$POLICY" ] || continue
	DIAG_OUT "-- $POLICY"
	for ATTR in affected_cpus scaling_governor scaling_cur_freq scaling_min_freq scaling_max_freq cpuinfo_min_freq \
		cpuinfo_max_freq scaling_available_frequencies scaling_available_governors; do
		[ -r "$POLICY/$ATTR" ] && DIAG_KV "   $ATTR" "$(DIAG_READ "$POLICY/$ATTR")"
	done
	if [ -r "$POLICY/stats/time_in_state" ]; then
		DIAG_OUT "   time in state (frequency, 10 ms units):"
		DIAG_READ "$POLICY/stats/time_in_state" | DIAG_APPEND
	fi
	SCALING_MAX=$(DIAG_READ "$POLICY/scaling_max_freq")
	HARDWARE_MAX=$(DIAG_READ "$POLICY/cpuinfo_max_freq")
	if DIAG_IS_NUM "$SCALING_MAX" && DIAG_IS_NUM "$HARDWARE_MAX" && [ "$SCALING_MAX" -lt $((HARDWARE_MAX * 3 / 4)) ]; then
		DIAG_FINDING "CPU" "The CPU is capped at $((SCALING_MAX / 1000)) MHz of a possible $((HARDWARE_MAX / 1000)) MHz."
	fi
done

DIAG_SECTION "GPU"
for GPU in /sys/class/devfreq/*; do
	[ -d "$GPU" ] || continue
	DIAG_OUT "-- $(basename "$GPU")"
	for ATTR in governor cur_freq min_freq max_freq available_frequencies; do
		[ -r "$GPU/$ATTR" ] && DIAG_KV "   $ATTR" "$(DIAG_READ "$GPU/$ATTR")"
	done
done

DIAG_SECTION "Temperatures"
HOTTEST=0
for ZONE in /sys/class/thermal/thermal_zone*; do
	[ -d "$ZONE" ] || continue
	TEMP=$(DIAG_READ "$ZONE/temp")
	DIAG_IS_NUM "$TEMP" || continue
	[ "$TEMP" -gt 1000 ] && TEMP=$((TEMP / 1000))
	TRIPS=""
	for TRIP in "$ZONE"/trip_point_*_temp; do
		[ -r "$TRIP" ] && TRIPS="$TRIPS $(($(DIAG_READ "$TRIP") / 1000))"
	done
	DIAG_KV "$(DIAG_READ "$ZONE/type")" "${TEMP} C (trip points:${TRIPS:- none}, policy $(DIAG_READ "$ZONE/policy"))"
	[ "$TEMP" -gt "$HOTTEST" ] && HOTTEST=$TEMP
done
[ "$HOTTEST" -ge 85 ] && DIAG_FINDING "THERMAL" "The device is running at ${HOTTEST} C. Expect throttling or shutdowns."
[ "$HOTTEST" -ge 75 ] && [ "$HOTTEST" -lt 85 ] && DIAG_FINDING "THERMAL" "The device is warm (${HOTTEST} C)."
for COOLING in /sys/class/thermal/cooling_device*; do
	[ -d "$COOLING" ] || continue
	CUR=$(DIAG_READ "$COOLING/cur_state")
	DIAG_KV "$(DIAG_READ "$COOLING/type")" "state ${CUR} of $(DIAG_READ "$COOLING/max_state")"
	DIAG_IS_NUM "$CUR" && [ "$CUR" -gt 0 ] && DIAG_FINDING "THERMAL" "$(DIAG_READ "$COOLING/type") is throttling (state $CUR)."
done

DIAG_SECTION "Memory"
DIAG_CMD "free" free -m
DIAG_FILE /proc/swaps
AVAILABLE=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
TOTAL=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
if DIAG_IS_NUM "$AVAILABLE" && DIAG_IS_NUM "$TOTAL" && [ "$TOTAL" -gt 0 ] && [ $((AVAILABLE * 100 / TOTAL)) -lt 10 ]; then
	DIAG_FINDING "MEMORY" "Only $((AVAILABLE / 1024)) MB of $((TOTAL / 1024)) MB memory is available."
fi
OOM=$(dmesg 2>/dev/null | grep -ci "out of memory\|oom-killer")
[ "${OOM:-0}" -gt 0 ] && DIAG_FINDING "MEMORY" "The kernel killed processes for lack of memory $OOM time(s) since boot."

DIAG_SECTION "Busiest processes"
DIAG_CMD "top" top -b -n 1

DIAG_SECTION "Kernel messages"
DIAG_DMESG "thermal|throttl|cpufreq|devfreq|over.?temp|oom" 40

DIAG_FINISH "Thermal and CPU report saved"
exit 0
