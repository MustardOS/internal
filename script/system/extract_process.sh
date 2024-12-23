#!/bin/sh

if [ -z "$1" ]; then
	printf "Need to run %s <PORT_SCRIPT>\n" "$0"
	exit 1
fi

PORT_SCRIPT="$1"
DEVICE_ARCH=$(uname -m)

PROC_MATCH() {
	case "$1" in
		"raloc"*)
			if [ "$DEVICE_ARCH" = "aarch64" ]; then
				printf "retroarch"
			else
				printf "retroarch32"
			fi
			exit 0
			;;
		"monodir"*)
			printf "mono"
			exit 0
			;;
		"exec"*)
			printf "%s" "$(echo "$1" | sed "s/^\"//; s/\"$//; s/\${suffix}/$DEVICE_ARCH/")" | awk '{print tolower($0)}'
			exit 0
			;;
		"runtime"*)
			printf "%s" "$(echo "$1" | sed "s/^\"//; s/\"$//")" | awk '{print tolower($0)}'
			exit 0
			;;
		*"vcmiclient")
			printf "vcmiclient"
			exit 0
			;;
		*"rlvm")
			printf "rlvm.%s" "$DEVICE_ARCH"
			exit 0
			;;
		*"box86")
			printf "box86"
			exit 0
			;;
		*"box64")
			printf "box64"
			exit 0
			;;
		*"love")
			printf "love"
			exit 0
			;;
		*"gmloader")
			printf "gmloader"
			exit 0
			;;
		*"gmloadernext")
			printf "gmloadernext"
			exit 0
			;;
	esac
}

while read -r line; do
	line=$(echo "$line" | sed 's/#.*//') # Remove comments
	[ -z "$line" ] && continue           # Skip empty lines
	PROC_MATCH "$line"                   # Match based on the line content
done <"$PORT_SCRIPT"

if grep -q "\$GPTOKEYB" "$PORT_SCRIPT"; then
	PORT_PROCESS=$(grep "\$GPTOKEYB" "$PORT_SCRIPT" | awk -F'"' '{print $2}' | sed 's/\.gptk$//')
	if [ "$PORT_PROCESS" != "\$exec" ] && [ "$PORT_PROCESS" != "\$runtime" ]; then
		PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n1 | sed "s/\${DEVICE_ARCH}/$DEVICE_ARCH/")
		printf "%s" "$PORT_PROCESS" | awk '{print tolower($0)}'
		exit 0
	fi
fi

PORT_PROCESS=$(sed 's/#.*//' "$PORT_SCRIPT" | grep -oP '(?<=\./)[^\s|]+')
if [ -n "$PORT_PROCESS" ]; then
	case "$PORT_PROCESS" in
		*.gptk) PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n2 | tail -n1) ;;
		*user/config.txt) PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n2 | tail -n1) ;;
		*tonno.txt) PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n2 | tail -n1) ;;
		*oga_controls) PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n2 | tail -n1) ;;
		*) PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n1) ;;
	esac
	printf "%s" "$PORT_PROCESS" | sed "s/\${DEVICE_ARCH}/$DEVICE_ARCH/" | awk '{print tolower($0)}'
	exit 0
fi
