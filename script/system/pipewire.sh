#!/bin/sh

. /opt/muos/script/var/func.sh

FAST_READY_GRACE_MS=300
FAST_READY_POLL_MS=50

SINK_DISCOVERY_TIMEOUT_MS=3000
SINK_DISCOVERY_POLL_MS=100

PROC_GONE_TIMEOUT_MS=2000

RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/run/pipewire-0}}"
RUNTIME_SOCK="$RUNTIME_DIR/pipewire-0"

RUNTIME_DIR_INIT() {
	mkdir -p "$RUNTIME_DIR"
	chmod 700 "$RUNTIME_DIR"

	export XDG_RUNTIME_DIR="$RUNTIME_DIR"
}

SLEEP_MS() {
	SEC=$(printf '%s' "$1" | awk '{printf "%.3f", $1/1000}')
	TBOX sleep "$SEC"
}

SOCKET_READY_FAST() {
	[ -S "$RUNTIME_SOCK" ] || return 1
	return 0
}

SOCKET_READY() {
	[ -S "$RUNTIME_SOCK" ] || return 1
	XDG_RUNTIME_DIR="$RUNTIME_DIR" pw-cli info >/dev/null 2>&1 || return 1
	return 0
}

PROC_GONE() {
	NAME=$1
	LIMIT_MS=${2:-$PROC_GONE_TIMEOUT_MS}
	ELAPSED=0

	while pgrep -x "$NAME" >/dev/null 2>&1; do
		SLEEP_MS 50
		ELAPSED=$((ELAPSED + 50))
		[ "$ELAPSED" -ge "$LIMIT_MS" ] && return 1
	done

	return 0
}

GET_NODE_ID() {
	XDG_RUNTIME_DIR="$RUNTIME_DIR" pw-cli ls Node 2>/dev/null | awk -v pat="$1" '
	BEGIN { id=""; name=""; mc="" }

	# Start of node block: lines like "id 38, type PipeWire:Interface:Node/3"
	/^[[:space:]]*id [0-9]+,/ {
		if (id != "" && mc == "Audio/Sink" && (pat == "" || index(name, pat) > 0)) {
			print id; exit
		}
		id = $2; sub(/,$/, "", id)
		name = ""; mc = ""
		next
	}

	# media.class = "Audio/Sink"
	/^[[:space:]]*media\.class = "/ {
		mc = $0
		sub(/^.*= "/, "", mc); sub(/".*$/, "", mc)
		next
	}

	# node.name = "alsa_output..."
	/^[[:space:]]*node\.name = "/ {
		name = $0
		sub(/^.*= "/, "", name); sub(/".*$/, "", name)
		next
	}

	# Last block if file ended without another "id ..." line)
	END {
		if (id != "" && mc == "Audio/Sink" && (pat == "" || index(name, pat) > 0)) {
			print id
		}
	}
	' | head -n1
}

GET_DEFAULT_SINK() {
	XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl status 2>/dev/null |
		awk -F': ' '/Default Sink:/ {print $2; exit}'
}

SET_DEFAULT_SINK() {
	C_SINK=$(GET_DEFAULT_SINK)
	[ -n "$C_SINK" ] && [ "$C_SINK" = "$1" ] && return 0

	XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl set-default "$1" >/dev/null 2>&1
}

GET_VOLUME() {
	XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null |
		awk '
		{ for (i=1;i<=NF;i++) if ($i ~ /^[0-9.]+$/) { v=$i; break } }
		END { if (v=="") exit; printf "%d\n", int(v*100+0.5) }
	'
}

SET_VOLUME() {
	C_SINK=$(GET_VOLUME)
	[ -n "$C_SINK" ] && [ "$C_SINK" -eq "$1" ] && return 0

	XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl set-volume @DEFAULT_AUDIO_SINK@ "$1"% >/dev/null 2>&1
}

