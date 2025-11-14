#!/bin/sh

set -eu

USAGE() {
	printf "Usage: %s <search term> <directory1> [directory2 ...]\n" "$0"
	exit 1
}

[ "$#" -lt 2 ] && USAGE

. /opt/muos/script/var/func.sh

RESULTS_JSON="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/search.json"
FRIENDLY_JSON="$MUOS_STORE_DIR/info/name/global.json"

SKIP_FILE="$(GET_VAR "device" "storage/sdcard/mount")/MUOS/info/skip.ini"
[ ! -s "$SKIP_FILE" ] && SKIP_FILE="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/skip.ini"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

S_TERM="$1"

# Shift one argument over so we are left with only directories to search
shift

TMP_MOUNT_MAP="$TMP_DIR/mountmap.txt"
: >"$TMP_MOUNT_MAP"

# Spit out the mount path, well just the single like 'mmc' or 'sdcard'
for ROOT in "$@"; do
	MP="$(dirname "$ROOT")"
	TAG="$(basename "$MP")"
	printf "%s|%s\n" "$ROOT" "$TAG" >>"$TMP_MOUNT_MAP"
done

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

TMP_ALL_FILES="$TMP_DIR/all_files.txt"
: >"$TMP_ALL_FILES"

# Walk the directory and list all files via ripgrep.  Then for each path
# we'll go into chuck in full absolute path, relative directory, filename,
# and filename without extension.  The four fields (with a fancy pipe) to
# $TMP_ALL_FILES for later indexing.  This is as fast as we can possibly go.
for S_DIR in "$@"; do
	/opt/muos/bin/rg --files "$S_DIR" --ignore-file "$SKIP_FILE" 2>/dev/null |
		awk -v ROOT="$S_DIR/" -F/ '
        {
            fullpath = $0
            rel = fullpath
            sub("^" ROOT, "", rel)

            n = split(rel, parts, "/")

            dir = ""
            for (i = 1; i < n; i++)
                dir = (i == 1 ? parts[i] : dir "/" parts[i])

            base = parts[n]
            base_id = base
            sub(/\.[^.]*$/, "", base_id)

            print fullpath "|" dir "|" base "|" base_id
        }
    ' >>"$TMP_ALL_FILES"
done

TMP_GOT_FILES="$TMP_DIR/g_files.txt"
: >"$TMP_GOT_FILES"

for S_DIR in "$@"; do
	/opt/muos/bin/rg --files "$S_DIR" --ignore-file "$SKIP_FILE" 2>/dev/null |
		/opt/muos/bin/rg --pcre2 -i "/(?!.*\/).*$S_TERM" |
		while IFS= read -r FPATH; do
			rel="${FPATH#"$S_DIR/"}"
			DIR=$(dirname "$rel")
			BASE=$(basename "$rel")
			printf "%s|%s|%s\n" "$FPATH" "$DIR" "$BASE" >>"$TMP_GOT_FILES"
		done
done

TMP_RESULTS="$TMP_DIR/results.txt"
SEEN="$TMP_DIR/seen.txt"
: >"$TMP_RESULTS"
: >"$SEEN"

# Time to structure our flat file with good ol' pipes because that way
# it will be easier to debug later on.  Is it performant? Look probably
# not, we could probably just go straight to JSON but again, I'm tired.
while IFS='|' read -r FPATH DIR BASE; do
	BASE_ID="${BASE%.*}"
	PRETTY="$BASE_ID"

	SYS=$(basename "$DIR")
	LOOKUP=$(/opt/muos/frontend/mulookup -f "$SYS" "$S_TERM" 2>/dev/null)

	MATCH=""
	if [ -n "$LOOKUP" ]; then
		TMP_LOOK="$TMP_DIR/lookup.txt"
		printf "%s\n" "$LOOKUP" >"$TMP_LOOK"

		while IFS='|' read -r ID NAME; do
			ID_LC=$(printf "%s" "$ID" | tr '[:upper:]' '[:lower:]')
			BASE_ID_LC=$(printf "%s" "$BASE_ID" | tr '[:upper:]' '[:lower:]')
			[ "$ID_LC" = "$BASE_ID_LC" ] && MATCH="$ID|$NAME" && break
		done <"$TMP_LOOK"
	fi

	[ -n "$MATCH" ] && PRETTY="${MATCH#*\|}"

	TAG="$(
		awk -F'|' -v p="$FPATH" '
            p ~ ("^" $1) { print $2; exit }
        ' "$TMP_MOUNT_MAP"
	)"

	[ "$BASE" = "." ] && continue
	[ -z "$BASE" ] && continue

	printf "%s|%s|%s|%s\n" "$TAG" "$DIR" "$BASE" "$PRETTY" >>"$TMP_RESULTS"
	printf "%s|%s\n" "$DIR" "$BASE" >>"$SEEN"
done <"$TMP_GOT_FILES"

TMP_MAPPER="$TMP_DIR/mapper.txt"
: >"$TMP_MAPPER"

