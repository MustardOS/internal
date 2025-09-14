#!/bin/sh

. /opt/muos/script/var/func.sh

ACT_GO=/tmp/act_go

LOG_INFO "$0" 0 "FRONTEND" "Starting Frontend Installer"

read -r START_TIME _ </proc/uptime
SET_VAR "system" "start_time" "$START_TIME"

while :; do
	[ -s "$ACT_GO" ] && {
		IFS= read -r ACTION <"$ACT_GO"

		LOG_INFO "$0" 0 "FRONTEND" "$(printf "Loading '%s' Action" "$ACTION")"

		case "$ACTION" in
			"installer")
				touch /tmp/pdi_go
				EXEC_MUX "installer" "muxfrontend"
				;;

			# We could have just done a straight exit but I'm going to leave
			# this in just in case we have to expand in the future...
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
