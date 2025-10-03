#!/bin/sh

. /opt/muos/script/var/func.sh

AUDIO_CONTROL="$(GET_VAR "device" "audio/control")"
MAX_VOL="$(GET_VAR "device" "audio/max")"

ACT_GO=/tmp/act_go

#:] ### Wait for audio stack
#:] Don't proceed to the frontend until PipeWire reports that it is ready.
LOG_INFO "$0" 0 "BOOTING" "Waiting for Pipewire Init"
until [ "$(GET_VAR "device" "audio/ready")" -eq 1 ]; do TBOX sleep 0.01; done

LOG_INFO "$0" 0 "FRONTEND" "Starting Frontend Installer"

read -r START_TIME _ </proc/uptime
SET_VAR "system" "start_time" "$START_TIME"

# Reset audio control status
amixer -c 0 sset "$AUDIO_CONTROL" "${MAX_VOL}%" unmute >/dev/null 2>&1

while :; do
	[ -s "$ACT_GO" ] && {
		IFS= read -r ACTION <"$ACT_GO"

		LOG_INFO "$0" 0 "FRONTEND" "$(printf "Loading '%s' Action" "$ACTION")"

		case "$ACTION" in
			"installer")
				touch /tmp/pdi_go
				EXEC_MUX "installer" "muxfrontend"
				;;

			"install") break ;;

			"shutdown")
				PLAY_SOUND shutdown
				/opt/muos/script/mux/quit.sh poweroff frontend
				;;

			*)
				printf "Unknown Module: %s\n" "$ACTION" >&2
				EXEC_MUX "$ACTION" "muxfrontend"
				;;
		esac
	}

done
