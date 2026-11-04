#!/bin/sh

. /opt/muos/script/var/base.sh

LOCK_RUN storage-write "$@" || {
	[ "$LOCK_STATUS" -eq 75 ] && printf '%s\n' "Core definition sync could not acquire the storage lock" >&2
	exit "$LOCK_STATUS"
}

ARCHIVE=${1:-}
MANIFEST_ROOT="$MUOS_STORE_DIR/info/manifest"
TARGET="$MANIFEST_ROOT/coresync"

[ -r "$ARCHIVE" ] || {
	printf 'Core definition archive is not readable: %s\n' "$ARCHIVE" >&2
	exit 1
}

mkdir -p "$MANIFEST_ROOT" || exit 1
WORK=$(mktemp -d "$MANIFEST_ROOT/.coresync.XXXXXX") || exit 1
STAGED=""
BACKUP=""
FAILED=""
INSTALLED=0

CORE_SYNC_CLEANUP() {
	[ -n "$STAGED" ] && [ -e "$STAGED" ] && rm -rf "$STAGED"
	if [ "$INSTALLED" -eq 1 ]; then
		[ ! -e "$TARGET" ] || rm -rf "$TARGET"
		[ -z "$BACKUP" ] || [ ! -e "$BACKUP" ] || mv "$BACKUP" "$TARGET"
	elif [ -n "$BACKUP" ] && [ -e "$BACKUP" ]; then
		[ -e "$TARGET" ] || mv "$BACKUP" "$TARGET"
	fi
	[ -n "$FAILED" ] && [ -e "$FAILED" ] && rm -rf "$FAILED"
	[ -d "$WORK" ] && rm -rf "$WORK"
}

trap 'CORE_SYNC_CLEANUP' EXIT
trap 'exit 1' HUP INT TERM

unzip -Z1 "$ARCHIVE" >"$WORK/entries" || exit 1
while IFS= read -r ENTRY; do
	case "$ENTRY" in
		/* | *'/../'* | '../'* | *'/..' | *'//'* | '')
			printf 'Unsafe core definition archive entry: %s\n' "$ENTRY" >&2
			exit 1
			;;
		core/ | core/*/) ;;
		core/*/*.json)
			RELATIVE=${ENTRY#core/}
			case "$RELATIVE" in
				*/*/*) printf 'Unsupported core definition path: %s\n' "$ENTRY" >&2; exit 1 ;;
			esac
			;;
		*)
			printf 'Unsupported core definition archive entry: %s\n' "$ENTRY" >&2
			exit 1
			;;
	esac
done <"$WORK/entries"

unzip -qq "$ARCHIVE" -d "$WORK" || exit 1
SOURCE="$WORK/core"
[ -d "$SOURCE" ] || {
	printf 'Core definition archive has no core directory\n' >&2
	exit 1
}

if find "$SOURCE" -type l -print -quit | grep -q . ||
	find "$SOURCE" -type f ! -name '*.json' -print -quit | grep -q .; then
	printf 'Core definition archive contains an unsupported entry\n' >&2
	exit 1
fi

COUNT=0
for DEFINITION in "$SOURCE"/*/*.json; do
	[ -f "$DEFINITION" ] || continue
	jq -e '
		type == "object" and
		(.runtime == "libretro" or .runtime == "external" or .runtime == "pickles") and
		(.default | type == "string") and
		((if .runtime == "external" then .external else .libretro end)[.default] != null)
	' "$DEFINITION" >/dev/null || {
		printf 'Invalid core definition: %s\n' "$DEFINITION" >&2
		exit 1
	}
	COUNT=$((COUNT + 1))
done

[ "$COUNT" -gt 0 ] || {
	printf 'Core definition archive is empty\n' >&2
	exit 1
}

STAGED="$MANIFEST_ROOT/.coresync.new.$$"
mv "$SOURCE" "$STAGED" || exit 1

if [ -e "$TARGET" ]; then
	BACKUP="$MANIFEST_ROOT/.coresync.old.$$"
	mv "$TARGET" "$BACKUP" || exit 1
fi

if ! mv "$STAGED" "$TARGET"; then
	[ -n "$BACKUP" ] && mv "$BACKUP" "$TARGET"
	exit 1
fi
STAGED=""
INSTALLED=1

SYNC_ERROR=""
if ! /opt/muos/script/system/assign.sh >/dev/null 2>&1; then
	SYNC_ERROR="Core assignments could not be regenerated"
elif ! /opt/muos/script/system/catalogue.sh >/dev/null 2>&1; then
	SYNC_ERROR="Catalogue directories could not be generated"
fi

if [ -n "$SYNC_ERROR" ]; then
	FAILED="$MANIFEST_ROOT/.coresync.failed.$$"
	mv "$TARGET" "$FAILED" || exit 1
	if [ -n "$BACKUP" ]; then
		mv "$BACKUP" "$TARGET" || exit 1
		BACKUP=""
	fi
	rm -rf "$FAILED"
	FAILED=""
	INSTALLED=0
	/opt/muos/script/system/assign.sh >/dev/null 2>&1
	/opt/muos/script/system/catalogue.sh >/dev/null 2>&1
	printf '%s; definitions were rolled back\n' "$SYNC_ERROR" >&2
	exit 1
fi

[ -n "$BACKUP" ] && rm -rf "$BACKUP"
BACKUP=""
INSTALLED=0
printf 'Installed %s core definitions\n' "$COUNT"
