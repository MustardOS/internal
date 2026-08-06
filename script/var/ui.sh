#!/bin/sh

# When the frontend runs a task natively it sets MUOS_TASK_UI, and these helpers
# emit protocol records for it to read.  Without that variable the same calls print
# plain text, so one script serves both the native and terminal paths.
#
# Records go to descriptor 3 rather than stdout. So TASK_PROMPT has to return its answer
# through a command substitution, which captures stdout, then a record written there
# would never reach the frontend.  All task scripts must leave descriptor 3 alone!
#
# The Diagnostics script belong on stderr either way, which is logged rather than displayed.

TASK_CLEAN() {
	printf '%s' "$1" | tr -d '\011\012\015'
}

TASK_IS_NATIVE() {
	[ -n "${MUOS_TASK_UI:-}" ]
}

if TASK_IS_NATIVE; then
	exec 3>&1

	TASK_BEGIN() {
		printf 'MUOS:BEGIN\tID=%s\tTITLE=%s\n' "$(TASK_CLEAN "$1")" "$(TASK_CLEAN "$2")" >&3
	}

	TASK_STATUS() {
		printf 'MUOS:STATUS\tTEXT=%s\n' "$(TASK_CLEAN "$1")" >&3
	}

	TASK_DETAIL() {
		printf 'MUOS:DETAIL\tTEXT=%s\n' "$(TASK_CLEAN "$1")" >&3
	}

	# A maximum of zero tells the frontend to show an indeterminate indicator
	TASK_PROGRESS() {
		printf 'MUOS:PROGRESS\tVALUE=%s\tMAX=%s\n' "${1:-0}" "${2:-0}" >&3
	}

	TASK_LOG() {
		printf 'MUOS:LOG\tLEVEL=%s\tTEXT=%s\n' "$(TASK_CLEAN "$1")" "$(TASK_CLEAN "$2")" >&3
	}

	TASK_ERROR() {
		printf 'MUOS:ERROR\tCODE=%s\tTEXT=%s\n' "$(TASK_CLEAN "$1")" "$(TASK_CLEAN "$2")" >&3
	}

	TASK_COMPLETE() {
		printf 'MUOS:COMPLETE\tTEXT=%s\n' "$(TASK_CLEAN "$1")" >&3
	}

	# Asks the frontend a question and echoes the chosen value.
	# Usage: TASK_PROMPT id type title message "One|Two" default
	# Returns non-zero when the user cancelled instead of answering.
	TASK_PROMPT() {
		printf 'MUOS:PROMPT\tID=%s\tTYPE=%s\tTITLE=%s\tMESSAGE=%s\tOPTIONS=%s\tDEFAULT=%s\n' \
			"$(TASK_CLEAN "$1")" "$(TASK_CLEAN "$2")" "$(TASK_CLEAN "$3")" \
			"$(TASK_CLEAN "$4")" "$(TASK_CLEAN "$5")" "$(TASK_CLEAN "$6")" >&3

		while IFS= read -r TASK_REPLY; do
			case "$TASK_REPLY" in
				"MUOS:CANCEL") return 1 ;;
				"MUOS:RESPONSE	"*)
					printf '%s' "${TASK_REPLY##*VALUE=}"
					return 0
					;;
			esac
		done

		return 1
	}

else

	TASK_BEGIN() {
		printf '%s\n' "$2"
	}

	TASK_STATUS() {
		printf '%s\n' "$1"
	}

	TASK_DETAIL() {
		printf '  %s\n' "$1"
	}

	TASK_PROGRESS() {
		[ "${2:-0}" -gt 0 ] 2>/dev/null && printf '  %s of %s\n' "$1" "$2"
	}

	TASK_LOG() {
		printf '%s\n' "$2" >&2
	}

	TASK_ERROR() {
		printf 'Error: %s\n' "$2"
	}

	TASK_COMPLETE() {
		printf '%s\n' "$1"
	}

	# Without the frontend there is nobody around to ask!
	TASK_PROMPT() {
		printf '%s' "$6"
	}

fi
