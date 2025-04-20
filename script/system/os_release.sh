#!/bin/sh

VERSION_FILE="/opt/muos/config/version.txt"
OS_RELEASE="/etc/os-release"
VERSION_LINE="0000.0_UNKNOWN"
BUILD_ID="unknown"

if [ -f "$VERSION_FILE" ]; then
	VERSION_LINE=$(sed -n 1p "$VERSION_FILE")
	BUILD_ID=$(sed -n 2p "$VERSION_FILE")
fi

VERSION_ID=${VERSION_LINE%%_*}
VERSION_CODENAME=${VERSION_LINE#*_}

{
	printf 'NAME=muOS\n'
	printf 'VERSION="%s (%s)"\n' "$VERSION_ID" "$VERSION_CODENAME"
	printf 'ID=muos\n'
	printf 'VERSION_ID=%s\n' "$VERSION_ID"
	printf 'PRETTY_NAME="muOS %s (%s)"\n' "$VERSION_ID" "$VERSION_CODENAME"
	printf 'ANSI_COLOR="1;33"\n'
	printf 'HOME_URL="https://muos.dev/"\n'
	printf 'SUPPORT_URL="https://community.muos.dev/"\n'
	printf 'BUILD_ID=%s\n' "$BUILD_ID"
} > "$OS_RELEASE"

