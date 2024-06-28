#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

. /opt/muos/script/var/global/web_service.sh

killall -q sshd sftpgo gotty syncthing ntp.sh

if [ "$GC_WEB_SHELL" -eq 1 ]; then
	chmod -R 700 /opt/openssh/var /opt/openssh/etc
	nice -2 /opt/openssh/sbin/sshd >/dev/null &
fi

if [ "$GC_WEB_BROWSER" -eq 1 ]; then
	nice -2 /opt/sftpgo/sftpgo serve -c /opt/sftpgo >/dev/null &
fi

if [ "$GC_WEB_TERMINAL" -eq 1 ]; then
	nice -2 /opt/muos/bin/gotty \
		--config /opt/muos/config/gotty \
		--width 0 \
		--height 0 \
		/bin/sh >/dev/null &
fi

if [ "$GC_WEB_SYNCTHING" -eq 1 ]; then
	CURRENT_IP=$(cat "/opt/muos/config/address.txt")

	nice -2 /opt/muos/bin/syncthing serve \
		--home="$DC_STO_ROM_MOUNT/MUOS/syncthing" \
		--skip-port-probing \
		--gui-address="$CURRENT_IP:7070" \
		--no-browser \
		--no-default-folder >/dev/null &
fi

if [ "$GC_WEB_NTP" -eq 1 ]; then
	nice -2 /opt/muos/script/web/ntp.sh &
fi
