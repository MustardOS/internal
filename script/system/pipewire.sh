#!/bin/sh

. /opt/muos/script/var/func.sh

for TIMEOUT in $(seq 1 30); do
	if [ -e /run/dbus/system_bus_socket ]; then
		printf "D-Bus socket is available\n"
		break
	fi
	printf "(%d of 30) Waiting for D-Bus...\n" "$TIMEOUT"
	/opt/muos/bin/toybox sleep 1
done

if [ ! -e /run/dbus/system_bus_socket ]; then
	printf "Timeout expired waiting for D-Bus\n"
	exit 1
fi

if ! pgrep -x "pipewire" >/dev/null; then
	chrt -f 88 pipewire -c "/opt/muos/share/conf/pipewire.conf" &
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
	/opt/muos/bin/toybox sleep 1
done

if ! pw-cli info >/dev/null 2>&1; then
	printf "Timeout expired waiting for PipeWire...\nPipeWire:\n\t%s\nWirePlumber:\n\t%s\nPipeWire Socket:\n\t%s\n" \
		"$(pgrep -l pipewire)" \
		"$(pgrep -l wireplumber)" \
		"$(ls -l /run/pipewire-0)"
	exit 1
fi

GET_NODE_ID() {
	pw-cli ls Node | awk -v path="$1" '
		BEGIN { id = "" }
		/^[[:space:]]*id [0-9]+,/ {
			id = $2
			gsub(/,/, "", id)
		}
		/node.name/ {
			if (index($0, path)) {
				print id
				exit
			}
		}
	'
}

for TIMEOUT in $(seq 1 30); do
	if pw-cli ls Node 2>/dev/null | grep -q "Audio/Sink"; then
		INTERNAL_NODE_ID=$(GET_NODE_ID "$(GET_VAR "device" "audio/pf_internal")")
		EXTERNAL_NODE_ID=$(GET_NODE_ID "$(GET_VAR "device" "audio/pf_external")")

		if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
			DEFAULT_NODE_ID=$EXTERNAL_NODE_ID
			if [ "$(GET_VAR "config" "settings/hdmi/audio")" -eq 1 ]; then
				DEFAULT_NODE_ID=$INTERNAL_NODE_ID
			fi
		else
			DEFAULT_NODE_ID=$INTERNAL_NODE_ID
		fi

		if [ -n "$DEFAULT_NODE_ID" ]; then
			printf "Setting default node to ID: '%s'\n" "$DEFAULT_NODE_ID"
			wpctl set-default "$DEFAULT_NODE_ID"

			case "$(GET_VAR "config" "settings/advanced/volume")" in
				"loud") VOLUME="$(GET_VAR "device" "audio/max")" ;;
				"soft") VOLUME="35" ;;
				"silent") VOLUME="0" ;;
				*) VOLUME="$(GET_VAR "config" "settings/general/volume")" ;;
			esac

			/opt/muos/device/input/audio.sh "$VOLUME"

			amixer -c 0 sset "$(GET_VAR "device" "audio/control")" "$(GET_VAR "device" "audio/volume")"% unmute
			wpctl set-mute @DEFAULT_AUDIO_SINK@ "0"

			exit 0
		else
			printf "Node with ID '%s' not found\n" "$DEFAULT_NODE_ID"
			exit 1
		fi
	fi

	printf "(%d of 30) PipeWire sink not found yet\n" "$TIMEOUT"
	/opt/muos/bin/toybox sleep 1
done

printf "Timeout expired waiting for PipeWire sink...\n%s\n\nCheck your audio configuration\n" "$(pw-cli ls Node)"
exit 1
