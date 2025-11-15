#!/bin/sh

USAGE() {
	printf "Usage: %s <search term> <directory1> [directory2 ...]\n" "$0"
	exit 1
}

[ "$#" -lt 2 ] && USAGE

. /opt/muos/script/var/func.sh

RESULTS_JSON="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/search.json"

# Ensure lookup tables exist
LOOKUP_DIR="/opt/muos/share/lookup"
[ ! -s "$LOOKUP_DIR/internal.txt" ] && /opt/muos/frontend/mulookup --gen-all

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

IRP() {
	printf "/mnt/%s/ROMS" "$1"
}

TMD() {
	printf "%s/%s\n" "$TMP_DIR" "$1"
}

TMP_ALL_BASE_IDS=$(TMD "all_base_ids")
TMP_ALL_BASE_IDS_SORTED=$(TMD "all_base_ids_sorted")
TMP_ALL_FILES=$(TMD "all_files")
TMP_ALL_LOOKUP_IDS=$(TMD "all_lookup_ids")
TMP_ALL_LOOKUP_IDS_SORTED=$(TMD "all_lookup_ids_sorted")
TMP_GOOD_RESULTS=$(TMD "good_results")
TMP_GOT_FILES=$(TMD "g_files")
TMP_JOINED_PRETTY=$(TMD "joined_pretty")
TMP_LISTS_FILTERED=$(TMD "lists_filtered")
TMP_MATCHED_IDS=$(TMD "matched_ids")
TMP_MATCHES=$(TMD "matches")
TMP_MATCHES_CLEAN=$(TMD "matches_clean")
TMP_MATCHES_MAP=$(TMD "matches_map")
TMP_MOUNT_MAP=$(TMD "mountmap")
TMP_PREFIXES=$(TMD "prefixes")
TMP_PREFIXES_RAW=$(TMD "prefixes_raw")
TMP_RESULTS=$(TMD "results")
TMP_RESULTS_NO_DUPE=$(TMD "results_nodupe")

JSON_OUT=$(TMD "final.json")

S_TERM="$1"

# Shift one argument over so we are left with only directories to search
shift

# Spit out the mount path, well just the single like 'mmc' or 'sdcard'
for ROOT in "$@"; do
	MP="$(dirname "$ROOT")"
	TAG="$(basename "$MP")"
	printf "%s|%s\n" "$ROOT" "$TAG" >>"$TMP_MOUNT_MAP"
done

SKIP_FILE="$(GET_VAR "device" "storage/sdcard/mount")/MUOS/info/skip.ini"
[ ! -s "$SKIP_FILE" ] && SKIP_FILE="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/skip.ini"

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
            for (i = 1; i < n; i++) dir = (i == 1 ? parts[i] : dir "/" parts[i])

            base = parts[n]
            base_id = base
            sub(/\.[^.]*$/, "", base_id)

            print fullpath "|" dir "|" base "|" base_id
        }' >>"$TMP_ALL_FILES"
done

# Extract all base_ids from ROM list
cut -d'|' -f4 "$TMP_ALL_FILES" >"$TMP_ALL_BASE_IDS"

