#!/bin/sh

. /opt/muos/script/var/log.sh

IFCE="$(GET_VAR "device" "network/iface_active")"
[ -n "$IFCE" ] || IFCE="$(GET_VAR "device" "network/iface")"

NET_SCAN="/tmp/net_scan"
NET_SCAN_WORK="${NET_SCAN}.$$"
rm -f "$NET_SCAN"

CLEANUP_SCAN() {
	rm -f "$NET_SCAN_WORK"
}

trap CLEANUP_SCAN EXIT INT TERM

DECODE_SSID() {
	awk '
		BEGIN { hex = "0123456789abcdef" }
		{
			out = ""
			s = $0
			while (s != "") {
				c = substr(s, 1, 1)
				if (c == "\\" && substr(s, 2, 1) == "x" && length(s) >= 4) {
					out = out sprintf("%c", (index(hex, tolower(substr(s, 3, 1))) - 1) * 16 + index(hex, tolower(substr(s, 4, 1))) - 1)
					s = substr(s, 5)
				} else if (c == "\\" && length(s) >= 2) {
					out = out substr(s, 2, 1)
					s = substr(s, 3)
				} else {
					out = out c
					s = substr(s, 2)
				}
			}
			print out
		}'
}

SCAN_SSIDS() {
	case "$SCAN_TYPE" in
		wext) timeout 10 iwlist "$IFCE" scan 2>/dev/null | sed -n 's/^[[:space:]]*ESSID:"\(.*\)"$/\1/p' ;;
		*) timeout 10 iw dev "$IFCE" scan 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p' ;;
	esac
}

SUPPLICANT_SSIDS() {
	timeout 5 wpa_cli -i "$IFCE" scan >/dev/null 2>&1 || return
	sleep 4
	timeout 5 wpa_cli -i "$IFCE" scan_results 2>/dev/null | awk -F '\t' 'NR > 1 { print $5 }'
}

# If we are already connected, do NOT touch network at all...
WAS_ACTIVE=0
[ -n "$(GET_VAR "config" "network/active")" ] && WAS_ACTIVE=1
BOARD_NAME=$(GET_VAR "device" "board/name")

FINISH_SCAN() {
	if [ "$WAS_ACTIVE" -eq 0 ]; then
		case "$BOARD_NAME" in
			tui*) /opt/muos/script/init/async/S02network.sh stop ;;
			*) /opt/muos/script/init/async/S02network.sh disconnect ;;
		esac
	fi

	[ ! -s "$NET_SCAN_WORK" ] && printf "[!]" >"$NET_SCAN_WORK"
	mv -f "$NET_SCAN_WORK" "$NET_SCAN"
}

if [ "$WAS_ACTIVE" -eq 0 ]; then
	case "$BOARD_NAME" in
		mgx* | rg* | rk* | tui*) /opt/muos/script/init/async/S02network.sh load ;;
		*) ;;
	esac

	ACTIVE_IFCE=$(GET_VAR "device" "network/iface_active")
	[ -n "$ACTIVE_IFCE" ] && IFCE="$ACTIVE_IFCE"

	IFCE_WAIT=0
	while [ ! -d "/sys/class/net/$IFCE" ] && [ "$IFCE_WAIT" -lt 50 ]; do
		sleep 0.1
		IFCE_WAIT=$((IFCE_WAIT + 1))
	done

	LOG_INFO "$0" 0 "SSID-SCAN" "$(printf "Setting '%s' device up" "$IFCE")"
	ip link set dev "$IFCE" up
fi

rfkill unblock wifi 2>/dev/null

LOG_INFO "$0" 0 "SSID-SCAN" "Scanning for networks..."
SCAN_TYPE=$(GET_VAR "device" "network/type")
SCAN_DATA=""
SCAN_ATTEMPT=1
while :; do
	SCAN_DATA=$(SCAN_SSIDS | grep -v -e '^$' -e '^\\x00')
	[ -n "$SCAN_DATA" ] || [ "$SCAN_ATTEMPT" -ge 2 ] && break

	LOG_WARN "$0" 0 "SSID-SCAN" "$(printf "Scan attempt %s found nothing, trying again" "$SCAN_ATTEMPT")"
	SCAN_ATTEMPT=$((SCAN_ATTEMPT + 1))
	sleep 2
done

if [ -z "$SCAN_DATA" ]; then
	LOG_WARN "$0" 0 "SSID-SCAN" "Driver scan found nothing, asking the supplicant"
	SCAN_DATA=$(SUPPLICANT_SSIDS | grep -v -e '^$' -e '^\\x00')
fi

: >"$NET_SCAN_WORK"
if [ -z "$SCAN_DATA" ]; then
	printf "[!]" >"$NET_SCAN_WORK"
	FINISH_SCAN
	exit 0
fi

printf '%s\n' "$SCAN_DATA" | DECODE_SSID | sort -u >>"$NET_SCAN_WORK"

FINISH_SCAN
