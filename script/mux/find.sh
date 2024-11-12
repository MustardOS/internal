#!/bin/sh

USAGE() {
	echo "Usage: $0 <directory> <search term>"
	exit 1
}

if [ "$#" -ne 2 ]; then
	USAGE "$0"
fi

. /opt/muos/script/var/func.sh

RESULTS_JSON="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/search.json"
SKIP_FILE="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/skip.ini"

SDIR="$1"
STERM="$2"

TMP_JSON=$(mktemp)

# Initialize JSON structure with lookup and directory keys, and an empty folders object
echo "{\"lookup\": \"$STERM\", \"directory\": \"$SDIR\", \"folders\": {}}" >"$TMP_JSON"

# Process search results and build directory structure within folders key
/opt/muos/bin/rg --files "$SDIR" --ignore-file "$SKIP_FILE" 2>&1 |
	/opt/muos/bin/rg --pcre2 -i "\/(?!.*\/).*$STERM" |
	sed "s|^$SDIR/||" |
	while IFS= read -r RESULT; do
		jq --arg dir "$(dirname "$RESULT")" --arg file "$(basename "$RESULT")" '
			(.folders[$dir].content += [$file]) //
			(.folders[$dir] = { content: [$file] })
		' "$TMP_JSON" >"$TMP_JSON.tmp" && mv "$TMP_JSON.tmp" "$TMP_JSON"
	done

# Sort the folders by key and write to the final JSON output
jq '.folders |= (to_entries | sort_by(.key) | from_entries)' "$TMP_JSON" >"$RESULTS_JSON" && rm -f "$TMP_JSON"

echo "Directory structure with folders saved in $RESULTS_JSON"
