#!/bin/sh

. /opt/muos/script/var/func.sh

ADDR=$(GET_VAR "config" "network/address")
SUBN=$(GET_VAR "config" "network/subnet")
SSID=$(GET_VAR "config" "network/ssid")
PASS=$(GET_VAR "config" "network/pass")
GATE=$(GET_VAR "config" "network/gateway")
TYPE=$(GET_VAR "config" "network/type")
DNSA=$(GET_VAR "config" "network/dns")

case "$1" in
	start | restart | connect) DEL_VAR "config" "network/address" ;;
esac

FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")
BOARD_NAME=$(GET_VAR "device" "board/name")

HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_MODULE=$(GET_VAR "device" "network/module")
NET_IFACE=$(GET_VAR "device" "network/iface")
NET_NAME=$(GET_VAR "device" "network/name")

NET_COMPAT=$(GET_VAR "config" "settings/network/compat")
MAX_WAIT=$(GET_VAR "config" "settings/network/wait_timer")
RETRIES=$(GET_VAR "config" "settings/network/con_retry")
RETRY_DELAY="${RETRY_DELAY:-2}"

CONNECT_ON_BOOT=$(GET_VAR "config" "settings/network/boot")
NET_DRIVER_TYPE=$(GET_VAR "device" "network/type")

CUS_HOST="MUOS/info/hostname"
DEV_HOST=$(GET_VAR "device" "network/hostname")
SD1_HOST="$(GET_VAR "device" "storage/rom/mount")/$CUS_HOST"
SD2_HOST="$(GET_VAR "device" "storage/sdcard/mount")/$CUS_HOST"

SCN_PATH="/sys/class/net"
RESOLV_CONF="/etc/resolv.conf"
DHCP_CONF_SRC="${MUOS_SHARE_DIR}/conf/dhcpcd.conf"
DHCP_CONF_RUN="$MUOS_RUN_DIR/dhcpcd.conf"
DHCPCD_LOG="$MUOS_RUN_DIR/dhcpcd.log"

# Per profile network states!
NET_STATUS_DIR="$MUOS_RUN_DIR/network"
CURRENT_PROFILE=""

[ -n "$NET_IFACE" ] || NET_IFACE=$(GET_VAR "device" "network/iface_active")
[ -n "$NET_IFACE" ] || NET_IFACE="wlan0"

IFCE=$(GET_VAR "device" "network/iface_active")
[ -n "$IFCE" ] || IFCE="$NET_IFACE"

RC_OK=0
RC_FAIL=1
RC_INVALID_PASSWORD=2
RC_AP_NOT_FOUND=3
RC_AUTH_TIMEOUT=4
RC_DHCP_FAILED=5
RC_LINK_TIMEOUT=6
RC_WPA_START_FAILED=7

# Just in case some weird shit happens and the DNS is being
# cleared for whatever reason: https://dns.kitchen/jingle
if [ -z "$DNSA" ]; then
	DNSA="1.1.1.1"
	SET_VAR "config" "network/dns" "$DNSA"
fi

NET_STATUS() {
	[ -n "$CURRENT_PROFILE" ] || return 0
	mkdir -p "$NET_STATUS_DIR" 2>/dev/null
	printf "%s" "$1" >"$NET_STATUS_DIR/$CURRENT_PROFILE.status"
}

NET_STATUS_CLEAR() {
	[ -n "$CURRENT_PROFILE" ] && rm -f "$NET_STATUS_DIR/$CURRENT_PROFILE.status"
}

SET_ACTIVE() {
	SET_VAR "config" "network/active" "$1"
}

CLEAR_ACTIVE() {
	SET_VAR "config" "network/active" ""
}

FAIL_WITH() {
	NET_STATUS "$1"
	return "${2:-$RC_FAIL}"
}

MODULE_LOADED() {
	[ -n "$1" ] || return 1
	grep -q "^$1 " /proc/modules
}

NETWORK_DAEMONS_RUNNING() {
	ps | awk '
		/[d]hcpcd/ || /[u]dhcpc/ || /[w]pa_supplicant/ {
			FOUND = 1
			exit
		}

		END {
			exit FOUND ? 0 : 1
		}
	'
}

FORCE_SDIO_AWAKE() {
	for P in /sys/bus/sdio/devices/*/power/control; do
		[ -f "$P" ] || continue
		echo on >"$P"
	done
}

WAIT_FOR_SDIO() {
	I=0

	while [ "$I" -lt "${MAX_WAIT:-5}" ]; do
		[ -d "/sys/bus/mmc/devices/mmc2:0001" ] && return 0
		I=$((I + 1))
		sleep 1
	done

	return 1
}

WAIT_FOR_IFACE_SCAN() {
	W_IFACE=$1
	I=0

	while [ "$I" -lt "${MAX_WAIT:-5}" ]; do
		if [ -n "$W_IFACE" ] && [ -d "$SCN_PATH/$W_IFACE" ]; then
			printf "%s" "$W_IFACE"
			return 0
		fi
		if [ -d "$SCN_PATH/wlan0" ]; then
			printf "%s" "wlan0"
			return 0
		fi
		for N in "$SCN_PATH"/wlan* "$SCN_PATH"/eth*; do
			[ -d "$N" ] || continue
			printf "%s" "${N##*/}"
			return 0
		done
		I=$((I + 1))
		sleep 1
	done

	return 1
}

LOAD_MODULE() {
	[ "${HAS_NETWORK:-0}" -eq 0 ] && return 0

	if MODULE_LOADED "$NET_NAME"; then
		case "$BOARD_NAME" in
			rg-vita*)
				# PCIe WiFi - autoloaded by kernel, no SDIO reload cycle needed
				;;
			rg*)
				modprobe -qr "$NET_NAME"
				sleep 1
				;;
		esac
	fi

	FORCE_SDIO_AWAKE

	case "$BOARD_NAME" in
		rg-vita*)
			# PCIe WiFi - autoloaded by kernel, only load if somehow missing
			if [ -n "$NET_NAME" ] && ! MODULE_LOADED "$NET_NAME"; then
				modprobe -qf "$NET_NAME"
			fi
			;;
		rg*)
			if [ -n "$NET_NAME" ] && ! MODULE_LOADED "$NET_NAME"; then
				modprobe -qf "$NET_NAME"
			fi
			;;
		mgx* | tui*)
			if [ -n "$NET_NAME" ] && ! MODULE_LOADED "$NET_NAME"; then
				modprobe -q "$NET_MODULE"
			fi
			;;
		rk*)
			modprobe -q cfg80211
			if [ -n "$NET_NAME" ] && ! MODULE_LOADED "$NET_NAME"; then
				modprobe -q "$NET_NAME"
			fi
			;;
	esac

	sleep 1

	if [ "${NET_COMPAT:-0}" -eq 1 ]; then
		case "$BOARD_NAME" in
			rg*) WAIT_FOR_SDIO || return 1 ;;
		esac
	fi

	NET_IFACE_TMP=$(WAIT_FOR_IFACE_SCAN "$NET_IFACE")
	if [ -n "$NET_IFACE_TMP" ]; then
		NET_IFACE="$NET_IFACE_TMP"
		IFCE="$NET_IFACE_TMP"
	elif [ -z "$NET_IFACE" ]; then
		NET_IFACE=$(GET_VAR "device" "network/iface_active")
		[ -n "$NET_IFACE" ] || NET_IFACE="wlan0"
		IFCE="$NET_IFACE"
	fi

	SET_VAR "device" "network/iface_active" "$IFCE"

	ip link set "$IFCE" up
	sleep 1

	[ -L "$SCN_PATH/$IFCE/phy80211" ] && iw dev "$IFCE" set power_save off

	if [ -n "$DNSA" ]; then
		[ -f "$RESOLV_CONF" ] && cp "$RESOLV_CONF" "$RESOLV_CONF.bak"
		printf "nameserver %s\n" "$DNSA" >"$RESOLV_CONF"
	fi

	return 0
}

