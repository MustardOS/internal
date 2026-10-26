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

HEX_ESCAPE() {
	awk '{
		out = ""
		s = $0
		while (length(s) > 0) {
			if (substr(s, 1, 2) == "\\x") {
				hex = substr(s, 3, 2)
				out = out sprintf("%c", strtonum("0x" hex))
				s = substr(s, 5)
			} else {
				out = out substr(s, 1, 1)
				s = substr(s, 2)
			}
		}
		print out
	}'
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
		mgx* | rg-vita* | rk* | tui*) /opt/muos/script/init/async/S02network.sh load ;;
		rg*) [ ! -d "/sys/bus/mmc/devices/mmc2:0001" ] && /opt/muos/script/init/async/S02network.sh load ;;
		*) ;;
	esac

	ACTIVE_IFCE=$(GET_VAR "device" "network/iface_active")
	[ -n "$ACTIVE_IFCE" ] && IFCE="$ACTIVE_IFCE"

	LOG_INFO "$0" 0 "SSID-SCAN" "$(printf "Setting '%s' device up" "$IFCE")"
	ip link set dev "$IFCE" up
fi

LOG_INFO "$0" 0 "SSID-SCAN" "Scanning for networks..."
SCAN_TYPE=$(GET_VAR "device" "network/type")
SCAN_DATA=""
SCAN_ATTEMPT=1
while :; do
	case "$SCAN_TYPE" in
		wext) SCAN_DATA=$(timeout 10 iwlist "$IFCE" scan 2>/dev/null) ;;
		nl80211) SCAN_DATA=$(timeout 10 iw dev "$IFCE" scan 2>/dev/null) ;;
		*) break ;;
	esac

	if [ -n "$SCAN_DATA" ] || [ "$SCAN_ATTEMPT" -ge 2 ]; then
		break
	fi

	LOG_WARN "$0" 0 "SSID-SCAN" "$(printf "Scan attempt %s found nothing, trying again" "$SCAN_ATTEMPT")"
	SCAN_ATTEMPT=$((SCAN_ATTEMPT + 1))
	sleep 2
done

: >"$NET_SCAN_WORK"
if [ -z "$SCAN_DATA" ]; then
	printf "[!]" >"$NET_SCAN_WORK"
	FINISH_SCAN
	exit 0
fi

printf '%s\n' "$SCAN_DATA" |
	grep -E 'ESSID:|SSID:' |
	sed -e 's/^[[:space:]]*ESSID:"//' -e 's/^[[:space:]]*SSID: //' -e 's/"$//' |
	grep -v '^$' |
	grep -v '^\\x00' |
	sort -u |
	HEX_ESCAPE >>"$NET_SCAN_WORK"

FINISH_SCAN