# Look we are back to being slow because of the following reverse lookups but
# that's the price you pay for MAME still having to use 8.3 filename systems!
awk -F'|' '{print $2}' "$TMP_ALL_FILES" | cut -d/ -f1 | sort -u |
	while IFS= read -r SYS; do
		[ -z "$SYS" ] && continue
		LOOKUP=$(/opt/muos/frontend/mulookup -f "$SYS" "$S_TERM" 2>/dev/null)
		[ -z "$LOOKUP" ] && continue

		printf "%s\n" "$LOOKUP" |
			while IFS='|' read -r ID NAME; do
				[ -z "$ID" ] && continue
				printf "%s|%s\n" "$(printf "%s" "$ID" | tr '[:upper:]' '[:lower:]')" "$NAME" >>"$TMP_MAPPER"
			done
	done

TMP_REV_MATCHES="$TMP_DIR/rev_matches.txt"
: >"$TMP_REV_MATCHES"

# Now that we have the reverse lookups time for some matchmaking!
# Love is in the air, doo doo doo...
awk -F'|' '
    NR==FNR { map[$1]=$2; next }
    {
        base_id_l = tolower($4)
        if (base_id_l == "" || !(base_id_l in map)) next
        print $1 "|" $2 "|" $3 "|" map[base_id_l]
    }
' "$TMP_MAPPER" "$TMP_ALL_FILES" >"$TMP_REV_MATCHES"

while IFS='|' read -r FPATH DIR BASE PRETTY; do
	[ -z "$BASE" ] && continue

	if grep -qx "$DIR|$BASE" "$SEEN" 2>/dev/null; then
		continue
	fi

	# The following is complete bullshit because the lookup relies on
	# a prefix match in $TMP_MOUNT_MAP and then assumes the first
	# matching line is the correct one and silently falls apart if
	# multiple paths share a prefix... for fucks sake!
	TAG="$(
		awk -F'|' -v p="$FPATH" '
            p ~ ("^" $1) { print $2; exit }
        ' "$TMP_MOUNT_MAP"
	)"

	[ "$BASE" = "." ] && continue
	[ -z "$BASE" ] && continue

	printf "%s|%s|%s|%s\n" "$TAG" "$DIR" "$BASE" "$PRETTY" >>"$TMP_RESULTS"
	printf "%s|%s\n" "$DIR" "$BASE" >>"$SEEN"
done <"$TMP_REV_MATCHES"

# Uncomment the below to get a flat file debug output so you can see how we structure
# the results file for parsing below with the JSON builder...
# cat "$TMP_RESULTS"

INFER_ROM_PATH() {
	printf "/mnt/%s/ROMS" "$1"
}

JSON_OUT="$TMP_DIR/final.json"

# It's 11pm and I'm tired after a long week, I'm sure there is a better way than building
# the fucking JSON structure manually... we probably don't need all the spaces but trying
# to debug a compact JSON is a pain in the arse.  So here we are, we could probably maybe
# use jq somehow to make things easier on ourselves but this will have to suffice for now
{
	printf "{\n"
	printf "  \"lookup\": \"%s\",\n" "$(printf '%s' "$S_TERM" | jq -R . | sed 's/^"//;s/"$//')"

	printf "  \"directories\": [\n"
	awk -F'|' '{print $1}' "$TMP_RESULTS" |
		sort -u |
		while IFS= read -r TAG; do
			printf "    \"%s\",\n" "$(INFER_ROM_PATH "$TAG")"
		done |
		sed '$ s/,$//'
	printf "  ],\n"

	printf "  \"folders\": {\n"

	LAST_DIR=""
	HAVE_ITEMS=0

	sort "$TMP_RESULTS" |
		while IFS='|' read -r TAG DIR BASE PRETTY; do
			[ -z "$BASE" ] && continue
			[ -z "$PRETTY" ] && continue

			FULL_DIR="$(INFER_ROM_PATH "$TAG")/$DIR"
			if [ "$FULL_DIR" != "$LAST_DIR" ]; then
				if [ "$LAST_DIR" != "" ] && [ "$HAVE_ITEMS" -eq 1 ]; then
					printf "\n      ]\n    },\n"
				fi

				printf "    \"%s\": {\n" "$FULL_DIR"
				printf "      \"content\": [\n"

				HAVE_ITEMS=0
			fi

			if [ "$HAVE_ITEMS" -eq 1 ]; then
				printf ",\n"
			fi

			printf "        {\n          \"file\": \"%s\",\n          \"name\": \"%s\"\n        }" \
				"$(printf '%s' "$BASE" | jq -R . | sed 's/^"//;s/"$//')" \
				"$(printf '%s' "$PRETTY" | jq -R . | sed 's/^"//;s/"$//')"

			HAVE_ITEMS=1
			LAST_DIR="$FULL_DIR"
		done

	if [ "$HAVE_ITEMS" -eq 1 ]; then
		printf "\n      ]\n    }\n"
	fi

	printf "\n      ]\n"
	printf "    }\n"
	printf "  }\n"
	printf "}\n"

} >"$JSON_OUT"

# descent into madness
mv "$JSON_OUT" "$RESULTS_JSON"