UNLOAD_MODULE() {
	[ "${HAS_NETWORK:-0}" -eq 0 ] && return 0

	if [ -n "$IFCE" ] && [ -d "$SCN_PATH/$IFCE" ]; then
		iw dev "$IFCE" disconnect
		iw dev "$IFCE" set power_save off
		ip addr flush dev "$IFCE"
		ip route del default dev "$IFCE"
		ip link set "$IFCE" down
	fi

	killall -q wpa_supplicant dhcpcd udhcpc
	sleep 2

	# PCIe WiFi modules are autoloaded by the kernel - don't unload them
	# as modprobe -qf silently fails to reload them after removal
	case "$BOARD_NAME" in
		rg-vita*) ;;
		*)
			if MODULE_LOADED "$NET_NAME"; then
				modprobe -qr "$NET_NAME"
				sleep 2
			fi
			;;
	esac

	[ -f "$RESOLV_CONF.bak" ] && mv -f "$RESOLV_CONF.bak" "$RESOLV_CONF"

	return 0
}

RELOAD_MODULE() {
	UNLOAD_MODULE
	sleep 2
	LOAD_MODULE
}

WAIT_FOR_MODULE() {
	MOD="$1"
	TIMEOUT="${2:-5}"
	I=0
	while [ "$I" -lt "$TIMEOUT" ]; do
		MODULE_LOADED "$MOD" && return 0
		I=$((I + 1))
		sleep 1
	done
	return 1
}

WAIT_FOR_IFACE() {
	IFACE="$1"
	TIMEOUT="${2:-5}"
	I=0
	while [ "$I" -lt "$TIMEOUT" ]; do
		[ -d "/sys/class/net/$IFACE" ] && return 0
		I=$((I + 1))
		sleep 1
	done
	return 1
}

WAIT_FOR_IFACE_READY() {
	IFACE="$1"
	TIMEOUT="${2:-5}"
	I=0
	while [ "$I" -lt "$TIMEOUT" ]; do
		ip link set "$IFACE" up && return 0
		I=$((I + 1))
		sleep 1
	done
	return 1
}

DESTROY_DHCPCD() {
	if NETWORK_DAEMONS_RUNNING; then
		killall -q dhcpcd udhcpc wpa_supplicant

		WAIT_PROCESS_GONE dhcpcd 3
		WAIT_PROCESS_GONE udhcpc 3
		WAIT_PROCESS_GONE wpa_supplicant 3

		if NETWORK_DAEMONS_RUNNING; then
			killall -9 dhcpcd udhcpc wpa_supplicant
			WAIT_PROCESS_GONE dhcpcd 2
			WAIT_PROCESS_GONE udhcpc 2
			WAIT_PROCESS_GONE wpa_supplicant 2
		fi
	fi

	rm -rf /var/run/wpa_supplicant 2>/dev/null
	mkdir -p /var/run/wpa_supplicant 2>/dev/null
}

RESTORE_HOSTNAME() {
	HOSTFILE=""
	[ -e "$DEV_HOST" ] && HOSTFILE="$DEV_HOST"
	[ -z "$HOSTFILE" ] && [ -e "$SD2_HOST" ] && HOSTFILE="$SD2_HOST"
	[ -z "$HOSTFILE" ] && [ -e "$SD1_HOST" ] && HOSTFILE="$SD1_HOST"
	[ -z "$HOSTFILE" ] && return 0

	IFS= read -r HOSTNAME <"$HOSTFILE"
	hostname "$HOSTNAME"
	printf "%s" "$HOSTNAME" >"/etc/hostname"

	LOG_INFO "$0" 0 "NETWORK" "$(printf "Hostname restored to %s" "$HOSTNAME")"
}

PREPARE_DHCPCD_CONF() {
	mkdir -p "$MUOS_RUN_DIR" || return 1

	if [ ! -f "$DHCP_CONF_SRC" ]; then
		LOG_ERROR "$0" 0 "NETWORK" "$(printf "Missing dhcpcd config: %s" "$DHCP_CONF_SRC")"
		return 1
	fi

	cp "$DHCP_CONF_SRC" "$DHCP_CONF_RUN" || {
		LOG_ERROR "$0" 0 "NETWORK" "$(printf "Failed to copy dhcpcd config: %s -> %s" "$DHCP_CONF_SRC" "$DHCP_CONF_RUN")"
		return 1
	}

	return 0
}

CALCULATE_IAID() {
	MAC_FILE="/sys/class/net/$IFCE/address"
	[ -r "$MAC_FILE" ] || return 1

	IFS= read -r MAC <"$MAC_FILE"
	O5=${MAC#*:*:*:*:}
	O5=${O5%%:*}
	O6=${MAC##*:}

	case "$O5$O6" in
		"" | *[!0123456789abcdefABCDEF]*) return 1 ;;
	esac

	IAID=$(((0x$O5 << 8) | 0x$O6))

	PREPARE_DHCPCD_CONF || return 1

	DHCP_CONF_TMP="$DHCP_CONF_RUN.$$"

	{
		awk '$1 != "iaid"' "$DHCP_CONF_RUN"
		printf "iaid %s\n" "$IAID"
	} >"$DHCP_CONF_TMP" || {
		rm -f "$DHCP_CONF_TMP"
		return 1
	}

	mv -f "$DHCP_CONF_TMP" "$DHCP_CONF_RUN" || {
		rm -f "$DHCP_CONF_TMP"
		return 1
	}

	LOG_INFO "$0" 0 "NETWORK" "$(printf "Using IAID: %s" "$IAID")"

	return 0
}

LOG_DHCPCD_OUTPUT() {
	[ -s "$DHCPCD_LOG" ] || return 0

	while IFS= read -r LINE || [ -n "$LINE" ]; do
		[ -n "$LINE" ] || continue
		LOG_WARN "$0" 0 "NETWORK" "$(printf "dhcpcd: %s" "$LINE")"
	done <"$DHCPCD_LOG"

	return 0
}

MASK_TO_CIDR() {
	MASK="$1"
	case "$MASK" in
		*.*.*.*) ;;
		*)
			printf "%s" "$MASK"
			return
			;;
	esac

	BITS=0
	IFS=.
	for OCTET in $MASK; do
		VAL=$OCTET
		while [ "$VAL" -gt 0 ]; do
			BITS=$((BITS + (VAL & 1)))
			VAL=$((VAL >> 1))
		done
	done
	unset IFS

	printf "%s" "$BITS"
}

