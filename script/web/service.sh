#!/bin/sh

. /opt/muos/script/var/func.sh

SERVICE_MATCH() {
	SRV="$1"
	MATCH_MODE="x"
	MATCH_PAT="$SRV"

	case "$SRV" in
		sshd)
			if [ -x /opt/openssh/sbin/sshd ]; then
				MATCH_MODE="f"
				MATCH_PAT="/opt/openssh/sbin/sshd"
			else
				MATCH_MODE="x"
				MATCH_PAT="sshd"
			fi
			;;
		sftpgo)
			if [ -x /opt/sftpgo/sftpgo ]; then
				MATCH_MODE="f"
				MATCH_PAT="/opt/sftpgo/sftpgo"
			else
				MATCH_MODE="x"
				MATCH_PAT="sftpgo"
			fi
			;;
		ttyd)
			if [ -x /opt/muos/bin/ttyd ]; then
				MATCH_MODE="f"
				MATCH_PAT="/opt/muos/bin/ttyd"
			else
				MATCH_MODE="x"
				MATCH_PAT="ttyd"
			fi
			;;
		syncthing)
			if [ -x /opt/muos/bin/syncthing ]; then
				MATCH_MODE="f"
				MATCH_PAT="/opt/muos/bin/syncthing"
			else
				MATCH_MODE="x"
				MATCH_PAT="syncthing"
			fi
			;;
		ntp)
			if [ -x /opt/muos/script/web/ntp.sh ]; then
				MATCH_MODE="f"
				MATCH_PAT="/opt/muos/script/web/ntp.sh"
			else
				MATCH_MODE="x"
				MATCH_PAT="ntpd"
			fi
			;;
		tailscaled)
			if [ -x /opt/muos/bin/tailscaled ]; then
				MATCH_MODE="f"
				MATCH_PAT="/opt/muos/bin/tailscaled"
			else
				MATCH_MODE="x"
				MATCH_PAT="tailscaled"
			fi
			;;
	esac
}

PROC_EXISTS() {
	case "$MATCH_MODE" in
		x) pgrep -x "$MATCH_PAT" >/dev/null 2>&1 ;;
		f) pgrep -f "$MATCH_PAT" >/dev/null 2>&1 ;;
	esac
}

SOFT_KILL() {
	case "$MATCH_MODE" in
		x) pkill -TERM -x "$MATCH_PAT" >/dev/null 2>&1 || killall "$MATCH_PAT" >/dev/null 2>&1 ;;
		f) pkill -TERM -f "$MATCH_PAT" >/dev/null 2>&1 ;;
	esac
}

# Die!
HARD_KILL() {
	case "$MATCH_MODE" in
		x) PIDS=$(pgrep -x "$MATCH_PAT") ;;
		f) PIDS=$(pgrep -f "$MATCH_PAT") ;;
	esac

	# shellcheck disable=SC2086
	[ -n "$PIDS" ] && kill -KILL $PIDS 2>/dev/null
}

MANAGE_WEBSERV() {
	ACT="$1"
	SRV="$2"

	SERVICE_MATCH "$SRV"

	case "$ACT" in
		start)
			if ! PROC_EXISTS; then
				case "$SRV" in
					sshd)
						chmod -R 700 /opt/openssh/var /opt/openssh/etc
						nice -2 /opt/openssh/sbin/sshd >/dev/null 2>&1 &
						;;
					sftpgo)
						nice -2 /opt/sftpgo/sftpgo serve -c /opt/sftpgo >/dev/null 2>&1 &
						;;
					ttyd)
						nice -2 /opt/muos/bin/ttyd \
							--port 8080 \
							--url-arg \
							--writable \
							/bin/sh -l >/dev/null 2>&1 &
						;;
					syncthing)
						[ ! -s /opt/muos/bin/syncthing ] && cp "/opt/muos/bin/syncthing.backup" "/opt/muos/bin/syncthing"
						nice -2 /opt/muos/bin/syncthing serve \
							--home="$MUOS_STORE_DIR/syncthing" \
							--no-port-probing \
							--gui-address="0.0.0.0:7070" \
							--no-browser \
							--no-upgrade >/dev/null 2>&1 &
						;;
					ntp)
						nice -2 /opt/muos/script/web/ntp.sh >/dev/null 2>&1 &
						;;
					tailscaled)
						nice -2 /opt/muos/bin/tailscaled >/dev/null 2>&1 &
						;;
					*)
						printf "Unknown Web Service: %s\n" "$SRV" >&2
						;;
				esac
			fi
			;;
		stop)
			SOFT_TRIES=30
			while PROC_EXISTS; do
				if [ "$SOFT_TRIES" -gt 0 ]; then
					SOFT_KILL
					SOFT_TRIES=$((SOFT_TRIES - 1))
				else
					HARD_KILL
				fi
				TBOX sleep 0.1
			done
			;;
	esac
}

SERVICE_LIST="sshd sftpgo ttyd syncthing ntp tailscaled"
for WEBSRV in $SERVICE_LIST; do
	if [ ! "$1" = "stopall" ] && [ "$(GET_VAR "config" "web/$WEBSRV")" -eq 1 ]; then
		MANAGE_WEBSERV start "$WEBSRV" &
	else
		MANAGE_WEBSERV stop "$WEBSRV" &
	fi
done &
