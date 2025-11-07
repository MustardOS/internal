#!/bin/sh

. /opt/muos/script/var/func.sh

BOOT_CONSOLE_MODE="$(GET_VAR "config" "boot/device_mode")"
HDMI_INTERNAL_AUDIO=$(GET_VAR "config" "settings/hdmi/audio")
PF_INTERNAL="$(GET_VAR "device" "audio/pf_internal")"
PF_EXTERNAL="$(GET_VAR "device" "audio/pf_external")"
GEN_VOL="$(GET_VAR "config" "settings/general/volume")"
ADV_VOL="$(GET_VAR "config" "settings/advanced/volume")"
ADV_OD="$(GET_VAR "config" "settings/advanced/overdrive")"
MAX_VOL="$(GET_VAR "device" "audio/max")"
READY="$(GET_VAR "device" "audio/ready")"

DBUS_SOCKET="/run/dbus/system_bus_socket"

PROC_GONE_TIMEOUT_MS=2000

RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/run/pipewire-0}}"
RUNTIME_SOCK="$RUNTIME_DIR/pipewire-0"

RUNTIME_INIT() {
	ln -sf "$MUOS_SHARE_DIR/conf/wireplumber.lua" "/usr/share/wireplumber/main.lua.d/60-muos-wireplumber.lua"
}

SOCKET_READY() {
	[ -S "$RUNTIME_SOCK" ] || return 1
	pw-cli info >/dev/null 2>&1 || return 1
	return 0
}

PROC_GONE() {
	NAME=$1
	LIMIT_MS=${2:-$PROC_GONE_TIMEOUT_MS}
	ELAPSED=0

	while pgrep -x "$NAME" >/dev/null 2>&1; do
		TBOX sleep 0.05
		ELAPSED=$((ELAPSED + 50))
		[ "$ELAPSED" -ge "$LIMIT_MS" ] && return 1
	done

	return 0
}

GET_NODE_ID() {
	PATTERN=$1
	ID=
	MEDIA=
	NAME=

	# What an absolute fucking pain in the arse, this is up there with network
	# with what I believe is the worst possible method to get a stupid Node ID
	pw-cli list-objects Node 2>/dev/null | {
		while IFS= read -r LINE; do
			case $LINE in
				[[:space:]]id\ [0-9]*,*)
					ID=$(printf '%s\n' "$LINE" | awk '{print $2}' | tr -d ',')
					MEDIA=
					NAME=
					;;
				*"media.class ="*)
					MEDIA=$(printf '%s\n' "$LINE" | sed 's/.*= "//; s/".*//')
					;;
				*"node.name ="*)
					NAME=$(printf '%s\n' "$LINE" | sed 's/.*= "//; s/".*//')
					;;
			esac

			if [ -n "$ID" ] && [ -n "$MEDIA" ] && [ -n "$NAME" ]; then
				if [ "$MEDIA" = "Audio/Sink" ] &&
					printf '%s\n' "$NAME" | grep -iq "$PATTERN"; then
					printf '%s\n' "$ID"
					break
				fi
				MEDIA=
				NAME=
			fi
		done
	}
}

GET_DEFAULT_SINK() {
	wpctl status 2>/dev/null | awk -F': ' '/Default Sink:/ {print $2; exit}'
}

SET_DEFAULT_SINK() {
	C_SINK=$(GET_DEFAULT_SINK)
	[ -n "$C_SINK" ] && [ "$C_SINK" = "$1" ] && return 0

	wpctl set-default "$1" >/dev/null 2>&1
}

GET_VOLUME() {
	wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '
		{ for (i=1;i<=NF;i++) if ($i ~ /^[0-9.]+$/) { v=$i; break } }
		END { if (v=="") exit; printf "%d\n", int(v*100+0.5) }
	'
}

SET_VOLUME() {
	C_SINK=$(GET_VOLUME)
	[ -n "$C_SINK" ] && [ "$C_SINK" -eq "$1" ] && return 0

	wpctl set-volume @DEFAULT_AUDIO_SINK@ "$1"% >/dev/null 2>&1
}