WPA_RUNNING() {
	pgrep -f "wpa_supplicant.*$IFCE" >/dev/null 2>&1
}

WAIT_PROCESS_GONE() {
	PROC_NAME="$1"
	TIMEOUT="${2:-5}"
	I=0

	[ -n "$PROC_NAME" ] || return 0

	while [ "$I" -lt "$TIMEOUT" ]; do
		if ! pgrep -x "$PROC_NAME" >/dev/null 2>&1; then
			return 0
		fi

		I=$((I + 1))
		sleep 1
	done

	return 1
}

WPA_CONFIG_HEADER() {
	[ "$IFCE" = "eth0" ] && return 0
	[ -n "$WPA_CONFIG" ] || return 1

	mkdir -p /var/run/wpa_supplicant 2>/dev/null

	if [ -f "$WPA_CONFIG" ] && grep -q '^ctrl_interface=' "$WPA_CONFIG"; then
		return 0
	fi

	WPA_CONFIG_TMP="$WPA_CONFIG.$$"

	{
		printf "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=0\n"
		printf "update_config=1\n"
		[ -f "$WPA_CONFIG" ] && cat "$WPA_CONFIG"
	} >"$WPA_CONFIG_TMP" || {
		rm -f "$WPA_CONFIG_TMP"
		return 1
	}

	mv -f "$WPA_CONFIG_TMP" "$WPA_CONFIG"
}

WPA_STATUS_VALUE() {
	WPA_KEY="$1"
	[ -n "$WPA_KEY" ] || return 1
	command -v wpa_cli >/dev/null 2>&1 || return 1

	wpa_cli -i "$IFCE" status 2>/dev/null | awk -F= -v KEY="$WPA_KEY" '$1 == KEY { print $2; exit }'
}

WAIT_WPA_COMPLETED() {
	[ "$IFCE" = "eth0" ] && return 0
	[ -n "$PASS" ] || return 0
	command -v wpa_cli >/dev/null 2>&1 || return 0

	WAIT=25
	while [ "$WAIT" -gt 0 ]; do
		WPA_STATE=$(WPA_STATUS_VALUE "wpa_state")

		case "$WPA_STATE" in
			COMPLETED)
				LOG_INFO "$0" 0 "NETWORK" "WPA handshake completed"
				return 0
				;;
			DISCONNECTED | INACTIVE)
				if ! WPA_RUNNING; then
					LOG_ERROR "$0" 0 "NETWORK" "WPA Supplicant exited before handshake completed"
					FAIL_WITH "INVALID_PASSWORD" "$RC_INVALID_PASSWORD"
					return $?
				fi
				;;
		esac

		LOG_WARN "$0" 0 "NETWORK" "$(printf "Waiting for WPA completion... (%ds, state: %s)" "$WAIT" "${WPA_STATE:-unknown}")"
		WAIT=$((WAIT - 1))
		sleep 1
	done

	LOG_ERROR "$0" 0 "NETWORK" "WPA authentication timeout"
	FAIL_WITH "AUTH_TIMEOUT" "$RC_AUTH_TIMEOUT"
}

WAIT_CARRIER() {
	[ "$IFCE" = "eth0" ] && return 0

	I=0
	while [ "$I" -lt 5 ]; do
		IFS= read -r CARRIER_VAL <"/sys/class/net/$IFCE/carrier" 2>/dev/null
		[ "${CARRIER_VAL:-}" = "1" ] && return 0
		I=$((I + 1))
		sleep 1
	done

	LOG_ERROR "$0" 0 "NETWORK" "Link carrier timeout"
	FAIL_WITH "LINK_TIMEOUT" "$RC_LINK_TIMEOUT"
}

WAIT_NETWORK_ASSOC() {
	[ "$IFCE" = "eth0" ] && return 0

	[ "$NET_DRIVER_TYPE" = "wext" ] && iwconfig "$IFCE" retry off

	WAIT=20
	while [ "$WAIT" -gt 0 ]; do
		case "$NET_DRIVER_TYPE" in
			wext)
				OUT=$(iwconfig "$IFCE")
				case "$OUT" in
					*'ESSID:"'*)
						LOG_INFO "$0" 0 "NETWORK" "WiFi Associated!"
						WAIT_WPA_COMPLETED || return $?
						return 0
						;;
				esac
				;;
			nl80211)
				if iw dev "$IFCE" link | grep -q "SSID:"; then
					LOG_INFO "$0" 0 "NETWORK" "WiFi Associated!"
					WAIT_WPA_COMPLETED || return $?
					return 0
				fi
				;;
		esac

		if WPA_RUNNING; then
			:
		else
			if [ -n "$PASS" ]; then
				LOG_ERROR "$0" 0 "NETWORK" "WPA Supplicant exited before association completed"
				FAIL_WITH "AUTH_TIMEOUT" "$RC_AUTH_TIMEOUT"
				return $?
			fi
		fi

		LOG_WARN "$0" 0 "NETWORK" "$(printf "Waiting for WiFi Association... (%ds)" "$WAIT")"
		WAIT=$((WAIT - 1))
		sleep 1
	done

	LOG_ERROR "$0" 0 "NETWORK" "Association timeout"

	if [ -n "$PASS" ]; then
		FAIL_WITH "AUTH_TIMEOUT" "$RC_AUTH_TIMEOUT"
		return $?
	fi

	FAIL_WITH "FAILED" "$RC_FAIL"
}

