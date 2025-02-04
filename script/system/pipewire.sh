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
	chrt -f 88 pipewire -c "/opt/muos/config/pipewire.conf" &
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
	if pw-cli ls Node 2>/dev/null | grep -q "Audio/Sink"; then
    		INTERNAL_NODE_ID=$(
        		XDG_RUNTIME_DIR="/var/run" pw-cli ls Node |
            			awk -v path="$(GET_VAR "device" "audio/pf_internal")" '
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
    		)
     

		EXTERNAL_NODE_ID=$(
    			XDG_RUNTIME_DIR="/var/run" pw-cli ls Node |
        			awk -v path="$(GET_VAR "device" "audio/pf_external")" '
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
		)

		if [ -n "$INTERNAL_NODE_ID" ]; then
			printf "Setting default node to ID: '%s'\n" "$INTERNAL_NODE_ID"
			mkdir -p "/run/muos/audio"
			XDG_RUNTIME_DIR="/var/run" wpctl set-default "$INTERNAL_NODE_ID"
			amixer -c 0 sset "$(GET_VAR "device" "audio/control")" 100% unmute
			printf "%s" "$INTERNAL_NODE_ID" >"/run/muos/audio/nid_internal"
			printf "%s" "$EXTERNAL_NODE_ID" >"/run/muos/audio/nid_external"
			printf "%s" "$(XDG_RUNTIME_DIR="/var/run" wpctl get-volume "$INTERNAL_NODE_ID" | grep -o '[0-9]*\.[0-9]*')" >"/run/muos/audio/pw_vol"

			case "$(GET_VAR "global" "settings/advanced/volume")" in
				"loud")
					XDG_RUNTIME_DIR="/var/run" wpctl set-volume "$(GET_VAR "audio" "nid_internal")" "$(GET_VAR "device" "audio/max")"%
					;;
				"quiet")
					XDG_RUNTIME_DIR="/var/run" wpctl set-volume "$(GET_VAR "audio" "nid_internal")" "$(GET_VAR "device" "audio/min")"%
					;;
				*)
					RESTORED=$(cat "/opt/muos/config/volume.txt")
					XDG_RUNTIME_DIR="/var/run" wpctl set-volume "$(GET_VAR "audio" "nid_internal")" "$RESTORED"%
					;;
			esac

			exit 0
		else
			printf "Node with name '%s' not found.\n" "$(GET_VAR "device" "audio/pf_internal")"
			exit 1
		fi
	fi
	printf "(%d of 30) PipeWire sink not found yet\n" "$TIMEOUT"
	sleep 1
done

printf "Timeout expired waiting for PipeWire sink...\n%s\n\nCheck your audio configuration\n" "$(pw-cli ls Node)"
exit 1