FADE_DOWN() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Fading sink volume down..."

	N=0
	while [ "$N" -lt 8 ]; do
		wpctl set-volume @DEFAULT_AUDIO_SINK@ 16%- >/dev/null 2>&1 || break
		TBOX sleep 0.05
		N=$((N + 1))
	done

	wpctl set-volume @DEFAULT_AUDIO_SINK@ 0% >/dev/null 2>&1
	wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 >/dev/null 2>&1
}

STOP_AUDIO_STACK() {
	for PROC in pipewire wireplumber; do
		killall -q -15 "$PROC" 2>/dev/null
		PROC_GONE "$PROC" "$PROC_GONE_TIMEOUT_MS" || killall -q -9 "$PROC" 2>/dev/null
	done
}

REQUIRE_DBUS() {
	ELAPSED=0

	while [ ! -S "$DBUS_SOCKET" ]; do
		TBOX sleep 0.1
		ELAPSED=$((ELAPSED + 100))
		[ "$ELAPSED" -ge 3000 ] && break
	done

	if [ -S "$DBUS_SOCKET" ]; then
		LOG_SUCCESS "$0" 0 "PIPEWIRE" "D-Bus socket is available"
	else
		LOG_WARN "$0" 0 "PIPEWIRE" "D-Bus not ready after 3s; proceeding"
	fi

	return 0
}

DO_PRESTART() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Restoring Default Sound System"
	cp -f "$MUOS_SHARE_DIR/conf/asound.conf" "/etc/asound.conf"

	LOG_INFO "$0" 0 "PIPEWIRE" "ALSA Config Restoring"
	cp -f "$MUOS_SHARE_DIR/conf/alsa.conf" "/usr/share/alsa/alsa.conf"

	LOG_INFO "$0" 0 "PIPEWIRE" "Restoring Audio State"
	alsactl -U -f "/opt/muos/device/control/asound.state" restore
}

FINALISE_AUDIO() {
	export XDG_RUNTIME_DIR="$RUNTIME_DIR"

	ELAPSED=0
	while ! pw-cli ls Node 2>/dev/null | grep -q "Audio/Sink"; do
		TBOX sleep 0.1
	done

	INT_ID=$(GET_NODE_ID "$PF_INTERNAL")
	EXT_ID=$(GET_NODE_ID "$PF_EXTERNAL")

	if [ "$BOOT_CONSOLE_MODE" -eq 1 ]; then
		DEF_ID="$EXT_ID"
		[ "$HDMI_INTERNAL_AUDIO" -eq 1 ] && DEF_ID="$INT_ID"
	else
		DEF_ID="$INT_ID"
	fi

	if [ -z "$DEF_ID" ]; then
		SET_VAR "device" "audio/ready" "1"
		return 1
	fi

	CS=$(wpctl status 2>/dev/null | awk -F': ' '/Default Sink:/ {print $2; exit}')

	if [ "$CS" != "$DEF_ID" ] && [ -n "$DEF_ID" ]; then
		wpctl set-default "$DEF_ID" >/dev/null 2>&1
	fi

	case "$ADV_VOL" in
		loud) V="$MAX_VOL" ;;
		soft) V=35 ;;
		silent) V=0 ;;
		*) V="$GEN_VOL" ;;
	esac

	if [ "$BOOT_CONSOLE_MODE" -eq 1 ]; then
		if [ "${ADV_OD:-0}" -eq 1 ]; then V=200; else V=100; fi
	fi

	CURR_VOL=$(
		wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null |
			awk '{for(i=1;i<=NF;i++) if($i~/^[0-9.]+$/){v=$i;break}} END{if(v!="") printf "%d\n", int(v*100+0.5)}'
	)

	if [ -z "$CURR_VOL" ] || [ "$CURR_VOL" -ne "$V" ]; then
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "$V"% >/dev/null 2>&1
	fi

	wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1
	SET_VAR "device" "audio/ready" "1"

	LOG_SUCCESS "$0" 0 "PIPEWIRE" "$(printf "Audio Finalised (node=%s, vol=%s%%)" "$DEF_ID" "$V")"
	return 0
}

