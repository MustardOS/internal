#!/bin/sh

. /opt/muos/script/var/func.sh

SSID="$(GET_VAR "config" "network/ssid")"
PASS="$(GET_VAR "config" "network/pass")"

SSID_WPA="$(GET_VAR "config" "network/ssid_wpa")"
[ -z "$SSID_WPA" ] && SSID_WPA=$(printf '%s' "$SSID" | sed 's/\\/\\\\/g; s/"/\\"/g')

WPA_CONFIG_TMP=$(mktemp) || exit 1
WPA_PASS_TMP=""

CLEANUP() {
	rm -f "$WPA_CONFIG_TMP"
	[ -n "$WPA_PASS_TMP" ] && rm -f "$WPA_PASS_TMP"
}

trap CLEANUP EXIT INT TERM

WRITE_ACTIVE_WPA_CONFIG() {
	case ${#PASS} in
		64)
			printf "network={\n\tssid=\"%s\"\n\tscan_ssid=1\n\tpsk=%s\n\tpriority=10\n}" \
				"$SSID_WPA" "$PASS" >"$WPA_CONFIG_TMP"
			;;
		0)
			printf "network={\n\tssid=\"%s\"\n\tscan_ssid=1\n\tkey_mgmt=NONE\n\tpriority=10\n}" \
				"$SSID_WPA" >"$WPA_CONFIG_TMP"
			;;
		*)
			WPA_PASS_TMP=$(mktemp) || return 1

			wpa_passphrase "$SSID" "$PASS" >"$WPA_PASS_TMP" || return 1

			# Extract the derived hex PSK and persist it (replacing the plain password)
			sed -n '/^[[:space:]]*psk=/s/^[[:space:]]*psk=//p' "$WPA_PASS_TMP" >"/opt/muos/config/network/pass"

			awk '/^network=/ { print; print "\tpriority=10"; next }
			     /ssid=/     { print; print "\tscan_ssid=1"; next }
			     !/^[[:space:]]*#psk=/' "$WPA_PASS_TMP" >"$WPA_CONFIG_TMP"
			;;
	esac

	mv -f "$WPA_CONFIG_TMP" "$WPA_CONFIG"
	WPA_CONFIG_TMP=""
}

WRITE_ACTIVE_WPA_CONFIG
