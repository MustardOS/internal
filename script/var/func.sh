#!/bin/sh

GLOBAL_CONFIG="/opt/muos/config/config.ini"
export GLOBAL_CONFIG

DEVICE_TYPE=$(tr '[:upper:]' '[:lower:]' <"/opt/muos/config/device.txt")
export DEVICE_TYPE

DEVICE_CONFIG="/opt/muos/device/$DEVICE_TYPE/config.ini"
export DEVICE_CONFIG

ALSA_CONFIG="/usr/share/alsa/alsa.conf"
export ALSA_CONFIG

DEVICE_CONTROL_DIR="/opt/muos/device/$DEVICE_TYPE/control"
export DEVICE_CONTROL_DIR

MUOS_BOOT_LOG="/opt/muos/boot.log"
export MUOS_BOOT_LOG

PARSE_INI() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^${KEY}[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "${INI_FILE}"
}

MODIFY_INI() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	NEW_VALUE="$4"

	if ! grep -q "^\[${SECTION}\]" "${INI_FILE}"; then
		echo "Section [${SECTION}] not found in ${INI_FILE}"
		return 1
	fi

	if ! sed -n "/^\[${SECTION}\]/,/^\[/p" "${INI_FILE}" | grep -q "^${KEY}[ ]*="; then
		echo "Key [${KEY}] not found in section [${SECTION}] of ${INI_FILE}"
		return 1
	fi

	sed -i "/^\[${SECTION}\]/,/^\[/ s|^${KEY}[ ]*=.*|${KEY}=${NEW_VALUE}|" "${INI_FILE}"
}

LOGGER() {
	_SCRIPT=$1
	_TITLE=$2
	_MESSAGE=$3
	if [ "$(PARSE_INI "$GLOBAL_CONFIG" "boot" "factory_reset")" -eq 1 ]; then
		_FORM=$(
			cat <<EOF
$_TITLE

$_MESSAGE
EOF
		)
		/opt/muos/extra/muxstart "$_FORM" && sleep 0.5
	fi
	printf "%s\t[%s] :: %s - %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$_SCRIPT" "$_TITLE" "$_MESSAGE" >>$MUOS_BOOT_LOG
}
