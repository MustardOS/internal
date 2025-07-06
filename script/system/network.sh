#!/bin/sh

. /opt/muos/script/var/func.sh

ADDR=$(GET_VAR "config" "network/address")
SUBN=$(GET_VAR "config" "network/subnet")
SSID=$(GET_VAR "config" "network/ssid")
GATE=$(GET_VAR "config" "network/gateway")
TYPE=$(GET_VAR "config" "network/type")
DDNS=$(GET_VAR "config" "network/dns") # The extra D is for dodecahedron!
IFCE=$(GET_VAR "device" "network/iface")
DRIV=$(GET_VAR "device" "network/type")

DEV_HOST="$(GET_VAR "device" "network/hostname")"
SD1_HOST="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/hostname"
SD2_HOST="$(GET_VAR "device" "storage/sdcard/mount")/MUOS/info/hostname"

RETRIES="${RETRIES:-5}"
RETRY_DELAY="${RETRY_DELAY:-2}"
RETRY_CURR=0

DHCP_CONF="/etc/dhcpcd.conf"

CALCULATE_IAID() {
	MAC=$(cat /sys/class/net/"$IFCE"/address)
	OCT5=$(echo "$MAC" | cut -d: -f5)
	OCT6=$(echo "$MAC" | cut -d: -f6)
	IAID=$(printf "0x%02x%02x" 0x"$OCT5" 0x"$OCT6")

	LOG_INFO "$0" 0 "NETWORK" "Using IAID: %s" "$IAID"
	sed -i "/^iaid/d" "$DHCP_CONF"
	echo "iaid $IAID" >>"$DHCP_CONF"
}

