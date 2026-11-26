#!/bin/sh

. /opt/muos/script/var/config.sh

HOOK_EVENT=${1:-}
[ $# -gt 0 ] && shift

case "$HOOK_EVENT" in
	startup | awake | content_finish | network_connect) HOOK_WAIT=0 ;;
	shutdown | sleep | content_start | network_disconnect) HOOK_WAIT=1 ;;
	*)
		printf 'Usage: %s {startup|shutdown|sleep|awake|content_start|content_finish|network_connect|network_disconnect} [argument]...\n' "$0" >&2
		exit 1
		;;
esac

IS_ONE "$(GET_VAR "config" "settings/advanced/user_init")" || exit 0

HOOK_DIR="$MUOS_STORE_DIR/hook/$HOOK_EVENT"
[ -d "$HOOK_DIR" ] || exit 0

HOOK_LOG_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/log"
HOOK_LOG="$HOOK_LOG_DIR/hook.log"
HOOK_TIMEOUT=${HOOK_TIMEOUT:-10}

mkdir -p "$HOOK_LOG_DIR"
[ "$HOOK_EVENT" = startup ] && : >"$HOOK_LOG"

MUOS_HOOK_EVENT=$HOOK_EVENT
export MUOS_HOOK_EVENT

for HOOK in "$HOOK_DIR"/*.sh; do
	[ -f "$HOOK" ] || continue

	printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$HOOK_EVENT" "${HOOK##*/}" >>"$HOOK_LOG"

	if [ "$HOOK_WAIT" -eq 1 ]; then
		timeout "$HOOK_TIMEOUT" sh "$HOOK" "$@" </dev/null >>"$HOOK_LOG" 2>&1
		HOOK_RC=$?
		[ "$HOOK_RC" -eq 0 ] || printf '[%s] [%s] %s exited with %s\n' \
			"$(date '+%Y-%m-%d %H:%M:%S')" "$HOOK_EVENT" "${HOOK##*/}" "$HOOK_RC" >>"$HOOK_LOG"
	else
		setsid sh "$HOOK" "$@" </dev/null >>"$HOOK_LOG" 2>&1 &
	fi
done

exit 0
