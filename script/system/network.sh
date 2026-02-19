#!/bin/sh

. /opt/muos/script/var/func.sh

ADDR=$(GET_VAR "config" "network/address")
SUBN=$(GET_VAR "config" "network/subnet")
SSID=$(GET_VAR "config" "network/ssid")
PASS=$(GET_VAR "config" "network/pass")
GATE=$(GET_VAR "config" "network/gateway")
TYPE=$(GET_VAR "config" "network/type")
DDNS=$(GET_VAR "config" "network/dns") # The extra D is for dodecahedron!

DRIV=$(GET_VAR "device" "network/type")
IFCE="$(GET_VAR "device" "network/iface_active")"
[ -n "$IFCE" ] || IFCE="$(GET_VAR "device" "network/iface")"

DEV_HOST="$(GET_VAR "device" "network/hostname")"
SD1_HOST="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/hostname"
SD2_HOST="$(GET_VAR "device" "storage/sdcard/mount")/MUOS/info/hostname"

DHCP_CONF="/etc/dhcpcd.conf"
RESOLV_CONF="/etc/resolv.conf"

RETRIES=$(GET_VAR "config" "settings/network/con_retry")
RETRY_DELAY="${RETRY_DELAY:-2}"

STATUS_FILE="$MUOS_RUN_DIR/network.status"

# Return codes for frontend UI updates
RC_OK=0
RC_FAIL=1
RC_INVALID_PASSWORD=2
RC_AP_NOT_FOUND=3
RC_AUTH_TIMEOUT=4
RC_DHCP_FAILED=5
RC_LINK_TIMEOUT=6
RC_WPA_START_FAILED=7

NET_STATUS() { printf "%s" "$1" >"$STATUS_FILE"; }
NET_STATUS_CLEAR() { rm -f "$STATUS_FILE"; }

FAIL_WITH() {
	NET_STATUS "$1"
	return "${2:-$RC_FAIL}"
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

# Exterminate!
DESTROY_DHCPCD() {
	killall -q dhcpcd wpa_supplicant 2>/dev/null
	sleep 1
	killall -9 dhcpcd wpa_supplicant 2>/dev/null

	LOG_INFO "$0" 0 "NETWORK" "Clearing Previous DHCP Addresses"
	rm -rf /var/db/dhcpcd/*
	mkdir -p /var/db/dhcpcd
}

# Determine if the SSID appears in scan results
# Returns 0 if found, 1 if not found, 2 if scan failed
SSID_PRESENT() {
	OUT=$(iw dev "$IFCE" scan 2>/dev/null) || return 2
	printf "%s\n" "$OUT" | awk -v ssid="$SSID" '
		$1=="SSID:" { sub(/^SSID:[[:space:]]*/,""); if ($0==ssid) { found=1; exit } }
		END { exit(found?0:1) }
	'
}

# Determine if the SSID is open (no RSN/WPA in its BSS block)
# Returns 0=open, 1=secured or not found, 2=scan failed
IS_OPEN_NETWORK() {
	OUT=$(iw dev "$IFCE" scan 2>/dev/null) || return 2
	printf "%s\n" "$OUT" | awk -v ssid="$SSID" '
		BEGIN { in=0; open=0 }
		/^BSS[[:space:]]/ { in=0; open=1 }
		$1=="SSID:" {
			line=$0; sub(/^SSID:[[:space:]]*/,"",line)
			if (line==ssid) { in=1; next }
			in=0
		}
		in && (/^[[:space:]]*RSN:/ || /^[[:space:]]*WPA:/) { open=0 }
		END { exit((in && open)?0:1) }
	'
}

