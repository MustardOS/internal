#!/bin/sh

# shellcheck disable=SC2016

DETAIL_FILE="$LANDING_STATE/detail.json"
DETAIL_INTEGRITY_DIR="$MUOS_RUN_DIR/integrity"
DETAIL_INTEGRITY_SCRIPT="/opt/muos/script/system/tegridy.sh"
DETAIL_USAGE_DIR="$MUOS_RUN_DIR/battery_usage"
DETAIL_CATEGORIES="signature provenance scripts frontend device kernel modules dtb ramdisk bootloader boot_resources"

DETAIL_SERIAL=
DETAIL_STATIC=null

DETAIL_NUMBER() {
	case "$1" in
		'' | - | *[!0-9-]* | ?*-*) printf 'null' ;;
		*) printf '%s' "$1" ;;
	esac
}

DETAIL_FIRST() {
	for DF_PATH in "$@"; do
		DF_VALUE=$(READ_UINT "$DF_PATH")
		[ -n "$DF_VALUE" ] && [ "$DF_VALUE" -gt 0 ] && {
			printf '%s' "$DF_VALUE"
			return 0
		}
	done
}

DETAIL_GLOB() {
	for DG_PATH in $1; do
		[ -e "$DG_PATH" ] && {
			printf '%s' "$DG_PATH"
			return 0
		}
	done
}

DETAIL_RANGE() {
	tr -s ' \t' '\n' <"$1" 2>/dev/null |
		awk '$1 + 0 > 0 { if (!low || $1 + 0 < low) low = $1 + 0; if ($1 + 0 > high) high = $1 + 0 } END { if (low) printf "%d %d", low, high }'
}

DETAIL_GPU_MODEL() {
	DGM_INFO=$(DETAIL_GLOB "/sys/devices/platform/gpu/gpuinfo /sys/devices/platform/*gpu*/gpuinfo")
	if [ -n "$DGM_INFO" ]; then
		DGM_VALUE=$(READ_FILE "$DGM_INFO")
		[ -n "$DGM_VALUE" ] && {
			printf '%s' "${DGM_VALUE%% *}"
			return 0
		}
	fi

	DGM_COMPAT=$(DETAIL_GLOB "/sys/devices/platform/gpu/of_node/compatible /sys/devices/platform/*gpu*/of_node/compatible")
	[ -n "$DGM_COMPAT" ] || return 0

	case "$(tr '\000' ' ' <"$DGM_COMPAT" 2>/dev/null)" in
		*img*) printf 'PowerVR Rogue' ;;
		*mali*) printf 'Mali' ;;
	esac
}

DETAIL_CONNECTED() {
	DC_STATE=$(GET_VAR "device" "network/state")
	[ -n "$DC_STATE" ] && [ "$(READ_FILE "$DC_STATE")" = "up" ] && [ -n "$(DEVICE_ADDRESS)" ]
}

DETAIL_LINK_VALUE() {
	iw dev "$1" link 2>/dev/null | awk -v want="$2" '{ sub(/^[ \t]+/, "") } index($0, want) == 1 { sub(want "[ \t]*", ""); print; exit }'
}