WIFI_CONFIG() {
	[ "$IFCE" = "eth0" ] && return 0

	LOG_INFO "$0" 0 "NETWORK" "$(printf "Setting ESSID: %s" "$SSID")"

	if [ -n "$PASS" ]; then
		NET_STATUS "AUTHENTICATING"
		/opt/muos/script/web/password.sh
		WPA_CONFIG_HEADER || {
			LOG_ERROR "$0" 0 "NETWORK" "Failed to prepare WPA control interface"
			FAIL_WITH "WPA_START_FAILED" "$RC_WPA_START_FAILED"
			return $?
		}

		case "$NET_DRIVER_TYPE" in
			wext)
				LOG_INFO "$0" 0 "NETWORK" "Starting WPA Supplicant (wext)"
				if ! wpa_supplicant -B -i "$IFCE" -c "$WPA_CONFIG" -D wext; then
					LOG_ERROR "$0" 0 "NETWORK" "Failed to start WPA Supplicant (wext)"
					FAIL_WITH "WPA_START_FAILED" "$RC_WPA_START_FAILED"
					return $?
				fi
				;;
			nl80211)
				LOG_INFO "$0" 0 "NETWORK" "Starting WPA Supplicant (nl80211)"
				if ! wpa_supplicant -B -i "$IFCE" -c "$WPA_CONFIG" -D nl80211; then
					LOG_ERROR "$0" 0 "NETWORK" "Failed to start WPA Supplicant (nl80211)"
					FAIL_WITH "WPA_START_FAILED" "$RC_WPA_START_FAILED"
					return $?
				fi
				;;
		esac
	else
		LOG_INFO "$0" 0 "NETWORK" "Connecting to open network"
		iwconfig "$IFCE" mode Managed
		iwconfig "$IFCE" essid -- "$SSID"
		iwconfig "$IFCE" key off
	fi

	NET_STATUS "ASSOCIATING"
	WAIT_NETWORK_ASSOC || return $?
	WAIT_CARRIER || return $?

	return 0
}

IP_DHCP() {
	NET_STATUS "WAITING_IP"

	if command -v dhcpcd >/dev/null 2>&1; then
		LOG_INFO "$0" 0 "NETWORK" "dhcpcd was found!"

		CALCULATE_IAID || {
			LOG_ERROR "$0" 0 "NETWORK" "Failed to prepare dhcpcd config"
			FAIL_WITH "DHCP_FAILED" "$RC_DHCP_FAILED"
			return $?
		}

		rm -f "$DHCPCD_LOG"

		if ! dhcpcd -4 -q -f "$DHCP_CONF_RUN" "$IFCE" >"$DHCPCD_LOG" 2>&1; then
			LOG_ERROR "$0" 0 "NETWORK" "$(printf "dhcpcd failed using %s" "$DHCP_CONF_RUN")"
			LOG_DHCPCD_OUTPUT
			FAIL_WITH "DHCP_FAILED" "$RC_DHCP_FAILED"
			return $?
		fi
	elif command -v udhcpc >/dev/null 2>&1; then
		LOG_INFO "$0" 0 "NETWORK" "udhcpc was found!"
		udhcpc -i "$IFCE" -b -q >/dev/null 2>&1
	else
		LOG_ERROR "$0" 0 "NETWORK" "No DHCP client found (tried dhcpcd, udhcpc)"
		FAIL_WITH "DHCP_FAILED" "$RC_DHCP_FAILED"
		return $?
	fi

	I=0
	while [ "$I" -lt 20 ]; do
		IP=$(ip -4 -o addr show dev "$IFCE" | awk '{split($4, a, "/"); print a[1]; exit}')
		[ -n "$IP" ] && return 0

		if WPA_RUNNING; then
			:
		else
			if [ -n "$PASS" ]; then
				LOG_ERROR "$0" 0 "NETWORK" "Authentication failed during DHCP (WPA Supplicant not running!)"
				FAIL_WITH "INVALID_PASSWORD" "$RC_INVALID_PASSWORD"
				return $?
			fi
		fi

		I=$((I + 1))
		sleep 1
	done

	LOG_ERROR "$0" 0 "NETWORK" "DHCP failed"
	LOG_DHCPCD_OUTPUT
	FAIL_WITH "DHCP_FAILED" "$RC_DHCP_FAILED"
}

IP_STATIC() {
	NET_STATUS "WAITING_IP"

	# Convert dotted subnet mask to CIDR prefix length if needed
	# (e.g. 255.255.255.0 -> 24) so it accepts the address correctly
	CIDR=$(MASK_TO_CIDR "$SUBN")
	LOG_INFO "$0" 0 "NETWORK" "$(printf "Static config: %s/%s via %s dns %s" "$ADDR" "$CIDR" "$GATE" "$DNSA")"

	ip addr flush dev "$IFCE"
	ip route del default dev "$IFCE" 2>/dev/null

	if ! ip addr add "$ADDR"/"$CIDR" dev "$IFCE"; then
		LOG_ERROR "$0" 0 "NETWORK" "Failed to assign static IP address"
		FAIL_WITH "FAILED" "$RC_FAIL"
		return $?
	fi

	if ! ip route add default via "$GATE" dev "$IFCE"; then
		LOG_ERROR "$0" 0 "NETWORK" "Failed to add default route via gateway"
		FAIL_WITH "FAILED" "$RC_FAIL"
		return $?
	fi

	# Write DNS immediately for static configs so VALIDATE_NETWORK can ping
	if [ -n "$DNSA" ]; then
		[ -f "$RESOLV_CONF" ] && cp "$RESOLV_CONF" "$RESOLV_CONF.bak"
		printf "nameserver %s\n" "$DNSA" >"$RESOLV_CONF"
	fi

	IP=$(ip -4 -o addr show dev "$IFCE" | awk '{split($4, a, "/"); print a[1]; exit}')
	if [ -z "$IP" ]; then
		LOG_ERROR "$0" 0 "NETWORK" "Static IP assignment produced no address"
		FAIL_WITH "FAILED" "$RC_FAIL"
		return $?
	fi

	return 0
}

VALIDATE_NETWORK() {
	NET_STATUS "VALIDATING"
	[ ! -s "$RESOLV_CONF" ] && printf "nameserver %s\n" "$DNSA" >"$RESOLV_CONF"

	IP=$(ip -4 -o addr show dev "$IFCE" | awk '{split($4, a, "/"); print a[1]; exit}')
	if [ -z "$IP" ]; then
		LOG_ERROR "$0" 0 "NETWORK" "No active network address"
		FAIL_WITH "DHCP_FAILED" "$RC_DHCP_FAILED"
		return $?
	fi

	SET_VAR "config" "network/address" "$IP"

	for TGT in "$DNSA" 1.1.1.1 8.8.8.8; do
		if ping -q -c1 -w2 "$TGT" >/dev/null 2>&1; then
			if arping -c1 -w1 "$GATE" >/dev/null 2>&1; then
				LOG_INFO "$0" 0 "NETWORK" "Gateway reachable via ARP"
			else
				LOG_WARN "$0" 0 "NETWORK" "Gateway did not respond to ARP"
			fi

			LOG_SUCCESS "$0" 0 "NETWORK" "$(printf "Network is now active (%s)" "$IP")"
			return 0
		fi
	done

	LOG_WARN "$0" 0 "NETWORK" "$(printf "Network has local address %s but external validation failed" "$IP")"
	return 0
}