WAIT_NETWORK_ASSOC() {
	[ "$IFCE" = "eth0" ] && return 0

	[ "$DRIV" = "wext" ] && iwconfig "$IFCE" retry off 2>/dev/null

	WAIT=20
	while [ "$WAIT" -gt 0 ]; do
		case "$DRIV" in
			wext)
				OUT=$(iwconfig "$IFCE" 2>/dev/null)
				case "$OUT" in
					*'ESSID:"'*)
						LOG_INFO "$0" 0 "NETWORK" "WiFi Associated!"
						return 0
						;;
				esac
				;;
			nl80211)
				if iw dev "$IFCE" link 2>/dev/null | grep -q "SSID:"; then
					LOG_INFO "$0" 0 "NETWORK" "WiFi Associated!"
					return 0
				fi
				;;
		esac

		LOG_WARN "$0" 0 "NETWORK" "$(printf "Waiting for WiFi Association... (%ds)" "$WAIT")"
		WAIT=$((WAIT - 1))
		sleep 1
	done

	LOG_ERROR "$0" 0 "NETWORK" "Association timeout"

	# If wpa_supplicant is running on this iface, treat as auth timeout/bad
	if pgrep -f "wpa_supplicant.*-i[[:space:]]*$IFCE" >/dev/null 2>&1 ||
		pgrep -f "wpa_supplicant.*$IFCE" >/dev/null 2>&1; then
		FAIL_WITH "AUTH_TIMEOUT" "$RC_AUTH_TIMEOUT"
	fi

	FAIL_WITH "FAILED" "$RC_FAIL"
}

WAIT_CARRIER() {
	[ "$IFCE" = "eth0" ] && return 0

	I=0
	while [ "$I" -lt 5 ]; do
		[ "$(cat /sys/class/net/"$IFCE"/carrier 2>/dev/null)" = "1" ] && return 0
		I=$((I + 1))
		sleep 1
	done

	LOG_ERROR "$0" 0 "NETWORK" "Link carrier timeout"
	FAIL_WITH "LINK_TIMEOUT" "$RC_LINK_TIMEOUT"
}

WPA_RUNNING() {
	pgrep -f "wpa_supplicant.*-i[[:space:]]*$IFCE" >/dev/null 2>&1 ||
		pgrep -f "wpa_supplicant.*$IFCE" >/dev/null 2>&1
}

WIFI_CONFIG() {
	[ "$IFCE" = "eth0" ] && return 0

	SSID_PRESENT

	RC=$?
	if [ "$RC" -eq 1 ]; then
		LOG_ERROR "$0" 0 "NETWORK" "$(printf "SSID not found: %s" "$SSID")"
		FAIL_WITH "AP_NOT_FOUND" "$RC_AP_NOT_FOUND"
	elif [ "$RC" -eq 2 ]; then
		LOG_WARN "$0" 0 "NETWORK" "WiFi scan failed (continuing)"
	fi

	LOG_INFO "$0" 0 "NETWORK" "$(printf "Setting ESSID: %s" "$SSID")"
	if iw dev "$IFCE" info >/dev/null 2>&1; then
		iwconfig "$IFCE" essid -- "$SSID" 2>/dev/null
	fi

	OPEN=0
	if [ -z "$PASS" ]; then
		IS_OPEN_NETWORK
		RC=$?
		if [ "$RC" -eq 0 ]; then
			OPEN=1
		elif [ "$RC" -eq 2 ]; then
			OPEN=0
		else
			OPEN=0
		fi
	fi

	if [ -n "$PASS" ] || [ "$OPEN" -eq 0 ]; then
		if [ -z "$PASS" ]; then
			LOG_ERROR "$0" 0 "NETWORK" "Password required for secured network"
			FAIL_WITH "INVALID_PASSWORD" "$RC_INVALID_PASSWORD"
		fi

		NET_STATUS "AUTHENTICATING"
		/opt/muos/script/web/password.sh

		# Pin BSSID (best effort anyway)
		BEST_BSSID=$(
			iw dev "$IFCE" scan 2>/dev/null |
				awk -v ssid="$SSID" '
				/BSS/ { b=$2 }
				/SSID:/ { s=$2 }
				s==ssid && /SSID:/ { sub(/[\(\)]/,"",b); print b; exit }
			'
		)

		sed -i '/^bssid=/d' "$WPA_CONFIG" 2>/dev/null
		[ -n "$BEST_BSSID" ] && {
			LOG_INFO "$0" 0 "NETWORK" "$(printf "Pinning BSSID: %s" "$BEST_BSSID")"
			sed -i "/^ssid=/i bssid=$BEST_BSSID" "$WPA_CONFIG" 2>/dev/null
		}

		case "$DRIV" in
			wext)
				LOG_INFO "$0" 0 "NETWORK" "Starting wpa_supplicant (wext)"
				if ! wpa_supplicant -B -i "$IFCE" -c "$WPA_CONFIG" -D wext 2>/dev/null; then
					LOG_ERROR "$0" 0 "NETWORK" "Failed to start wpa_supplicant (wext)"
					FAIL_WITH "WPA_START_FAILED" "$RC_WPA_START_FAILED"
				fi
				;;
			nl80211)
				LOG_INFO "$0" 0 "NETWORK" "Starting wpa_supplicant (nl80211)"
				if ! wpa_supplicant -B -i "$IFCE" -c "$WPA_CONFIG" -D nl80211 2>/dev/null; then
					LOG_ERROR "$0" 0 "NETWORK" "Failed to start wpa_supplicant (nl80211)"
					FAIL_WITH "WPA_START_FAILED" "$RC_WPA_START_FAILED"
				fi
				;;
		esac
	else
		# For those who enjoy connecting to an open network...
		if iw dev "$IFCE" info >/dev/null 2>&1; then
			LOG_INFO "$0" 0 "NETWORK" "Connecting to open network"
			iwconfig "$IFCE" mode Managed 2>/dev/null
			iwconfig "$IFCE" key off 2>/dev/null
		fi
	fi

	NET_STATUS "ASSOCIATING"
	WAIT_NETWORK_ASSOC || return $?

	WAIT_CARRIER || return $?

	return 0
}

