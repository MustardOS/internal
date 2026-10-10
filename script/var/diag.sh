#!/bin/sh

# Shared helpers for the Diagnostics tasks.  Each report is written to a text file on
# the primary storage and ends with a list of findings in plain language.

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

DIAG_FINDINGS=""
DIAG_FINDING_COUNT=0
DIAG_REPORT=""

DIAG_STORE_DIR() {
	DIAG_MOUNT=$(GET_VAR "device" "storage/rom/mount" 2>/dev/null)
	[ -d "$DIAG_MOUNT" ] || DIAG_MOUNT="/mnt/mmc"
	DIAG_DIR="$DIAG_MOUNT/MUOS/log/diagnostics"
	mkdir -p "$DIAG_DIR" 2>/dev/null || DIAG_DIR="/tmp"
	printf '%s' "$DIAG_DIR"
}

DIAG_BEGIN() {
	TASK_BEGIN "$1" "$2"
	DIAG_REPORT="$(DIAG_STORE_DIR)/${1}_$(date +"%Y-%m-%d_%H-%M-%S").txt"
	: >"$DIAG_REPORT"

	printf '%s\n' "$2" >>"$DIAG_REPORT"
	DIAG_OUT "Generated: $(date)"
	DIAG_KV "Board" "$(DIAG_READ /opt/muos/device/config/board/name)"
	DIAG_KV "Version" "$(head -n 1 /opt/muos/config/system/version 2>/dev/null) ($(DIAG_READ /opt/muos/config/system/build))"
	DIAG_KV "Kernel" "$(uname -r) $(uname -v)"
	DIAG_KV "Model" "$(DIAG_DT_STR /proc/device-tree/model)"
	DIAG_KV "Uptime" "$(cut -d' ' -f1 /proc/uptime) s"
}

# Native tasks read protocol records from stdout, so plain text only goes to the report there
DIAG_OUT() {
	printf '%s\n' "$*" >>"$DIAG_REPORT"
	TASK_IS_NATIVE || printf '%s\n' "$*"
}

DIAG_SECTION() {
	TASK_IS_NATIVE && TASK_STATUS "$1"
	DIAG_OUT ""
	DIAG_OUT "==== $1 ===="
}

# Indents piped text into the report, and onto the terminal outside the frontend
DIAG_APPEND() {
	if TASK_IS_NATIVE; then
		sed 's/^/   /' >>"$DIAG_REPORT"
	else
		sed 's/^/   /' | tee -a "$DIAG_REPORT"
	fi
}

DIAG_KV() {
	DIAG_OUT "$(printf '%-24s %s' "$1:" "$2")"
}

DIAG_FINDING() {
	DIAG_FINDING_COUNT=$((DIAG_FINDING_COUNT + 1))
	DIAG_FINDINGS="${DIAG_FINDINGS}${DIAG_FINDING_COUNT}. [$1] $2
"
}

DIAG_READ() {
	[ -r "$1" ] && head -c 4096 "$1" 2>/dev/null | tr -d '\000'
}

DIAG_IS_NUM() {
	case "$1" in '' | - | *[!0-9-]*) return 1 ;; esac
	return 0
}

DIAG_ABS() {
	if [ "$1" -lt 0 ]; then printf '%d' $((-$1)); else printf '%d' "$1"; fi
}

# Runs a command with a time limit and adds its output to the report
DIAG_CMD() {
	DIAG_LABEL=$1
	shift
	DIAG_OUT "-- $DIAG_LABEL"
	if ! command -v "$1" >/dev/null 2>&1; then
		DIAG_OUT "   ($1 is not available)"
		return 1
	fi
	timeout 15 "$@" 2>&1 | head -n 400 | DIAG_APPEND
	return 0
}

DIAG_FILE() {
	DIAG_OUT "-- $1"
	if [ -r "$1" ]; then
		head -n 300 "$1" 2>/dev/null | DIAG_APPEND
	else
		DIAG_OUT "   (missing)"
	fi
}

# Lists every small readable attribute in a sysfs directory
DIAG_ATTRS() {
	for DIAG_ATTR in "$1"/*; do
		[ -f "$DIAG_ATTR" ] && [ -r "$DIAG_ATTR" ] || continue
		case "$(basename "$DIAG_ATTR")" in uevent | modalias | *_raw | edid | descriptors) continue ;; esac
		DIAG_OUT "$(printf '   %-28s %s' "$(basename "$DIAG_ATTR")" "$(DIAG_READ "$DIAG_ATTR" | head -n 1 | cut -c1-160)")"
	done
}

# Lists a configuration group, leaving out anything that could be a secret
DIAG_CONFIG() {
	DIAG_OUT "-- $1"
	[ -d "$1" ] || {
		DIAG_OUT "   (missing)"
		return
	}
	find "$1" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r DIAG_CFG; do
		DIAG_KEY=${DIAG_CFG#"$1"/}
		case "$DIAG_KEY" in
			*pass* | *ssid* | *secret* | *token* | *key* | *psk* | *uuid*) DIAG_VALUE="(hidden)" ;;
			*) DIAG_VALUE=$(DIAG_READ "$DIAG_CFG" | head -n 1 | cut -c1-120) ;;
		esac
		printf '   %-34s %s\n' "$DIAG_KEY" "$DIAG_VALUE"
	done | DIAG_TEE
}

# Writes already formatted lines into the report, and onto the terminal outside the frontend
DIAG_TEE() {
	if TASK_IS_NATIVE; then
		cat >>"$DIAG_REPORT"
	else
		tee -a "$DIAG_REPORT"
	fi
}

DIAG_RUNNING() {
	pidof "$1" >/dev/null 2>&1 || pgrep -f "$1" >/dev/null 2>&1
}

DIAG_DMESG() {
	DIAG_OUT "-- Kernel messages matching: $1"
	dmesg 2>/dev/null | grep -iE "$1" | tail -n "${2:-60}" | DIAG_APPEND
}

DIAG_DT_STR() {
	[ -r "$1" ] && tr '\0' ' ' <"$1"
}

DIAG_DT_U32() {
	[ -r "$1" ] || return 1
	od -An -v -tx1 "$1" | tr -s ' \n' ' ' | {
		read -r DIAG_BYTES
		# shellcheck disable=SC2086
		set -- $DIAG_BYTES
		DIAG_LIST=""
		while [ $# -ge 4 ]; do
			DIAG_LIST="$DIAG_LIST $(printf '%d' "0x$1$2$3$4")"
			shift 4
		done
		printf '%s' "${DIAG_LIST# }"
	}
}

DIAG_FINISH() {
	DIAG_SECTION "Findings"
	if [ "$DIAG_FINDING_COUNT" -eq 0 ]; then
		DIAG_OUT "No problems found."
	else
		printf '%s' "$DIAG_FINDINGS" >>"$DIAG_REPORT"
		TASK_IS_NATIVE || printf '%s' "$DIAG_FINDINGS"
	fi
	DIAG_OUT ""
	DIAG_OUT "Report saved to $DIAG_REPORT"
	sync

	TASK_DETAIL "$DIAG_REPORT"
	if [ "$DIAG_FINDING_COUNT" -eq 0 ]; then
		TASK_COMPLETE "${1:-Report saved} - no problems found"
	else
		TASK_COMPLETE "${1:-Report saved} - $DIAG_FINDING_COUNT finding(s)"
	fi
}
