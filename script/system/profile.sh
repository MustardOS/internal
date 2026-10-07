#!/bin/sh

. /opt/muos/script/var/func.sh

PROFILE_SHARE="$MUOS_SHARE_DIR/profile"
PROFILE_DEFAULT="$PROFILE_SHARE/system/default.conf"
PROFILE_RULES="$PROFILE_SHARE/system/rules.conf"
PROFILE_LOG_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/profile"
PROFILE_PENDING="$PROFILE_SHARE/state/pending"
PROFILE_STATE="$PROFILE_SHARE/state"
PROFILE_PREVIOUS="$PROFILE_STATE/previous.conf"
PROFILE_ACTIVE="$PROFILE_STATE/active"
PROFILE_OEM="$PROFILE_SHARE/oem"

PROFILE_USAGE() {
	printf 'Usage: %s apply FILE merge|replace\n' "$0" >&2
	printf '       %s undo\n' "$0" >&2
	printf '       %s save FILE NAME [DESCRIPTION]\n' "$0" >&2
	printf '       %s import-oem SOURCE\n' "$0" >&2
	printf '       %s import-wifi SOURCE\n' "$0" >&2
	printf '       %s check FILE\n' "$0" >&2
	printf '       %s flush [DIRECTORY]\n' "$0" >&2
	exit 2
}

PROFILE_FIELD() {
	awk -v WANT="$2" '
		NR == 1 { sub(/^\357\273\277/, "") }
		{ sub(/\r$/, "") }
		index($0, "=") > 0 {
			KEY = substr($0, 1, index($0, "=") - 1)
			if (KEY == WANT) { print substr($0, index($0, "=") + 1); exit }
		}
	' "$1"
}

