#!/bin/sh

parse_ini() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	IN_SECTION=0
	while IFS='=' read -r LINE_KEY LINE_VALUE || [ -n "$LINE_KEY" ]; do
		if echo "$LINE_KEY" | grep -q '^\['; then
			CURRENT_SECTION=$(echo "$LINE_KEY" | sed 's/\[\(.*\)\]/\1/')
			[ "$CURRENT_SECTION" = "$SECTION" ] && IN_SECTION=1 || IN_SECTION=0
		elif [ "$IN_SECTION" -eq 1 ] && [ "$LINE_KEY" = "$KEY" ]; then
			echo "$LINE_VALUE"
		fi
	done < "$INI_FILE"
}

