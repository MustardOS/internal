#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/device/audio.sh

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
	if pw-cli ls Node 2>/dev/null | grep -q "$DC_SND_PLATFORM"; then

		NODE_ID=$(
			XDG_RUNTIME_DIR="/var/run" pw-cli ls Node |
				awk -v path="$DC_SND_OBJECT" '
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
			XDG_RUNTIME_DIR="/var/run" wpctl set-default "$NODE_ID"
			amixer -c 0 sset 'digital volume' 100% unmute
			exit 0
		else
			printf "Node with object path '%s' not found.\n" "$DC_SND_OBJECT"
			exit 1
		fi
	fi
	printf "(%d of 30) ALSA sink not found yet\n" "$TIMEOUT"
	sleep 1
done

printf "Timeout expired waiting for ALSA sink...\n%s\n\nCheck your audio configuration\n" "$(pw-cli ls Node)"
exit 1