FADE_DOWN() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Fading sink volume down..."

	N=0
	while [ "$N" -lt 8 ]; do
		XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl set-volume @DEFAULT_AUDIO_SINK@ 16%- >/dev/null 2>&1 || break
		SLEEP_MS 80
		N=$((N + 1))
	done

	XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl set-volume @DEFAULT_AUDIO_SINK@ 0% >/dev/null 2>&1
	XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 >/dev/null 2>&1
}

STOP_AUDIO_STACK() {
	for PROC in pipewire wireplumber; do
		killall -q -15 "$PROC" 2>/dev/null
		PROC_GONE "$PROC" "$PROC_GONE_TIMEOUT_MS" || killall -q -9 "$PROC" 2>/dev/null
	done
}

REQUIRE_DBUS() {
	ELAPSED=0

	while [ ! -S "/run/dbus/system_bus_socket" ]; do
		SLEEP_MS 100
		ELAPSED=$((ELAPSED + 100))
		[ "$ELAPSED" -ge 3000 ] && break
	done

	if [ -S "/run/dbus/system_bus_socket" ]; then
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

CACHE_VARS() {
	BOOT_CONSOLE_MODE="$(GET_VAR "config" "boot/device_mode")"
	AUDIO_CONTROL="$(GET_VAR "device" "audio/control")"
	PF_INTERNAL="$(GET_VAR "device" "audio/pf_internal")"
	PF_EXTERNAL="$(GET_VAR "device" "audio/pf_external")"
	GEN_VOL="$(GET_VAR "config" "settings/general/volume")"
	ADV_VOL="$(GET_VAR "config" "settings/advanced/volume")"
	ADV_OD="$(GET_VAR "config" "settings/advanced/overdrive")"
	MAX_VOL="$(GET_VAR "device" "audio/max")"

	export BOOT_CONSOLE_MODE PF_INTERNAL PF_EXTERNAL GEN_VOL ADV_VOL ADV_OD MAX_VOL
}

FINALISE_AUDIO() {
	export XDG_RUNTIME_DIR="$RUNTIME_DIR"

	ELAPSED=0
	while ! XDG_RUNTIME_DIR="$RUNTIME_DIR" pw-cli ls Node 2>/dev/null | grep -q "Audio/Sink"; do
		SLEEP_MS "$SINK_DISCOVERY_POLL_MS"
		ELAPSED=$((ELAPSED + SINK_DISCOVERY_POLL_MS))
		if [ "$ELAPSED" -ge "$SINK_DISCOVERY_TIMEOUT_MS" ]; then
			SET_VAR "device" "audio/ready" "1"
			return 1
		fi
	done

	INT_ID=$(GET_NODE_ID "$PF_INTERNAL")
	EXT_ID=$(GET_NODE_ID "$PF_EXTERNAL")

	if [ "$BOOT_CONSOLE_MODE" -eq 1 ]; then
		DEF_ID="$EXT_ID"
		if [ "$(GET_VAR "config" "settings/hdmi/audio")" -eq 1 ]; then
			DEF_ID="$INT_ID"
		fi
	else
		DEF_ID="$INT_ID"
	fi

	if [ -z "$DEF_ID" ]; then
		SET_VAR "device" "audio/ready" "1"
		return 1
	fi

	CS=$(
		XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl status 2>/dev/null |
			awk -F': ' '/Default Sink:/ {print $2; exit}'
	)

	if [ "$CS" != "$DEF_ID" ] && [ -n "$DEF_ID" ]; then
		XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl set-default "$DEF_ID" >/dev/null 2>&1
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
		XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null |
			awk '{for(i=1;i<=NF;i++) if($i~/^[0-9.]+$/){v=$i;break}} END{if(v!="") printf "%d\n", int(v*100+0.5)}'
	)

	if [ -z "$CURR_VOL" ] || [ "$CURR_VOL" -ne "$V" ]; then
		XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl set-volume @DEFAULT_AUDIO_SINK@ "$V"% >/dev/null 2>&1
	fi

	XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1

	LOG_SUCCESS "$0" 0 "PIPEWIRE" "Audio Finalised (node=%s, vol=%s%%)" "$DEF_ID" "$V"
	return 0
}

