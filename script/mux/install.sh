#!/bin/sh

. /opt/muos/script/var/boot.sh
. /opt/muos/script/var/runtime.sh

DEVICE_FRONTEND_START() { :; }
DEVICE_FRONTEND_EXEC() { EXEC_MUX "$@"; }
# shellcheck source=/dev/null
DEVICE_FRONTEND_SCRIPT=$(DEVICE_SCRIPT frontend.sh) && . "$DEVICE_FRONTEND_SCRIPT"

LOG_INFO "$0" 0 "BOOTING" "Waiting for Pipewire Init"
if [ "$(GET_VAR "config" "settings/advanced/audio_ready")" -eq 1 ]; then
	until [ "$(GET_VAR "device" "audio/ready")" -eq 1 ]; do sleep 0.1; done
fi

LOG_INFO "$0" 0 "FRONTEND" "Starting Frontend Installer"

read -r START_TIME _ </proc/uptime
SET_VAR "system" "start_time" "$START_TIME"

RESET_MIXER

DEVICE_FRONTEND_START

while :; do
	[ -s "$ACT_GO" ] && {
		IFS= read -r ACTION <"$ACT_GO"

		LOG_INFO "$0" 0 "FRONTEND" "$(printf "Loading '%s' Action" "$ACTION")"

		case "$ACTION" in
			"installer")
				touch /tmp/pdi_go
				DEVICE_FRONTEND_EXEC "installer" "muxfrontend"
				;;

			"install") break ;;
			"shutdown") /opt/muos/script/mux/quit.sh poweroff frontend ;;

			*)
				printf "Unknown Module: %s\n" "$ACTION" >&2
				DEVICE_FRONTEND_EXEC "$ACTION" "muxfrontend"
				;;
		esac
	}

done
