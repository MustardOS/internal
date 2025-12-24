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

RETRIES="${RETRIES:-5}"
RETRY_DELAY="${RETRY_DELAY:-2}"

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

WAIT_NETWORK_ASSOC() {
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
	return 1
}

WAIT_CARRIER() {
	I=0
	while [ "$I" -lt 5 ]; do
		[ "$(cat /sys/class/net/"$IFCE"/carrier)" = "1" ] && return 0
		I=$((I + 1))
		sleep 1
	done

	LOG_ERROR "$0" 0 "NETWORK" "Link carrier timeout"
	return 1
}

WIFI_CONFIG() {
	LOG_INFO "$0" 0 "NETWORK" "$(printf "Setting ESSID: %s" "$SSID")"
	if iw dev "$IFCE" info >/dev/null 2>&1; then
		iwconfig "$IFCE" essid -- "$SSID"
	fi

	if [ -n "$PASS" ]; then
		/opt/muos/script/web/password.sh

		# You're the best... around
		BEST_BSSID=$(iw dev "$IFCE" scan 2>/dev/null |
			awk -v ssid="$SSID" '
				/BSS/ { b=$2 }
				/SSID:/ && $2 == ssid { sub(/[\(\)]/,"",b); print b; exit }
			')

		sed -i '/^bssid=/d' "$WPA_CONFIG"
		[ -n "$BEST_BSSID" ] && {
			LOG_INFO "$0" 0 "NETWORK" "$(printf "Pinning BSSID: %s" "$BEST_BSSID")"
			sed -i "/^ssid=/i bssid=$BEST_BSSID" "$WPA_CONFIG"
		}

		case "$DRIV" in
			wext)
				LOG_INFO "$0" 0 "NETWORK" "Starting wpa_supplicant (wext)"
				if ! wpa_supplicant -B -i "$IFCE" -c "$WPA_CONFIG" -D wext 2>/dev/null; then
					LOG_WARN "$0" 0 "NETWORK" "Failed to start wpa_supplicant, falling back to 'Managed' mode"
					iwconfig "$IFCE" mode Managed
					iwconfig "$IFCE" key off
				fi
				;;
			nl80211)
				LOG_INFO "$0" 0 "NETWORK" "Starting wpa_supplicant (nl80211)"
				if ! wpa_supplicant -B -i "$IFCE" -c "$WPA_CONFIG" -D nl80211; then
					LOG_ERROR "$0" 0 "NETWORK" "Failed to start wpa_supplicant"
					return 1
				fi
				;;
		esac
	else
		if iw dev "$IFCE" info >/dev/null 2>&1; then
			LOG_INFO "$0" 0 "NETWORK" "Connecting to open network"
			iwconfig "$IFCE" mode Managed
			iwconfig "$IFCE" key off
		fi
	fi

	WAIT_NETWORK_ASSOC || return 1

	WAIT_CARRIER || return 1

	return 0
}

IP_DHCP() {
	dhcpcd "$IFCE" &

	I=0
	while [ "$I" -lt 20 ]; do
		IP=$(ip -4 -o addr show dev "$IFCE" | awk '{print $4}' | cut -d/ -f1)
		[ -n "$IP" ] && return 0
		I=$((I + 1))
		sleep 1
	done

	LOG_ERROR "$0" 0 "NETWORK" "DHCP failed"
	return 1
}

IP_STATIC() {
	ip addr flush dev "$IFCE" 2>/dev/null || true
	ip route del default dev "$IFCE" 2>/dev/null || true
	ip addr add "$ADDR"/"$SUBN" dev "$IFCE" 2>/dev/null || true
	ip route add default via "$GATE" dev "$IFCE" 2>/dev/null || true

	IP=$(ip -4 -o addr show dev "$IFCE" | awk '{print $4}' | cut -d/ -f1)
}

VALIDATE_NETWORK() {
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
	return 1
}

DESTROY_DHCPCD() {
	killall -q dhcpcd wpa_supplicant
	sleep 1
	killall -9 dhcpcd wpa_supplicant

	LOG_INFO "$0" 0 "NETWORK" "Clearing Previous DHCP Addresses"
	rm -rf /var/db/dhcpcd/*
	mkdir -p /var/db/dhcpcd
}

TRY_CONNECT() {
	[ -z "$SSID" ] && return 0

	rfkill unblock all
	iw dev "$IFCE" set power_save off

	RESTORE_HOSTNAME
	DESTROY_DHCPCD

	iw dev "$IFCE" disconnect 2>/dev/null || true
	ip addr flush dev "$IFCE" 2>/dev/null || true
	ip route del default dev "$IFCE" 2>/dev/null || true

	CALCULATE_IAID

	ip link set dev "$IFCE" down
	sleep 1

	ip link set dev "$IFCE" up || return 1
	sleep 1

	WIFI_CONFIG || return 1

	if [ "$TYPE" -eq 0 ]; then
		IP_DHCP || return 1
	else
		IP_STATIC
	fi

	sleep 1

	VALIDATE_NETWORK
}

case "$1" in
	disconnect)
		DESTROY_DHCPCD

		iw dev "$IFCE" disconnect
		: >"$WPA_CONFIG"

		LOG_INFO "$0" 0 "NETWORK" "$(printf "Setting '%s' device down" "$IFCE")"
		ip addr flush dev "$IFCE" 2>/dev/null || true
		ip route del default dev "$IFCE" 2>/dev/null || true
		ip link set dev "$IFCE" down 2>/dev/null || true

		LOG_INFO "$0" 0 "NETWORK" "Stopping Network Services"
		/opt/muos/script/web/service.sh stopall &

		LOG_INFO "$0" 0 "NETWORK" "Stopping Keepalive Script"
		killall -9 keepalive.sh &
		/opt/muos/script/device/network.sh unload
		;;

	connect)
		case "$(GET_VAR "device" "board/name")" in
			rg*) [ ! -d "/sys/bus/mmc/devices/mmc2:0001" ] && /opt/muos/script/device/network.sh load ;;
			rk* | tui*) /opt/muos/script/device/network.sh load ;;
			*) ;;
		esac

		RETRY_CURR=0
		while [ "$RETRY_CURR" -lt "$RETRIES" ]; do
			if TRY_CONNECT; then
				LOG_SUCCESS "$0" 0 "NETWORK" "Network Connected Successfully"

				LOG_INFO "$0" 0 "NETWORK" "Starting Keepalive Script"
				/opt/muos/script/web/keepalive.sh &

				LOG_INFO "$0" 0 "NETWORK" "Starting Enabled Network Services"
				/opt/muos/script/web/service.sh &

				exit 0
			fi

			RETRY_CURR=$((RETRY_CURR + 1))
			LOG_WARN "$0" 0 "NETWORK" "$(printf "Retrying Network Connection (%s/%s)" "$RETRY_CURR" "$RETRIES")"
			sleep "$RETRY_DELAY"
		done

		LOG_ERROR "$0" 0 "NETWORK" "All Connection Attempts Failed"

		exit 1
		;;
esac
