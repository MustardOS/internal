#!/bin/sh

if [ -z "$1" ]; then
	echo "Need to run $0 <PORT_SCRIPT>"
	exit 1
fi

PORT_SCRIPT="$1"
DEVICE_ARCH=$(uname -m)

# Check for "raloc" value for RetroArch ports... why?
PORT_PROCESS=$(grep -oP '(?<=raloc=)[^\s]+' "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	if [ "$DEVICE_ARCH" = "aarch64" ]; then
		echo "retroarch"
	else
		echo "retroarch32"
	fi
	exit 0
fi

# Check for "monodir" value in the script
PORT_PROCESS=$(grep -oP '(?<=monodir=)[^\s]+' "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	echo "mono"
	exit 0
fi

# Check for "exec" value in the script
PORT_PROCESS=$(grep -oP '(?<=exec=)[^\s]+' "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	PORT_PROCESS=$(echo "$PORT_PROCESS" | sed 's/^"\(.*\)"$/\1/')
	PORT_PROCESS=$(echo "$PORT_PROCESS" | sed "s/\${suffix}/$DEVICE_ARCH/")
	echo "$PORT_PROCESS" | tr '[:upper:]' '[:lower:]'
	exit 0
fi

# Check for "runtime" value in the script (frt etc.)
PORT_PROCESS=$(grep -oP '(?<=runtime=)[^\s]+' "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	PORT_PROCESS=$(echo "$PORT_PROCESS" | sed 's/^"\(.*\)"$/\1/')
	echo "$PORT_PROCESS" | tr '[:upper:]' '[:lower:]'
	exit 0
fi

# Heroes of Might and Magic 3 clone
PORT_PROCESS=$(grep -oP "(vcmiclient)" "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	echo "vcmiclient"
	exit 0
fi

# RealLive clone
PORT_PROCESS=$(grep -oP "(rlvm)" "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	echo "rlvm.$DEVICE_ARCH"
	exit 0
fi

# Box86 process launch
PORT_PROCESS=$(grep -oP "(box86)" "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	echo "box86"
	exit 0
fi

# Box64 process launch
PORT_PROCESS=$(grep -oP "(box64)" "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	echo "box64"
	exit 0
fi

# Check for "./bin/love" and return "love"
PORT_PROCESS=$(grep -oP "\./bin/love" "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	echo "love"
	exit 0
fi

# Check for "./gmloader"
PORT_PROCESS=$(grep -oP "\./gmloader" "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	echo "gmloader"
	exit 0
fi

# Check to see if gptokeyb has a sane value attached
PORT_PROCESS=$(grep "\$GPTOKEYB" "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	PORT_PROCESS=$(grep "\$GPTOKEYB" "$PORT_SCRIPT" | awk -F'"' '{print $2}' | sed 's/\.gptk$//')
	if [ ! "$PORT_PROCESS" = "\$exec" ] || [ ! "$PORT_PROCESS" = "\$runtime" ]; then
		PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n1)
		PORT_PROCESS=$(echo "$PORT_PROCESS" | sed -e "s/\${DEVICE_ARCH}/$DEVICE_ARCH/" -e "s/\$DEVICE_ARCH/$DEVICE_ARCH/")
		echo "$PORT_PROCESS" | tr '[:upper:]' '[:lower:]'
		exit 0
	fi
fi

# Generic process name launch
PORT_PROCESS=$(sed 's/#.*//' "$PORT_SCRIPT" | grep -v '^$' | grep -oP '(?<=\./)[^\s|]+' "$PORT_SCRIPT")
if [ -n "$PORT_PROCESS" ]; then
	if echo "$PORT_PROCESS" | grep -q '\.gptk'; then
		PORT_PROCESS=$(echo "$PORT_PROCESS" | grep -v '\.gptk$' | head -n2 | tail -n1)
	elif echo "$PORT_PROCESS" | grep -q 'user/config.txt'; then
		PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n2 | tail -n1)
	elif echo "$PORT_PROCESS" | grep -q 'tonno.txt'; then
		PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n2 | tail -n1)
	elif echo "$PORT_PROCESS" | grep -q 'oga_controls'; then
		PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n2 | tail -n1)
	else
		PORT_PROCESS=$(echo "$PORT_PROCESS" | head -n1)
	fi

	PORT_PROCESS=$(echo "$PORT_PROCESS" | sed -e "s/\${DEVICE_ARCH}/$DEVICE_ARCH/" -e "s/\$DEVICE_ARCH/$DEVICE_ARCH/")
	echo "$PORT_PROCESS" | tr '[:upper:]' '[:lower:]'
	exit 0
fi
