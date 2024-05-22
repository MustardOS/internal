#!/bin/sh

parse_ini() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	IN_SECTION=0

	while IFS= read -r LINE || [ -n "$LINE" ]; do
		LINE=$(echo "$LINE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

		[ -z "$LINE" ] && continue
		FIRST_CHAR=$(echo "$LINE" | cut -c 1)
		[ "$FIRST_CHAR" = ";" ] && continue
		[ "$FIRST_CHAR" = "#" ] && continue

		if echo "$LINE" | grep -q '^\['; then
			CURRENT_SECTION=$(echo "$LINE" | sed 's/^\[\(.*\)\]$/\1/')
			if [ "$CURRENT_SECTION" = "$SECTION" ]; then
				IN_SECTION=1
			else
				IN_SECTION=0
			fi
		elif [ "$IN_SECTION" -eq 1 ]; then
			LINE_KEY=$(echo "$LINE" | cut -d '=' -f 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
			LINE_VALUE=$(echo "$LINE" | cut -d '=' -f 2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
			if [ "$LINE_KEY" = "$KEY" ]; then
				echo "$LINE_VALUE"
				return 0
			fi
		fi
	done < "$INI_FILE"

	return 1
}

modify_ini() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	NEW_VALUE="$4"
	IN_SECTION=0
	FOUND_SECTION=0
	FOUND_KEY=0

	TMP_FILE=$(mktemp /tmp/tmpfile.XXXXXX)

	while IFS= read -r LINE || [ -n "$LINE" ]; do
		LINE=$(echo "$LINE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

		if echo "$LINE" | grep -q '^\['; then
			if [ "$IN_SECTION" -eq 1 ] && [ "$FOUND_KEY" -eq 0 ]; then
				echo "$KEY=$NEW_VALUE" >> "$TMP_FILE"
				FOUND_KEY=1
			fi
			CURRENT_SECTION=$(echo "$LINE" | sed 's/^\[\(.*\)\]$/\1/')
			if [ "$CURRENT_SECTION" = "$SECTION" ]; then
				IN_SECTION=1
				FOUND_SECTION=1
			else
				IN_SECTION=0
			fi
		fi

		if [ "$IN_SECTION" -eq 1 ]; then
			LINE_KEY=$(echo "$LINE" | cut -d '=' -f 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
			if [ "$LINE_KEY" = "$KEY" ]; then
				echo "$KEY=$NEW_VALUE" >> "$TMP_FILE"
				FOUND_KEY=1
				continue
			fi
		fi

		echo "$LINE" >> "$TMP_FILE"
	done < "$INI_FILE"

	if [ "$FOUND_SECTION" -eq 0 ]; then
		echo "[$SECTION]" >> "$TMP_FILE"
		echo "$KEY=$NEW_VALUE" >> "$TMP_FILE"
	elif [ "$FOUND_KEY" -eq 0 ]; then
		echo "$KEY=$NEW_VALUE" >> "$TMP_FILE"
	fi

	mv "$TMP_FILE" "$INI_FILE"
}

