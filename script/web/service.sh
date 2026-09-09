#!/bin/sh

. /opt/muos/script/var/func.sh

PROCESS_HELPER="/opt/muos/script/var/process.sh"
LANDING_STATUS="/opt/muos/script/web/status.sh"
LANDING_BIN="/opt/muos/frontend/muweb"
LANDING_SECRET="$MUOS_CONF_SYSTEM/landing_secret"

SERVICE_PROCESS_NAME() {
	case "$1" in
		mdns | landing | sshd | sftpgo | ttyd | syncthing | tailscaled) printf 'web-%s\n' "$1" ;;
		*) return 1 ;;
	esac
}

VALID_LOCAL_NAME() {
	case "$1" in
		"" | -* | *- | *[!A-Za-z0-9-]*) return 1 ;;
	esac
	[ "${#1}" -le 63 ]
}

BOOL_WEB_SETTING() {
	[ "$(GET_VAR "config" "web/$1")" = "1" ] && printf true || printf false
}

# The dashboard should look like the device it is showing, so the active theme's palette
# is read out of its scheme and handed to the page. Only the handful of colours the page
# actually needs are taken; everything else it derives from them.
#
# A theme has a default scheme and, when active.txt names one, an alternate that overrides
# part of it. The alternate is rarely complete: muOS.ini restyles the background and the
# accent but says nothing about the list text, which still comes from the default. So both
# are read, in that order, and the later value wins key by key.
THEME_PALETTE() {
	TP_ACTIVE=$(GET_VAR "config" "theme/active")
	[ -n "$TP_ACTIVE" ] || TP_ACTIVE="MustardOS"
	TP_DIR="$MUOS_STORE_DIR/theme/$TP_ACTIVE"

	# A theme keeps a palette at its root and one per screen size; either will do, since
	# the colours are the same and only the metrics differ.
	TP_INI="$TP_DIR/scheme/global.ini"
	[ -r "$TP_INI" ] || TP_INI=$(find "$TP_DIR" -name global.ini -path '*/scheme/*' 2>/dev/null | head -n 1)
	[ -n "$TP_INI" ] && [ -r "$TP_INI" ] || return 1

	TP_ALT=""
	if [ -r "$TP_DIR/active.txt" ]; then
		IFS= read -r TP_NAME <"$TP_DIR/active.txt"
		TP_NAME=${TP_NAME%"$(printf '\r')"}
		[ -n "$TP_NAME" ] &&
			TP_ALT=$(find "$TP_DIR/alternate" -maxdepth 1 -iname "$TP_NAME.ini" 2>/dev/null | head -n 1)
	fi

	awk -F' *= *' '
		FNR == 1 { section = "" }
		/^\[/ { section = $0; next }
		$2 ~ /^[0-9A-Fa-f]{6}$/ { colour[section "|" $1] = $2 }
		END {
			want["[background]|BACKGROUND"] = "background"
			want["[background]|BACKGROUND_GRADIENT_COLOR"] = "shade"
			want["[grid]|CELL_DEFAULT_TEXT"] = "text"
			want["[grid]|CELL_FOCUS_BACKGROUND"] = "accent"
			want["[header]|HEADER_TEXT"] = "heading"
			want["[battery]|BATTERY_LOW"] = "warn"
			want["[battery]|BATTERY_ACTIVE"] = "good"

			for (key in want)
				if (key in colour) printf "        %s: \"#%s\",\n", want[key], colour[key]
		}
	' "$TP_INI" $TP_ALT
}

PREPARE_LANDING_ROOT() {
	LANDING_ROOT="$MUOS_RUN_DIR/landing"
	LANDING_SOURCE=/opt/muos/share/web
	[ -d "$LANDING_SOURCE" ] || return 1
	mkdir -p "$LANDING_ROOT/js" "$LANDING_ROOT/css" || return 1

	cp -f "$LANDING_SOURCE"/index.html "$LANDING_SOURCE"/logo.svg "$LANDING_ROOT"/ || return 1
	cp -f "$LANDING_SOURCE"/css/dashboard.css "$LANDING_ROOT/css"/ || return 1

	for LANDING_PART in core theme dialog session view dashboard crop catalogue pickles boot; do
		cp -f "$LANDING_SOURCE/js/$LANDING_PART.js" "$LANDING_ROOT/js"/ || return 1
	done

	mkdir -p "$LANDING_ROOT/state" || return 1
	"$LANDING_STATUS" once || LOG_WARN "$0" 0 "WEB" "Web Dashboard could not gather its first reading"

	MDNS_NAME=$(GET_VAR "config" "web/mdns_name")
	VALID_LOCAL_NAME "$MDNS_NAME" || MDNS_NAME=muos
	LOCAL_NAME=
	[ "$(GET_VAR "config" "web/mdns")" = "1" ] && LOCAL_NAME="$MDNS_NAME.local"
	LANDING_RUNTIME=$(mktemp "$LANDING_ROOT/js/.runtime.XXXXXX") || return 1

	{
		printf 'window.MUOS_RUNTIME = {\n'
		printf '    localName: "%s",\n' "$LOCAL_NAME"
		printf '    theme: {\n'
		THEME_PALETTE
		printf '    },\n'
		printf '    services: {\n'
		printf '        sftpgo: {enabled: %s, port: %s},\n' \
			"$(BOOL_WEB_SETTING sftpgo)" "$(GET_WEB_PORT "sftpgo_port" 9090)"
		printf '        syncthing: {enabled: %s, port: %s},\n' \
			"$(BOOL_WEB_SETTING syncthing)" "$(GET_WEB_PORT "syncthing_port" 7070)"
		printf '        ttyd: {enabled: %s, port: %s},\n' \
			"$(BOOL_WEB_SETTING ttyd)" "$(GET_WEB_PORT "ttyd_port" 8080)"
		printf '        sshd: {enabled: %s, port: %s}\n' \
			"$(BOOL_WEB_SETTING sshd)" "$(GET_WEB_PORT "sshd_port" 22)"
		printf '    }\n};\n'
	} >"$LANDING_RUNTIME" || {
		rm -f "$LANDING_RUNTIME"
		return 1
	}

	chmod 0644 "$LANDING_RUNTIME"
	mv -f "$LANDING_RUNTIME" "$LANDING_ROOT/js/runtime.js"
}

START_MDNS() {
	MUDNS_BIN=/opt/muos/frontend/mudns
	[ -x "$MUDNS_BIN" ] || {
		LOG_ERROR "$0" 0 "WEB" "Local DNS helper is unavailable"
		return 1
	}

	MDNS_NAME=$(GET_VAR "config" "web/mdns_name")
	VALID_LOCAL_NAME "$MDNS_NAME" || MDNS_NAME=muos
	set -- "$MUDNS_BIN" --hostname "$MDNS_NAME"

	if [ "$(GET_VAR "config" "web/landing")" = "1" ]; then
		set -- "$@" --service "_http._tcp:$(GET_WEB_PORT "landing_port" 80):MustardOS"
	fi

	if [ "$(GET_VAR "config" "web/sftpgo")" = "1" ]; then
		set -- "$@" --service "_http._tcp:$(GET_WEB_PORT "sftpgo_port" 9090):MustardOS Files"
		set -- "$@" --service "_sftp-ssh._tcp:$(GET_WEB_PORT "sftpgo_sftp_port" 2022):MustardOS SFTP"
	fi

	if [ "$(GET_VAR "config" "web/ttyd")" = "1" ]; then
		set -- "$@" --service "_http._tcp:$(GET_WEB_PORT "ttyd_port" 8080):MustardOS Terminal"
	fi

	if [ "$(GET_VAR "config" "web/syncthing")" = "1" ]; then
		set -- "$@" --service "_http._tcp:$(GET_WEB_PORT "syncthing_port" 7070):MustardOS Syncthing"
	fi

	if [ "$(GET_VAR "config" "web/sshd")" = "1" ]; then
		set -- "$@" --service "_ssh._tcp:$(GET_WEB_PORT "sshd_port" 22):MustardOS SSH"
	fi

	"$PROCESS_HELPER" start web-mdns "$@"
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
				mdns) START_MDNS ;;
				landing)
					[ -x "$LANDING_BIN" ] || {
						LOG_ERROR "$0" 0 "WEB" "Web Dashboard server is unavailable"
						return 1
					}
					PREPARE_LANDING_ROOT || {
						LOG_ERROR "$0" 0 "WEB" "Web Dashboard files could not be prepared"
						return 1
					}
					LANDING_PORT=$(GET_WEB_PORT "landing_port" 80)

					# Both trees are made on demand elsewhere, so make sure they exist before
					# the server resolves them, otherwise a fresh device has nothing to open.
					LANDING_CATALOGUE="$MUOS_STORE_DIR/info/catalogue"
					LANDING_PICKLES="$MUOS_STORE_DIR/save/pickles"
					mkdir -p "$LANDING_CATALOGUE" "$LANDING_PICKLES"

					set -- "$LANDING_BIN" --root "$LANDING_ROOT" --port "$LANDING_PORT" \
						--catalogue "$LANDING_CATALOGUE" --pickles "$LANDING_PICKLES"

					# A catalogue folder is named after a system, and a system is not content:
					# on its own it can only report the artwork somebody already put there.
					# Given the assign map and the card, the dashboard can list the content
					# each catalogue is actually responsible for, and so say what is missing.
					LANDING_INFO="$MUOS_SHARE_DIR/info"
					[ -r "$LANDING_INFO/assign/assign.json" ] && set -- "$@" --info "$LANDING_INFO"

					# Only the ROMS directory of each storage root: the rest of a card holds
					# BIOS files, ports, muOS itself and whatever else has been copied on, and
					# none of that is content the catalogue is responsible for. The device's
					# own mount comes first so it is still covered when it is not one of the
					# three standard ones.
					LANDING_SEEN=""
					for LANDING_MOUNT in "$(GET_VAR "device" "storage/rom/mount")" /mnt/mmc /mnt/sdcard /mnt/usb; do
						[ -n "$LANDING_MOUNT" ] || continue

						LANDING_ROMS="$LANDING_MOUNT/ROMS"
						[ -d "$LANDING_ROMS" ] || continue

						# The device mount is usually /mnt/mmc as well, so do not pass it twice.
						case " $LANDING_SEEN " in
							*" $LANDING_ROMS "*) continue ;;
						esac

						LANDING_SEEN="$LANDING_SEEN $LANDING_ROMS"
						set -- "$@" --content "$LANDING_ROMS"
					done

					# Browsing and downloading are always available. Authentication is what
					# unlocks changing anything, and every change then wants the rolling code
					# the device is showing, so two handhelds on one network cannot touch each
					# other by accident. Without it the dashboard stays strictly read only.
					if [ "$(GET_VAR "config" "web/landing_auth")" = "0" ]; then
						set -- "$@" --readonly
					else
						set -- "$@" --secret "$LANDING_SECRET"
					fi

					"$PROCESS_HELPER" start "$PROCESS_NAME" "$@" || return 1

					"$PROCESS_HELPER" start web-landstat "$LANDING_STATUS" watch ||
						LOG_ERROR "$0" 0 "WEB" "Web Dashboard readings are unavailable"
					;;
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
				landing)
					"$PROCESS_HELPER" stop-group web-landstat
					"$PROCESS_HELPER" stop-group "$PROCESS_NAME"
					;;
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

SERVICE_LIST="mdns landing sshd sftpgo ttyd syncthing tailscaled"
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

		if [ "$2" != "mdns" ] && [ "$(GET_VAR "config" "web/mdns")" = "1" ]; then
			MANAGE_WEBSERV stop mdns
			MANAGE_WEBSERV start mdns || LOG_ERROR "$0" 0 "WEB" "Failed to refresh Local DNS advertisements"
		fi

		if [ "$2" != "landing" ] && [ "$(GET_VAR "config" "web/landing")" = "1" ]; then
			MANAGE_WEBSERV stop landing
			MANAGE_WEBSERV start landing || LOG_ERROR "$0" 0 "WEB" "Failed to refresh Web Dashboard links"
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
