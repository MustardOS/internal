#!/bin/sh

OS_RELEASE="/etc/os-release"

OS_NAME="MustardOS"
OS_ID="muos"

BUILD_ID=$(cat "/opt/muos/config/system/build")

VERSION_LINE=$(cat "/opt/muos/config/system/version")
VERSION_ID=${VERSION_LINE%%_*}
VERSION_CODENAME=${VERSION_LINE#*_}

{
	printf 'NAME=%s\n' "$OS_NAME"
	printf 'VERSION="%s (%s)"\n' "$VERSION_ID" "$VERSION_CODENAME"
	printf 'ID=%s\n' "$OS_ID"
	printf 'VERSION_ID=%s\n' "$VERSION_ID"
	printf 'PRETTY_NAME="%s %s (%s)"\n' "$OS_NAME" "$VERSION_ID" "$VERSION_CODENAME"
	printf 'ANSI_COLOR="1;33"\n'
	printf 'HOME_URL="https://muos.dev/"\n'
	printf 'SUPPORT_URL="https://community.muos.dev/"\n'
	printf 'BUILD_ID=%s\n' "$BUILD_ID"
} >"$OS_RELEASE"
