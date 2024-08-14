#!/bin/sh

FB_SWITCH() {
	WIDTH="$1"
	HEIGHT="$2"
	DEPTH="$3"

	echo 4 >/sys/class/graphics/fb0/blank
	cat /dev/zero >/dev/fb0 2>/dev/null

	VIRTUAL_HEIGHT=$((HEIGHT * 2))

	fbset -fb /dev/fb0 -g "${WIDTH}" "${HEIGHT}" "${WIDTH}" "${VIRTUAL_HEIGHT}" "${DEPTH}"
	echo 0 >/sys/class/graphics/fb0/blank
}

# Writes a setting value to the display driver.
#
# Usage: DISPLAY_WRITE NAME COMMAND PARAM
DISPLAY_WRITE() {
	printf '%s\n' "$1" >/sys/kernel/debug/dispdbg/name
	printf '%s\n' "$2" >/sys/kernel/debug/dispdbg/command
	printf '%s\n' "$3" >/sys/kernel/debug/dispdbg/param
	echo 1 >/sys/kernel/debug/dispdbg/start
}

# Reads and prints a setting value from the display driver.
#
# Usage: DISPLAY_READ NAME COMMAND
DISPLAY_READ() {
	printf '%s\n' "$1" >/sys/kernel/debug/dispdbg/name
	printf '%s\n' "$2" >/sys/kernel/debug/dispdbg/command
	echo 1 >/sys/kernel/debug/dispdbg/start
	cat /sys/kernel/debug/dispdbg/info
}

# Prints current system uptime in hundredths of a second. Unlike date or
# EPOCHREALTIME, this won't decrease if the system clock is set back, so it can
# be used to measure an interval of real time.
UPTIME() {
	cut -d ' ' -f 1 /proc/uptime
}

PARSE_INI() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^${KEY}[ ]*=[ ]*/ { s/^[^=]*=[ ]*//; p; q; }; n; b l; }" "${INI_FILE}"
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

	sed -i "/^\[${SECTION}\]/,/^\[/ s|^${KEY}[ ]*=.*|${KEY} = ${NEW_VALUE}|" "${INI_FILE}"
}

GEN_VAR() {
	BASE_DIR="/run/muos/$1/$2"
	[ ! -d "$BASE_DIR" ] && mkdir -p "$BASE_DIR"
	for VAR_NAME in $3; do
		case "$1" in
			global)
				VAR_VALUE=$(PARSE_INI "$GLOBAL_CONFIG" "$(echo "$2" | sed 's/\//./g')" "$VAR_NAME")
				;;
			device)
				VAR_VALUE=$(PARSE_INI "$DEVICE_CONFIG" "$(echo "$2" | sed 's/\//./g')" "$VAR_NAME")
				;;
			*)
				echo "Error: Configuration type '$1' not found!"
				return 1
				;;
		esac
		printf "%s" "$VAR_VALUE" >"$BASE_DIR/$VAR_NAME"
	done
	chmod -R 755 "$BASE_DIR"
}

SAVE_VAR() {
	case "$1" in
		global)
			MODIFY_INI "$GLOBAL_CONFIG" "$1" "$(echo "$2" | sed 's/\//./g')" "$3"
			;;
		device)
			MODIFY_INI "$DEVICE_CONFIG" "$1" "$(echo "$2" | sed 's/\//./g')" "$3"
			;;
		*)
			echo "Error: Configuration type '$1' not found!"
			return 1
			;;
	esac
}

SET_VAR() {
	printf "%s" "$3" >"/run/muos/$1/$2"
}

GET_VAR() {
	cat "/run/muos/$1/$2"
}

LOGGER() {
	if [ "$(GET_VAR "global" "boot/factory_reset")" -eq 1 ]; then
		/opt/muos/extra/muxstart "$(printf "%s\n\n%s\n" "$2" "$3")" && sleep 0.5
	fi
	printf "%s\t[%s] :: %s - %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$1" "$2" "$3" >>$MUOS_BOOT_LOG
}
