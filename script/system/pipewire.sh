#!/bin/sh

. /opt/muos/script/var/func.sh

for TIMEOUT in $(seq 1 30); do
	if [ -e /run/dbus/system_bus_socket ]; then
		printf "D-Bus socket is available\n"
		break
	fi
	printf "(%d of 30) Waiting for D-Bus...\n" "$TIMEOUT"
	sleep 1
done

if [ ! -e /run/dbus/system_bus_socket ]; then
	printf "Timeout expired waiting for D-Bus\n"
	exit 1
fi

if ! pgrep -x "pipewire" >/dev/null; then
	pipewire &
	printf "Starting PipeWire\n"
else
	printf "PipeWire is already running\n"
	exit 1
fi

printf "Waiting for PipeWire to start...\n"
for TIMEOUT in $(seq 1 30); do
	if pw-cli info >/dev/null 2>&1; then
		printf "PipeWire is now responsive!\n"
		break
	fi
	printf "(%d of 30) PipeWire not responsive yet...\n" "$TIMEOUT"
	pgrep -l pipewire
	sleep 1
done

if ! pw-cli info >/dev/null 2>&1; then
	printf "Timeout expired waiting for PipeWire...\nPipeWire:\n\t%s\nWirePlumber:\n\t%s\nPipeWire Socket:\n\t%s\n" \
		"$(pgrep -l pipewire)" \
		"$(pgrep -l wireplumber)" \
		"$(ls -l /run/pipewire-0)"
	exit 1
fi

for TIMEOUT in $(seq 1 30); do
	if pw-cli ls Node 2>/dev/null | grep -q "$(GET_VAR "device" "audio/platform")"; then

		NODE_ID=$(
			XDG_RUNTIME_DIR="/var/run" pw-cli ls Node |
				awk -v path="$(GET_VAR "device" "audio/object")" '
        /id/ {
            id = $2
        }
        /object.path/ && $0 ~ path {
            gsub(/,$/, "", id)
            print id
        }
    '
		)

		if [ -n "$NODE_ID" ]; then
			printf "Setting default node to ID: '%s'\n" "$NODE_ID"
			mkdir -p "/run/muos/audio"
			XDG_RUNTIME_DIR="/var/run" wpctl set-default "$NODE_ID"
			amixer -c 0 sset "$(GET_VAR "device" "audio/control")" 100% unmute
			printf "%s" "$NODE_ID" >"/run/muos/audio/node_id"
			printf "%s" "$(XDG_RUNTIME_DIR="/var/run" wpctl get-volume "$NODE_ID" | grep -o '[0-9]*\.[0-9]*')" >"/run/muos/audio/pw_vol"

			case "$(GET_VAR "global" "settings/advanced/volume")" in
            	"loud")
            		XDG_RUNTIME_DIR="/var/run" wpctl set-volume @DEFAULT_AUDIO_SINK@ "$(GET_VAR "device" "audio/max")"%
            		;;
            	"quiet")
            		XDG_RUNTIME_DIR="/var/run" wpctl set-volume @DEFAULT_AUDIO_SINK@ "$(GET_VAR "device" "audio/min")"%
            		;;
            	*)
            		RESTORED=$(cat "/opt/muos/config/volume.txt")
            		XDG_RUNTIME_DIR="/var/run" wpctl set-volume @DEFAULT_AUDIO_SINK@ "$RESTORED"%
            		;;
            esac

			exit 0
		else
			printf "Node with object path '%s' not found.\n" "$(GET_VAR "device" "audio/object")"
			exit 1
		fi
	fi
	printf "(%d of 30) ALSA sink not found yet\n" "$TIMEOUT"
	sleep 1
done

printf "Timeout expired waiting for ALSA sink...\n%s\n\nCheck your audio configuration\n" "$(pw-cli ls Node)"
exit 1
