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

# Convert directories array to JSON
directories=$(printf '%s\n' "$@" | jq -R . | jq -s .)

# Process all directories and create JSON structure in a single pipeline
{
	# Process each directory and output all matching files
	for S_DIR in "$@"; do
		# rg --files: List all files in directory (no content search, just enumerate files)
		# --color=never: Disable ANSI color codes (clean output for piping)
		# --ignore-file: Use skip.ini to exclude unwanted files/directories
		# 2>/dev/null: Suppress permission denied errors
		/opt/muos/bin/rg --color=never --files "$S_DIR" --ignore-file "$SKIP_FILE" 2>/dev/null |

		# rg (second call): Filter filenames by search term
		# --color=never: Disable ANSI color codes for clean piping
		# --pcre2: Use Perl-compatible regex engine (supports advanced patterns)
		# -i: Case-insensitive matching
		# "/(?!.*\/).*$S_TERM": Regex to match only filenames, not directory paths
		#   /: Match paths ending with slash (file paths)
		#   (?!.*\/): Negative lookahead - ensure no slash after this point
		#   .*$S_TERM: Match any characters followed by search term
		# || true: Prevent script exit when no matches found (rg exits with status 1)
		/opt/muos/bin/rg --color=never --pcre2 -i "/(?!.*\/).*$S_TERM" || true
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
	# map(...): Transform each file path string into {dir:..., file:...} object
	#   split("/"): Split path by "/" into array of components
	#   {dir: (.[:-1] | join("/")), file: .[-1]}: Create object where:
	#     .[:-1]: All elements except last (directory components)
	#     join("/"): Rejoin directory components with "/"
	#    .[-1]: Last element (filename)
	map(split("/") | {dir: (.[:-1] | join("/")), file: .[-1]}) |

	# group_by(.dir): Group all objects by their "dir" field (sorted)
	# Creates array of arrays, each sub-array contains objects with same directory
	group_by(.dir) |

	# map({...}): Transform each group into key-value pair object
	map({
		# key: .[0].dir: Use directory from first object in group (all have same dir)
		key: .[0].dir,

		# value: {content: [...]}: Create object with "content" array
		# map(.file): Extract "file" field from each object in group
		# | sort: Sort filenames alphabetically
		value: {content: map(.file) | sort}
	}) |

	# from_entries: Convert array of {key:..., value:...} objects into single object
	# Each key becomes a property name, each value becomes the property value
	from_entries |

	# Final JSON structure: Create object with lookup term, directories, and folders
	#   $lookup: Use the lookup variable passed from shell
	#   $directories: Use the directories array passed from shell
	#   .: Reference the current grouped folders object
	#
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
