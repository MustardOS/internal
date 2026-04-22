#!/bin/sh

. /opt/muos/script/var/func.sh

FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")
BOARD_NAME=$(GET_VAR "device" "board/name")

HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_MODULE=$(GET_VAR "device" "network/module")
NET_IFACE=$(GET_VAR "device" "network/iface")
NET_NAME=$(GET_VAR "device" "network/name")

ADDR=$(GET_VAR "config" "network/address")
SUBN=$(GET_VAR "config" "network/subnet")
SSID=$(GET_VAR "config" "network/ssid")
PASS=$(GET_VAR "config" "network/pass")
GATE=$(GET_VAR "config" "network/gateway")
TYPE=$(GET_VAR "config" "network/type")
DNSA=$(GET_VAR "config" "network/dns")

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
DHCP_CONF="/etc/dhcpcd.conf"
STATUS_FILE="$MUOS_RUN_DIR/network.status"

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

NET_STATUS() {
	printf "%s" "$1" >"$STATUS_FILE"
}

NET_STATUS_CLEAR() {
	rm -f "$STATUS_FILE"
}

FAIL_WITH() {
	NET_STATUS "$1"
	return "${2:-$RC_FAIL}"
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

	if grep -qw "^$NET_NAME" /proc/modules; then
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
			if ! grep -qw "^$NET_NAME" /proc/modules; then
				modprobe -qf "$NET_NAME"
			fi
			;;
		rg*)
			if ! grep -qw "^$NET_NAME" /proc/modules; then
				modprobe -qf "$NET_NAME"
			fi
			;;
		mgx* | tui*)
			if ! grep -qw "^$NET_NAME" /proc/modules; then
				insmod "$NET_MODULE"
			fi
			;;
		rk*)
			modprobe -q cfg80211
			if [ -n "$NET_NAME" ] && ! grep -qw "^$NET_NAME" /proc/modules; then
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
			if grep -qw "^$NET_NAME" /proc/modules; then
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
		grep -qw "^$MOD" /proc/modules && return 0
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
	if pidof dhcpcd udhcpc wpa_supplicant >/dev/null 2>&1; then
		killall -q dhcpcd udhcpc wpa_supplicant
		sleep 1
		killall -9 dhcpcd udhcpc wpa_supplicant
		sleep 1
	fi
}

RESTORE_HOSTNAME() {
	HOSTFILE=""
	[ -e "$DEV_HOST" ] && HOSTFILE="$DEV_HOST"
	[ -z "$HOSTFILE" ] && [ -e "$SD2_HOST" ] && HOSTFILE="$SD2_HOST"
	[ -z "$HOSTFILE" ] && [ -e "$SD1_HOST" ] && HOSTFILE="$SD1_HOST"
	[ -z "$HOSTFILE" ] && return 0

	HOSTNAME=$(cat "$HOSTFILE")
	hostname "$HOSTNAME"
	printf "%s" "$HOSTNAME" >"/etc/hostname"

	LOG_INFO "$0" 0 "NETWORK" "$(printf "Hostname restored to %s" "$HOSTNAME")"
}

