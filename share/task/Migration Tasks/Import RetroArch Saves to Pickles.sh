#!/bin/sh
# HELP: Copy compatible RetroArch save games and optional save states into Pickles. Existing Pickles saves are never replaced and the RetroArch originals are left untouched.
# ICON: retroarch
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/config.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "import_retroarch_saves_to_pickles" "Import RetroArch Saves to Pickles"

MODE=$(TASK_PROMPT \
	"retroarch_pickles_mode" \
	"choice" \
	"Import RetroArch Saves" \
	"Existing Pickles saves stay untouched. Save states are copied only when their content and assigned core match." \
	"Save Games and States|Save Games Only" \
	"Save Games and States") || {
	TASK_COMPLETE "Import cancelled"
	exit 0
}

IMPORT_STATES=1
[ "$MODE" = "Save Games Only" ] && IMPORT_STATES=0

RA_SAVE_ROOT="${RA_SAVE_ROOT:-$MUOS_STORE_DIR/save/file}"
RA_STATE_ROOT="${RA_STATE_ROOT:-$MUOS_STORE_DIR/save/state}"
PICKLES_ROOT="${PICKLES_ROOT:-$MUOS_STORE_DIR/pickles}"
ASSIGN_ROOT="${ASSIGN_ROOT:-$MUOS_SHARE_DIR/info/content}"
CORE_ROOT="${CORE_ROOT:-$MUOS_SHARE_DIR/core}"
CORE_INFO_ROOT="${CORE_INFO_ROOT:-$MUOS_SHARE_DIR/emulator/retroarch/info}"
STATE_TOOL="${STATE_TOOL:-/opt/muos/frontend/mustate}"
WORK_DIR="/tmp/muos/retroarch-pickles-import.$$"
CONTENT_INDEX="$WORK_DIR/content.tsv"
SAVE_LIST="$WORK_DIR/saves.list"
STATE_LIST="$WORK_DIR/states.list"
CANDIDATES="$WORK_DIR/candidates.list"
MOUNTS="$WORK_DIR/mounts.list"
ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount" 2>/dev/null)
REPORT_DIR="$ROM_MOUNT/MUOS/log"
REPORT="$REPORT_DIR/retroarch-pickles-import.txt"

mkdir -p "$WORK_DIR" "$REPORT_DIR" || {
	TASK_ERROR "workspace" "Could not prepare the import workspace"
	TASK_COMPLETE "Nothing was imported"
	exit 1
}

trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

: >"$CONTENT_INDEX"
: >"$SAVE_LIST"
: >"$STATE_LIST"
: >"$MOUNTS"

REPORT_LINE() {
	printf '%s\n' "$1" >>"$REPORT"
}

NORMALISE() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

CORE_INFO_VALUE() {
	CIV_ID=${1%_libretro.so}
	CIV_FILE="$CORE_INFO_ROOT/${CIV_ID}_libretro.info"
	[ -f "$CIV_FILE" ] || CIV_FILE="$CORE_INFO_ROOT/$CIV_ID.info"
	[ -f "$CIV_FILE" ] || return 1
	sed -n "s/^$2[[:space:]]*=[[:space:]]*\"\(.*\)\"[[:space:]]*$/\1/p" "$CIV_FILE" | head -n 1
}

CORE_NAME() { CORE_INFO_VALUE "$1" corename; }
CORE_VERSION() { CORE_INFO_VALUE "$1" display_version; }

