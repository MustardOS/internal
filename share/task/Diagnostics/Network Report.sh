#!/bin/sh
# HELP: Network Report - Checks Wi-Fi, addresses, routing, DNS, internet access and the clock, then saves a report to SD1
# ICON: network
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/diag.sh

DIAG_BEGIN "network_report" "Network Report"

REDACT() {
	sed -e 's/\(ssid[= :]*\).*/\1(hidden)/I' -e 's/\(SSID:\).*/\1 (hidden)/' -e 's/\(psk[= :]*\).*/\1(hidden)/I'
}

IFACE=$(GET_VAR "device" "network/iface" 2>/dev/null)
[ -n "$IFACE" ] || IFACE=wlan0

DIAG_SECTION "muOS network configuration"
DIAG_CONFIG "$MUOS_CONF_DEVICE/network"
DIAG_CONFIG "$MUOS_CONF_GLOBAL/network"
DIAG_KV "Network enabled" "$(GET_VAR "config" "network/enabled" 2>/dev/null)"

DIAG_SECTION "Interfaces"
DIAG_CMD "ip addr" ip addr
if [ ! -d "/sys/class/net/$IFACE" ]; then
	DIAG_FINDING "WIFI" "The Wi-Fi interface $IFACE does not exist. The Wi-Fi driver is not loaded."
fi
DIAG_CMD "rfkill" rfkill list
rfkill list 2>/dev/null | grep -q "Soft blocked: yes" && DIAG_FINDING "WIFI" "A radio is soft blocked (rfkill)."
rfkill list 2>/dev/null | grep -q "Hard blocked: yes" && DIAG_FINDING "WIFI" "A radio is hard blocked (rfkill)."

DIAG_SECTION "Wi-Fi"
LINK=$(timeout 5 iw dev "$IFACE" link 2>/dev/null)
printf '%s\n' "${LINK:-not connected}" | REDACT | DIAG_APPEND
timeout 5 iw dev "$IFACE" info 2>/dev/null | REDACT | DIAG_APPEND
command -v wpa_cli >/dev/null 2>&1 && timeout 5 wpa_cli -i "$IFACE" status 2>/dev/null | REDACT | DIAG_APPEND
for DAEMON in wpa_supplicant udhcpc dhcpcd; do
	DIAG_RUNNING "$DAEMON" && DIAG_KV "$DAEMON" "running" || DIAG_KV "$DAEMON" "not running"
done
if [ -d "/sys/class/net/$IFACE" ]; then
	case "$LINK" in
		*"Not connected"* | "") DIAG_FINDING "WIFI" "Wi-Fi is not connected to a network." ;;
	esac
	SIGNAL=$(printf '%s' "$LINK" | sed -n 's/.*signal: \(-[0-9]*\) dBm.*/\1/p')
	DIAG_IS_NUM "$SIGNAL" && [ "$SIGNAL" -lt -75 ] && DIAG_FINDING "WIFI" "The Wi-Fi signal is weak ($SIGNAL dBm). Move closer to the router."
fi

DIAG_SECTION "Addresses and routes"
ADDRESS=$(ip -4 addr show "$IFACE" 2>/dev/null | sed -n 's/.*inet \([0-9.]*\).*/\1/p' | head -n 1)
DIAG_KV "IPv4 address" "${ADDRESS:-none}"
DIAG_CMD "Routes" ip route
GATEWAY=$(ip route 2>/dev/null | sed -n 's/^default via \([0-9.]*\).*/\1/p' | head -n 1)
DIAG_KV "Gateway" "${GATEWAY:-none}"
DIAG_FILE /etc/resolv.conf
[ -z "$ADDRESS" ] && [ -d "/sys/class/net/$IFACE" ] && DIAG_FINDING "NETWORK" "$IFACE has no IPv4 address. DHCP did not complete."
[ -z "$GATEWAY" ] && DIAG_FINDING "NETWORK" "There is no default route, so nothing outside the local network can be reached."

DIAG_SECTION "Reachability"
PING_TARGET() {
	if timeout 6 ping -c 2 -W 2 "$2" >/dev/null 2>&1; then
		DIAG_KV "$1" "reachable ($2)"
		return 0
	fi
	DIAG_KV "$1" "NOT reachable ($2)"
	return 1
}
[ -n "$GATEWAY" ] && { PING_TARGET "Gateway" "$GATEWAY" || DIAG_FINDING "NETWORK" "The router ($GATEWAY) does not answer."; }
PING_TARGET "Internet by address" 1.1.1.1 || DIAG_FINDING "NETWORK" "The internet cannot be reached by address."
if timeout 6 nslookup github.com >/dev/null 2>&1; then
	DIAG_KV "DNS" "github.com resolves"
else
	DIAG_KV "DNS" "github.com does NOT resolve"
	DIAG_FINDING "NETWORK" "DNS lookups fail, so names such as github.com cannot be found."
fi
if command -v curl >/dev/null 2>&1; then
	HTTP=$(timeout 15 curl -s -o /dev/null -w "%{http_code} in %{time_total}s" https://github.com 2>/dev/null)
	DIAG_KV "HTTPS to github.com" "${HTTP:-failed}"
	case "$HTTP" in 2* | 3*) ;; *) DIAG_FINDING "NETWORK" "HTTPS requests fail (github.com: ${HTTP:-no answer}). Downloads and updates will not work." ;; esac
fi

DIAG_SECTION "Clock"
DIAG_KV "Date" "$(date)"
DIAG_KV "Hardware clock" "$(hwclock -r 2>/dev/null)"
YEAR=$(date +%Y)
[ "$YEAR" -lt 2025 ] && DIAG_FINDING "CLOCK" "The clock reads $YEAR. Secure downloads fail when the date is this far off."
[ -x /opt/muos/bin/chronyc ] && DIAG_CMD "Time sync" /opt/muos/bin/chronyc -n tracking

DIAG_SECTION "Listening services"
DIAG_CMD "netstat" netstat -tln

DIAG_SECTION "Kernel messages"
DIAG_DMESG "wlan|wifi|80211|rtl|8188|8821|aic|xradio|ssv|brcm|dhd|mmc.*sdio|firmware" 60

DIAG_FINISH "Network report saved"
exit 0
