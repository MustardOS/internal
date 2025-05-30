#!/bin/sh

OS_RELEASE="/etc/os-release"

VERSION_LINE=$(cat "/opt/muos/config/system/version")
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
	printf 'BUILD_ID=%s\n' "$(cat "/opt/muos/config/system/build")"
} >"$OS_RELEASE"
