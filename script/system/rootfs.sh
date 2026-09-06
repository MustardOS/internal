#!/bin/sh

MODE=${1:-restore}
ROOT_PREFIX=${2:-}

case "$ROOT_PREFIX" in
	"" | /) ROOT_PREFIX= ;;
	*/) ROOT_PREFIX=${ROOT_PREFIX%/} ;;
esac

COMMON_ROOT="$ROOT_PREFIX/opt/muos/share/conf/rootfs"

ROOT_PATH() {
	printf "%s/%s" "$ROOT_PREFIX" "$1"
}

ENSURE_PARENT() {
	PARENT=${1%/*}
	[ "$PARENT" = "$1" ] && PARENT=/
	mkdir -p "$PARENT"
}

INSTALL_FILE() {
	RELATIVE_PATH=$1
	FILE_MODE=$2
	MUTABLE=$3
	SOURCE_NAME=${RELATIVE_PATH##*/}
	SOURCE_PATH="$COMMON_ROOT/$SOURCE_NAME"
	TARGET_PATH=$(ROOT_PATH "$RELATIVE_PATH")

	[ -f "$SOURCE_PATH" ] || {
		printf "Missing common rootfs source: %s\n" "$SOURCE_PATH" >&2
		return 1
	}

	if [ "$MODE" = restore ] && [ "$MUTABLE" -eq 1 ] &&
		[ -f "$TARGET_PATH" ] && [ ! -L "$TARGET_PATH" ]; then
		chmod "$FILE_MODE" "$TARGET_PATH" 2>/dev/null || return 1
		return 0
	fi

	if [ "$MODE" = restore ] && [ "$MUTABLE" -eq 0 ] && cmp -s "$SOURCE_PATH" "$TARGET_PATH" 2>/dev/null; then
		chmod "$FILE_MODE" "$TARGET_PATH" 2>/dev/null || return 1
		return 0
	fi

	[ ! -d "$TARGET_PATH" ] || {
		printf "Refusing to replace rootfs directory: %s\n" "$TARGET_PATH" >&2
		return 1
	}

	ENSURE_PARENT "$TARGET_PATH" || return 1
	TARGET_TEMP="$TARGET_PATH.tmp.$$"
	rm -f "$TARGET_TEMP"
	cp -f "$SOURCE_PATH" "$TARGET_TEMP" || return 1
	chmod "$FILE_MODE" "$TARGET_TEMP" || {
		rm -f "$TARGET_TEMP"
		return 1
	}
	chown 0:0 "$TARGET_TEMP" 2>/dev/null || true
	mv -f "$TARGET_TEMP" "$TARGET_PATH"
}

ENSURE_LINK() {
	RELATIVE_PATH=$1
	LINK_TARGET=$2
	TARGET_PATH=$(ROOT_PATH "$RELATIVE_PATH")

	case "$LINK_TARGET" in
		/opt/muos/*)
			[ -e "$ROOT_PREFIX$LINK_TARGET" ] || {
				printf "Missing common rootfs link source: %s\n" "$ROOT_PREFIX$LINK_TARGET" >&2
				return 1
			}
			;;
	esac

	if [ -L "$TARGET_PATH" ] && [ "$(readlink "$TARGET_PATH")" = "$LINK_TARGET" ]; then
		return 0
	fi

	[ ! -d "$TARGET_PATH" ] || {
		printf "Refusing to replace rootfs directory: %s\n" "$TARGET_PATH" >&2
		return 1
	}

	ENSURE_PARENT "$TARGET_PATH" || return 1
	rm -f "$TARGET_PATH"
	ln -s "$LINK_TARGET" "$TARGET_PATH"
}

case "$MODE" in
	install | restore) ;;
	*)
		printf "Usage: %s {install|restore} [root-prefix]\n" "$0" >&2
		exit 2
		;;
esac

RESULT=0

INSTALL_FILE etc/issue 0644 0 || RESULT=1
INSTALL_FILE etc/hostname 0644 1 || RESULT=1
INSTALL_FILE etc/wpa_supplicant.conf 0600 1 || RESULT=1
INSTALL_FILE etc/umtprd/umtprd.conf 0644 0 || RESULT=1
INSTALL_FILE opt/sftpgo/sftpgo.json 0644 0 || RESULT=1

ENSURE_LINK etc/nsswitch.conf /opt/muos/share/conf/rootfs/nsswitch.conf || RESULT=1
ENSURE_LINK etc/profile.d/50-muos.sh /opt/muos/share/conf/rootfs/muos-profile.sh || RESULT=1
ENSURE_LINK etc/profile.d/umask.sh /opt/muos/share/conf/rootfs/umask.sh || RESULT=1

ENSURE_LINK etc/security/limits.d/25-pw-rlimits.conf /opt/muos/share/conf/rootfs/rlimits.conf || RESULT=1

ENSURE_LINK etc/mtab ../proc/self/mounts || RESULT=1
ENSURE_LINK etc/resolv.conf ../tmp/resolv.conf || RESULT=1

exit "$RESULT"
