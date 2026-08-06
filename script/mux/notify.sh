#!/bin/sh
# Raises a notification in the running frontend, for trying the levels and the stacking
# without having to reproduce whatever would normally cause them.
#
#   notify.sh <info|success|warning|error> "Message"
#   notify.sh stack          Sends several at once to watch them pile up
#
# Errors are raised as a modal that has to be acknowledged, the rest are toasts.

. /opt/muos/script/var/func.sh

DROP="$MUOS_RUN_DIR/notify"

SEND() {
	printf "%s\t%s\n" "$1" "$2" >>"$DROP"
}

case "${1:-}" in
	info | success | warning | error)
		[ -n "$2" ] || {
			printf "Usage: %s <info|success|warning|error> \"Message\"\n" "$(basename "$0")"
			exit 1
		}

		SEND "$1" "$2"
		;;
	stack)
		SEND "info" "First message, this one is oldest"
		SEND "success" "Second message came along"
		SEND "warning" "Third message pushes the stack"
		SEND "info" "Fourth waits its turn in the queue"
		;;
	*)
		printf "Usage: %s <info|success|warning|error> \"Message\"\n" "$(basename "$0")"
		printf "       %s stack\n" "$(basename "$0")"
		exit 1
		;;
esac