PROFILE_KNOWN() {
	awk '
		NR == FNR {
			if (index($0, "=") > 0) {
				KEY = substr($0, 1, index($0, "=") - 1)
				if (index(KEY, "/") > 0) ALLOWED[KEY] = 1
			}
			next
		}
		FNR == 1 { sub(/^\357\273\277/, "") }
		{ sub(/\r$/, "") }
		/^[ \t]*(#|$)/ { next }
		index($0, "=") > 0 {
			KEY = substr($0, 1, index($0, "=") - 1)
			if (KEY in ALLOWED) print KEY "=" substr($0, index($0, "=") + 1)
		}
	' "$PROFILE_DEFAULT" "$1"
}

PROFILE_VALIDATE() {
	awk -v PROBLEMS="$2" -v OEM="${3:-0}" -v ORIGINAL="${4:-}" '
		function BAD(REASON) {
			SHOWN = ORIGINAL != "" ? SOURCE[FNR] : LINE
			if (SHOWN ~ /^[ \t]*([a-z_\/]*\/)?pass[ \t]*=/) SHOWN = substr(SHOWN, 1, index(SHOWN, "=")) "(hidden)"
			printf "Line %d: %s\n    %s\n\n", FNR, SHOWN, REASON >PROBLEMS
			FAILED = 1
		}
		function TRIM(TEXT) {
			gsub(/^[ \t]+|[ \t]+$/, "", TEXT)
			return TEXT
		}
		BEGIN {
			FS = "\t"
			if (ORIGINAL != "") {
				while ((getline TEXT <ORIGINAL) > 0) {
					COUNT++
					if (COUNT == 1) sub(/^\357\273\277/, "", TEXT)
					sub(/\r$/, "", TEXT)
					SOURCE[COUNT] = TEXT
				}
			}
		}
		NR == FNR {
			KIND[$1] = $2
			LOW[$1] = $3
			HIGH[$1] = $4
			CHOICES[$1] = $5
			SCOPE[$1] = $6
			next
		}
		FNR == 1 { sub(/^\357\273\277/, "") }
		{
			sub(/\r$/, "")
			LINE = $0
		}
		LINE ~ /^[ \t]*(#|$)/ { next }
		index(LINE, "=") == 0 {
			BAD("This line is not in setting=value form")
			next
		}
		{
			KEY = TRIM(substr(LINE, 1, index(LINE, "=") - 1))
			VALUE = substr(LINE, index(LINE, "=") + 1)

			if (index(KEY, "/") == 0) {
				if (KEY != "name" && KEY != "description" && KEY != "type") BAD("Only name, description and type can be used without a setting path")
				next
			}

			if (!(KEY in KIND)) {
				if (ORIGINAL != "") BAD("This is not a wifi.conf setting, so check the spelling")
				else BAD("This is not a setting MustardOS knows about, so check the spelling")
				next
			}

			if (KIND[KEY] == "refused") {
				BAD(LOW[KEY])
				next
			}

			if (SCOPE[KEY] == "oem" && OEM != 1) {
				BAD("Network settings belong in wifi.conf on a newly flashed card")
				next
			}

			if (KIND[KEY] == "int") {
				VALUE = TRIM(VALUE)
				if (VALUE !~ /^-?[0-9]+$/) {
					if (KEY == "network/type") BAD("Use dhcp or static")
					else BAD("The value must be a whole number")
					next
				}
				if ((LOW[KEY] != "" && VALUE + 0 < LOW[KEY] + 0) || (HIGH[KEY] != "" && VALUE + 0 > HIGH[KEY] + 0)) {
					BAD("The value must be from " LOW[KEY] " to " HIGH[KEY])
					next
				}
				if (CHOICES[KEY] != "" && index("," CHOICES[KEY] ",", "," (VALUE + 0) ",") == 0) {
					LIST = CHOICES[KEY]
					gsub(/,/, ", ", LIST)
					BAD("The value must be one of " LIST)
					next
				}
				VALUE = VALUE + 0
			} else if (CHOICES[KEY] != "" && index("," CHOICES[KEY] ",", "," VALUE ",") == 0) {
				LIST = CHOICES[KEY]
				gsub(/,/, ", ", LIST)
				BAD("The value must be one of " LIST)
				next
			}

			if (KEY in SEEN) {
				BAD("This setting is already set on line " SEEN[KEY])
				next
			}

			SEEN[KEY] = FNR
			print KEY "=" VALUE
		}
		END { exit FAILED }
	' "$PROFILE_RULES" "$1"
}

PROFILE_LOG_NAME() {
	PLN_BASE=${1##*/}
	case "$PLN_BASE" in
		*.[Cc][Oo][Nn][Ff]) PLN_BASE=${PLN_BASE%.*} ;;
	esac
	printf '%s_error.txt' "$PLN_BASE"
}

PROFILE_LOG_READY() {
	[ -d "${PROFILE_LOG_DIR%/log/profile}" ] && mkdir -p "$PROFILE_LOG_DIR"
}

PROFILE_LOG_TARGET() {
	if PROFILE_LOG_READY; then
		printf '%s/%s' "$PROFILE_LOG_DIR" "$(PROFILE_LOG_NAME "$1")"
	else
		mkdir -p "$PROFILE_PENDING"
		printf '%s/%s' "$PROFILE_PENDING" "$(PROFILE_LOG_NAME "$1")"
	fi
}

PROFILE_WRITE_LOG() {
	PWL_SOURCE=$1
	PWL_PROBLEMS=$2
	PWL_SUMMARY=$3
	PWL_TARGET=$(PROFILE_LOG_TARGET "$PWL_SOURCE")
	PWL_NAME=$(PROFILE_FIELD "$PWL_SOURCE" name)

	{
		printf 'Profile: %s\n' "${PWL_NAME:-${PWL_SOURCE##*/}}"
		printf 'File: %s\n' "${PWL_SOURCE##*/}"
		printf 'Checked: %s\n\n' "$(date '+%Y-%m-%d %H:%M')"
		printf '%s\n\n' "$PWL_SUMMARY"
		[ -s "$PWL_PROBLEMS" ] && cat "$PWL_PROBLEMS"
	} >"$PWL_TARGET"

	LOG_WARN "$0" 0 "PROFILE" "$(printf "Profile problems written to '%s'" "$PWL_TARGET")"
}

PROFILE_CLEAR_LOG() {
	rm -f "$PROFILE_LOG_DIR/$(PROFILE_LOG_NAME "$1")" "$PROFILE_PENDING/$(PROFILE_LOG_NAME "$1")"
}

PROFILE_FLUSH_PENDING() {
	[ -d "$PROFILE_PENDING" ] || return 0
	PROFILE_LOG_READY || return 0
	for PFP_FILE in "$PROFILE_PENDING"/*_error.txt; do
		[ -f "$PFP_FILE" ] && mv -f "$PFP_FILE" "$PROFILE_LOG_DIR/"
	done
	rmdir "$PROFILE_PENDING" 2>/dev/null || :
}

PROFILE_CHECKED() {
	PC_SOURCE=$1
	PC_LINES=$2
	PC_OEM=${3:-0}
	PC_ORIGINAL=${4:-}
	PC_PROBLEMS="$MUOS_RUN_DIR/profile.problems.$$"

	rm -f "$PC_PROBLEMS"
	if ! PROFILE_VALIDATE "$PC_SOURCE" "$PC_PROBLEMS" "$PC_OEM" "$PC_ORIGINAL" >"$PC_LINES"; then
		PROFILE_WRITE_LOG "$PC_SOURCE" "$PC_PROBLEMS" "Nothing was applied and no settings were changed. Fix the lines below and try again."
		rm -f "$PC_PROBLEMS" "$PC_LINES"
		return 4
	fi
	rm -f "$PC_PROBLEMS"

	if [ ! -s "$PC_LINES" ]; then
		PROFILE_WRITE_LOG "$PC_SOURCE" /dev/null "Nothing was applied because the file does not contain any settings."
		rm -f "$PC_LINES"
		return 3
	fi

	PROFILE_CLEAR_LOG "$PC_SOURCE"
	return 0
}

PROFILE_CURRENT() {
	awk -v BASE="$MUOS_CONF_GLOBAL" '
		index($0, "=") > 0 {
			KEY = substr($0, 1, index($0, "=") - 1)
			if (index(KEY, "/") == 0) next
			FILE = BASE "/" KEY
			VALUE = ""
			FOUND = (getline VALUE <FILE)
			close(FILE)
			if (FOUND >= 0) print KEY "=" VALUE
			else print
		}
	' "$PROFILE_DEFAULT"
}

PROFILE_WRITE_CURRENT() {
	PWC_TARGET=$1
	PWC_NAME=$2
	PWC_DESC=$3
	PWC_TYPE=$4

	case "$PWC_TARGET" in
		*/*) mkdir -p "${PWC_TARGET%/*}" || return 1 ;;
	esac
	PWC_TEMP="$PWC_TARGET.tmp.$$"
	{
		printf 'name=%s\n' "$PWC_NAME"
		printf 'description=%s\n' "$PWC_DESC"
		printf 'type=%s\n' "$PWC_TYPE"
		PROFILE_CURRENT
	} >"$PWC_TEMP" && mv -f "$PWC_TEMP" "$PWC_TARGET" && return 0

	rm -f "$PWC_TEMP"
	return 1
}

PROFILE_APPLY_LINES() {
	PAL_PENDING="$MUOS_RUN_DIR/profile.pending.$$"

	awk -v BASE="$MUOS_CONF_GLOBAL" '
		{
			KEY = substr($0, 1, index($0, "=") - 1)
			FILE = BASE "/" KEY
			CURRENT = ""
			FOUND = (getline CURRENT <FILE)
			close(FILE)
			if (FOUND >= 0 && CURRENT == substr($0, index($0, "=") + 1)) next
			print
		}
	' >"$PAL_PENDING" || return 1

	if [ -s "$PAL_PENDING" ]; then
		if ! { [ -x "$MUOS_VAR_BIN" ] && "$MUOS_VAR_BIN" apply global <"$PAL_PENDING" 2>/dev/null; }; then
			while IFS= read -r PAL_LINE; do
				SET_VAR "config" "${PAL_LINE%%=*}" "${PAL_LINE#*=}" ||
					LOG_WARN "$0" 0 "PROFILE" "$(printf "Could not set '%s'" "${PAL_LINE%%=*}")"
			done <"$PAL_PENDING"
		fi
	fi

	rm -f "$PAL_PENDING"
}

PROFILE_SNAPSHOT() {
	PROFILE_WRITE_CURRENT "$PROFILE_PREVIOUS" "Previous Settings" "Settings from before the last profile was applied" "snapshot"
}

PROFILE_APPLY() {
	PA_FILE=$1
	PA_MODE=$2

	[ -r "$PA_FILE" ] || {
		LOG_ERROR "$0" 0 "PROFILE" "$(printf "Profile not found: '%s'" "$PA_FILE")"
		return 1
	}

	case "$PA_MODE" in
		merge | replace) ;;
		*) PROFILE_USAGE ;;
	esac

	PA_LINES="$MUOS_RUN_DIR/profile.apply.$$"
	PROFILE_CHECKED "$PA_FILE" "$PA_LINES" || return

	PROFILE_SNAPSHOT || LOG_WARN "$0" 0 "PROFILE" "Could not save the previous settings"

	if [ "$PA_MODE" = replace ]; then
		PROFILE_KNOWN "$PROFILE_DEFAULT" | awk '
			NR == FNR {
				CHOSEN[substr($0, 1, index($0, "=") - 1)] = 1
				next
			}
			!(substr($0, 1, index($0, "=") - 1) in CHOSEN)
		' "$PA_LINES" - | cat - "$PA_LINES" | PROFILE_APPLY_LINES
	else
		PROFILE_APPLY_LINES <"$PA_LINES"
	fi
	rm -f "$PA_LINES"

	PA_NAME=$(PROFILE_FIELD "$PA_FILE" name)
	mkdir -p "$PROFILE_STATE"
	printf '%s' "${PA_NAME:-${PA_FILE##*/}}" >"$PROFILE_ACTIVE"

	LOG_INFO "$0" 0 "PROFILE" "$(printf "Applied '%s' (%s)" "${PA_NAME:-$PA_FILE}" "$PA_MODE")"
}