ASSIGNED_CORE() {
	AC_PATH=$1
	AC_REL=${AC_PATH#*/ROMS/}
	[ "$AC_REL" != "$AC_PATH" ] || return 1
	AC_FILE=${AC_REL##*/}
	AC_STEM=${AC_FILE%.*}
	case "$AC_REL" in
		*/*) AC_DIR=${AC_REL%/*} ;;
		*) AC_DIR= ;;
	esac

	AC_CFG="$ASSIGN_ROOT/${AC_DIR:+$AC_DIR/}$AC_STEM.cfg"
	[ -f "$AC_CFG" ] || AC_CFG="$ASSIGN_ROOT/${AC_DIR:+$AC_DIR/}core.cfg"

	if [ ! -f "$AC_CFG" ]; then
		AC_SCAN=$AC_DIR
		while :; do
			AC_CFG="$ASSIGN_ROOT/${AC_SCAN:+$AC_SCAN/}core_recursive.cfg"
			[ -f "$AC_CFG" ] && break
			[ -n "$AC_SCAN" ] || return 1
			case "$AC_SCAN" in
				*/*) AC_SCAN=${AC_SCAN%/*} ;;
				*) AC_SCAN= ;;
			esac
		done
	fi

	sed -n '1{s/\r$//;p;}' "$AC_CFG"
}

CORE_MATCHES() {
	CM_CORE=$1
	CM_RA=$2
	case "$CM_CORE" in
		*_libretro.so) ;;
		*) return 1 ;;
	esac
	[ -f "$CORE_ROOT/$CM_CORE" ] || return 1

	CM_RA_KEY=$(NORMALISE "$CM_RA")
	CM_CORE_ID=${CM_CORE%_libretro.so}
	CM_CORE_KEY=$(NORMALISE "$CM_CORE_ID")
	[ "$CM_RA_KEY" = "$CM_CORE_KEY" ] && return 0

	CM_NAME=$(CORE_NAME "$CM_CORE")
	[ -n "$CM_NAME" ] || return 1
	CM_NAME_KEY=$(NORMALISE "$CM_NAME")
	[ "$CM_RA_KEY" = "$CM_NAME_KEY" ]
}

RESOLVE_CONTENT() {
	RC_KEY=$1
	RC_RA_CORE=$2
	MATCH_COUNT=0
	MATCH_SIGNATURE=
	MATCH_CORE=
	MATCH_DIR=
	MATCH_STEM=

	awk -v key="$RC_KEY" 'index($0, key "\t") == 1 { print substr($0, length(key) + 2) }' \
		"$CONTENT_INDEX" >"$CANDIDATES"

	while IFS= read -r RC_PATH; do
		[ -n "$RC_PATH" ] || continue
		RC_CORE=$(ASSIGNED_CORE "$RC_PATH") || continue
		CORE_MATCHES "$RC_CORE" "$RC_RA_CORE" || continue

		RC_REL=${RC_PATH#*/ROMS/}
		RC_FILE=${RC_REL##*/}
		RC_STEM=${RC_FILE%.*}
		case "$RC_REL" in
			*/*) RC_DIR=${RC_REL%/*} ;;
			*) RC_DIR= ;;
		esac
		RC_CORE_ID=${RC_CORE%_libretro.so}
		RC_SIGNATURE="$RC_CORE_ID|$RC_DIR|$RC_STEM"
		[ "$RC_SIGNATURE" = "$MATCH_SIGNATURE" ] && continue

		MATCH_COUNT=$((MATCH_COUNT + 1))
		MATCH_SIGNATURE=$RC_SIGNATURE
		MATCH_CORE=$RC_CORE_ID
		MATCH_DIR=$RC_DIR
		MATCH_STEM=$RC_STEM
	done <"$CANDIDATES"

	[ "$MATCH_COUNT" -eq 1 ]
}

NEXT_STATE_SLOT() {
	NS_DIR=$1
	NS_MANIFEST="$NS_DIR/states.ini"
	NS_INDEX=0
	while [ "$NS_INDEX" -lt 64 ]; do
		if [ ! -e "$NS_DIR/slot_$NS_INDEX.state" ] \
			&& ! grep -Fqx "[slot_$NS_INDEX]" "$NS_MANIFEST" 2>/dev/null; then
			printf '%s' "$NS_INDEX"
			return 0
		fi
		NS_INDEX=$((NS_INDEX + 1))
	done
	return 1
}

STATE_SLOT() {
	SS_DIR=$1
	SS_PREFERRED=$2
	case "$SS_PREFERRED" in
		'' | *[!0-9]*) ;;
		*)
			if [ "$SS_PREFERRED" -lt 64 ] && [ ! -e "$SS_DIR/slot_$SS_PREFERRED.state" ] \
				&& ! grep -Fqx "[slot_$SS_PREFERRED]" "$SS_DIR/states.ini" 2>/dev/null; then
				printf '%s' "$SS_PREFERRED"
				return 0
			fi
			;;
	esac
	NEXT_STATE_SLOT "$SS_DIR"
}

ADD_STATE_MANIFEST() {
	ASM_MANIFEST=$1
	ASM_SLOT=$2
	ASM_NAME=$3
	ASM_CREATED=$4
	ASM_CORE=$5
	ASM_VERSION=$6
	ASM_TEMP="$ASM_MANIFEST.tmp.$$"

	{
		[ -f "$ASM_MANIFEST" ] && cat "$ASM_MANIFEST"
		[ ! -s "$ASM_MANIFEST" ] || printf '\n'
		printf '[slot_%s]\n' "$ASM_SLOT"
		printf 'name=%s\n' "$ASM_NAME"
		printf 'created=%s\n' "$ASM_CREATED"
		printf 'crc=\ncore=%s\ncore_version=%s\n' "$ASM_CORE" "$ASM_VERSION"
		printf 'disc_index=-1\ndisc_ejected=0\ndisc_path=\n'
	} >"$ASM_TEMP" && mv -f "$ASM_TEMP" "$ASM_MANIFEST"
}

RZIP_COMPRESSED() {
	RZ_MAGIC=$(dd if="$1" bs=1 count=8 2>/dev/null | od -An -tx1 | tr -d ' \n')
	case "$RZ_MAGIC" in
		23525a4950760123 | 23525a4950760223) return 0 ;;
	esac
	return 1
}

for ROLE in rom sdcard usb; do
	MOUNT=$(GET_VAR "device" "storage/$ROLE/mount" 2>/dev/null)
	[ -n "$MOUNT" ] || continue
	[ -d "$MOUNT/ROMS" ] || continue
	grep -Fqx "$MOUNT" "$MOUNTS" 2>/dev/null && continue
	printf '%s\n' "$MOUNT" >>"$MOUNTS"
done

TASK_STATUS "Indexing Content"
while IFS= read -r MOUNT; do
	find "$MOUNT/ROMS" -type f ! -name '.*' 2>/dev/null
done <"$MOUNTS" | while IFS= read -r CONTENT; do
	CONTENT_FILE=${CONTENT##*/}
	CONTENT_STEM=${CONTENT_FILE%.*}
	CONTENT_KEY=$(NORMALISE "$CONTENT_STEM")
	[ -n "$CONTENT_KEY" ] && printf '%s\t%s\n' "$CONTENT_KEY" "$CONTENT"
done >"$CONTENT_INDEX"

if [ -d "$RA_SAVE_ROOT" ]; then
	find "$RA_SAVE_ROOT" -mindepth 2 -type f 2>/dev/null | while IFS= read -r SOURCE; do
		SOURCE_NAME=${SOURCE##*/}
		SOURCE_EXT=${SOURCE_NAME##*.}
		SOURCE_EXT=$(printf '%s' "$SOURCE_EXT" | tr '[:upper:]' '[:lower:]')
		case "$SOURCE_EXT" in
			srm | sav | eep | fla | sra | mpk | ram | nv | rtc) printf '%s\n' "$SOURCE" ;;
		esac
	done >"$SAVE_LIST"
fi

if [ "$IMPORT_STATES" -eq 1 ] && [ -d "$RA_STATE_ROOT" ]; then
	find "$RA_STATE_ROOT" -mindepth 2 -type f 2>/dev/null | while IFS= read -r SOURCE; do
		SOURCE_NAME=${SOURCE##*/}
		case "$SOURCE_NAME" in
			*.png | *.PNG) ;;
			*.state*) printf '%s\n' "$SOURCE" ;;
		esac
	done >"$STATE_LIST"
fi

SAVE_TOTAL=$(wc -l <"$SAVE_LIST" | tr -d ' ')
STATE_TOTAL=$(wc -l <"$STATE_LIST" | tr -d ' ')
TOTAL=$((SAVE_TOTAL + STATE_TOTAL))
PROGRESS=0
SAVE_IMPORTED=0
STATE_IMPORTED=0
EXISTING=0
UNMATCHED=0
AMBIGUOUS=0
COMPRESSED=0
FULL=0
FAILED=0

{
	printf 'RetroArch to Pickles Import\n'
	printf 'Date: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
	printf 'Mode: %s\n\n' "$MODE"
} >"$REPORT"

if [ "$TOTAL" -eq 0 ]; then
	REPORT_LINE "No compatible RetroArch save files were found."
	TASK_DETAIL "$REPORT"
	TASK_COMPLETE "No RetroArch saves were found"
	exit 0
fi

if [ ! -x "$STATE_TOOL" ]; then
	REPORT_LINE "The native save conversion tool is not available: $STATE_TOOL"
	TASK_ERROR "converter" "The save conversion tool is not installed"
	TASK_DETAIL "$REPORT"
	TASK_COMPLETE "Nothing was imported"
	exit 1
fi

TASK_STATUS "Importing Save Games"
while IFS= read -r SOURCE; do
	[ -n "$SOURCE" ] || continue
	PROGRESS=$((PROGRESS + 1))
	TASK_PROGRESS "$PROGRESS" "$TOTAL"

	SOURCE_REL=${SOURCE#"$RA_SAVE_ROOT"/}
	RA_CORE=${SOURCE_REL%%/*}
	SOURCE_NAME=${SOURCE##*/}
	SOURCE_EXT=${SOURCE_NAME##*.}
	SOURCE_EXT=$(printf '%s' "$SOURCE_EXT" | tr '[:upper:]' '[:lower:]')
	SOURCE_STEM=${SOURCE_NAME%.*}
	SOURCE_KEY=$(NORMALISE "$SOURCE_STEM")
	TASK_DETAIL "$SOURCE_NAME"

	RZIP_COMPRESSED "$SOURCE" && COMPRESSED=$((COMPRESSED + 1))

	if ! RESOLVE_CONTENT "$SOURCE_KEY" "$RA_CORE"; then
		if [ "$MATCH_COUNT" -gt 1 ]; then
			AMBIGUOUS=$((AMBIGUOUS + 1))
			REPORT_LINE "SKIPPED ambiguous content: $RA_CORE/$SOURCE_NAME"
		else
			UNMATCHED=$((UNMATCHED + 1))
			REPORT_LINE "SKIPPED no matching assigned content: $RA_CORE/$SOURCE_NAME"
		fi
		continue
	fi

	TARGET_EXT=srm
	[ "$SOURCE_EXT" = "rtc" ] && TARGET_EXT=rtc
	TARGET_DIR="$PICKLES_ROOT/sram/$MATCH_CORE${MATCH_DIR:+/$MATCH_DIR}"
	TARGET="$TARGET_DIR/$MATCH_STEM.$TARGET_EXT"
	if [ -e "$TARGET" ]; then
		EXISTING=$((EXISTING + 1))
		REPORT_LINE "SKIPPED existing Pickles save: $TARGET"
		continue
	fi

	TEMP_SAVE="$WORK_DIR/save.$PROGRESS"
	if mkdir -p "$TARGET_DIR" && "$STATE_TOOL" extract "$SOURCE" "$TEMP_SAVE" && mv "$TEMP_SAVE" "$TARGET"; then
		SAVE_IMPORTED=$((SAVE_IMPORTED + 1))
		REPORT_LINE "COPIED save game: $SOURCE -> $TARGET"
	else
		FAILED=$((FAILED + 1))
		rm -f "$TARGET"
		REPORT_LINE "FAILED save game: $SOURCE -> $TARGET"
	fi
done <"$SAVE_LIST"

if [ "$IMPORT_STATES" -eq 1 ]; then
	TASK_STATUS "Importing Save States"
	while IFS= read -r SOURCE; do
		[ -n "$SOURCE" ] || continue
		PROGRESS=$((PROGRESS + 1))
		TASK_PROGRESS "$PROGRESS" "$TOTAL"

		SOURCE_REL=${SOURCE#"$RA_STATE_ROOT"/}
		RA_CORE=${SOURCE_REL%%/*}
		SOURCE_NAME=${SOURCE##*/}
		STATE_LABEL=
		PREFERRED_SLOT=0
		case "$SOURCE_NAME" in
			*.state.auto)
				SOURCE_STEM=${SOURCE_NAME%.state.auto}
				STATE_LABEL="Imported RetroArch Auto State"
				;;
			*.state)
				SOURCE_STEM=${SOURCE_NAME%.state}
				STATE_LABEL="Imported RetroArch State 0"
				;;
			*.state[0-9]*)
				SOURCE_STEM=${SOURCE_NAME%%.state[0-9]*}
				STATE_NUMBER=${SOURCE_NAME#"$SOURCE_STEM.state"}
				case "$STATE_NUMBER" in
					*[!0-9]*) continue ;;
				esac
				PREFERRED_SLOT=$STATE_NUMBER
				STATE_LABEL="Imported RetroArch State $STATE_NUMBER"
				;;
			*) continue ;;
		esac
		SOURCE_KEY=$(NORMALISE "$SOURCE_STEM")
		TASK_DETAIL "$SOURCE_NAME"

		RZIP_COMPRESSED "$SOURCE" && COMPRESSED=$((COMPRESSED + 1))

		if ! RESOLVE_CONTENT "$SOURCE_KEY" "$RA_CORE"; then
			if [ "$MATCH_COUNT" -gt 1 ]; then
				AMBIGUOUS=$((AMBIGUOUS + 1))
				REPORT_LINE "SKIPPED ambiguous content: $RA_CORE/$SOURCE_NAME"
			else
				UNMATCHED=$((UNMATCHED + 1))
				REPORT_LINE "SKIPPED no matching assigned content: $RA_CORE/$SOURCE_NAME"
			fi
			continue
		fi

		TARGET_DIR="$PICKLES_ROOT/state/$MATCH_CORE${MATCH_DIR:+/$MATCH_DIR}/$MATCH_STEM"
		TEMP_STATE="$WORK_DIR/state.$PROGRESS"
		if ! "$STATE_TOOL" convert "$SOURCE" "$TEMP_STATE"; then
			FAILED=$((FAILED + 1))
			REPORT_LINE "FAILED save state conversion: $SOURCE"
			continue
		fi
		STATE_EXISTS=0
		for EXISTING_STATE in "$TARGET_DIR"/slot_*.state; do
			[ -f "$EXISTING_STATE" ] || continue
			if cmp -s "$TEMP_STATE" "$EXISTING_STATE"; then
				STATE_EXISTS=1
				break
			fi
		done
		if [ "$STATE_EXISTS" -eq 1 ]; then
			rm -f "$TEMP_STATE"
			EXISTING=$((EXISTING + 1))
			REPORT_LINE "SKIPPED existing Pickles state: $SOURCE"
			continue
		fi

		SLOT=$(STATE_SLOT "$TARGET_DIR" "$PREFERRED_SLOT") || {
			rm -f "$TEMP_STATE"
			FULL=$((FULL + 1))
			REPORT_LINE "SKIPPED Pickles state slots are full: $TARGET_DIR"
			continue
		}
		TARGET="$TARGET_DIR/slot_$SLOT.state"
		THUMB_SOURCE=
		if [ -f "$SOURCE.png" ]; then
			THUMB_SOURCE="$SOURCE.png"
		elif [ -f "${SOURCE%.*}.png" ]; then
			THUMB_SOURCE="${SOURCE%.*}.png"
		fi
		THUMB_TARGET="$TARGET_DIR/slot_$SLOT.png"
		CREATED=$(stat -c '%Y' "$SOURCE" 2>/dev/null)
		[ -n "$CREATED" ] || CREATED=$(date '+%s')

		STATE_CORE=$(CORE_NAME "$MATCH_CORE" 2>/dev/null)
		STATE_VERSION=$(CORE_VERSION "$MATCH_CORE" 2>/dev/null)
		if mkdir -p "$TARGET_DIR" && mv "$TEMP_STATE" "$TARGET" \
			&& ADD_STATE_MANIFEST "$TARGET_DIR/states.ini" "$SLOT" "$STATE_LABEL" "$CREATED" "$STATE_CORE" "$STATE_VERSION"; then
			[ -z "$THUMB_SOURCE" ] || cp "$THUMB_SOURCE" "$THUMB_TARGET" 2>/dev/null || :
			STATE_IMPORTED=$((STATE_IMPORTED + 1))
			REPORT_LINE "COPIED save state: $SOURCE -> $TARGET"
		else
			FAILED=$((FAILED + 1))
			rm -f "$TEMP_STATE" "$TARGET" "$THUMB_TARGET"
			REPORT_LINE "FAILED save state: $SOURCE -> $TARGET"
		fi
	done <"$STATE_LIST"
fi

TASK_STATUS "Syncing Filesystem"
sync
TASK_PROGRESS "$TOTAL" "$TOTAL"

{
	printf '\nSummary\n'
	printf 'Save games copied: %s\n' "$SAVE_IMPORTED"
	printf 'Save states copied: %s\n' "$STATE_IMPORTED"
	printf 'Existing Pickles files skipped: %s\n' "$EXISTING"
	printf 'Unmatched files skipped: %s\n' "$UNMATCHED"
	printf 'Ambiguous files skipped: %s\n' "$AMBIGUOUS"
	printf 'Compressed files converted: %s\n' "$COMPRESSED"
	printf 'Full state lists skipped: %s\n' "$FULL"
	printf 'Copy failures: %s\n' "$FAILED"
} >>"$REPORT"

TASK_DETAIL "$REPORT"
TASK_COMPLETE "Copied $SAVE_IMPORTED save game(s) and $STATE_IMPORTED save state(s)"

[ "$FAILED" -eq 0 ]
