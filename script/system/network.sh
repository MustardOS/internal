#!/bin/sh

. /opt/muos/script/var/func.sh

ADDR=$(GET_VAR "global" "network/address")
SUBN=$(GET_VAR "global" "network/subnet")
SSID=$(GET_VAR "global" "network/ssid")
GATE=$(GET_VAR "global" "network/gateway")
TYPE=$(GET_VAR "global" "network/type")
DDNS=$(GET_VAR "global" "network/dns") # The extra D is for dodecahedron!
IFCE=$(GET_VAR "device" "network/iface")
DRIV=$(GET_VAR "device" "network/type")

RETRIES="${RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-3}"
RETRY_CURR=0

CURRENT_IP="/opt/muos/config/address.txt"
: >"$CURRENT_IP"
IP="0.0.0.0"

killall -q dhcpcd wpa_supplicant

TRY_CONNECT() {
	if [ "$RETRY_CURR" -eq 0 ]; then
		LOG_INFO "$0" 0 "NETWORK" "Starting Network Connection..."
		[ -z "$SSID" ] && return 1

		LOG_INFO "$0" 0 "NETWORK" "Setting '%s' device up" "$IFCE"
		ip link set dev "$IFCE" up

		if [ "$IFCE" = "wlan0" ]; then
			LOG_INFO "$0" 0 "NETWORK" "Configuring WPA Supplicant"
			/opt/muos/script/web/password.sh
			wpa_supplicant -d -B -i "$IFCE" -c "$WPA_CONFIG" -D "$DRIV"

			CARRIER_WAIT=10
			while [ "$CARRIER_WAIT" -gt 0 ]; do
				if iw dev "$IFCE" link | grep "SSID:"; then
					break
				fi
				LOG_INFO "$0" 0 "NETWORK" "Waiting for Wi-Fi Association... (%ds)" "$CARRIER_WAIT"
				CARRIER_WAIT=$((CARRIER_WAIT - 1))
				sleep 1
			done

			if [ "$CARRIER_WAIT" -eq 0 ]; then
				LOG_ERROR "$0" 0 "NETWORK" "Wi-Fi Association Timed Out"
				return 1
			fi
		fi
	fi

	LOG_INFO "$0" 0 "NETWORK" "Detecting Network Connection Type"
	if [ "$TYPE" -eq 0 ]; then
		LOG_INFO "$0" 0 "NETWORK" "Detected 'DHCP' Mode"
		LOG_INFO "$0" 0 "NETWORK" "Clearing Previous DHCP Addresses"
		rm -rf /var/db/dhcpcd/*

		LOG_INFO "$0" 0 "NETWORK" "Starting DHCP Server..."
		dhcpcd -d -w "$IFCE"

		if pgrep "dhcpcd" >/dev/null; then
			LOG_SUCCESS "$0" 0 "NETWORK" "DHCP Server Started"
			LOG_INFO "$0" 0 "NETWORK" "Resolving Nameserver"
			DDNS=$(sed -n 's/^nameserver //p' /etc/resolv.conf | head -n1)
		else
			LOG_ERROR "$0" 0 "NETWORK" "DHCP Server Failure"
			return 1
		fi
	else
		LOG_INFO "$0" 0 "NETWORK" "Detected 'STATIC' Mode"
		LOG_INFO "$0" 0 "NETWORK" "Adding Static Address"
		ip addr add "$ADDR"/"$SUBN" dev "$IFCE"
		LOG_INFO "$0" 0 "NETWORK" "Adding Default IP Route"
		ip route | grep "default via $GATE" || ip route add default via "$GATE"
		DDNS=$(GET_VAR "global" "network/dns")
	fi

	LOG_INFO "$0" 0 "NETWORK" "Saving IP Address Variable"
	IP=$(ip -4 a show dev "$IFCE" | sed -nE 's/.*inet ([0-9.]+)\/.*/\1/p')

	# Validate internet reachability via DNS or fallback servers
	LOG_INFO "$0" 0 "NETWORK" "Validating Network Connection"
	if ping -q -c1 -w2 "$DDNS" >/dev/null 2>&1 ||
		ping -q -c1 -w2 1.1.1.1 >/dev/null 2>&1 ||    # Cloudflare
		ping -q -c1 -w2 8.8.8.8 >/dev/null 2>&1; then # Google
		LOG_SUCCESS "$0" 0 "NETWORK" "Active Network Connection Found"
	else
		LOG_ERROR "$0" 0 "NETWORK" "No Active Network Connection Found"
		IP="0.0.0.0"
		return 1
	fi

	TMP_FILE=$(mktemp)
	echo "${IP:-0.0.0.0}" >"$TMP_FILE"
	mv "$TMP_FILE" "$CURRENT_IP"

	return 0
}

case "$1" in
	disconnect)
		: >"$WPA_CONFIG"
		: >"$CURRENT_IP"

		LOG_INFO "$0" 0 "NETWORK" "Clearing Previous DHCP Addresses"
		rm -rf /var/db/dhcpcd/*

		LOG_INFO "$0" 0 "NETWORK" "Setting '%s' device down" "$IFCE"
		ip link set dev "$IFCE" down

		LOG_INFO "$0" 0 "NETWORK" "Stopping Network Services"
		/opt/muos/script/web/service.sh stopall &
		;;

	connect)
		CONNECTED=0

		while [ "$RETRIES" -gt 0 ]; do
			if TRY_CONNECT; then
				CONNECTED=1
				LOG_SUCCESS "$0" 0 "NETWORK" "Network Connected Successfully!"
				LOG_INFO "$0" 0 "NETWORK" "Starting Enabled Network Services"
				/opt/muos/script/web/service.sh &
				break
			fi
			if [ "$CONNECTED" -eq 0 ]; then
				RETRIES=$((RETRIES - 1))
				RETRY_CURR=$((RETRY_CURR + 1))
				LOG_INFO "$0" 0 "NETWORK" "Retrying Network Connection (%s)" "$RETRY_CURR"
				sleep "$RETRY_DELAY"
			fi
		done

		#if [ "$CONNECTED" -eq 0 ]; then
		#	LOG_ERROR "$0" 0 "NETWORK" "Sending Network Disconnection"
		#	exec "$0" disconnect
		#fi
		;;
esac
