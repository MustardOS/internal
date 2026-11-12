#!/bin/sh

case "${1:-}" in
	recover)
		X86_BOOT_WIDTH=
		X86_BOOT_HEIGHT=
		[ ! -r /opt/muos/device/config/screen/width ] || IFS= read -r X86_BOOT_WIDTH </opt/muos/device/config/screen/width
		[ ! -r /opt/muos/device/config/screen/height ] || IFS= read -r X86_BOOT_HEIGHT </opt/muos/device/config/screen/height

		X86_BOOT_LOGO="/opt/muos/share/bootlogo/${X86_BOOT_WIDTH}x${X86_BOOT_HEIGHT}/bootlogo.bmp"
		[ -f "$X86_BOOT_LOGO" ] || X86_BOOT_LOGO=/opt/muos/share/bootlogo/640x480/bootlogo.bmp

		if [ -c /dev/fb0 ] && [ -x /opt/muos/frontend/musplash ] && [ -f "$X86_BOOT_LOGO" ]; then
			exec /opt/muos/frontend/musplash -i "$X86_BOOT_LOGO" -f /dev/fb0 -s stretch
		fi
		;;
esac

exit 0
