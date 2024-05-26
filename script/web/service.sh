#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

CURRENT_IP=$(cat "/opt/muos/config/address.txt")

killall sshd
killall sftpgo
killall gotty
killall syncthing

SRV_SHELL=$(parse_ini "$CONFIG" "web" "shell")
if [ "$SRV_SHELL" -eq 1 ]; then
	# Special directories that should not be world editable!
	chmod -R 700 /opt/openssh/var /opt/openssh/etc
	nice -2 /opt/openssh/sbin/sshd > /dev/null &
fi

SRV_BROWSER=$(parse_ini "$CONFIG" "web" "browser")
if [ "$SRV_BROWSER" -eq 1 ]; then
	nice -2 /opt/sftpgo/sftpgo serve -c /opt/sftpgo > /dev/null &
fi

SRV_TERMINAL=$(parse_ini "$CONFIG" "web" "terminal")
if [ "$SRV_TERMINAL" -eq 1 ]; then
	nice -2 /opt/muos/bin/gotty --config /opt/muos/config/gotty --width 0 --height 0 /bin/sh > /dev/null &
fi

SRV_SYNCTHING=$(parse_ini "$CONFIG" "web" "syncthing")
if [ "$SRV_SYNCTHING" -eq 1 ]; then
	nice -2 /opt/muos/bin/syncthing serve --home="$STORE_ROM/MUOS/syncthing" --skip-port-probing --gui-address="$CURRENT_IP:7070" --no-browser --no-default-folder > /dev/null &
fi

SRV_NTP=$(parse_ini "$CONFIG" "web" "ntp")
if [ "$SRV_NTP" -eq 1 ]; then
	NTP_POOL=$(parse_ini "$CONFIG" "clock" "pool")
	nice -2 ntpdate -b "$NTP_POOL" > /dev/null &
	NTP_PID=$!
	wait $NTP_PID
	hwclock --systohc
fi