NORMALISE_PRIORITY() {
	NET_PRIORITY="$1"

	case "${NET_PRIORITY:-5}" in
		"" | *[!0-9]*) NET_PRIORITY=5 ;;
	esac

	[ "$NET_PRIORITY" -lt 1 ] && NET_PRIORITY=1
	[ "$NET_PRIORITY" -gt 9 ] && NET_PRIORITY=9

	printf "%s" "$((10 - NET_PRIORITY))"
}

APPEND_WPA_PROFILE() {
	NET_PROF_SSID="$1"
	NET_PROF_PASS="$2"
	NET_PROF_PRIORITY="$3"

	NET_PROF_SSID_WPA=$(printf '%s' "$NET_PROF_SSID" | sed 's/\\/\\\\/g; s/"/\\"/g')

	case ${#NET_PROF_PASS} in
		64)
			printf "network={\n\tssid=\"%s\"\n\tscan_ssid=1\n\tpsk=%s\n\tpriority=%s\n}\n" \
				"$NET_PROF_SSID_WPA" "$NET_PROF_PASS" "$NET_PROF_PRIORITY" >>"$WPA_CONFIG"
			;;
		0)
			printf "network={\n\tssid=\"%s\"\n\tscan_ssid=1\n\tkey_mgmt=NONE\n\tpriority=%s\n}\n" \
				"$NET_PROF_SSID_WPA" "$NET_PROF_PRIORITY" >>"$WPA_CONFIG"
			;;
		*)
			NET_PROF_TMP=$(mktemp) || return 1

			wpa_passphrase "$NET_PROF_SSID" "$NET_PROF_PASS" >"$NET_PROF_TMP" || {
				rm -f "$NET_PROF_TMP"
				return 1
			}

			NET_PROF_PSK=$(sed -n '/^[[:space:]]*psk=/s/^[[:space:]]*psk=//p' "$NET_PROF_TMP")
			rm -f "$NET_PROF_TMP"

			[ -n "$NET_PROF_PSK" ] || return 1

			printf "network={\n\tssid=\"%s\"\n\tscan_ssid=1\n\tpsk=%s\n\tpriority=%s\n}\n" \
				"$NET_PROF_SSID_WPA" "$NET_PROF_PSK" "$NET_PROF_PRIORITY" >>"$WPA_CONFIG"
			;;
	esac
}

LOAD_PROFILE_BY_SSID() {
	PROFILE_MATCH_SSID="$1"
	PROFILE_DIR="${MUOS_SHARE_DIR}/network"

	[ -d "$PROFILE_DIR" ] || return 1

	for NET_PROF in "$PROFILE_DIR"/*.ini; do
		[ -f "$NET_PROF" ] || continue

		NET_PROF_SSID=$(PARSE_INI "$NET_PROF" "network" "ssid")
		[ "$NET_PROF_SSID" = "$PROFILE_MATCH_SSID" ] || continue

		NET_PROF_TYPE=$(PARSE_INI "$NET_PROF" "network" "type")
		NET_PROF_PASS=$(PARSE_INI "$NET_PROF" "network" "pass")
		NET_PROF_ADDR=$(PARSE_INI "$NET_PROF" "network" "address")
		NET_PROF_SUBN=$(PARSE_INI "$NET_PROF" "network" "subnet")
		NET_PROF_GATE=$(PARSE_INI "$NET_PROF" "network" "gateway")
		NET_PROF_DNSA=$(PARSE_INI "$NET_PROF" "network" "dns")

		case "$NET_PROF_TYPE" in
			static) TYPE=1 ;;
			*) TYPE=0 ;;
		esac

		PASS="$NET_PROF_PASS"
		ADDR="$NET_PROF_ADDR"
		SUBN="$NET_PROF_SUBN"
		GATE="$NET_PROF_GATE"
		[ -n "$NET_PROF_DNSA" ] && DNSA="$NET_PROF_DNSA"

		SET_VAR "config" "network/type" "$TYPE"
		SET_VAR "config" "network/ssid" "$NET_PROF_SSID"
		SET_VAR "config" "network/pass" "$PASS"

		if [ "$TYPE" -eq 1 ]; then
			SET_VAR "config" "network/address" "$ADDR"
			SET_VAR "config" "network/subnet" "$SUBN"
			SET_VAR "config" "network/gateway" "$GATE"
			SET_VAR "config" "network/dns" "$DNSA"
		fi

		NET_PROF_BASE="${NET_PROF##*/}"
		CURRENT_PROFILE="${NET_PROF_BASE%.ini}"

		return 0
	done

	return 1
}

# Load a profiles definition by its profile name (the INI) into the connection variables
LOAD_PROFILE_BY_NAME() {
	PROFILE_NAME="$1"
	[ -n "$PROFILE_NAME" ] || return 1

	NET_PROF="${MUOS_SHARE_DIR}/network/${PROFILE_NAME}.ini"
	[ -f "$NET_PROF" ] || return 1

	SSID=$(PARSE_INI "$NET_PROF" "network" "ssid")
	[ -n "$SSID" ] || return 1

	NET_PROF_TYPE=$(PARSE_INI "$NET_PROF" "network" "type")
	PASS=$(PARSE_INI "$NET_PROF" "network" "pass")
	ADDR=$(PARSE_INI "$NET_PROF" "network" "address")
	SUBN=$(PARSE_INI "$NET_PROF" "network" "subnet")
	GATE=$(PARSE_INI "$NET_PROF" "network" "gateway")
	NET_PROF_DNSA=$(PARSE_INI "$NET_PROF" "network" "dns")
	[ -n "$NET_PROF_DNSA" ] && DNSA="$NET_PROF_DNSA"

	case "$NET_PROF_TYPE" in
		static) TYPE=1 ;;
		*) TYPE=0 ;;
	esac

	SET_VAR "config" "network/type" "$TYPE"
	SET_VAR "config" "network/ssid" "$SSID"
	SET_VAR "config" "network/pass" "$PASS"
	DEL_VAR "config" "network/ssid_wpa"

	if [ "$TYPE" -eq 1 ]; then
		SET_VAR "config" "network/address" "$ADDR"
		SET_VAR "config" "network/subnet" "$SUBN"
		SET_VAR "config" "network/gateway" "$GATE"
		SET_VAR "config" "network/dns" "$DNSA"
	fi

	CURRENT_PROFILE="$PROFILE_NAME"

	return 0
}

SCAN_SETTLE() {
	[ "$IFCE" = "eth0" ] && return 0

	I=0
	while [ "$I" -lt "${SCAN_SETTLE_TRIES:-8}" ]; do
		iw dev "$IFCE" scan >/dev/null 2>&1 && return 0
		I=$((I + 1))
		sleep 1
	done

	return 0
}

