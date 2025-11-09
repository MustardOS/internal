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

TMP_FRIENDLY="/tmp/f_result.json"
TMP_FRIENDLY_FILES="$TMP_DIR/f_files.txt"

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

# Convert directories array to JSON
directories=$(printf '%s\n' "$@" | jq -R . | jq -s .)

# Process all directories and create JSON structure in a single pipeline
{
	# Process each directory and output all matching files
	for S_DIR in "$@"; do
		/opt/muos/bin/rg --color=never --files "$S_DIR" --ignore-file "$SKIP_FILE" 2>/dev/null |
		/opt/muos/bin/rg --color=never --pcre2 -i "/(?!.*\/).*$S_TERM" | sed "s|^$S_DIR/||" || true
	done
} |
# Input to jq: File paths (one per line)
# Example:
#   /mnt/sdcard/ROMS/Pico-8/awesome_platform_adventure.p8
#   /mnt/sdcard/ROMS/Ports/open_source_adventure.zip
# jq -R: Read each line as string instead of JSON
# jq -s: read all inputs into an array and use it as
# the single input value
jq -R . | jq -s --arg lookup "$S_TERM" --argjson directories "$directories" '
	# Transform each file path string into {dir:..., file:...} object
	map(split("/") | {dir: (.[:-1] | join("/")), file: .[-1]}) |

	# Group all objects by their "dir" field (sorted)
	group_by(.dir) |
	map({
		# If directory is empty (e.g. local search, with path removed by sed above),
		# use "." instead
		key: (.[0].dir | if . == "" then "." else . end),
		value: {content: map(.file) | sort}
	}) |

	# Convert array of {key:..., value:...} objects into single object
	from_entries |

	# Final JSON structure: Create object with lookup term, directories, and folders
	# Example:
	#   {
	#     "lookup": "adventure",
	#     "directories": ["/mnt/sdcard/ROMS"],
	#     "folders": {
	#       "/mnt/sdcard/ROMS/Pico-8": {
	#         "content": ["awesome_platform_adventure.p8"]
	#       },
	#       "/mnt/sdcard/ROMS/Ports": {
	#         "content": ["open_source_adventure.zip"]
	#       }
	#     }
	#   }
	{lookup: $lookup, directories: $directories, folders: .}
' > "$RESULTS_JSON"
