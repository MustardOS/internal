#!/bin/sh

. /opt/muos/script/var/func.sh

BUNDLED_MANIFEST_DIR="$MUOS_SHARE_DIR/info/manifest"
USER_MANIFEST_DIR="$MUOS_STORE_DIR/info/manifest"

OUTPUT_FILE="$USER_MANIFEST_DIR/assign.json"
LOG_FILE="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/assign_gen.txt"

ASSIGN_WORK=""
OUTPUT_TMP=""

ASSIGN_CLEANUP() {
	[ -n "$ASSIGN_WORK" ] && [ -d "$ASSIGN_WORK" ] && rm -rf "$ASSIGN_WORK"
	[ -n "$OUTPUT_TMP" ] && [ -f "$OUTPUT_TMP" ] && rm -f "$OUTPUT_TMP"
}

trap 'ASSIGN_CLEANUP' EXIT
trap 'exit 1' HUP INT TERM

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

[ "$VERBOSE" -eq 1 ] && : >"$LOG_FILE"

mkdir -p "$USER_MANIFEST_DIR" || exit 1
ASSIGN_WORK=$(mktemp -d /tmp/muos-assign.XXXXXX) || exit 1
chmod 700 "$ASSIGN_WORK" || exit 1

TMP_BASE="$ASSIGN_WORK/base.json"
TMP_JSON="$ASSIGN_WORK/add.json"
TMP_LIST="$ASSIGN_WORK/list.txt"
TMP_KEYS="$ASSIGN_WORK/keys.txt"

if [ "$PURGE" -eq 0 ] && [ -f "$OUTPUT_FILE" ] && jq -e -S 'select(type == "object")' "$OUTPUT_FILE" >"$TMP_BASE"; then
	:
else
	printf '{}\n' >"$TMP_BASE"
fi

jq -r 'keys[]' "$TMP_BASE" >"$TMP_KEYS"

MANIFEST_FILES=""
for C_FILE in libretro external; do
	if [ -r "$USER_MANIFEST_DIR/$C_FILE.json" ] && jq -e 'type == "object"' "$USER_MANIFEST_DIR/$C_FILE.json" >/dev/null 2>&1; then
		MANIFEST_FILES="$MANIFEST_FILES $USER_MANIFEST_DIR/$C_FILE.json"
	elif [ -r "$BUNDLED_MANIFEST_DIR/$C_FILE.json" ] && jq -e 'type == "object"' "$BUNDLED_MANIFEST_DIR/$C_FILE.json" >/dev/null 2>&1; then
		MANIFEST_FILES="$MANIFEST_FILES $BUNDLED_MANIFEST_DIR/$C_FILE.json"
	fi
done

if [ -z "$MANIFEST_FILES" ]; then
	printf "No core definitions found in %s\n" "$BUNDLED_MANIFEST_DIR" >&2
	exit 1
fi

# shellcheck disable=SC2086
jq -r -s '
	[ .[] | to_entries[] | . as $e | ($e.value.friendly // [])[] | "\(.)\t\($e.key)" ]
	| unique[]
' $MANIFEST_FILES >"$TMP_LIST"

set --
while IFS="$(printf '\t')" read -r KEY SYSTEM || [ -n "$KEY" ]; do
	[ -n "$KEY" ] && [ -n "$SYSTEM" ] || continue
	if grep -Fxq "$KEY" "$TMP_KEYS"; then
		[ "$VERBOSE" -eq 1 ] && printf "Ignore '%s' already exists\n" "$KEY" | tee -a "$LOG_FILE"
		SKIPPED=$((SKIPPED + 1))
	else
		[ "$VERBOSE" -eq 1 ] && printf "Assign '%s' to '%s'\n" "$KEY" "$SYSTEM" | tee -a "$LOG_FILE"
		set -- "$@" "$KEY" "$SYSTEM"
		printf '%s\n' "$KEY" >>"$TMP_KEYS"
		ADDED=$((ADDED + 1))
	fi
done <"$TMP_LIST"

jq -n --args \
	'$ARGS.positional as $items | reduce range(0; $items|length; 2) as $i ({}; .[$items[$i]] = $items[$i + 1])' \
	"$@" >"$TMP_JSON" || exit 1

OUTPUT_TMP=$(mktemp "$USER_MANIFEST_DIR/.assign.json.XXXXXX") || exit 1
if ! jq -S -s '.[0] * .[1]' "$TMP_BASE" "$TMP_JSON" >"$OUTPUT_TMP" || ! chmod 644 "$OUTPUT_TMP" ||
	! mv -f "$OUTPUT_TMP" "$OUTPUT_FILE"; then
	rm -f "$OUTPUT_TMP"
	OUTPUT_TMP=""
	exit 1
fi
OUTPUT_TMP=""

[ "$VERBOSE" -eq 1 ] && {
	printf "\nAssign Added\t\t%d\n" "$ADDED"
	printf "Assign Skipped\t\t%d\n" "$SKIPPED"
	printf "\nTotal Assign Systems\t\t%d\n\n" "$((ADDED + SKIPPED))"
} | tee -a "$LOG_FILE"

exit 0