# Pick the highest-priority auto-connect profile whose SSID is currently in range, and print its
# profile name. Manual profiles (autoconnect != 1) are ignored.  Strict priority: a lower
# number in our frontend means it takes priority (1 = highest)
SELECT_BEST_PROFILE() {
	PROFILE_DIR="${MUOS_SHARE_DIR}/network"
	[ -d "$PROFILE_DIR" ] || return 1

	SCAN_OUT=$(iw dev "$IFCE" scan 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p')
	[ -n "$SCAN_OUT" ] || return 1

	BEST_NAME=""
	BEST_PRIO=99

	for NET_PROF in "$PROFILE_DIR"/*.ini; do
		[ -f "$NET_PROF" ] || continue

		NET_PROF_AC=$(PARSE_INI "$NET_PROF" "network" "autoconnect")
		[ "${NET_PROF_AC:-1}" -eq 1 ] || continue

		NET_PROF_SSID=$(PARSE_INI "$NET_PROF" "network" "ssid")
		[ -n "$NET_PROF_SSID" ] || continue

		printf '%s\n' "$SCAN_OUT" | grep -Fxq "$NET_PROF_SSID" || continue

		NET_PROF_PR=$(PARSE_INI "$NET_PROF" "network" "priority")
		case "${NET_PROF_PR:-5}" in
			"" | *[!0-9]*) NET_PROF_PR=5 ;;
		esac

		if [ "$NET_PROF_PR" -lt "$BEST_PRIO" ]; then
			BEST_PRIO="$NET_PROF_PR"
			NET_PROF_BASE="${NET_PROF##*/}"
			BEST_NAME="${NET_PROF_BASE%.ini}"
		fi
	done

	[ -n "$BEST_NAME" ] || return 1
	printf "%s" "$BEST_NAME"
}

