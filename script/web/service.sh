#!/bin/sh
# shellcheck disable=1090,2002

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

NETADDR=$(cat "/opt/muos/config/address.txt")

killall sshd
killall sftpgo
killall gotty
killall syncthing

SRV_SHELL=$(parse_ini "$CONFIG" "web" "shell")
if [ "$SRV_SHELL" -eq 1 ]; then
	nice -2 /opt/openssh/sbin/sshd > /dev/null &
fi

SRV_BROWSER=$(parse_ini "$CONFIG" "web" "browser")
if [ "$SRV_BROWSER" -eq 1 ]; then
	nice -2 /opt/sftpgo/sftpgo serve -c /opt/sftpgo > /dev/null &
fi

SRV_TERMINAL=$(parse_ini "$CONFIG" "web" "terminal")
if [ "$SRV_TERMINAL" -eq 1 ]; then
	nice -2 /opt/muos/app/gotty --config /opt/muos/app/gotty-config --width 0 --height 0 /bin/sh > /dev/null &
fi

SRV_SYNCTHING=$(parse_ini "$CONFIG" "web" "syncthing")
if [ "$SRV_SYNCTHING" -eq 1 ]; then
	nice -2 /opt/muos/app/syncthing serve --home="/mnt/mmc/MUOS/syncthing" --skip-port-probing --gui-address="$NETADDR:7070" --no-browser --no-default-folder > /dev/null &
fi

SRV_NTP=$(parse_ini "$CONFIG" "web" "ntp")
if [ "$SRV_NTP" -eq 1 ]; then
	NTP_POOL=$(parse_ini "$CONFIG" "clock" "pool")
	nice -2 ntpdate -b "$NTP_POOL" > /dev/null &
fi

