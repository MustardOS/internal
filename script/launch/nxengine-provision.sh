#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

NX_LOGPATH="${1:-/dev/null}"
NX_BIOS_ROOT="$MUOS_STORE_DIR/bios"
NX_TARGET="$NX_BIOS_ROOT/nxengine"
NX_CONTENT="$NX_TARGET/Doukutsu.exe"
NX_LOCK="$NX_BIOS_ROOT/.nxengine.lock"
NX_LOCK_HELD=0
NX_WORK=""
NX_URL="https://bot.libretro.com/assets/cores/Cave%20Story/Cave%20Story%20(En).zip"
NX_SHA256="b8e1b4ed667a6b075811abc52e468ef3c534e7e24e2ef0bc44d8ff95999c83fd"

NX_LOG() {
	printf '%s\n' "$1" >>"$NX_LOGPATH"
}

NX_CLEANUP() {
	ARCHIVE_CACHE_CLEANUP
	[ -n "$NX_WORK" ] && [ -d "$NX_WORK" ] && rm -rf "$NX_WORK"
	if [ "$NX_LOCK_HELD" -eq 1 ]; then
		rm -f "$NX_LOCK/pid" "$NX_LOCK/start" 2>/dev/null
		rmdir "$NX_LOCK" 2>/dev/null
	fi
}

NX_ACQUIRE_LOCK() {
	if mkdir "$NX_LOCK" 2>/dev/null; then
		NX_LOCK_HELD=1
	else
		NX_PID=$(cat "$NX_LOCK/pid" 2>/dev/null)
		NX_START=$(cat "$NX_LOCK/start" 2>/dev/null)
		NX_CURRENT_START=""
		case "$NX_PID" in '' | *[!0-9]*) ;; *) NX_CURRENT_START=$(awk '{print $22}' "/proc/$NX_PID/stat" 2>/dev/null) ;; esac
		[ -n "$NX_CURRENT_START" ] && [ "$NX_CURRENT_START" = "$NX_START" ] && return 1
		rm -f "$NX_LOCK/pid" "$NX_LOCK/start" 2>/dev/null
		rmdir "$NX_LOCK" 2>/dev/null || return 1
		mkdir "$NX_LOCK" 2>/dev/null || return 1
		NX_LOCK_HELD=1
	fi

	printf '%s\n' "$$" >"$NX_LOCK/pid" || return 1
	awk '{print $22}' "/proc/$$/stat" >"$NX_LOCK/start" 2>/dev/null || return 1
	return 0
}

[ -f "$NX_CONTENT" ] && exit 0
mkdir -p "$NX_BIOS_ROOT" || exit 1

trap 'NX_CLEANUP' EXIT
trap 'exit 1' HUP INT TERM

if ! NX_ACQUIRE_LOCK; then
	NX_WAIT=0
	while [ "$NX_WAIT" -lt 120 ]; do
		[ -f "$NX_CONTENT" ] && exit 0
		sleep 1
		NX_WAIT=$((NX_WAIT + 1))
	done
	NX_LOG "Timed out waiting for Cave Story provisioning"
	exit 1
fi

NX_WORK=$(mktemp -d "$NX_BIOS_ROOT/.nxengine.XXXXXX") || exit 1
chmod 700 "$NX_WORK" || exit 1
NX_ARCHIVE="$NX_WORK/Cave Story (En).zip"
NX_EXTRACT="$NX_WORK/extract"

NX_LOG "Downloading verified Cave Story data"
curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
	--connect-timeout 10 --max-time 120 --max-filesize 8388608 \
	--retry 2 --retry-delay 1 --output "$NX_ARCHIVE" "$NX_URL" || exit 1

printf '%s  %s\n' "$NX_SHA256" "$NX_ARCHIVE" | sha256sum -c - >/dev/null 2>&1 || {
	NX_LOG "Cave Story data failed verification"
	exit 1
}

export ARCHIVE_MAX_ENTRIES=1024
export ARCHIVE_MAX_ENTRY_BYTES=16777216
export ARCHIVE_MAX_TOTAL_BYTES=33554432
export ARCHIVE_MAX_RATIO=500
SAFE_ARCHIVE "$NX_ARCHIVE" || {
	NX_LOG "Cave Story data failed archive checks"
	exit 1
}

mkdir "$NX_EXTRACT" || exit 1
unzip -q "$NX_ARCHIVE" -d "$NX_EXTRACT" || exit 1

NX_SOURCE=""
for NX_CANDIDATE in "$NX_EXTRACT/Cave Story (en)" "$NX_EXTRACT/Cave Story (En)"; do
	if [ -f "$NX_CANDIDATE/Doukutsu.exe" ]; then
		NX_SOURCE="$NX_CANDIDATE"
		break
	fi
done

[ -n "$NX_SOURCE" ] || {
	NX_LOG "Cave Story data is incomplete"
	exit 1
}

NX_OLD=""
if [ -e "$NX_TARGET" ]; then
	NX_OLD="$NX_BIOS_ROOT/.nxengine.old.$$"
	mv "$NX_TARGET" "$NX_OLD" || exit 1
fi

if ! mv "$NX_SOURCE" "$NX_TARGET"; then
	[ -n "$NX_OLD" ] && mv "$NX_OLD" "$NX_TARGET" 2>/dev/null
	exit 1
fi

[ -n "$NX_OLD" ] && rm -rf "$NX_OLD"
NX_LOG "Cave Story data installed"
exit 0