DETAIL_NETWORK_DOC() {
	[ "$(GET_VAR "device" "board/network")" = "1" ] || {
		printf 'null'
		return 0
	}

	DN_IFACE=$(GET_VAR "device" "network/iface")
	DN_MAC=$(READ_FILE "/sys/class/net/$DN_IFACE/address")
	[ -n "$DN_MAC" ] || DN_MAC=$(READ_FILE "/opt/muos/config/network/mac")

	DN_CONNECTED=false
	DN_SSID=
	DN_SIGNAL=
	DN_FREQ=
	DN_GATEWAY=
	DN_DNS=

	if DETAIL_CONNECTED; then
		DN_CONNECTED=true
		DN_SSID=$(DETAIL_LINK_VALUE "$DN_IFACE" "SSID:")
		[ -n "$DN_SSID" ] || DN_SSID=$(wpa_cli -i "$DN_IFACE" status 2>/dev/null | sed -n 's/^ssid=//p')
		DN_SIGNAL=$(DETAIL_LINK_VALUE "$DN_IFACE" "signal:")
		DN_SIGNAL=${DN_SIGNAL%% *}
		DN_FREQ=$(DETAIL_LINK_VALUE "$DN_IFACE" "freq:")
		DN_FREQ=${DN_FREQ%%[!0-9]*}
		[ -n "$DN_FREQ" ] || DN_FREQ=$(wpa_cli -i "$DN_IFACE" status 2>/dev/null | sed -n 's/^freq=//p')
		DN_GATEWAY=$(ip route 2>/dev/null | awk '$1 == "default" { for (i = 2; i < NF; i++) if ($i == "via") { print $(i + 1); exit } }')
		DN_DNS=$(awk '$1 == "nameserver" { printf "%s%s", sep, $2; sep = " " }' /etc/resolv.conf 2>/dev/null)
	fi

	"$JQ_BIN" -n -c \
		--arg hostname "$(READ_FILE /etc/hostname)" \
		--arg mac "$DN_MAC" \
		--argjson connected "$DN_CONNECTED" \
		--arg ip "$(DEVICE_ADDRESS)" \
		--arg ssid "$DN_SSID" \
		--argjson signal "$(DETAIL_NUMBER "$DN_SIGNAL")" \
		--argjson frequency "$(DETAIL_NUMBER "$DN_FREQ")" \
		--arg gateway "$DN_GATEWAY" \
		--arg dns "$DN_DNS" \
		'{"hostname": $hostname, "mac": $mac, "connected": $connected, "ip": $ip, "ssid": $ssid,
		  "signal": $signal, "frequency": $frequency, "gateway": $gateway, "dns": $dns}' 2>/dev/null || printf 'null'
}

DETAIL_INTEGRITY_DOC() {
	if [ ! -e "$DETAIL_INTEGRITY_DIR/complete" ]; then
		[ -r "$DETAIL_INTEGRITY_SCRIPT" ] && sh "$DETAIL_INTEGRITY_SCRIPT" >/dev/null 2>&1 &
		printf 'null'
		return 0
	fi

	DI_OUT=
	for DI_CATEGORY in $DETAIL_CATEGORIES; do
		DI_CLEAN=false
		[ "$(READ_FILE "$DETAIL_INTEGRITY_DIR/$DI_CATEGORY")" = "Clean" ] && DI_CLEAN=true
		DI_OUT="${DI_OUT:+$DI_OUT,}\"$DI_CATEGORY\": $DI_CLEAN"
	done

	printf '{%s}' "$DI_OUT"
}