TRY_CONNECT() {
	IP="0.0.0.0"

	[ -z "$SSID" ] && exit 0

	LOG_INFO "$0" 0 "NETWORK" "Detecting Hostname Restore"
	HOSTFILE=""
	[ -e "$DEV_HOST" ] && HOSTFILE="$DEV_HOST"
	[ -z "$HOSTFILE" ] && [ -e "$SD2_HOST" ] && HOSTFILE="$SD2_HOST"
	[ -z "$HOSTFILE" ] && [ -e "$SD1_HOST" ] && HOSTFILE="$SD1_HOST"

	if [ -n "$HOSTFILE" ]; then
		HOSTNAME=$(cat "$HOSTFILE")
		hostname "$HOSTNAME"
		printf "%s" "$HOSTNAME" >/etc/hostname
	fi

	LOG_INFO "$0" 0 "NETWORK" "Starting Network Connection..."

	pgrep dhcpcd >/dev/null && killall -q dhcpcd
	pgrep wpa_supplicant >/dev/null && killall -q wpa_supplicant

	WAIT_IFACE=20
	while [ "$WAIT_IFACE" -gt 0 ]; do
		[ -d "/sys/class/net/$IFCE" ] && break

		LOG_WARN "$0" 0 "NETWORK" "Waiting for interface '%s' to appear... (%ds)" "$IFCE" "$WAIT_IFACE"

		/opt/muos/bin/toybox sleep 1
		WAIT_IFACE=$((WAIT_IFACE - 1))
	done

	CALCULATE_IAID

	mkdir -p /var/db/dhcpcd || true

	LOG_INFO "$0" 0 "NETWORK" "Setting '%s' device up" "$IFCE"
	if ! ip link set dev "$IFCE" up; then
		LOG_ERROR "$0" 0 "NETWORK" "Failed to bring up interface '$IFCE'"
		return 1
	fi

	if [ "$IFCE" = "wlan0" ]; then
		LOG_INFO "$0" 0 "NETWORK" "Configuring WPA Supplicant"
		/opt/muos/script/web/password.sh

		if [ ! -s "$WPA_CONFIG" ]; then
			LOG_ERROR "$0" 0 "NETWORK" "Missing WPA Supplicant Configuration"
			return 1
		fi

		wpa_supplicant -B -i "$IFCE" -c "$WPA_CONFIG" -D "$DRIV"

		WAIT_CARRIER=20
		while [ "$WAIT_CARRIER" -gt 0 ]; do
			if iw dev "$IFCE" link | grep "SSID:"; then
				break
			fi
			LOG_WARN "$0" 0 "NETWORK" "Waiting for Wi-Fi Association... (%ds)" "$WAIT_CARRIER"
			WAIT_CARRIER=$((WAIT_CARRIER - 1))
			/opt/muos/bin/toybox sleep 1
		done

		if [ "$WAIT_CARRIER" -eq 0 ]; then
			LOG_ERROR "$0" 0 "NETWORK" "Wi-Fi Association Timed Out"
			return 1
		fi
	fi

	LOG_INFO "$0" 0 "NETWORK" "Detecting Network Connection Type"
	if [ "$TYPE" -eq 0 ]; then
		LOG_INFO "$0" 0 "NETWORK" "Detected 'DHCP' Mode"

		LOG_INFO "$0" 0 "NETWORK" "Clearing Previous DHCP Addresses"
		rm -rf /var/db/dhcpcd/*

		LOG_INFO "$0" 0 "NETWORK" "Starting DHCP Client..."
		dhcpcd "$IFCE" &

		WAIT_IP=20
		while [ "$WAIT_IP" -gt 0 ]; do
			LOG_WARN "$0" 0 "NETWORK" "Waiting for DHCP Lease... (%ds)" "$WAIT_IP"
			IP=$(ip -4 a show dev "$IFCE" | sed -nE 's/.*inet ([0-9.]+)\/.*/\1/p')

			if [ -n "$IP" ]; then
				LOG_SUCCESS "$0" 0 "NETWORK" "DHCP Lease Acquired: %s" "$IP"
				LOG_INFO "$0" 0 "NETWORK" "Resolving Nameserver"
				DDNS=$(sed -n 's/^nameserver //p' /etc/resolv.conf | head -n1)
				break
			fi

			/opt/muos/bin/toybox sleep 1
			WAIT_IP=$((WAIT_IP - 1))
		done

		if [ -z "$IP" ]; then
			LOG_ERROR "$0" 0 "NETWORK" "Failed to Acquire IP via DHCP"
			return 1
		fi
	else
		LOG_INFO "$0" 0 "NETWORK" "Detected 'STATIC' Mode"

		LOG_INFO "$0" 0 "NETWORK" "Flushing Previous Static Interface"
		ip addr flush dev "$IFCE"
		ip route del default dev "$IFCE" 2>/dev/null

		LOG_INFO "$0" 0 "NETWORK" "Adding Static Address"
		ip addr add "$ADDR"/"$SUBN" dev "$IFCE"

		LOG_INFO "$0" 0 "NETWORK" "Adding Default IP Route"
		ip route | grep "default via $GATE" || ip route add default via "$GATE"

		IP=$(ip -4 a show dev "$IFCE" | sed -nE 's/.*inet ([0-9.]+)\/.*/\1/p')
	fi

	LOG_INFO "$0" 0 "NETWORK" "Validating Network Connection"
	if ping -q -c1 -w2 "$DDNS" ||
		ping -q -c1 -w2 1.1.1.1 ||
		ping -q -c1 -w2 8.8.8.8; then
		LOG_SUCCESS "$0" 0 "NETWORK" "Active Network Connection Found"
	else
		LOG_ERROR "$0" 0 "NETWORK" "No Active Network Connection Found"
		return 1
	fi

	SET_VAR "config" "network/address" "$IP"

	return 0
}

case "$1" in
	disconnect)
		case "$(GET_VAR "device" "board/name")" in
			tui*) /opt/muos/device/script/module.sh unload-network ;;
			*) ;;
		esac

		: >"$WPA_CONFIG"

		LOG_INFO "$0" 0 "NETWORK" "Clearing Previous DHCP Addresses"
		rm -rf /var/db/dhcpcd/*

		LOG_INFO "$0" 0 "NETWORK" "Setting '%s' device down" "$IFCE"
		ip link set dev "$IFCE" down

		LOG_INFO "$0" 0 "NETWORK" "Stopping Network Services"
		/opt/muos/script/web/service.sh stopall &

		LOG_INFO "$0" 0 "NETWORK" "Stopping Keepalive Script"
		killall -9 "keepalive.sh" &
		;;

	connect)
		case "$(GET_VAR "device" "board/name")" in
			tui*) /opt/muos/device/script/module.sh load-network ;;
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
			LOG_WARN "$0" 0 "NETWORK" "Retrying Network Connection (%s/%s)" "$RETRY_CURR" "$RETRIES"
			/opt/muos/bin/toybox sleep "$RETRY_DELAY"
		done

		LOG_ERROR "$0" 0 "NETWORK" "All Connection Attempts Failed"
		exit 1
		;;
esac
