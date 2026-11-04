#!/bin/sh

. /opt/muos/script/var/config.sh
. /opt/muos/script/var/wpa.sh

SSID="$(GET_VAR "config" "network/ssid")"
PASS="$(GET_VAR "config" "network/pass")"

umask 077
WPA_CONFIG_TMP=$(mktemp "$WPA_CONFIG.XXXXXX") || exit 1
trap 'rm -f "$WPA_CONFIG_TMP"' EXIT
trap 'exit 1' INT TERM

WPA_NETWORK "$SSID" "$PASS" 10 >"$WPA_CONFIG_TMP" || exit 1

WPA_PSK=$(sed -n 's/^[[:space:]]*psk=//p' "$WPA_CONFIG_TMP")
[ -n "$WPA_PSK" ] && [ "$WPA_PSK" != "$PASS" ] && SET_VAR "config" "network/pass" "$WPA_PSK"

mv -f "$WPA_CONFIG_TMP" "$WPA_CONFIG"
