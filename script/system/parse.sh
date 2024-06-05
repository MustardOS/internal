#!/bin/sh

parse_ini() {
	# https://stackoverflow.com/a/40778047
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^$KEY[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$INI_FILE"
}

modify_ini() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	NEW_VALUE="$4"

	if ! grep -q "^\[$SECTION\]" "$INI_FILE"; then
		echo "Section [$SECTION] not found in $INI_FILE"
		return 1
	fi

	if ! sed -n "/^\[$SECTION\]/,/^\[/p" "$INI_FILE" | grep -q "^$KEY[ ]*="; then
		echo "Key [$KEY] not found in section [$SECTION] of $INI_FILE"
		return 1
	fi

	sed -i "/^\[$SECTION\]/,/^\[/ s/^$KEY[ ]*=.*/$KEY=$NEW_VALUE/" "$INI_FILE"
}

