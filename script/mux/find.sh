#!/bin/sh

set -eu

USAGE() {
	printf "Usage: %s <directory> <search term>\n" "$0"
	exit 1
}

[ "$#" -ne 2 ] && USAGE

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

S_DIR="$1"
S_TERM="$2"

# Generate friendly name JSON so we can use that for the search results for quicker parsing
if [ -f "$FRIENDLY_JSON" ]; then
	/opt/muos/bin/rg -i "$S_TERM" "$FRIENDLY_JSON" |
		sed -e '1s/^/{\n/' -e '$s/,$//' -e '$a}' >"$TMP_FRIENDLY"
	jq -r 'keys[]' "$TMP_FRIENDLY" >"$TMP_FRIENDLY_FILES"
else
	printf "{}" >"$TMP_FRIENDLY"
	: >"$TMP_FRIENDLY_FILES"
fi

RG_SEARCH() {
	/opt/muos/bin/rg --files "$S_DIR" --ignore-file "$SKIP_FILE" 2>/dev/null |
		/opt/muos/bin/rg --pcre2 -i "/(?!.*\/).*$1" |
		sed "s|^$S_DIR/||"
}

{
	while IFS= read -r F_NAME; do
		RG_SEARCH "$F_NAME"
	done <"$TMP_FRIENDLY_FILES"
	RG_SEARCH "$S_TERM"
} | sort -u >"$TMP_FILES"

# Create and populate JSON structure for parsing in muxsearch
jq -n --arg lookup "$S_TERM" --arg directory "$S_DIR" '
    {lookup: $lookup, directory: $directory, folders: {}}
' >"$TMP_RESULTS"

while IFS= read -r RESULT; do
	jq --arg dir "$(dirname "$RESULT")" --arg file "$(basename "$RESULT")" '
        (.folders[$dir].content += [$file]) //
        (.folders[$dir] = { content: [$file] })
    ' "$TMP_RESULTS" >"$TMP_RESULTS.tmp"
	mv "$TMP_RESULTS.tmp" "$TMP_RESULTS"
done <"$TMP_FILES"

jq '.folders |= (to_entries | sort_by(.key) | from_entries)' "$TMP_RESULTS" >"$RESULTS_JSON"