IP_DHCP() {
	NET_STATUS "WAITING_IP"
	dhcpcd "$IFCE" >/dev/null 2>&1 &

	I=0
	while [ "$I" -lt 20 ]; do
		IP=$(ip -4 -o addr show dev "$IFCE" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
		[ -n "$IP" ] && return 0

		# If we are using wpa_supplicant and it died or deauthed somehow
		# we'll just classify as invalid password/auth issue... So annoying!
		if WPA_RUNNING; then
			# still running, ok
			:
		else
			if [ -n "$PASS" ]; then
				LOG_ERROR "$0" 0 "NETWORK" "Authentication failed during DHCP (wpa_supplicant not running)"
				FAIL_WITH "INVALID_PASSWORD" "$RC_INVALID_PASSWORD"
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

	ip addr flush dev "$IFCE" 2>/dev/null
	ip route del default dev "$IFCE" 2>/dev/null
	ip addr add "$ADDR"/"$SUBN" dev "$IFCE" 2>/dev/null
	ip route add default via "$GATE" dev "$IFCE" 2>/dev/null

	IP=$(ip -4 -o addr show dev "$IFCE" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
	[ -n "$IP" ] || FAIL_WITH "FAILED" "$RC_FAIL"
}

VALIDATE_NETWORK() {
	NET_STATUS "VALIDATING"
	[ ! -s "$RESOLV_CONF" ] && printf "nameserver %s\n" "$DDNS" >"$RESOLV_CONF"

	for TGT in "$DDNS" 1.1.1.1 8.8.8.8; do
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
	[ -z "$SSID" ] && return 0

	rfkill unblock all 2>/dev/null
	iw dev "$IFCE" set power_save off 2>/dev/null

	RESTORE_HOSTNAME
	DESTROY_DHCPCD

	iw dev "$IFCE" disconnect 2>/dev/null
	ip addr flush dev "$IFCE" 2>/dev/null
	ip route del default dev "$IFCE" 2>/dev/null

	CALCULATE_IAID

	ip link set dev "$IFCE" down 2>/dev/null
	sleep 1

	ip link set dev "$IFCE" up 2>/dev/null || FAIL_WITH "FAILED" "$RC_FAIL"
	sleep 1

	WIFI_CONFIG || return $?

	if [ "$TYPE" -eq 0 ]; then
		IP_DHCP || return $?
	else
		IP_STATIC || return $?
	fi

	sleep 1

	VALIDATE_NETWORK
}

case "$1" in
	disconnect)
		DESTROY_DHCPCD

		iw dev "$IFCE" disconnect 2>/dev/null
		: >"$WPA_CONFIG" 2>/dev/null

		LOG_INFO "$0" 0 "NETWORK" "$(printf "Setting '%s' device down" "$IFCE")"
		ip addr flush dev "$IFCE" 2>/dev/null
		ip route del default dev "$IFCE" 2>/dev/null
		ip link set dev "$IFCE" down 2>/dev/null

		LOG_INFO "$0" 0 "NETWORK" "Stopping Network Services"
		/opt/muos/script/web/service.sh stopall &

		LOG_INFO "$0" 0 "NETWORK" "Stopping Keepalive Script"
		killall -9 keepalive.sh 2>/dev/null &
		/opt/muos/script/device/network.sh unload
		;;

	connect)
		case "$(GET_VAR "device" "board/name")" in
			rg*) [ ! -d "/sys/bus/mmc/devices/mmc2:0001" ] && /opt/muos/script/device/network.sh load ;;
			mgx* | rk* | tui*) /opt/muos/script/device/network.sh load ;;
			*) ;;
		esac

		NET_STATUS "ASSOCIATING"

		RETRY_CURR=0
		while [ "$RETRY_CURR" -lt "$RETRIES" ]; do
			TRY_CONNECT
			RC=$?

			if [ "$RC" -eq "$RC_OK" ]; then
				LOG_SUCCESS "$0" 0 "NETWORK" "Network Connected Successfully"

				LOG_INFO "$0" 0 "NETWORK" "Starting Keepalive Script"
				/opt/muos/script/web/keepalive.sh &

				LOG_INFO "$0" 0 "NETWORK" "Starting Enabled Network Services"
				/opt/muos/script/web/service.sh &

				LOG_INFO "$0" 0 "NETWORK" "Restarting Chrony Service"
				/opt/muos/script/init/S00chrony restart

				LOG_INFO "$0" 0 "NETWORK" "Running Chrony Time Sync"
				chronyc burst 4/4
				sleep 2
				chronyc -a makestep

				NET_STATUS "CONNECTED"
				sleep 1
				NET_STATUS_CLEAR
				exit 0
			fi

			case "$RC" in
				"$RC_INVALID_PASSWORD")
					LOG_ERROR "$0" 0 "NETWORK" "Invalid WiFi password"
					NET_STATUS "INVALID_PASSWORD"
					sleep 2
					NET_STATUS_CLEAR
					exit 1
					;;
				"$RC_AP_NOT_FOUND")
					LOG_ERROR "$0" 0 "NETWORK" "Access point not found"
					NET_STATUS "AP_NOT_FOUND"
					sleep 2
					NET_STATUS_CLEAR
					exit 1
					;;
				"$RC_WPA_START_FAILED")
					LOG_ERROR "$0" 0 "NETWORK" "wpa_supplicant start failed"
					NET_STATUS "WPA_START_FAILED"
					sleep 2
					NET_STATUS_CLEAR
					exit 1
					;;
			esac

			RETRY_CURR=$((RETRY_CURR + 1))
			LOG_WARN "$0" 0 "NETWORK" "$(printf "Retrying Network Connection (%s/%s)" "$RETRY_CURR" "$RETRIES")"
			sleep "$RETRY_DELAY"
		done

		LOG_ERROR "$0" 0 "NETWORK" "All Connection Attempts Failed"
		NET_STATUS "FAILED"
		sleep 2
		NET_STATUS_CLEAR
		exit 1
		;;
esac
