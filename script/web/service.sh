#!/bin/sh
# shellcheck disable=SC2086

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

GET_PIDS() {
	case "$MATCH_MODE" in
		x) pgrep -x "$MATCH_PAT" 2>/dev/null ;;
		f) pgrep -f "$MATCH_PAT" 2>/dev/null ;;
	esac
}

SOFT_KILL() {
	case "$MATCH_MODE" in
		x) pkill -TERM -x "$MATCH_PAT" >/dev/null 2>&1 ;;
		f) pkill -TERM -f "$MATCH_PAT" >/dev/null 2>&1 ;;
	esac
}

# Die!
HARD_KILL() {
	PIDS=$(GET_PIDS)
	[ -n "$PIDS" ] && kill -KILL $PIDS >/dev/null 2>&1
}

# Terminate any active ssh connections, hopefully also sftp connections too
STOP_SSHD_GRACEFUL() {
	pkill -TERM -f 'sshd:.*@' >/dev/null 2>&1
	sleep 0.2
	pkill -TERM -x sshd >/dev/null 2>&1
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
						/opt/openssh/sbin/sshd -D >/dev/null 2>&1 &
						;;
					sftpgo)
						/opt/sftpgo/sftpgo serve -c /opt/sftpgo >/dev/null 2>&1 &
						;;
					ttyd)
						/opt/muos/bin/ttyd \
							--port 8080 \
							--url-arg \
							--writable \
							/bin/sh -l >/dev/null 2>&1 &
						;;
					syncthing)
						[ ! -s /opt/muos/bin/syncthing ] && cp "/opt/muos/bin/syncthing.backup" "/opt/muos/bin/syncthing"
						/opt/muos/bin/syncthing serve \
							--home="$MUOS_STORE_DIR/syncthing" \
							--no-port-probing \
							--gui-address="0.0.0.0:7070" \
							--no-browser \
							--no-upgrade >/dev/null 2>&1 &
						;;
					tailscaled)
						/opt/muos/bin/tailscaled >/dev/null 2>&1 &
						;;
					*)
						printf "Unknown Web Service: %s\n" "$SRV" >&2
						return 1
						;;
				esac
			fi
			;;
		stop)
			TRY=30

			case "$SRV" in
				sshd) STOP_SSHD_GRACEFUL ;;
				*) SOFT_KILL ;;
			esac

			while PROC_EXISTS; do
				if [ "$TRY" -gt 0 ]; then
					case "$SRV" in
						sshd) STOP_SSHD_GRACEFUL ;;
						*) SOFT_KILL ;;
					esac
					TRY=$((TRY - 1))
				else
					# After a hard kill attempt, try not to loop forever...
					HARD_KILL
					break
				fi
				sleep 0.1
			done

			if PROC_EXISTS; then
				HARD_KILL
			fi
			;;
		*)
			printf "Usage: %s {start|stop|stopall}\n" "$0" >&2
			return 1
			;;
	esac
}

SERVICE_LIST="sshd sftpgo ttyd syncthing tailscaled"
case "$1" in
	stopall)
		for WEBSRV in $SERVICE_LIST; do
			MANAGE_WEBSERV stop "$WEBSRV"
		done
		;;
	*)
		for WEBSRV in $SERVICE_LIST; do
			if [ "$(GET_VAR "config" "web/$WEBSRV")" -eq 1 ]; then
				MANAGE_WEBSERV start "$WEBSRV" &
			else
				MANAGE_WEBSERV stop "$WEBSRV" &
			fi
		done

		wait >/dev/null 2>&1
		;;
esac

exit 0
