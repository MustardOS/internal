#!/bin/sh

for _muos_path in /opt/muos/bin /opt/muos/share/emulator/zulu/bin; do
	[ -d "$_muos_path" ] || continue
	case ":${PATH:-}:" in
		*:"$_muos_path":*) ;;
		*) PATH="${PATH:+$PATH:}$_muos_path" ;;
	esac
done
export PATH

if [ -d /opt/muos/share/emulator/zulu ]; then
	JAVA_HOME=/opt/muos/share/emulator/zulu
	export JAVA_HOME
fi

if [ -x /bin/vi ]; then
	EDITOR=/bin/vi
fi
[ -z "${EDITOR:-}" ] || export EDITOR

unset _muos_path
