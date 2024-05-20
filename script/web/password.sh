#!/bin/sh

if [ -z "$1" ]; then
    echo "Usage: $0 <ssid> <password>"
    exit 1
fi

SSID="$1"
PASS="$2"

WPA_CONFIG=/etc/wpa_supplicant.conf

(
/usr/sbin/wpa_passphrase "$SSID" << EOF
$PASS
EOF
) > "$WPA_CONFIG"

sed -i '3d' "$WPA_CONFIG"

