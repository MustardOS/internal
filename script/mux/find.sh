#!/bin/sh

set -eu

USAGE() {
	printf "Usage: %s <search term> <directory1> [directory2 ...]\n" "$0"
	exit 1
}

[ "$#" -lt 2 ] && USAGE

. /opt/muos/script/var/func.sh

RESULTS_JSON="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/search.json"
FRIENDLY_JSON="$MUOS_STORE_DIR/info/name/general.json"
SKIP_FILE="$(GET_VAR "device" "storage/sdcard/mount")/MUOS/info/skip.ini"
[ ! -s "$SKIP_FILE" ] && SKIP_FILE="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/skip.ini"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

S_TERM="$1"

# Shift one argument over so we are left with only directories to search
shift

TMP_FRIENDLY="$TMP_DIR/f_result.json"
TMP_FRIENDLY_FILES="$TMP_DIR/f_files.txt"

# Generate friendly name JSON so we can use that for the search results for quicker parsing
if [ -f "$FRIENDLY_JSON" ]; then
	/opt/muos/bin/rg -i "$S_TERM" "$FRIENDLY_JSON" |
		sed -e '1s/^/{\n/' -e '$s/,$//' -e '$a}' >"$TMP_FRIENDLY"
	jq -r 'keys[]' "$TMP_FRIENDLY" >"$TMP_FRIENDLY_FILES"
else
	printf "{}" >"$TMP_FRIENDLY"
	: >"$TMP_FRIENDLY_FILES"
fi

TMP_FILES="$TMP_DIR/files.txt"
directories=$(printf '%s\n' "$@" | jq -R . | jq -s .)

# Okay now we'll go through each of the requested directories and find content based on the search term
for S_DIR in "$@"; do
	/opt/muos/bin/rg --files "$S_DIR" --ignore-file "$SKIP_FILE" 2>/dev/null |
		/opt/muos/bin/rg --pcre2 -i "/(?!.*\/).*$S_TERM" |
		sed "s|^$S_DIR/||" | while IFS= read -r FILE; do
		DIR=$(dirname "$FILE")
		BASE=$(basename "$FILE")
		printf "%s\t%s\n" "$DIR" "$BASE" >>"$TMP_FILES"
	done
done

# Batch process all of the names we found through our lookup program
TMP_NAMES="$TMP_DIR/names.txt"
cut -f2 "$TMP_FILES" | sed -E 's/\.[^.]+$//' | /opt/muos/frontend/mulookup --batch >"$TMP_NAMES"

paste "$TMP_FILES" "$TMP_NAMES" |
	jq -R -s --arg lookup "$S_TERM" --argjson directories "$directories" '
    split("\n") | map(select(length>0)) |
    map(split("\t")) |
    group_by(.[0]) |
    map({
        key: (.[0][0] | if . == "" then "." else . end),
        value: {
            content: map({
                file: .[1],
                name: .[2]
            }) | sort_by(.file)
        }
    }) | from_entries |
    {lookup: $lookup, directories: $directories, folders: .}
' >"$RESULTS_JSON"