PROFILE_UNDO() {
	[ -r "$PROFILE_PREVIOUS" ] || {
		LOG_WARN "$0" 0 "PROFILE" "There are no previous settings to restore"
		return 3
	}

	PU_HELD="$PROFILE_STATE/previous.hold.$$"
	PROFILE_WRITE_CURRENT "$PU_HELD" "Previous Settings" "Settings from before the last profile was applied" "snapshot" || return 1

	PROFILE_KNOWN "$PROFILE_PREVIOUS" | PROFILE_APPLY_LINES
	mv -f "$PU_HELD" "$PROFILE_PREVIOUS"
	rm -f "$PROFILE_ACTIVE"

	LOG_INFO "$0" 0 "PROFILE" "Restored the previous settings"
}

PROFILE_SAVE() {
	PS_TARGET=$1
	PS_NAME=$2
	PS_DESC=${3:-}

	[ -n "$PS_TARGET" ] && [ -n "$PS_NAME" ] || PROFILE_USAGE
	case "$PS_NAME" in
		*'
'*) return 1 ;;
	esac

	PROFILE_WRITE_CURRENT "$PS_TARGET" "$PS_NAME" "$PS_DESC" "user" || return 1
	LOG_INFO "$0" 0 "PROFILE" "$(printf "Saved current settings as '%s'" "$PS_NAME")"
}