START_PIPEWIRE() {
	RUNTIME_INIT

	if ! pgrep -x "pipewire" >/dev/null 2>&1; then
		LOG_INFO "$0" 0 "PIPEWIRE" "$(printf "Starting PipeWire (runtime: %s)" "$RUNTIME_DIR")"
		chrt -f 88 pipewire -c "$MUOS_SHARE_DIR/conf/pipewire.conf" &
	else
		LOG_WARN "$0" 0 "PIPEWIRE" "PipeWire already running"
	fi

	if ! pgrep -x "wireplumber" >/dev/null 2>&1; then
		LOG_INFO "$0" 0 "PIPEWIRE" "Starting WirePlumber..."
		wireplumber &
	fi

	return 0
}

DO_START() {
	if ! START_PIPEWIRE; then
		LOG_ERROR "$0" 0 "PIPEWIRE" "Failed to start"
		exit 1
	fi

	RESET_AMIXER

	(DO_PRESTART) &
	REQUIRE_DBUS &

	(FINALISE_AUDIO) &

	LOG_INFO "$0" 0 "PIPEWIRE" "Fast-start complete; finalising in background"
	exit 0
}

DO_STOP() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Audio shutdown sequence..."

	[ "${MU_INTERACTIVE_STOP:-0}" -eq 1 ] && FADE_DOWN

	STOP_AUDIO_STACK

	SET_VAR "device" "audio/ready" "0"
	LOG_SUCCESS "$0" 0 "PIPEWIRE" "Audio shutdown complete"
}

DO_RELOAD() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Reloading audio routing/volume"

	if SOCKET_READY; then
		if FINALISE_AUDIO; then
			LOG_SUCCESS "$0" 0 "PIPEWIRE" "Reload complete"
			exit 0
		fi
	fi

	LOG_WARN "$0" 0 "PIPEWIRE" "Reload incomplete (daemon/socket not ready)"
	exit 1
}

HAS_SINK() {
	pw-cli ls Node 2>/dev/null | grep -q "Audio/Sink"
}

PRINT_STATUS() {
	SOCK=0
	SINK=0

	SOCKET_READY && SOCK=1
	HAS_SINK && SINK=1

	DEF_SINK=$(wpctl status 2>/dev/null | awk -F': ' '/Default Sink:/ {print $2; exit}')

	PW_PID="$(pgrep -xo pipewire)"
	WP_PID="$(pgrep -xo wireplumber)"

	printf "PipeWire:\t\t%s\n" "$([ -n "$PW_PID" ] && printf "running\t\t%s" "$PW_PID" || printf "stopped")"
	printf "WirePlumber:\t\t%s\n" "$([ -n "$WP_PID" ] && printf "running\t\t%s" "$WP_PID" || printf "stopped")"
	printf "Socket:\t\t\t%s\n" "$([ "$SOCK" -eq 1 ] && printf "ready\t\t%s" "$RUNTIME_SOCK" || printf "not ready")"
	printf "Audio Sink:\t\t%s%s\n" "$([ "$SINK" -eq 1 ] && printf "available" || printf "missing")" "$([ -n "$DEF_SINK" ] && printf " (default: %s)" "$DEF_SINK" || printf "")"
	printf "MustardOS Ready:\t%s\n" "$([ "$READY" = "1" ] && printf "yes" || printf "no")"

	if [ "$RUNNING" -ne 1 ]; then
		return 3
	fi

	if [ "$SOCK" -eq 1 ] && [ "$SINK" -eq 1 ]; then
		return 0
	fi

	return 1
}

case "$1" in
	start) DO_START ;;
	stop) DO_STOP ;;
	restart)
		DO_STOP
		DO_START
		;;
	reload) DO_RELOAD ;;
	status)
		if PRINT_STATUS; then
			exit 0
		else
			EC=$?
			exit "$EC"
		fi
		;;
	*)
		printf "Usage: %s {start|stop|restart|reload|status}\n" "$0"
		exit 1
		;;
esac
