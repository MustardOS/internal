#!/bin/sh

USAGE() {
	echo "Usage: $(basename "$0") [-h | -P | -r]"
	exit 1
}

[ "$#" -gt 1 ] && USAGE

case "${1:-}" in
	-h | -P | "") /opt/muos/script/system/halt.sh poweroff ;;
	-r) /opt/muos/script/system/halt.sh reboot ;;
	*) USAGE ;;
esac