# Extract friendly-name entries matching the search term
/opt/muos/bin/rg -i "$S_TERM" "$LOOKUP_DIR"/*.txt | sed 's|^[^:]*:||' >"$TMP_LISTS_FILTERED"
[ ! -s "$TMP_LISTS_FILTERED" ] && touch "$TMP_PREFIXES"

# Extract lookup base_ids from friendly lists
awk -F'|' '
    {
        base_id = $1
        pretty = $2
        if (tolower(pretty) ~ term) print base_id
        else if (tolower(base_id) ~ term) print base_id
    }
' term="$S_TERM" "$TMP_LISTS_FILTERED" >"$TMP_ALL_LOOKUP_IDS"

# Intersect ROM base_ids with lookup base_ids
sort -u "$TMP_ALL_BASE_IDS" >"$TMP_ALL_BASE_IDS_SORTED"
sort -u "$TMP_ALL_LOOKUP_IDS" >"$TMP_ALL_LOOKUP_IDS_SORTED"
comm -12 "$TMP_ALL_BASE_IDS_SORTED" "$TMP_ALL_LOOKUP_IDS_SORTED" >"$TMP_PREFIXES_RAW"

# Build final literal prefix patterns for ripgrep
awk '{print $0 "|"}' "$TMP_PREFIXES_RAW" >"$TMP_PREFIXES"

# Perform folder/global/internal friendly name lookups...
for FOLDER_FILE in "$LOOKUP_DIR"/*.txt; do
	BASENAME=$(basename "$FOLDER_FILE" .txt)
	/opt/muos/bin/rg -i -F -f "$TMP_PREFIXES" "$FOLDER_FILE" | sed "s/^/[FOLDER:$BASENAME] /" >>"$TMP_MATCHES"
done

/opt/muos/bin/rg -i -F -f "$TMP_PREFIXES" "$LOOKUP_DIR/global.txt" | sed 's/^/[GLOBAL] /' >>"$TMP_MATCHES"
/opt/muos/bin/rg -i -F -f "$TMP_PREFIXES" "$LOOKUP_DIR/internal.txt" | sed 's/^/[INTERNAL] /' >>"$TMP_MATCHES"

for S_DIR in "$@"; do
	/opt/muos/bin/rg --files "$S_DIR" --ignore-file "$SKIP_FILE" 2>/dev/null |
		/opt/muos/bin/rg --pcre2 -i "/[^/]*${S_TERM}.*" |
		while IFS= read -r FPATH; do
			rel="${FPATH#"$S_DIR/"}"
			DIR=$(dirname "$rel")
			BASE=$(basename "$rel")
			printf "%s|%s|%s\n" "$FPATH" "$DIR" "$BASE" >>"$TMP_GOT_FILES"
		done
done

# Strip our matches so they are clean to process then extract the matched ids
sed 's/^.*] //' "$TMP_MATCHES" >"$TMP_MATCHES_CLEAN"
cut -d'|' -f1 "$TMP_MATCHES_CLEAN" | sort -u >"$TMP_MATCHED_IDS"

# Select 'good' ROM files whose base_id appears in matched_ids
awk -F'|' '
    NR==FNR { id[$1]=1; next }
    {
        base_id=$4
        if (base_id in id) print $1 "|" $2 "|" $3
    }
' "$TMP_MATCHED_IDS" "$TMP_ALL_FILES" >"$TMP_GOOD_RESULTS"

# Chuck those back into our "found" files
cat "$TMP_GOOD_RESULTS" >>"$TMP_GOT_FILES"

# Clean our lookup matches to keep only "base_id|pretty"
sed 's/^.*] //' "$TMP_MATCHES" >"$TMP_MATCHES_CLEAN"

# Convert to map based on "base_id|pretty"
awk -F'|' '{ pretty[$1]=$2 } END { for (k in pretty) print k "|" pretty[k] }' \
	"$TMP_MATCHES_CLEAN" >"$TMP_MATCHES_MAP"

# Now to join g_files and the "pretty" map to fullpath|dir|base|pretty
if [ -s "$TMP_MATCHES_MAP" ]; then
	# We have at least one friendly name match so use use the map
	awk -F'|' '
        NR==FNR { pretty[$1]=$2; next }
        {
            full=$1; dir=$2; base=$3
            base_no_ext = base
            sub(/\.[^.]*$/, "", base_no_ext)
            if (base_no_ext in pretty) print full "|" dir "|" base "|" pretty[base_no_ext]
            else print full "|" dir "|" base "|" base_no_ext
        }
    ' "$TMP_MATCHES_MAP" "$TMP_GOT_FILES" >"$TMP_JOINED_PRETTY"
else
	# No matches at all so just use base_no_ext as the "pretty" name
	awk -F'|' '
        {
            full=$1; dir=$2; base=$3
            base_no_ext = base
            sub(/\.[^.]*$/, "", base_no_ext)
            print full "|" dir "|" base "|" base_no_ext
        }
    ' "$TMP_GOT_FILES" >"$TMP_JOINED_PRETTY"
fi

# Add the mount 'tag' of mmc/sdcard/etc using the mount map file
awk -F'|' -v OFS='|' '
    NR==FNR { tag[$1]=$2; next }
    {
        full=$1; dir=$2; base=$3; pretty=$4
        found=""
        for (p in tag) if (full ~ ("^" p)) { found = tag[p]; break }
        if (found != "") print found, dir, base, pretty
    }
' "$TMP_MOUNT_MAP" "$TMP_JOINED_PRETTY" >"$TMP_RESULTS"

# Purge duplicated entries
sort -u "$TMP_RESULTS" >"$TMP_RESULTS_NO_DUPE"

# It's 11pm and I'm tired after a long week, I'm sure there is a better way than building
# the fucking JSON structure manually... we probably don't need all the spaces but trying
# to debug a compact JSON is a pain in the arse.  So here we are, we could probably maybe
# use jq somehow to make things easier on ourselves but this will have to suffice for now
{
	printf "{\n"
	printf "  \"lookup\": \"%s\",\n" "$(printf '%s' "$S_TERM" | jq -R . | sed 's/^"//;s/"$//')"

	printf "  \"directories\": [\n"
	awk -F'|' '{print $1}' "$TMP_RESULTS_NO_DUPE" |
		sort -u |
		while IFS= read -r TAG; do
			printf "    \"%s\",\n" "$(IRP "$TAG")"
		done |
		sed '$ s/,$//'
	printf "  ],\n"

	printf "  \"folders\": {\n"

	LAST_DIR=""
	HAVE_ITEMS=0

	sort "$TMP_RESULTS_NO_DUPE" |
		while IFS='|' read -r TAG DIR BASE PRETTY; do
			[ -z "$BASE" ] && continue
			[ -z "$PRETTY" ] && continue

			FULL_DIR="$(IRP "$TAG")/$DIR"
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
