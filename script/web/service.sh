#!/bin/sh

. /opt/muos/script/var/func.sh

PROCESS_HELPER="/opt/muos/script/var/process.sh"

SERVICE_PROCESS_NAME() {
	case "$1" in
		sshd | sftpgo | ttyd | syncthing | tailscaled) printf 'web-%s\n' "$1" ;;
		*) return 1 ;;
	esac
}

MANAGE_WEBSERV() {
	ACT="$1"
	SRV="$2"
	PROCESS_NAME=$(SERVICE_PROCESS_NAME "$SRV") || {
		printf "Unknown Web Service: %s\n" "$SRV" >&2
		return 1
	}

	case "$ACT" in
		start)
			"$PROCESS_HELPER" status "$PROCESS_NAME" && return 0
			case "$SRV" in
				sshd)
					SSHD_PORT=$(GET_WEB_PORT "sshd_port" 22)
					SSHD_ETC=/etc/ssh
					SSHD_EMPTY=/var/empty

					if [ -x /opt/openssh/sbin/sshd ]; then
						SSHD_BIN=/opt/openssh/sbin/sshd
						SSHD_ETC=/opt/openssh/etc
						SSHD_EMPTY=/opt/openssh/var/empty
					elif [ -x /usr/sbin/sshd ]; then
						SSHD_BIN=/usr/sbin/sshd
					else
						SSHD_BIN=sshd
					fi

					mkdir -p "$SSHD_EMPTY"
					chown root:root /root "$SSHD_ETC" "$SSHD_EMPTY"
					chmod 700 /root "$SSHD_ETC" "$SSHD_EMPTY"
					chown root:root "$SSHD_ETC"/ssh_host_*_key
					chmod 600 "$SSHD_ETC"/ssh_host_*_key

					SSHD_CHECK=$("$SSHD_BIN" -t 2>&1) || {
						LOG_ERROR "$0" 0 "WEB" "$(printf "OpenSSH refused to start: %s" "$SSHD_CHECK")"
						return 1
					}

					"$PROCESS_HELPER" start "$PROCESS_NAME" "$SSHD_BIN" -D -p "$SSHD_PORT"
					;;
				sftpgo)
					chmod 755 "/opt/sftpgo"
					SFTPGO_PORT=$(GET_WEB_PORT "sftpgo_port" 9090)
					SFTPGO_SFTP_PORT=$(GET_WEB_PORT "sftpgo_sftp_port" 2022)
					"$PROCESS_HELPER" start "$PROCESS_NAME" env \
						"SFTPGO_HTTPD__BINDINGS__0__PORT=$SFTPGO_PORT" \
						"SFTPGO_SFTPD__BINDINGS__0__PORT=$SFTPGO_SFTP_PORT" \
						/opt/sftpgo/sftpgo serve -c /opt/sftpgo
					;;
				ttyd)
					TTYD_USER=$(GET_VAR "config" "web/ttyd_user")
					TTYD_PASS=$(GET_VAR "config" "web/ttyd_pass")
					TTYD_PORT=$(GET_WEB_PORT "ttyd_port" 8080)
					TTYD_IFACE=$(GET_VAR "device" "network/iface_active")
					[ -n "$TTYD_IFACE" ] || TTYD_IFACE=$(GET_VAR "device" "network/iface")
					TTYD_BIND=$(ip -4 -o addr show dev "$TTYD_IFACE" 2>/dev/null | awk 'NR==1 {sub(/\/.*/, "", $4); print $4}')

					if { [ -n "$TTYD_USER" ] && [ -z "$TTYD_PASS" ]; } || { [ -z "$TTYD_USER" ] && [ -n "$TTYD_PASS" ]; }; then
						LOG_ERROR "$0" 0 "WEB" "Virtual terminal login details are incomplete"
						return 1
					fi
					if [ -n "$TTYD_USER" ]; then
						case "$TTYD_USER" in
							*[!A-Za-z0-9_-]*)
								LOG_ERROR "$0" 0 "WEB" "Virtual terminal login name contains an unsupported character"
								return 1
								;;
						esac
						if [ "${#TTYD_USER}" -gt 32 ] || [ "${#TTYD_PASS}" -gt 128 ]; then
							LOG_ERROR "$0" 0 "WEB" "Virtual terminal login details are too long"
							return 1
						fi
						case "$TTYD_PASS" in
							*:*)
								LOG_ERROR "$0" 0 "WEB" "Virtual terminal password contains an unsupported character"
								return 1
								;;
						esac
					fi
					[ -n "$TTYD_BIND" ] || {
						LOG_ERROR "$0" 0 "WEB" "Virtual terminal could not find an active IPv4 interface"
						return 1
					}

					if [ -n "$TTYD_USER" ]; then
						"$PROCESS_HELPER" start "$PROCESS_NAME" /opt/muos/bin/ttyd \
							--interface "$TTYD_BIND" \
							--port "$TTYD_PORT" \
							--credential "$TTYD_USER:$TTYD_PASS" \
							--url-arg \
							--writable \
							/bin/sh -l
					else
						"$PROCESS_HELPER" start "$PROCESS_NAME" /opt/muos/bin/ttyd \
							--interface "$TTYD_BIND" \
							--port "$TTYD_PORT" \
							--url-arg \
							--writable \
							/bin/sh -l
					fi
					;;
				syncthing)
					SYNCTHING_PORT=$(GET_WEB_PORT "syncthing_port" 7070)
					[ ! -s /opt/muos/bin/syncthing ] && cp "/opt/muos/bin/syncthing.backup" "/opt/muos/bin/syncthing"
					"$PROCESS_HELPER" start "$PROCESS_NAME" /opt/muos/bin/syncthing serve \
						--home="$MUOS_STORE_DIR/syncthing" \
						--no-port-probing \
						--gui-address="0.0.0.0:$SYNCTHING_PORT" \
						--no-browser \
						--no-upgrade
					;;
				tailscaled) /opt/muos/script/web/tailscale.sh start ;;
			esac
			;;
		stop)
			case "$SRV" in
				tailscaled) /opt/muos/script/web/tailscale.sh stop ;;
				syncthing)
					TERMINATE_SYNCTHING
					"$PROCESS_HELPER" stop-group "$PROCESS_NAME"
					;;
				*) "$PROCESS_HELPER" stop-group "$PROCESS_NAME" ;;
			esac
			;;
		*)
			printf "Usage: %s {start|stop}\n" "$0" >&2
			return 1
			;;
	esac
}

SERVICE_LIST="sshd sftpgo ttyd syncthing tailscaled"
case "$1" in
	apply)
		SERVICE_PROCESS_NAME "$2" >/dev/null || exit 1
		MANAGE_WEBSERV stop "$2" || exit 1
		if [ "$(GET_VAR "config" "web/$2")" = "1" ]; then
			MANAGE_WEBSERV start "$2" || {
				LOG_ERROR "$0" 0 "WEB" "$(printf "Failed to start '%s' web service" "$2")"
				exit 1
			}
		fi
		;;
	stopall)
		for WEBSRV in $SERVICE_LIST; do
			MANAGE_WEBSERV stop "$WEBSRV"
		done
		;;
	*)
		for WEBSRV in $SERVICE_LIST; do
			if [ "$(GET_VAR "config" "web/$WEBSRV")" = "1" ]; then
				MANAGE_WEBSERV start "$WEBSRV" ||
					LOG_ERROR "$0" 0 "WEB" "$(printf "Failed to start '%s' web service" "$WEBSRV")" &
			else
				MANAGE_WEBSERV stop "$WEBSRV" &
			fi
		done

		wait
		;;
esac

exit 0
