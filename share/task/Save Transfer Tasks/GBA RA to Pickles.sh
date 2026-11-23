#!/bin/sh
# HELP: Copy every RetroArch GBA save files to Pickles.
# ICON: backup
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

# Created for muOS 2606.0 Andromeda +
# This script enables bulk transfer of GBA save files from RA to Pickles.
# Cores supported: mGBA, gpSP, VBA-M, VBA Next, Beetle GBA, Meteor & TempGBA.

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "gba_ra_to_pickles" "GBA RA to Pickles"

PICKLE_SRAM="$MUOS_STORE_DIR/save/pickles/sram"
RA_CONF="$MUOS_SHARE_DIR/info/config/retroarch.cfg"
INFO_DIR="$MUOS_SHARE_DIR/emulator/retroarch/info"
TAB="$(printf '\t')"
GBA_EXT="gba zip 7z gbc gb agb bin"

WORK="/tmp/gba_ra2pk_work.$$"
ROM_IDX="/tmp/gba_ra2pk_rom.$$"
PK_IDX="/tmp/gba_ra2pk_pk.$$"
trap 'rm -f "$WORK" "$ROM_IDX" "$PK_IDX"' EXIT

RA_SAVE="$(sed -n 's/^savefile_directory *= *"\(.*\)"/\1/p' "$RA_CONF" 2>/dev/null)"
[ -n "$RA_SAVE" ] || RA_SAVE="$MUOS_STORE_DIR/save/file"
RA_SORT="$(sed -n 's/^sort_savefiles_enable *= *"\(.*\)"/\1/p' "$RA_CONF" 2>/dev/null)"
RA_BYCONTENT="$(sed -n 's/^sort_savefiles_by_content_enable *= *"\(.*\)"/\1/p' "$RA_CONF" 2>/dev/null)"

if [ "$RA_SORT" = "false" ] || [ "$RA_BYCONTENT" = "true" ]; then
	TASK_ERROR "unsupported_layout" "RetroArch is not using per-core save folders. Turn 'Sort Saves Into Folders By Core Name' on and 'By Content' off, then retry."
	exit 1
fi

ROM_SD1="$(GET_VAR device storage/rom/mount)"
ROM_SD2="$(GET_VAR device storage/sdcard/mount)"

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$ROM_SD1/MUOS/backup/pickles-sram-$TS"
DID_BACKUP=0