PROFILE_IMPORT_OEM() {
	PIO_SOURCE=$1
	[ -r "$PIO_SOURCE" ] || return 0

	PIO_LINES="$MUOS_RUN_DIR/profile.oem.$$"
	PROFILE_CHECKED "$PIO_SOURCE" "$PIO_LINES" || return

	PIO_NAME=$(PROFILE_FIELD "$PIO_SOURCE" name)
	PIO_DESC=$(PROFILE_FIELD "$PIO_SOURCE" description)
	[ -n "$PIO_NAME" ] || PIO_NAME="OEM Profile"

	mkdir -p "$PROFILE_OEM" || return 1
	PIO_TARGET="$PROFILE_OEM/oem.conf"
	PIO_TEMP="$PIO_TARGET.tmp.$$"
	{
		printf 'name=%s\n' "$PIO_NAME"
		printf 'description=%s\n' "$PIO_DESC"
		printf 'type=oem\n'
		cat "$PIO_LINES"
	} >"$PIO_TEMP" && mv -f "$PIO_TEMP" "$PIO_TARGET"
	rm -f "$PIO_LINES"

	LOG_INFO "$0" 0 "PROFILE" "$(printf "Imported OEM profile '%s'" "$PIO_NAME")"
	PROFILE_APPLY "$PIO_TARGET" merge
}

