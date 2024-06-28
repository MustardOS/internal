#!/bin/sh

SSID=$(cat "/tmp/net_ssid")
PASS=$(cat "/tmp/net_pass")

WPA_CONFIG=/etc/wpa_supplicant.conf

wpa_passphrase "$SSID" "$PASS" >"$WPA_CONFIG"

sed -i '3d' "$WPA_CONFIG"

rm /tmp/net_ssid /tmp/net_pass