DETAIL_REFRESH_STATIC() {
	DETAIL_INTEGRITY_DONE=0
	[ -e "$DETAIL_INTEGRITY_DIR/complete" ] && DETAIL_INTEGRITY_DONE=1

	[ -n "$DETAIL_SERIAL" ] || DETAIL_SERIAL=$(/opt/muos/script/system/serial.sh 2>/dev/null)

	DR_CPU=$(awk -F': *' '/^model name/ && !model { model = $2 } /^processor/ { cores++ } END { printf "%s|%d", model, cores }' /proc/cpuinfo 2>/dev/null)
	DR_MODEL=${DR_CPU%|*}
	DR_CORES=${DR_CPU##*|}
	[ -n "$DR_MODEL" ] || DR_MODEL=$(lscpu 2>/dev/null | sed -n 's/^Model name:[ \t]*//p')

	DR_CPU_MIN=$(DETAIL_FIRST /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_min_freq /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq)
	DR_CPU_MAX=$(DETAIL_FIRST /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)

	DR_GPU_RANGE=
	DR_GPU_LIST=$(DETAIL_GLOB "/sys/class/devfreq/*gpu*/available_frequencies")
	[ -n "$DR_GPU_LIST" ] && DR_GPU_RANGE=$(DETAIL_RANGE "$DR_GPU_LIST")

	DR_WIDTH=$(GET_VAR "device" "screen/width")
	DR_HEIGHT=$(GET_VAR "device" "screen/height")
	DR_ZONE=$(readlink /etc/localtime 2>/dev/null)
	DR_ZONE=${DR_ZONE#*zoneinfo/}

	DETAIL_STATIC=$("$JQ_BIN" -n -c \
		--arg version "$(GET_VAR "system" "version")" \
		--arg build "$(GET_VAR "system" "build")" \
		--arg device "$(GET_VAR "device" "board/name")" \
		--arg serial "$DETAIL_SERIAL" \
		--arg kernel "$(uname -sr 2>/dev/null)" \
		--arg arch "$(uname -m 2>/dev/null)" \
		--arg display "${DR_WIDTH:+${DR_WIDTH}x$DR_HEIGHT}" \
		--arg cpu "$DR_MODEL" \
		--argjson cores "$(DETAIL_NUMBER "$DR_CORES")" \
		--argjson cpu_min "$(DETAIL_NUMBER "$DR_CPU_MIN")" \
		--argjson cpu_max "$(DETAIL_NUMBER "$DR_CPU_MAX")" \
		--arg gpu "$(DETAIL_GPU_MODEL)" \
		--argjson gpu_min "$(DETAIL_NUMBER "${DR_GPU_RANGE%% *}")" \
		--argjson gpu_max "$(DETAIL_NUMBER "${DR_GPU_RANGE##* }")" \
		--argjson design "$(DETAIL_NUMBER "$(GET_VAR "device" "battery/size")")" \
		--argjson network "$(DETAIL_NETWORK_DOC)" \
		--argjson integrity "$(DETAIL_INTEGRITY_DOC)" \
		--arg theme "$(GET_VAR "config" "theme/active")" \
		--arg language "$(GET_VAR "config" "settings/general/language")" \
		--arg zone "$DR_ZONE" \
		'{
			"system": {"version": $version, "build": $build, "device": $device, "serial": $serial,
			           "kernel": $kernel, "arch": $arch, "display": $display},
			"processor": {"cpu": $cpu, "cores": $cores, "cpu_min": $cpu_min, "cpu_max": $cpu_max,
			              "gpu": $gpu, "gpu_min": $gpu_min, "gpu_max": $gpu_max},
			"battery": {"design": $design},
			"network": $network,
			"integrity": $integrity,
			"frontend": {"theme": $theme, "language": $language, "zone": $zone}
		}' 2>/dev/null) || DETAIL_STATIC=null
	[ -n "$DETAIL_STATIC" ] || DETAIL_STATIC=null
}

DETAIL_WRITE() {
	if [ "${DETAIL_INTEGRITY_DONE:-0}" = 0 ] && [ -e "$DETAIL_INTEGRITY_DIR/complete" ]; then
		DETAIL_REFRESH_STATIC
	fi
	[ "$DETAIL_STATIC" != null ] || return 0

	read -r DW_LOAD1 DW_LOAD5 DW_LOAD15 DW_TASKS _ </proc/loadavg 2>/dev/null
	DW_TASKS=${DW_TASKS#*/}

	read -r DW_MEM_TOTAL DW_MEM_AVAILABLE DW_SWAP_TOTAL DW_SWAP_FREE <<-EOF
		$(awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 } /^SwapTotal:/ { st = $2 } /^SwapFree:/ { sf = $2 }
			END { printf "%d %d %d %d", t, a, st, sf }' /proc/meminfo 2>/dev/null)
	EOF

	DW_GOVERNOR_FILE=$(GET_VAR "device" "cpu/governor")
	[ -n "$DW_GOVERNOR_FILE" ] || DW_GOVERNOR_FILE=/sys/devices/system/cpu/cpufreq/policy0/scaling_governor

	DW_GPU_SPEED=
	DW_GPU_GOVERNOR=
	DW_GPU_DIR=$(DETAIL_GLOB "/sys/class/devfreq/*gpu*")
	if [ -n "$DW_GPU_DIR" ]; then
		DW_GPU_SPEED=$(READ_UINT "$DW_GPU_DIR/cur_freq")
		DW_GPU_GOVERNOR=$(READ_FILE "$DW_GPU_DIR/governor")
	fi
	[ -n "$DW_GPU_SPEED" ] || DW_GPU_SPEED=$(READ_UINT /sys/kernel/debug/clk/pll_gpu/clk_rate)

	DW_BATTERY_PATH=$(GET_VAR "device" "battery/capacity")
	DW_IFACE=$(GET_VAR "device" "network/iface")

	DW_TMP=$(mktemp "$LANDING_STATE/.detail.XXXXXX") || return 1

	if "$JQ_BIN" -n \
		--argjson static "$DETAIL_STATIC" \
		--argjson epoch "$WS_NOW" \
		--argjson uptime "$WS_UPTIME" \
		--arg load1 "${DW_LOAD1:-}" --arg load5 "${DW_LOAD5:-}" --arg load15 "${DW_LOAD15:-}" \
		--argjson tasks "$(DETAIL_NUMBER "$DW_TASKS")" \
		--argjson mem_total "$(DETAIL_NUMBER "$DW_MEM_TOTAL")" \
		--argjson mem_available "$(DETAIL_NUMBER "$DW_MEM_AVAILABLE")" \
		--argjson swap_total "$(DETAIL_NUMBER "$DW_SWAP_TOTAL")" \
		--argjson swap_free "$(DETAIL_NUMBER "$DW_SWAP_FREE")" \
		--argjson temperature "$(DETAIL_NUMBER "$(DETAIL_FIRST /sys/class/thermal/thermal_zone0/temp /sys/class/thermal/thermal_zone1/temp)")" \
		--argjson cpu_speed "$(DETAIL_NUMBER "$(DETAIL_FIRST /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_cur_freq /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq)")" \
		--arg governor "$(READ_FILE "$DW_GOVERNOR_FILE")" \
		--argjson gpu_speed "$(DETAIL_NUMBER "$DW_GPU_SPEED")" \
		--arg gpu_governor "$DW_GPU_GOVERNOR" \
		--argjson capacity "$(DETAIL_NUMBER "$(READ_UINT "$BATTERY_DIR/capacity")")" \
		--argjson voltage "$(DETAIL_NUMBER "$(READ_UINT "$BATTERY_DIR/voltage")")" \
		--argjson charging "$(DETAIL_NUMBER "$(READ_UINT "$BATTERY_DIR/charging")")" \
		--arg status "$(READ_FILE "${DW_BATTERY_PATH%/*}/status")" \
		--arg health "$(READ_FILE "$(GET_VAR "device" "battery/health")")" \
		--argjson last_charged "$(DETAIL_NUMBER "$(READ_FILE "$DETAIL_USAGE_DIR/last_charged")")" \
		--argjson time_on_battery "$(DETAIL_NUMBER "$(READ_FILE "$DETAIL_USAGE_DIR/time_on_battery")")" \
		--argjson unplug "$(DETAIL_NUMBER "$(READ_FILE "$DETAIL_USAGE_DIR/unplug_capacity")")" \
		--argjson shutdown "$(DETAIL_NUMBER "$(READ_FILE "$DETAIL_USAGE_DIR/last_shutdown_capacity")")" \
		--argjson boot "$(DETAIL_NUMBER "$(READ_FILE "$DETAIL_USAGE_DIR/last_boot_capacity")")" \
		--argjson off_duration "$(DETAIL_NUMBER "$(READ_FILE "$DETAIL_USAGE_DIR/last_off_duration")")" \
		--argjson off_delta "$(DETAIL_NUMBER "$(READ_FILE "$DETAIL_USAGE_DIR/last_off_capacity_delta")")" \
		--argjson rx "$(DETAIL_NUMBER "$(READ_UINT "/sys/class/net/$DW_IFACE/statistics/rx_bytes")")" \
		--argjson tx "$(DETAIL_NUMBER "$(READ_UINT "/sys/class/net/$DW_IFACE/statistics/tx_bytes")")" \
		--argjson storage "$STORAGE_CACHE" \
		'$static * {
			"epoch": $epoch,
			"runtime": {"uptime": $uptime, "load": [$load1, $load5, $load15], "tasks": $tasks,
			            "memory": {"total": $mem_total, "available": $mem_available},
			            "swap": {"total": $swap_total, "free": $swap_free}, "temperature": $temperature},
			"processor": {"speed": $cpu_speed, "governor": $governor, "gpu_speed": $gpu_speed,
			              "gpu_governor": $gpu_governor},
			"battery": {"capacity": $capacity, "voltage": $voltage, "charging": $charging, "status": $status,
			            "health": $health},
			"power": {"last_charged": $last_charged, "time_on_battery": $time_on_battery, "unplug": $unplug,
			          "shutdown": $shutdown, "boot": $boot, "off_duration": $off_duration, "off_delta": $off_delta},
			"traffic": {"rx": $rx, "tx": $tx},
			"storage": $storage
		}' >"$DW_TMP" 2>/dev/null; then
		chmod 0644 "$DW_TMP"
		mv -f "$DW_TMP" "$DETAIL_FILE" && return 0
	fi

	rm -f "$DW_TMP"
	return 1
}