TASK_STATUS "Reading core list"
INFO_MAP="$(awk '
	FNR == 1 {
		if (so != "" && gba && cn != "") print cn "\t" so
		so = FILENAME; sub(/.*\//, "", so); sub(/_libretro\.info$/, "", so)
		cn = ""; gba = 0
	}
	/^corename = "/ { c = $0; sub(/^corename = "/, "", c); sub(/".*/, "", c); cn = c }
	index($0, "Game Boy Advance") { gba = 1 }
	END { if (so != "" && gba && cn != "") print cn "\t" so }
' "$INFO_DIR"/*_libretro.info 2>/dev/null | awk -F"$TAB" '
	{ if (!($1 in m) || m[$1] ~ /_rumble$|^vba-m$/) m[$1] = $2 }
	END { for (k in m) print k "\t" m[k] }
')"

SO_FOR_FOLDER() {
	printf '%s\n' "$INFO_MAP" | awk -F"$TAB" -v f="$1" '$1 == f { print $2; exit }'
}

TASK_STATUS "Indexing ROM folders"
: >"$ROM_IDX"
for BASE in "$ROM_SD1/ROMS" "$ROM_SD2/ROMS"; do
	[ -d "$BASE" ] || continue
	find "$BASE" -type f 2>/dev/null | awk -v blen="${#BASE}" -v x=" $GBA_EXT " '
		{
			p = $0
			n = p; sub(/.*\//, "", n)
			e = n; sub(/.*\./, "", e)
			if (index(x, " " tolower(e) " ") == 0) next
			b = n; sub(/\.[^.]*$/, "", b)
			rel = substr(p, blen + 2)
			if (sub(/\/[^\/]*$/, "", rel) == 0) rel = ""
			print b "\t" rel
		}' >>"$ROM_IDX"
done

: >"$PK_IDX"
if [ -d "$PICKLE_SRAM" ]; then
	printf '%s\n' "$INFO_MAP" | while IFS="$TAB" read -r _cn _so; do
		_root="$PICKLE_SRAM/$_so"
		[ -d "$_root" ] || continue
		find "$_root" -type f -name '*.srm' 2>/dev/null | awk -v blen="${#_root}" -v so="$_so" '
			{
				p = $0
				n = p; sub(/.*\//, "", n); sub(/\.srm$/, "", n)
				rel = substr(p, blen + 2)
				if (sub(/\/[^\/]*$/, "", rel) == 0) rel = ""
				print so "\t" n "\t" rel
			}'
	done >>"$PK_IDX"
fi

: >"$WORK"
if [ -d "$RA_SAVE" ]; then
	for CF in "$RA_SAVE"/*/; do
		[ -d "$CF" ] || continue
		FOLDER="$(basename "$CF")"
		SO="$(SO_FOR_FOLDER "$FOLDER")"
		[ -n "$SO" ] || continue
		for SRM in "$CF"*.srm; do
			[ -f "$SRM" ] || continue
			printf '%s%s%s%s%s\n' "$SO" "$TAB" "$FOLDER" "$TAB" "$SRM" >>"$WORK"
		done
	done
fi

TOTAL="$(wc -l <"$WORK" | tr -d ' ')"
if [ "${TOTAL:-0}" -eq 0 ]; then
	TASK_COMPLETE "No RetroArch GBA saves found"
	exit 0
fi

TASK_STATUS "Found $TOTAL RetroArch GBA save(s)"
TASK_PROGRESS 0 "$TOTAL"

COPIED=0
SKIPPED=0
N=0
OIFS="$IFS"
IFS="$TAB"
while read -r SO FOLDER SRM; do
	IFS="$OIFS"
	N=$((N + 1))
	STEM="$(basename "$SRM" .srm)"
	TASK_STATUS "$STEM"
	TASK_PROGRESS "$N" "$TOTAL"

	REL="$(awk -F"$TAB" -v so="$SO" -v s="$STEM" '$1 == so && $2 == s { print $3; found = 1; exit } END { if (!found) exit 1 }' "$PK_IDX")"
	if [ $? -ne 0 ]; then
		REL="$(awk -F"$TAB" -v s="$STEM" '$1 == s { print $2; found = 1; exit } END { if (!found) exit 1 }' "$ROM_IDX")"
		if [ $? -ne 0 ]; then
			TASK_LOG "warn" "skip - ROM not found: $STEM"
			SKIPPED=$((SKIPPED + 1))
			IFS="$TAB"
			continue
		fi
	fi

	DST_DIR="$PICKLE_SRAM/$SO${REL:+/$REL}"
	DST="$DST_DIR/$STEM.srm"

	if [ -f "$DST" ]; then
		if cmp -s "$SRM" "$DST"; then
			SKIPPED=$((SKIPPED + 1))
			IFS="$TAB"
			continue
		fi
		_bk="$BACKUP_DIR/$SO${REL:+/$REL}"
		mkdir -p "$_bk"
		cp -p "$DST" "$_bk/$STEM.srm"
		[ -f "$DST.sum" ] && cp -p "$DST.sum" "$_bk/$STEM.srm.sum" 2>/dev/null
		DID_BACKUP=1
	fi

	mkdir -p "$DST_DIR"
	if cp "$SRM" "$DST.tmp.$$" && mv "$DST.tmp.$$" "$DST"; then
		rm -f "$DST.sum"
		[ -f "${SRM%.srm}.rtc" ] && cp "${SRM%.srm}.rtc" "$DST_DIR/$STEM.rtc" 2>/dev/null
		COPIED=$((COPIED + 1))
	else
		rm -f "$DST.tmp.$$"
		TASK_LOG "error" "copy failed: $STEM"
		SKIPPED=$((SKIPPED + 1))
	fi
	IFS="$TAB"
done <"$WORK"
IFS="$OIFS"

TASK_STATUS "Sync Filesystem"
sync

[ "$DID_BACKUP" -eq 1 ] && TASK_DETAIL "Replaced saves backed up to ${BACKUP_DIR#"$ROM_SD1"/}"
TASK_COMPLETE "$(printf 'GBA saves: %d copied, %d skipped' "$COPIED" "$SKIPPED")"
exit 0
