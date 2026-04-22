#!/bin/sh

. /opt/muos/script/var/func.sh

IFCE="$(GET_VAR "device" "network/iface_active")"
[ -n "$IFCE" ] || IFCE="$(GET_VAR "device" "network/iface")"

NET_SCAN="/tmp/net_scan"
rm -f "$NET_SCAN"

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

case "$(GET_VAR "device" "board/name")" in
	mgx* | rg-vita* | rk* | tui*) /opt/muos/script/init/async/S02network.sh load ;;
	rg*) [ ! -d "/sys/bus/mmc/devices/mmc2:0001" ] && /opt/muos/script/init/async/S02network.sh load ;;
	*) ;;
esac

LOG_INFO "$0" 0 "SSID-SCAN" "$(printf "Setting '%s' device up" "$IFCE")"
ip link set dev "$IFCE" up

LOG_INFO "$0" 0 "SSID-SCAN" "Scanning for networks..."
SCAN_DATA=""
case "$(GET_VAR "device" "network/type")" in
	wext) SCAN_DATA=$(timeout 15 iwlist "$IFCE" scan 2>/dev/null) ;;
	nl80211) SCAN_DATA=$(timeout 15 iw dev "$IFCE" scan 2>/dev/null) ;;
	*) SCAN_DATA="" ;;
esac

: >"$NET_SCAN"
[ -z "$SCAN_DATA" ] && exit 0

printf '%s\n' "$SCAN_DATA" |
	grep -E 'ESSID:|SSID:' |
	sed -e 's/^[[:space:]]*ESSID:"//' -e 's/^[[:space:]]*SSID: //' -e 's/"$//' |
	grep -v '^$' |
	grep -v '^\\x00' |
	sort -u |
	HEX_ESCAPE >>"$NET_SCAN"

/opt/muos/script/init/async/S02network.sh stop
[ ! -s "$NET_SCAN" ] && printf "[!]" >"$NET_SCAN"
