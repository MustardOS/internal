#!/bin/sh

# Keep muOS-owned tools available to interactive and non-interactive login shells.
for _muos_path in /opt/muos/bin /opt/openssh/bin /opt/micro /opt/fish/bin /opt/java/bin; do
	[ -d "$_muos_path" ] || continue
	case ":${PATH:-}:" in
		*:"$_muos_path":*) ;;
		*) PATH="${PATH:+$PATH:}$_muos_path" ;;
	esac
done
export PATH

if [ -d /opt/java ]; then
	JAVA_HOME=/opt/java
	export JAVA_HOME
fi

if [ -x /opt/micro/micro ]; then
	EDITOR=/opt/micro/micro
elif [ -x /bin/vi ]; then
	EDITOR=/bin/vi
fi
[ -z "${EDITOR:-}" ] || export EDITOR

unset _muos_path
