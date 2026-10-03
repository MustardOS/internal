#!/bin/sh

set -u

BASE=${1-}
REPORT=$(mktemp)
FILES=$(mktemp)
trap 'rm -f "$REPORT" "$FILES"' 0 HUP INT TERM

IS_SHELL() {
	case "$1" in
		*.sh) return 0 ;;
	esac

	IFS= read -r FIRST <"$1" 2>/dev/null || return 1
	case "$FIRST" in
		'#!'*/sh | '#!'*/sh' '* | '#!'*/bash* | '#!'*/ash* | '#!'*' sh' | '#!'*' bash'*) return 0 ;;
	esac
	return 1
}

ANNOTATE() {
	if [ -n "${GITHUB_ACTIONS-}" ]; then
		printf '::error file=%s,line=%s::%s\n' "$1" "$2" "$3"
	else
		printf '%s:%s: %s\n' "$1" "$2" "$3"
	fi
}

if [ -n "$BASE" ]; then
	git diff --name-only --diff-filter=ACMR "$BASE...HEAD"
else
	git ls-files
fi | while IFS= read -r FILE; do
	[ -f "$FILE" ] && IS_SHELL "$FILE" && printf '%s\n' "$FILE"
done >"$FILES"

if [ ! -s "$FILES" ]; then
	printf 'No shell scripts to check\n'
	exit 0
fi

printf 'Checking %s shell scripts for POSIX compliance\n' "$(wc -l <"$FILES" | tr -d ' ')"

FAILED=0

while IFS= read -r FILE; do
	IFS= read -r FIRST <"$FILE" 2>/dev/null || FIRST=
	case "$FIRST" in
		'#!/bin/sh' | '#!/bin/sh '* | '') ;;
		'#!'*)
			ANNOTATE "$FILE" 1 "Scripts must use '#!/bin/sh', found '$FIRST'"
			FAILED=1
			;;
	esac
done <"$FILES"

tr '\n' '\0' <"$FILES" | xargs -0 shellcheck --shell=sh --format=json1 >"$REPORT" 2>/dev/null

jq -r '
	.comments[]
	| select((.code >= 3000 and .code < 4000) or .level == "error")
	| [.file, .line, "SC\(.code): \(.message)"] | @tsv
' "$REPORT" >"$REPORT.tsv" || {
	rm -f "$REPORT.tsv"
	printf 'Unable to read the shellcheck report\n' >&2
	exit 1
}

TAB=$(printf '\t')
while IFS="$TAB" read -r FILE LINE MESSAGE; do
	ANNOTATE "$FILE" "$LINE" "$MESSAGE"
	FAILED=1
done <"$REPORT.tsv"
rm -f "$REPORT.tsv"

if [ "$FAILED" -eq 1 ]; then
	printf '\nNon-POSIX shell found. Scripts run under BusyBox ash, so please avoid bashisms.\n' >&2
	exit 1
fi

printf 'All shell scripts are POSIX compliant\n'
