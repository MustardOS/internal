#!/bin/sh

. /opt/muos/script/var/func.sh

killall -q sshd sftpgo gotty syncthing ntp.sh

if [ "$(GET_VAR "global" "web/shell")" -eq 1 ]; then
	chmod -R 700 /opt/openssh/var /opt/openssh/etc
	nice -2 /opt/openssh/sbin/sshd >/dev/null &
fi

if [ "$(GET_VAR "global" "web/browser")" -eq 1 ]; then
	nice -2 /opt/sftpgo/sftpgo serve -c /opt/sftpgo >/dev/null &
fi

if [ "$(GET_VAR "global" "web/terminal")" -eq 1 ]; then
	nice -2 /opt/muos/bin/gotty \
		--config /opt/muos/config/gotty \
		--width 0 \
		--height 0 \
		/bin/sh >/dev/null &
fi

if [ "$(GET_VAR "global" "web/syncthing")" -eq 1 ]; then
	CURRENT_IP=$(cat "/opt/muos/config/address.txt")

	nice -2 /opt/muos/bin/syncthing serve \
		--home="$(GET_VAR "device" "storage/rom/mount")/MUOS/syncthing" \
		--skip-port-probing \
		--gui-address="0.0.0.0:7070" \
		--no-browser \
		--no-default-folder >/dev/null &
fi

if [ "$(GET_VAR "global" "web/resilio")" -eq 1 ]; then
	nice -2 /opt/muos/bin/rslsync --webui.listen 0.0.0.0:6060 >/dev/null &
fi

if [ "$(GET_VAR "global" "web/ntp")" -eq 1 ]; then
	nice -2 /opt/muos/script/web/ntp.sh &
fi
