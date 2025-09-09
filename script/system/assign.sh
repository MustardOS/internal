#!/bin/sh

. /opt/muos/script/var/func.sh

ASSIGN_DIR="$MUOS_SHARE_DIR/info/assign"

OUTPUT_FILE="$ASSIGN_DIR/assign.json"
LOG_FILE="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/assign_gen.txt"

TMP_JSON="/tmp/assign_add.json"
TMP_LIST="/tmp/assign_list.txt"
TMP_KEYS="/tmp/assign_keys.txt"

ADDED=0
SKIPPED=0
VERBOSE=0
PURGE=0

for ARG in "$@"; do
	case "$ARG" in
		-p | --purge) PURGE=1 ;;
		-v | --verbose) VERBOSE=1 ;;
	esac
done

[ "$PURGE" -eq 1 ] && rm -f "$OUTPUT_FILE"
[ "$VERBOSE" -eq 1 ] && : >"$LOG_FILE"

[ -f "$OUTPUT_FILE" ] || echo "{}" >"$OUTPUT_FILE"
: >"$TMP_JSON"
: >"$TMP_LIST"
: >"$TMP_KEYS"

jq -r 'keys[]' "$OUTPUT_FILE" >"$TMP_KEYS"
find "$ASSIGN_DIR" -type f -name "*.ini" >"$TMP_LIST"

ENTRIES=""
while read -r INI; do
	SECTION=0
	DIR_NAME=$(basename "$(dirname "$INI")")
	while IFS= read -r LINE || [ -n "$LINE" ]; do
		case "$LINE" in
			"[friendly]") SECTION=1 ;;
			\[*]) SECTION=0 ;;
			"") continue ;;
			*)
				if [ "$SECTION" -eq 1 ]; then
					KEY=$(printf '%s' "$LINE" | tr -d '[:space:]')
					if grep -Fxq "$KEY" "$TMP_KEYS"; then
						[ "$VERBOSE" -eq 1 ] && printf "Ignore '%s' already exists\n" "$KEY" | tee -a "$LOG_FILE"
						SKIPPED=$((SKIPPED + 1))
					else
						[ "$VERBOSE" -eq 1 ] && printf "Assign '%s' to '%s'\n" "$KEY" "$DIR_NAME" | tee -a "$LOG_FILE"
						ENTRIES="$ENTRIES\"$KEY\":\"$DIR_NAME\","
						echo "$KEY" >>"$TMP_KEYS"
						ADDED=$((ADDED + 1))
					fi
				fi
				;;
		esac
	done <"$INI"
done <"$TMP_LIST"

rm -f "$TMP_LIST" "$TMP_KEYS"

if [ -n "$ENTRIES" ]; then
	echo "{${ENTRIES%,}}" >"$TMP_JSON"
else
	echo "{}" >"$TMP_JSON"
fi

jq -S -s 'add' "$OUTPUT_FILE" "$TMP_JSON" >"$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
rm -f "$TMP_JSON"

[ "$VERBOSE" -eq 1 ] && {
	printf "\nAssign Added\t\t%d\n" "$ADDED"
	printf "Assign Skipped\t\t%d\n" "$SKIPPED"
	printf "\nTotal Assign Systems\t\t%d\n\n" "$((ADDED + SKIPPED))"
} | tee -a "$LOG_FILE"
