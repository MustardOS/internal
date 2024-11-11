#!/bin/sh

. /opt/muos/script/var/func.sh

MANAGE_WEBSERV() {
	ACT=$1
	SRV=$2
	PID=$(pgrep "$SRV")

	case "$ACT" in
		"start")
			[ -z "$PID" ] && case "$SRV" in
				"sshd")
					chmod -R 700 /opt/openssh/var /opt/openssh/etc
					nice -2 /opt/openssh/sbin/sshd >/dev/null &
					;;
				"sftpgo")
					nice -2 /opt/sftpgo/sftpgo serve -c \
						/opt/sftpgo >/dev/null &
					;;
				"ttyd")
					nice -2 /opt/muos/bin/ttyd \
						--port 8080 \
						--url-arg \
						--writable \
						/bin/sh >/dev/null &
					;;
				"syncthing")
					[ ! -s /opt/muos/bin/syncthing ] && cp /opt/muos/bin/syncthing.backup /opt/muos/bin/syncthing
					nice -2 /opt/muos/bin/syncthing serve \
						--home=/run/muos/storage/syncthing \
						--skip-port-probing \
						--gui-address="0.0.0.0:7070" \
						--no-browser \
						--no-default-folder >/dev/null &
					;;
				"rslsync")
					nice -2 /opt/muos/bin/rslsync \
						--webui.listen 0.0.0.0:6060 >/dev/null &
					;;
				"ntp")
					nice -2 /opt/muos/script/web/ntp.sh &
					;;
				"tailscaled")
					nice -2 /opt/muos/bin/tailscaled >/dev/null &
					;;
				*)
					echo "Unknown Web Service: $SRV"
					;;
			esac
			;;
		"stop")
			[ -n "$PID" ] && kill "$PID"
			;;
	esac
}

for WEBSRV in sshd sftpgo ttyd syncthing rslsync ntp tailscaled; do
	if [ "$(GET_VAR "global" "network/enabled")" -eq 1 ] && [ "$(GET_VAR "global" "web/$WEBSRV")" -eq 1 ]; then
		TIMEOUT=30
		WAIT=0

		while ! ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; do
			if [ "$WAIT" -ge "$TIMEOUT" ]; then
				LOG_ERROR "$0" 0 "WEB SERVICES" "Network connection timed out after %d seconds" "$TIMEOUT"
				break
			fi

			WAIT=$((WAIT + 1))
			LOG_INFO "$0" 0 "WEB SERVICES" "Waiting for network connection... (%d)" "$WAIT"
			sleep 1
		done

		MANAGE_WEBSERV start "$WEBSRV" &
	else
		MANAGE_WEBSERV stop "$WEBSRV" &
	fi
done &
