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

S_TERM="$1"

# Shift one argument over so we are left with only directories to search
shift

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
TMP_MATCHES="$TMP_DIR/matches.txt"

# TODO: https://github.com/MustardOS/internal/pull/573#pullrequestreview-3035531164
# Ensure friendly file naming scheme system is being used at /run/muos/storage/info/name/global.json.

# Convert directories array to JSON
directories=$(printf '%s\n' "$@" | jq -R . | jq -s .)

# Process all directories and create JSON structure in a single pipeline
{
	# Process each directory and output all matching files
	for S_DIR in "$@"; do
		/opt/muos/bin/rg --color=never --files "$S_DIR" --ignore-file "$SKIP_FILE" 2>/dev/null |
		/opt/muos/bin/rg --color=never --pcre2 -i "/(?!.*\/).*$S_TERM" |
		# sed: Remove the leading directory path from each file (only affects local search)
        # || true: Prevent script exit when no matches found (rg exits with status 1)
        sed "s|^$S_DIR/||" >> "$TMP_MATCHES" || true
	done
}

# Second stage: Process the collected matches into JSON
# This avoids keeping the entire pipeline active for the full duration
cat "$TMP_MATCHES" |
# Input to jq: File paths (one per line)
# Example:
#   /mnt/sdcard/ROMS/Pico-8/awesome_platform_adventure.p8
#   /mnt/sdcard/ROMS/Ports/open_source_adventure.zip
jq -R . | jq -s --arg lookup "$S_TERM" --argjson directories "$directories" '
	# map(...): Transform each file path string into {dir:..., file:...} object
	map(split("/") | {dir: (.[:-1] | join("/")), file: .[-1]}) |

	# group_by(.dir): Group all objects by their "dir" field (sorted)
	group_by(.dir) |

	map({
		# If directory is empty (e.g. local search, with path removed by sed above),
		# use "." instead
		key: (.[0].dir | if . == "" then "." else . end),
		value: {content: map(.file) | sort}
	}) |

	# from_entries: Convert array of {key:..., value:...} objects into single object
	from_entries |

	# Final JSON structure: Create object with lookup term, directories, and folders
	# e.g.
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