START_PIPEWIRE() {
	RUNTIME_DIR_INIT

	if ! pgrep -x "pipewire" >/dev/null 2>&1; then
		LOG_INFO "$0" 0 "PIPEWIRE" "Starting PipeWire (runtime: %s)" "$RUNTIME_DIR"
		XDG_RUNTIME_DIR="$RUNTIME_DIR" chrt -f 88 pipewire -c "$MUOS_SHARE_DIR/conf/pipewire.conf" &
	else
		LOG_WARN "$0" 0 "PIPEWIRE" "PipeWire already running"
	fi

	if ! pgrep -x "wireplumber" >/dev/null 2>&1; then
		LOG_INFO "$0" 0 "PIPEWIRE" "Starting WirePlumber..."
		XDG_RUNTIME_DIR="$RUNTIME_DIR" wireplumber &
	fi

	ELAPSED=0
	while ! SOCKET_READY_FAST; do
		SLEEP_MS "$FAST_READY_POLL_MS"
		ELAPSED=$((ELAPSED + FAST_READY_POLL_MS))
		[ "$ELAPSED" -ge "$FAST_READY_GRACE_MS" ] && break
	done

	return 0
}

DO_START() {
	CACHE_VARS

	if ! START_PIPEWIRE; then
		LOG_ERROR "$0" 0 "PIPEWIRE" "Failed to start"
		exit 1
	fi

	amixer -c 0 sset "$AUDIO_CONTROL" "${MAX_VOL}%" unmute >/dev/null 2>&1
	SET_VAR "device" "audio/ready" "1"

	(DO_PRESTART) &
	REQUIRE_DBUS &

	(FINALISE_AUDIO) &

	LOG_INFO "$0" 0 "PIPEWIRE" "Fast-start complete; finalising in background"
	exit 0
}

DO_STOP() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Audio shutdown sequence..."

	if [ "${MU_INTERACTIVE_STOP:-0}" -eq 1 ]; then
		FADE_DOWN
	fi

	STOP_AUDIO_STACK

	SET_VAR "device" "audio/ready" "0"
	LOG_SUCCESS "$0" 0 "PIPEWIRE" "Audio shutdown complete"
}

DO_RELOAD() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Reloading audio routing/volume"

	if SOCKET_READY; then
		CACHE_VARS
		if FINALISE_AUDIO; then
			LOG_SUCCESS "$0" 0 "PIPEWIRE" "Reload complete"
			exit 0
		fi
	fi

	LOG_WARN "$0" 0 "PIPEWIRE" "Reload incomplete (daemon/socket not ready)"
	exit 1
}

IS_RUNNING() {
	PG_OK=0

	pgrep -x pipewire >/dev/null 2>&1 || PG_OK=1
	pgrep -x wireplumber >/dev/null 2>&1 || PG_OK=1

	[ "$PG_OK" -eq 0 ] || return 1
	return 0
}

HAS_SINK() {
	XDG_RUNTIME_DIR="$RUNTIME_DIR" pw-cli ls Node 2>/dev/null | grep -q "Audio/Sink"
}

PRINT_STATUS() {
	RUNNING=0
	SOCK=0
	SINK=0
	READY="$(GET_VAR "device" "audio/ready")"

	IS_RUNNING && RUNNING=1
	SOCKET_READY && SOCK=1
	HAS_SINK && SINK=1

	DEF_SINK=$(XDG_RUNTIME_DIR="$RUNTIME_DIR" wpctl status 2>/dev/null | awk -F': ' '/Default Sink:/ {print $2; exit}')

	printf "PipeWire:\t\t%s\n" "$([ "$RUNNING" -eq 1 ] && printf "running" || printf "stopped")"
	printf "WirePlumber:\t\t%s\n" "$(pgrep -x wireplumber >/dev/null 2>&1 && printf "running" || printf "stopped")"
	printf "Socket:\t\t\t%s\n" "$([ "$SOCK" -eq 1 ] && printf "ready (%s)" "$RUNTIME_SOCK" || printf "not ready")"
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
