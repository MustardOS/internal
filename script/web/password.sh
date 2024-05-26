#!/bin/sh

SSID=$(cat "/tmp/net_ssid")
PASS=$(cat "/tmp/net_pass")

WPA_CONFIG=/etc/wpa_supplicant.conf

#echo "ctrl_interface=/var/run/wpa_supplicant" > "$WPA_CONFIG"
#echo "ap_scan=1" >> "$WPA_CONFIG"
#echo "ieee80211w=1" >> "$WPA_CONFIG"
#echo "" >> "$WPA_CONFIG"

/usr/sbin/wpa_passphrase "$SSID" "$PASS" >> "$WPA_CONFIG"

sed -i '3d' "$WPA_CONFIG"

rm /tmp/net_ssid /tmp/net_pass

