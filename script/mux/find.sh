#!/bin/sh

set -eu

USAGE() {
	printf "Usage: %s <search term> <directory1> [directory2 ...]\n" "$0"
	exit 1
}

[ "$#" -lt 2 ] && USAGE

. /opt/muos/script/var/func.sh

RESULTS_JSON="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/search.json"
FRIENDLY_JSON="/run/muos/storage/info/name/general.json"
SKIP_FILE="$(GET_VAR "device" "storage/sdcard/mount")/MUOS/info/skip.ini"
[ ! -s "$SKIP_FILE" ] && SKIP_FILE="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/skip.ini"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

TMP_FRIENDLY="/tmp/f_result.json"
TMP_FRIENDLY_FILES="$TMP_DIR/f_files.txt"
TMP_FILES="$TMP_DIR/files.txt"
TMP_RESULTS="$TMP_DIR/results.json"

S_TERM="$1"

# Shift one argument over so we are left with only directories to search
shift

# Generate friendly name JSON so we can use that for the search results for quicker parsing
if [ -f "$FRIENDLY_JSON" ]; then
	/opt/muos/bin/rg -i "$S_TERM" "$FRIENDLY_JSON" |
		sed -e '1s/^/{\n/' -e '$s/,$//' -e '$a}' >"$TMP_FRIENDLY"
	jq -r 'keys[]' "$TMP_FRIENDLY" >"$TMP_FRIENDLY_FILES"
else
	printf "{}" >"$TMP_FRIENDLY"
	: >"$TMP_FRIENDLY_FILES"
fi

# Create and populate JSON structure for parsing in muxsearch
jq -n --arg lookup "$S_TERM" '{lookup: $lookup, directories: [], folders: {}}' >"$TMP_RESULTS"

# Okay now we'll go through each of the requested directories and find content based on the search term
for S_DIR in "$@"; do
	/opt/muos/bin/rg --files "$S_DIR" --ignore-file "$SKIP_FILE" 2>/dev/null |
		/opt/muos/bin/rg --pcre2 -i "/(?!.*\/).*$S_TERM" |
		sed "s|^$S_DIR/||" | sort -fu >>"$TMP_FILES" # yeah sort fuck you too

	jq --arg dir "$S_DIR" '.directories += [$dir]' "$TMP_RESULTS" >"$TMP_RESULTS.dirlist"
	mv "$TMP_RESULTS.dirlist" "$TMP_RESULTS"
done

# Time to make the JSON results file with everything above!
while IFS= read -r RESULT; do
	jq --arg dir "$(dirname "$RESULT")" --arg file "$(basename "$RESULT")" \
		'(.folders[$dir].content += [$file]) //(.folders[$dir] = { content: [$file] })' \
		"$TMP_RESULTS" >"$TMP_RESULTS.result"
	mv "$TMP_RESULTS.result" "$TMP_RESULTS"
done <"$TMP_FILES"

# And now we'll sort out the entries within each key
jq '.folders |= (to_entries | sort_by(.key) | from_entries)' "$TMP_RESULTS" >"$RESULTS_JSON"
