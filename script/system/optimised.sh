#!/bin/sh

. /opt/muos/script/var/log.sh

OPT_URL=$(GET_VAR "config" "extra/optimised/data")
OPT_ENABLED=$(GET_VAR "config" "settings/advanced/optimised")
OPT_NET_STATE=$(GET_VAR "device" "network/state")

OPT_DIR="$MUOS_STORE_DIR/info/manifest"
OPT_FILE="$OPT_DIR/optimised.json"
OPT_STAMP="$MUOS_RUN_DIR/optimised_checked"
OPT_LOCK="$MUOS_RUN_DIR/optimised.lock"
OPT_VERIFIER="/opt/muos/frontend/muverify"
OPT_AGE=720

OPT_URL=${OPT_URL:-https://github.com/MustardOS/extra/releases/latest/download/optimised.json}

[ "${OPT_ENABLED:-1}" = "1" ] || exit 0
[ -r "$OPT_NET_STATE" ] && [ "$(sed -n '1p' "$OPT_NET_STATE")" = "up" ] || exit 0
command -v curl >/dev/null 2>&1 || exit 0

if [ "${1-}" != "--force" ] && [ -e "$OPT_STAMP" ] && [ -n "$(find "$OPT_STAMP" -mmin "-$OPT_AGE" 2>/dev/null)" ]; then
	exit 0
fi

mkdir "$OPT_LOCK" 2>/dev/null || exit 0
OPT_TMP=$(mktemp -d "$MUOS_RUN_DIR/optimised.XXXXXX") || {
	rmdir "$OPT_LOCK"
	exit 1
}
trap 'rm -rf "$OPT_TMP"; rmdir "$OPT_LOCK" 2>/dev/null' EXIT INT TERM

touch "$OPT_STAMP"

OPT_FETCH() {
	curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
		--connect-timeout 5 --max-time 30 --max-filesize 4194304 -o "$2" "$1"
}

if ! OPT_FETCH "$OPT_URL" "$OPT_TMP/optimised.json" || ! OPT_FETCH "$OPT_URL.sig" "$OPT_TMP/optimised.json.sig"; then
	LOG_WARN "$0" 0 "OPTIMISED" "Could not download optimised profiles"
	exit 0
fi

if ! "$OPT_VERIFIER" --core "$OPT_TMP/optimised.json" "$OPT_TMP/optimised.json.sig" >/dev/null 2>&1; then
	LOG_WARN "$0" 0 "OPTIMISED" "Downloaded optimised profiles failed signature verification"
	exit 0
fi

if ! jq -e '(.generated | type) == "number" and (.content | type) == "object"' "$OPT_TMP/optimised.json" >/dev/null 2>&1; then
	LOG_WARN "$0" 0 "OPTIMISED" "Downloaded optimised profiles are not in the expected format"
	exit 0
fi

if [ -f "$OPT_FILE" ] && cmp -s "$OPT_FILE" "$OPT_TMP/optimised.json"; then
	exit 0
fi

mkdir -p "$OPT_DIR" &&
	mv -f "$OPT_TMP/optimised.json" "$OPT_FILE.tmp" &&
	mv -f "$OPT_FILE.tmp" "$OPT_FILE" &&
	LOG_INFO "$0" 0 "OPTIMISED" "Optimised profiles updated ($(jq '.content | length' "$OPT_FILE") entries)"
