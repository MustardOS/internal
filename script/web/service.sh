#!/bin/sh

. /opt/muos/script/var/func.sh

MANAGE_WEBSERV() {
	ACT=$1
	SRV=$2
	PID=$(pgrep "$SRV")

	case "$ACT" in
		"start")
			if [ -z "$PID" ]; then
				case "$SRV" in
					"shell")
						chmod -R 700 /opt/openssh/var /opt/openssh/etc
						nice -2 /opt/openssh/sbin/sshd >/dev/null &
						;;
					"browser")
						nice -2 /opt/sftpgo/sftpgo serve -c \
							/opt/sftpgo >/dev/null &
						;;
					"terminal")
						nice -2 /opt/muos/bin/gotty \
							--config /opt/muos/config/gotty \
							--width 0 \
							--height 0 \
							/bin/sh >/dev/null &
						;;
					"syncthing")
						nice -2 /opt/muos/bin/syncthing serve \
							--home=/run/muos/storage/syncthing \
							--skip-port-probing \
							--gui-address="0.0.0.0:7070" \
							--no-browser \
							--no-default-folder >/dev/null &
						;;
					"resilio")
						nice -2 /opt/muos/bin/rslsync \
							--webui.listen 0.0.0.0:6060 >/dev/null &
						;;
					"ntp")
						nice -2 /opt/muos/script/web/ntp.sh &
						;;
					*)
						echo "Unknown Web Service: $SRV"
						;;
				esac
			fi
			;;
		"stop")
			if [ -n "$PID" ]; then
				kill "$PID"
			fi
			;;
	esac
}

for WEBSRV in shell browser terminal syncthing resilio ntp; do
	if [ "$(GET_VAR "global" "network/enabled")" -eq 1 ] && [ "$(GET_VAR "global" "web/$WEBSRV")" -eq 1 ]; then
		MANAGE_WEBSERV start "$WEBSRV" &
	else
		MANAGE_WEBSERV stop "$WEBSRV" &
	fi
done &
