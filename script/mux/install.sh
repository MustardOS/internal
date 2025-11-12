#!/bin/sh

. /opt/muos/script/var/func.sh

ACT_GO=/tmp/act_go

#:] ### Wait for audio stack
#:] Don't proceed to the frontend until PipeWire reports that it is ready.
LOG_INFO "$0" 0 "BOOTING" "Waiting for Pipewire Init"
if [ "$(GET_VAR "config" "settings/advanced/audio_ready")" -eq 1 ]; then
	until [ "$(GET_VAR "device" "audio/ready")" -eq 1 ]; do TBOX sleep 0.1; done
fi

LOG_INFO "$0" 0 "FRONTEND" "Starting Frontend Installer"

read -r START_TIME _ </proc/uptime
SET_VAR "system" "start_time" "$START_TIME"

RESET_AMIXER

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