CALCULATE_IAID() {
	MAC=$(cat /sys/class/net/"$IFCE"/address)
	O5=${MAC#*:*:*:*:}
	O5=${O5%%:*}
	O6=${MAC##*:}
	IAID=$(((0x$O5 << 8) | 0x$O6))

	sed -i '/^iaid/d' "$DHCP_CONF"
	printf 'iaid %s\n' "$IAID" >>"$DHCP_CONF"

	LOG_INFO "$0" 0 "NETWORK" "$(printf "Using IAID: %s" "$IAID")"
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
	pgrep -f "wpa_supplicant.*-i[[:space:]]*$IFCE" >/dev/null 2>&1 ||
		pgrep -f "wpa_supplicant.*$IFCE" >/dev/null 2>&1
}

WAIT_CARRIER() {
	[ "$IFCE" = "eth0" ] && return 0

	I=0
	while [ "$I" -lt 5 ]; do
		[ "$(cat /sys/class/net/"$IFCE"/carrier)" = "1" ] && return 0
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
						return 0
						;;
				esac
				;;
			nl80211)
				if iw dev "$IFCE" link | grep -q "SSID:"; then
					LOG_INFO "$0" 0 "NETWORK" "WiFi Associated!"
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
		dhcpcd "$IFCE" >/dev/null 2>&1 &
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
		IP=$(ip -4 -o addr show dev "$IFCE" | awk '{print $4}' | cut -d/ -f1)
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

	IP=$(ip -4 -o addr show dev "$IFCE" | awk '{print $4}' | cut -d/ -f1)
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

	for TGT in "$DNSA" 1.1.1.1 8.8.8.8; do
		if ping -q -c1 -w2 "$TGT" >/dev/null 2>&1; then
			if arping -c1 -w1 "$GATE" >/dev/null 2>&1; then
				LOG_INFO "$0" 0 "NETWORK" "Gateway reachable via ARP"
			else
				LOG_WARN "$0" 0 "NETWORK" "Gateway did not respond to ARP"
			fi

			SET_VAR "config" "network/address" "$IP"
			LOG_SUCCESS "$0" 0 "NETWORK" "$(printf "Network is now active (%s)" "$IP")"
			return 0
		fi
	done

	LOG_ERROR "$0" 0 "NETWORK" "No active network connection"
	FAIL_WITH "FAILED" "$RC_FAIL"
}

TRY_CONNECT() {
	[ -z "$SSID" ] && [ "$IFCE" != "eth0" ] && return 0

	rfkill unblock all

	RESTORE_HOSTNAME
	DESTROY_DHCPCD

	if [ -d "/sys/class/net/$IFCE" ]; then
		CALCULATE_IAID

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

	WIFI_CONFIG || return $?

	if [ "${TYPE:-0}" -eq 0 ]; then
		IP_DHCP || return $?
	else
		IP_STATIC || return $?
	fi

	sleep 1

	VALIDATE_NETWORK
}

ON_CONNECTED() {
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
	[ "${HAS_NETWORK:-0}" -eq 0 ] && return 0
	[ "${CONNECT_ON_BOOT:-0}" -eq 0 ] && return 0

	LOG_INFO "$0" 0 "NETWORK" "Starting Network Service"

	case "$BOARD_NAME" in
		mgx* | rg-vita* | rk* | tui*) LOAD_MODULE ;;
		rg*) [ ! -d "/sys/bus/mmc/devices/mmc2:0001" ] && LOAD_MODULE ;;
	esac

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

		TRY_CONNECT
		RC=$?

		if [ "$RC" -eq "$RC_OK" ]; then
			LOG_SUCCESS "$0" 0 "NETWORK" "Network Connected Successfully"
			ON_CONNECTED
			NET_STATUS "CONNECTED"
			return 0
		fi

		case "$RC" in
			"$RC_INVALID_PASSWORD")
				LOG_ERROR "$0" 0 "NETWORK" "Invalid WiFi password"
				NET_STATUS "INVALID_PASSWORD"
				sleep 2
				NET_STATUS_CLEAR
				return 1
				;;
			"$RC_AP_NOT_FOUND")
				LOG_ERROR "$0" 0 "NETWORK" "Access point not found"
				NET_STATUS "AP_NOT_FOUND"
				sleep 2
				NET_STATUS_CLEAR
				return 1
				;;
			"$RC_WPA_START_FAILED")
				LOG_ERROR "$0" 0 "NETWORK" "WPA Supplicant start failed"
				NET_STATUS "WPA_START_FAILED"
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
	NET_STATUS "FAILED"
	sleep 2
	NET_STATUS_CLEAR
	return 1
}

DO_STOP() {
	[ "${HAS_NETWORK:-0}" -eq 0 ] && return 0

	LOG_INFO "$0" 0 "NETWORK" "Stopping Network Service"

	DESTROY_DHCPCD
	NET_STATUS_CLEAR

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
	CURRENT_STATUS=""
	[ -f "$STATUS_FILE" ] && CURRENT_STATUS=$(cat "$STATUS_FILE")

	IP=$(ip -4 -o addr show dev "$IFCE" | awk '{print $4}' | cut -d/ -f1)
	IFACE_UP=0
	[ -d "/sys/class/net/$IFCE" ] && IFACE_UP=1

	MOD_LOADED=0
	[ -n "$NET_NAME" ] && grep -qw "^$NET_NAME" /proc/modules && MOD_LOADED=1

	WPA_STATE=0
	WPA_RUNNING && WPA_STATE=1

	printf "Interface:\t%s\t(%s)\n" "$IFCE" "$([ "$IFACE_UP" -eq 1 ] && printf "up" || printf "down")"
	printf "Module:\t\t%s\t(%s)\n" "${NET_NAME:-unknown}" "$([ "$MOD_LOADED" -eq 1 ] && printf "loaded" || printf "not loaded")"
	printf "WPA Supplicant:\t%s\n" "$([ "$WPA_STATE" -eq 1 ] && printf "running" || printf "stopped")"
	printf "IP Address:\t%s\n" "${IP:-none}"
	printf "Status:\t\t%s\n" "${CURRENT_STATUS:-inactive}"

	[ -n "$IP" ] && return 0
	return 1
}

LOG_INFO "$0" 0 "NETWORK" "Bringing Up 'localhost' Network"
ifconfig lo up &

[ "${FACTORY_RESET:-0}" -eq 1 ] && exit 0

case "$1" in
	start) DO_START ;;
	stop) DO_STOP ;;
	restart)
		DO_STOP
		DO_START
		;;
	load) LOAD_MODULE ;;
	unload) UNLOAD_MODULE ;;
	status) DO_STATUS ;;
	*)
		printf "Usage: %s {start|stop|restart|load|unload|status}\n" "$0" >&2
		exit 1
		;;
esac