PROFILE_WIFI_KEYS() {
	awk -F '\t' '
		NR == FNR {
			if ($6 == "oem") {
				LEAF = $1
				sub(/^.*\//, "", LEAF)
				FULL[LEAF] = $1
			}
			next
		}
		FNR == 1 { sub(/^\357\273\277/, "") }
		{ sub(/\r$/, "") }
		/^[ \t]*(#|$)/ || index($0, "=") == 0 { print; next }
		{
			KEY = substr($0, 1, index($0, "=") - 1)
			VALUE = substr($0, index($0, "=") + 1)
			gsub(/^[ \t]+|[ \t]+$/, "", KEY)
			if (KEY == "type") {
				LOWER = tolower(VALUE)
				gsub(/^[ \t]+|[ \t]+$/, "", LOWER)
				if (LOWER == "dhcp") VALUE = 0
				if (LOWER == "static") VALUE = 1
			}
			print ((KEY in FULL) ? FULL[KEY] : "wifi/" KEY) "=" VALUE
		}
	' "$PROFILE_RULES" "$1"
}

PROFILE_IMPORT_WIFI() {
	PIW_SOURCE=$1
	[ -r "$PIW_SOURCE" ] || return 0

	PIW_KEYS="$MUOS_RUN_DIR/wifi.conf"
	PIW_LINES="$MUOS_RUN_DIR/profile.wifi.$$"
	PROFILE_WIFI_KEYS "$PIW_SOURCE" >"$PIW_KEYS" || {
		rm -f "$PIW_KEYS"
		return 1
	}

	PROFILE_CHECKED "$PIW_KEYS" "$PIW_LINES" 1 "$PIW_SOURCE"
	PIW_RESULT=$?
	rm -f "$PIW_KEYS"
	[ "$PIW_RESULT" -eq 0 ] || return "$PIW_RESULT"

	PROFILE_APPLY_LINES <"$PIW_LINES"
	rm -f "$PIW_LINES"

	LOG_INFO "$0" 0 "PROFILE" "Applied network settings from wifi.conf"
}

PROFILE_CHECK() {
	[ -r "$1" ] || return 1
	PCK_LINES="$MUOS_RUN_DIR/profile.check.$$"
	PROFILE_CHECKED "$1" "$PCK_LINES" || return
	awk 'END { print NR }' "$PCK_LINES"
	rm -f "$PCK_LINES"
}

for PROFILE_REQUIRED in "$PROFILE_DEFAULT" "$PROFILE_RULES"; do
	[ -r "$PROFILE_REQUIRED" ] || {
		LOG_ERROR "$0" 0 "PROFILE" "$(printf "Profile system file missing: '%s'" "$PROFILE_REQUIRED")"
		exit 1
	}
done

[ "${1:-}" = flush ] && [ -n "${2:-}" ] && PROFILE_LOG_DIR=$2

PROFILE_FLUSH_PENDING

case "${1:-}" in
	apply)
		[ "$#" -eq 3 ] || PROFILE_USAGE
		PROFILE_APPLY "$2" "$3"
		;;
	undo)
		[ "$#" -eq 1 ] || PROFILE_USAGE
		PROFILE_UNDO
		;;
	save)
		[ "$#" -ge 3 ] || PROFILE_USAGE
		PROFILE_SAVE "$2" "$3" "${4:-}"
		;;
	import-oem)
		[ "$#" -eq 2 ] || PROFILE_USAGE
		PROFILE_IMPORT_OEM "$2"
		;;
	import-wifi)
		[ "$#" -eq 2 ] || PROFILE_USAGE
		PROFILE_IMPORT_WIFI "$2"
		;;
	check)
		[ "$#" -eq 2 ] || PROFILE_USAGE
		PROFILE_CHECK "$2"
		;;
	flush)
		[ "$#" -le 2 ] || PROFILE_USAGE
		;;
	*) PROFILE_USAGE ;;
esac