BUILD_PROFILE_WPA_CONFIG() {
	PROFILE_DIR="${MUOS_SHARE_DIR}/network"
	[ -d "$PROFILE_DIR" ] || return 1

	: >"$WPA_CONFIG"
	WPA_CONFIG_HEADER || return 1

	NET_PROFILE_COUNT=0

	for NET_PROF in "$PROFILE_DIR"/*.ini; do
		[ -f "$NET_PROF" ] || continue

		NET_PROF_AC=$(PARSE_INI "$NET_PROF" "network" "autoconnect")
		[ "${NET_PROF_AC:-1}" -eq 1 ] || continue

		NET_PROF_SSID=$(PARSE_INI "$NET_PROF" "network" "ssid")
		[ -n "$NET_PROF_SSID" ] || continue

		NET_PROF_PASS=$(PARSE_INI "$NET_PROF" "network" "pass")
		NET_PROF_PR=$(PARSE_INI "$NET_PROF" "network" "priority")
		NET_PROF_WPA=$(NORMALISE_PRIORITY "$NET_PROF_PR")

		if APPEND_WPA_PROFILE "$NET_PROF_SSID" "$NET_PROF_PASS" "$NET_PROF_WPA"; then
			NET_PROFILE_COUNT=$((NET_PROFILE_COUNT + 1))
		fi
	done

	[ "$NET_PROFILE_COUNT" -gt 0 ] || return 1
	return 0
}

WIFI_CONFIG_PROFILES() {
	[ "$IFCE" = "eth0" ] && return 0

	LOG_INFO "$0" 0 "NETWORK" "Scanning saved auto-connect profiles"

	BUILD_PROFILE_WPA_CONFIG || {
		LOG_INFO "$0" 0 "NETWORK" "No auto-connect profiles available"
		FAIL_WITH "AP_NOT_FOUND" "$RC_AP_NOT_FOUND"
		return $?
	}

	NET_STATUS "AUTHENTICATING"

	case "$NET_DRIVER_TYPE" in
		wext)
			if ! wpa_supplicant -B -i "$IFCE" -c "$WPA_CONFIG" -D wext; then
				LOG_ERROR "$0" 0 "NETWORK" "Failed to start WPA Supplicant (wext)"
				FAIL_WITH "WPA_START_FAILED" "$RC_WPA_START_FAILED"
				return $?
			fi
			;;
		nl80211)
			if ! wpa_supplicant -B -i "$IFCE" -c "$WPA_CONFIG" -D nl80211; then
				LOG_ERROR "$0" 0 "NETWORK" "Failed to start WPA Supplicant (nl80211)"
				FAIL_WITH "WPA_START_FAILED" "$RC_WPA_START_FAILED"
				return $?
			fi
			;;
	esac

	NET_STATUS "ASSOCIATING"
	WAIT_NETWORK_ASSOC || return $?
	WAIT_CARRIER || return $?

	case "$NET_DRIVER_TYPE" in
		wext) SSID=$(iwconfig "$IFCE" 2>/dev/null | awk -F'"' '/ESSID:/ {print $2; exit}') ;;
		nl80211) SSID=$(iw dev "$IFCE" link 2>/dev/null | awk -F'SSID: ' '/SSID:/ {print $2; exit}') ;;
	esac

	if [ -z "$SSID" ]; then
		LOG_ERROR "$0" 0 "NETWORK" "Associated network did not report an SSID"
		FAIL_WITH "FAILED" "$RC_FAIL"
		return $?
	fi

	SET_VAR "config" "network/ssid" "$SSID"
	LOAD_PROFILE_BY_SSID "$SSID"

	return 0
}

TRY_CONNECT() {
	CONNECT_MODE="${1:-start}"
	MULTI_PROFILE=0

	if [ "$CONNECT_MODE" = "connect" ] || [ "$IFCE" = "eth0" ]; then
		[ -z "$SSID" ] && [ "$IFCE" != "eth0" ] && MULTI_PROFILE=1
	else
		SSID=""
		PASS=""
		TYPE=0
		MULTI_PROFILE=1
	fi

	rfkill unblock all

	RESTORE_HOSTNAME
	DESTROY_DHCPCD

	if [ -d "/sys/class/net/$IFCE" ]; then
		iw dev "$IFCE" disconnect
		ip addr flush dev "$IFCE"
		ip route del default dev "$IFCE"

		ip link set dev "$IFCE" up || {
			FAIL_WITH "FAILED" "$RC_FAIL"
			return $?
		}

		iw dev "$IFCE" set power_save off
	else
		FAIL_WITH "FAILED" "$RC_FAIL"
		return $?
	fi

	sleep 1

	if [ "$MULTI_PROFILE" -eq 1 ]; then
		WIFI_CONFIG_PROFILES || return $?

		if [ "${TYPE:-0}" -eq 0 ]; then
			IP_DHCP || return $?
		else
			IP_STATIC || return $?
		fi
	else
		WIFI_CONFIG || return $?

		if [ "${TYPE:-0}" -eq 0 ]; then
			IP_DHCP || return $?
		else
			IP_STATIC || return $?
		fi
	fi

	IP=$(ip -4 -o addr show dev "$IFCE" | awk '{split($4, a, "/"); print a[1]; exit}')
	if [ -n "$IP" ]; then
		SET_VAR "config" "network/address" "$IP"
		[ -n "$CURRENT_PROFILE" ] && SET_ACTIVE "$CURRENT_PROFILE"
		NET_STATUS "CONNECTED"
	fi

	sleep 1

	VALIDATE_NETWORK
}

SETUP_PROXY() {
	PROXY_ENABLED=$(GET_VAR "config" "settings/network/proxy_enabled")

	if [ "${PROXY_ENABLED:-0}" -ne 1 ]; then
		CLEAR_PROXY
		return 0
	fi

	PROXY_TYPE_IDX=$(GET_VAR "config" "settings/network/proxy_type")
	PROXY_SERVER=$(GET_VAR "config" "settings/network/proxy_server")
	PROXY_NOPROXY=$(GET_VAR "config" "settings/network/proxy_noproxy")

	[ -z "$PROXY_SERVER" ] && {
		CLEAR_PROXY
		return 0
	}

	case "${PROXY_TYPE_IDX:-0}" in
		1) PROXY_SCHEME="https://" ;;
		2) PROXY_SCHEME="socks5://" ;;
		*) PROXY_SCHEME="http://" ;;
	esac

	PROXY_URL="${PROXY_SCHEME}${PROXY_SERVER}"

	{
		printf "HTTP_PROXY=%s\n" "$PROXY_URL"
		printf "HTTPS_PROXY=%s\n" "$PROXY_URL"
		printf "ALL_PROXY=%s\n" "$PROXY_URL"
		printf "http_proxy=%s\n" "$PROXY_URL"
		printf "https_proxy=%s\n" "$PROXY_URL"
		printf "all_proxy=%s\n" "$PROXY_URL"
		if [ -n "$PROXY_NOPROXY" ]; then
			printf "NO_PROXY=%s\n" "$PROXY_NOPROXY"
			printf "no_proxy=%s\n" "$PROXY_NOPROXY"
		fi
	} >/etc/environment

	mkdir -p /etc/profile.d
	{
		printf "export HTTP_PROXY=%s\n" "$PROXY_URL"
		printf "export HTTPS_PROXY=%s\n" "$PROXY_URL"
		printf "export ALL_PROXY=%s\n" "$PROXY_URL"
		printf "export http_proxy=%s\n" "$PROXY_URL"
		printf "export https_proxy=%s\n" "$PROXY_URL"
		printf "export all_proxy=%s\n" "$PROXY_URL"
		if [ -n "$PROXY_NOPROXY" ]; then
			printf "export NO_PROXY=%s\n" "$PROXY_NOPROXY"
			printf "export no_proxy=%s\n" "$PROXY_NOPROXY"
		fi
	} >/etc/profile.d/proxy.sh

	export HTTP_PROXY="$PROXY_URL"
	export HTTPS_PROXY="$PROXY_URL"
	export ALL_PROXY="$PROXY_URL"
	export http_proxy="$PROXY_URL"
	export https_proxy="$PROXY_URL"
	export all_proxy="$PROXY_URL"
	if [ -n "$PROXY_NOPROXY" ]; then
		export NO_PROXY="$PROXY_NOPROXY"
		export no_proxy="$PROXY_NOPROXY"
	fi

	LOG_INFO "$0" 0 "NETWORK" "$(printf "Proxy configured: %s" "$PROXY_URL")"
}

CLEAR_PROXY() {
	if [ -f /etc/environment ]; then
		PROXY_TMP=$(mktemp)
		grep -iv "^\(http\|https\|all\|no\)_proxy=" /etc/environment >"$PROXY_TMP" 2>/dev/null || true
		mv -f "$PROXY_TMP" /etc/environment
	fi

	rm -f /etc/profile.d/proxy.sh

	unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy NO_PROXY no_proxy

	LOG_INFO "$0" 0 "NETWORK" "Proxy configuration cleared"
}

ON_CONNECTED() {
	SETUP_PROXY

	LOG_INFO "$0" 0 "NETWORK" "Starting Keepalive Script"
	/opt/muos/script/web/keepalive.sh &

	LOG_INFO "$0" 0 "NETWORK" "Starting Enabled Network Services"
	/opt/muos/script/web/service.sh &

	LOG_INFO "$0" 0 "NETWORK" "Restarting Chrony Service"
	/opt/muos/script/init/async/S02chrony.sh restart &

	LOG_INFO "$0" 0 "NETWORK" "Running Chrony Time Sync"
	chronyc burst 4/4
	sleep 2
	chronyc -a makestep
}

DO_START() {
	CONNECT_MODE="${1:-start}"
	CONNECT_PROFILE="$2"

	[ "${HAS_NETWORK:-0}" -eq 0 ] && return 0

	LOG_INFO "$0" 0 "NETWORK" "Starting Network Service"

	# Load the shared WiFi/BT module and unblock rfkill regardless of
	# connect-on-boot, since Bluetooth uses the same hardware chip.
	case "$BOARD_NAME" in
		mgx* | rg-vita* | rk* | tui*) LOAD_MODULE ;;
		rg*) [ ! -d "/sys/bus/mmc/devices/mmc2:0001" ] && LOAD_MODULE ;;
	esac

	rfkill unblock all

	# A fresh boot owns no connection until one is established, so drop any persisted active pointer!
	[ "$CONNECT_MODE" = "connect" ] || CLEAR_ACTIVE

	[ "${CONNECT_ON_BOOT:-0}" -eq 0 ] && [ "$CONNECT_MODE" != "connect" ] && return 0

	if [ "$CONNECT_MODE" != "connect" ]; then
		WAIT_FOR_IFACE "$IFCE" 5
		WAIT_FOR_IFACE_READY "$IFCE" 5
		SCAN_SETTLE

		BEST_PROFILE=$(SELECT_BEST_PROFILE)
		if [ -n "$BEST_PROFILE" ]; then
			LOG_INFO "$0" 0 "NETWORK" "$(printf "Auto-connect selecting highest-priority profile in range: %s" "$BEST_PROFILE")"
			CONNECT_PROFILE="$BEST_PROFILE"
			CONNECT_MODE="connect"
		fi
	fi

	if [ "$CONNECT_MODE" = "connect" ]; then
		if ! LOAD_PROFILE_BY_NAME "$CONNECT_PROFILE"; then
			LOG_ERROR "$0" 0 "NETWORK" "$(printf "Connect profile not found: %s" "$CONNECT_PROFILE")"
			return 1
		fi

		PREV_ACTIVE=$(GET_VAR "config" "network/active")
		if [ -n "$PREV_ACTIVE" ] && [ "$PREV_ACTIVE" != "$CURRENT_PROFILE" ]; then
			rm -f "$NET_STATUS_DIR/$PREV_ACTIVE.status"
		fi
		CLEAR_ACTIVE
	fi

	NET_STATUS "ASSOCIATING"

	RETRY_CURR=0
	RELOAD_DONE=0

	while [ "$RETRY_CURR" -lt "${RETRIES:-3}" ]; do
		NET_NAME=$(GET_VAR "device" "network/name")

		if [ -n "$NET_NAME" ]; then
			WAIT_FOR_MODULE "$NET_NAME" 5
		fi

		if ! WAIT_FOR_IFACE "$IFCE" 5; then
			LOG_WARN "$0" 0 "NETWORK" "Interface not found, attempting reload"
			RELOAD_MODULE
			sleep 2
		fi

		if ! WAIT_FOR_IFACE_READY "$IFCE" 5; then
			LOG_ERROR "$0" 0 "NETWORK" "Interface not ready"
			FAIL_WITH "FAILED" "$RC_FAIL"
			return 1
		fi

		TRY_CONNECT "$CONNECT_MODE"
		RC=$?

		if [ "$RC" -eq "$RC_OK" ]; then
			LOG_SUCCESS "$0" 0 "NETWORK" "Network Connected Successfully"
			[ -n "$CURRENT_PROFILE" ] && SET_ACTIVE "$CURRENT_PROFILE"
			NET_STATUS "CONNECTED"
			ON_CONNECTED
			return 0
		fi

		case "$RC" in
			"$RC_INVALID_PASSWORD")
				LOG_ERROR "$0" 0 "NETWORK" "Invalid WiFi password"
				NET_STATUS "INVALID_PASSWORD"
				CLEAR_ACTIVE
				sleep 2
				NET_STATUS_CLEAR
				return 1
				;;
			"$RC_AP_NOT_FOUND")
				LOG_ERROR "$0" 0 "NETWORK" "Access point not found"
				NET_STATUS "AP_NOT_FOUND"
				CLEAR_ACTIVE
				sleep 2
				NET_STATUS_CLEAR
				return 1
				;;
			"$RC_WPA_START_FAILED")
				LOG_ERROR "$0" 0 "NETWORK" "WPA Supplicant start failed"
				NET_STATUS "WPA_START_FAILED"
				CLEAR_ACTIVE
				sleep 2
				NET_STATUS_CLEAR
				return 1
				;;
		esac

		# Interface vanished mid-attempt... spooky, try one module reload at least
		if [ ! -d "/sys/class/net/$IFCE" ] && [ "$RELOAD_DONE" -eq 0 ]; then
			LOG_WARN "$0" 0 "NETWORK" "Interface missing, reloading network driver once"
			RELOAD_MODULE
			RELOAD_DONE=1
			sleep 2
		fi

		RETRY_CURR=$((RETRY_CURR + 1))
		LOG_WARN "$0" 0 "NETWORK" "$(printf "Retrying Network Connection (%s/%s)" "$RETRY_CURR" "${RETRIES:-3}")"
		sleep "$RETRY_DELAY"
	done

	LOG_ERROR "$0" 0 "NETWORK" "All Connection Attempts Failed"
	CLEAR_ACTIVE
	NET_STATUS "FAILED"
	sleep 2
	NET_STATUS_CLEAR
	return 1
}

DO_STOP() {
	[ "${HAS_NETWORK:-0}" -eq 0 ] && return 0

	LOG_INFO "$0" 0 "NETWORK" "Stopping Network Service"

	CLEAR_PROXY

	DESTROY_DHCPCD

	# Clear the connected profile status and the active pointer
	CURRENT_PROFILE=$(GET_VAR "config" "network/active")
	NET_STATUS_CLEAR
	CLEAR_ACTIVE

	iw dev "$IFCE" disconnect
	: >"$WPA_CONFIG"

	LOG_INFO "$0" 0 "NETWORK" "$(printf "Setting '%s' device down" "$IFCE")"
	ip addr flush dev "$IFCE"
	ip route del default dev "$IFCE"
	ip link set dev "$IFCE" down

	LOG_INFO "$0" 0 "NETWORK" "Stopping Network Services"
	/opt/muos/script/web/service.sh stopall &

	LOG_INFO "$0" 0 "NETWORK" "Stopping Keepalive Script"
	killall -9 keepalive.sh &

	UNLOAD_MODULE
}

DO_STATUS() {
	ACTIVE_PROFILE=$(GET_VAR "config" "network/active")

	CURRENT_STATUS=""
	[ -n "$ACTIVE_PROFILE" ] && [ -f "$NET_STATUS_DIR/$ACTIVE_PROFILE.status" ] &&
		IFS= read -r CURRENT_STATUS <"$NET_STATUS_DIR/$ACTIVE_PROFILE.status"

	IP=$(ip -4 -o addr show dev "$IFCE" | awk '{split($4, a, "/"); print a[1]; exit}')
	IFACE_UP=0
	[ -d "/sys/class/net/$IFCE" ] && IFACE_UP=1

	MOD_LOADED=0
	MODULE_LOADED "$NET_NAME" && MOD_LOADED=1

	WPA_STATE=0
	WPA_RUNNING && WPA_STATE=1

	printf "Interface:\t%s\t(%s)\n" "$IFCE" "$([ "$IFACE_UP" -eq 1 ] && printf "up" || printf "down")"
	printf "Module:\t\t%s\t(%s)\n" "${NET_NAME:-unknown}" "$([ "$MOD_LOADED" -eq 1 ] && printf "loaded" || printf "not loaded")"
	printf "WPA Supplicant:\t%s\n" "$([ "$WPA_STATE" -eq 1 ] && printf "running" || printf "stopped")"
	printf "Active Profile:\t%s\n" "${ACTIVE_PROFILE:-none}"
	printf "IP Address:\t%s\n" "${IP:-none}"
	printf "Status:\t\t%s\n" "${CURRENT_STATUS:-inactive}"

	[ -n "$IP" ] && return 0
	return 1
}

LOG_INFO "$0" 0 "NETWORK" "Bringing Up 'localhost' Network"
ifconfig lo up &

[ "${FACTORY_RESET:-0}" -eq 1 ] && exit 0

case "$1" in
	start) DO_START start ;;
	connect) DO_START connect "$2" ;;
	stop | disconnect) DO_STOP ;;
	restart)
		DO_STOP
		DO_START start
		;;
	load) LOAD_MODULE ;;
	unload) UNLOAD_MODULE ;;
	status) DO_STATUS ;;
	*)
		printf "Usage: %s {start|connect <profile>|stop|disconnect|restart|load|unload|status}\n" "$0" >&2
		exit 1
		;;
esac
