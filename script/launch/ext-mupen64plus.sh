#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "mupen64plus"

EMUDIR="$MUOS_SHARE_DIR/emulator/mupen64plus"
MP64_CFG="$EMUDIR/mupen64plus.cfg"
DEVICE_CFG="$EMUDIR/mupen64plus-device.cfg"
PLUGINDIR="$EMUDIR/plugins"
DATADIR="$EMUDIR/configs"

chmod +x "$EMUDIR"/mupen64plus
cd "$EMUDIR" || exit 1

if [ ! -f "$MP64_CFG" ]; then
	if [ ! -f "$DEVICE_CFG" ]; then
		exit 1
	fi

	if ! cp "$DEVICE_CFG" "$MP64_CFG"; then
		exit 1
	fi
fi

CONTROLS_DIR="$MUOS_STORE_DIR/save/file/Mupen64Plus"
TEMPLATE_INI="$DATADIR/Default-InputAutoCfg.ini"
TARGET_INI="$DATADIR/InputAutoCfg.ini"

FILENAME="$(basename -- "$FILE")"
GAMECONTROLS="${FILENAME%.*}"

CUSTOM_INI="$CONTROLS_DIR/${GAMECONTROLS}.ini"
DEFAULT_INI="$CONTROLS_DIR/Default.ini"
SAMPLE_INI="$CONTROLS_DIR/Sample.ini"

mkdir -p "$CONTROLS_DIR"

# 1) Sample.ini generation
if [ ! -f "$SAMPLE_INI" ]; then
	CONTROLLERNAME="$(/opt/muos/bin/sdl2-jstest --list 2>/dev/null |
		sed -n "s/^Joystick Name:[[:space:]]*'\(.*\)'.*$/\1/p" |
		head -n1)"
	if [ -n "$CONTROLLERNAME" ] && [ -f "$TEMPLATE_INI" ]; then
		ESCNAME="$(printf '%s' "$CONTROLLERNAME" | sed 's/[.[\*^$\/&]/\\&/g')"
		awk -v sec="$ESCNAME" '
      BEGIN{insec=0}
      /^\[.*\]$/{
        if(insec==1) exit
        name=$0; sub(/^\[/,"",name); sub(/\]$/,"",name)
        gsub(/^[ \t]+|[ \t]+$/, "", name)
        if(name==sec){ insec=1; print; next }
      }
      insec==1{ print }
    ' "$TEMPLATE_INI" >"$SAMPLE_INI"
		[ -s "$SAMPLE_INI" ] || rm -f "$SAMPLE_INI"
	fi
fi

# 2) Applicable ini file link (priority: ${GAMECONTROLS}.ini → Default.ini → Default-InputAutoCfg.ini)
rm -f "$TARGET_INI"
if [ -f "$CUSTOM_INI" ]; then
	ln -sf "$CUSTOM_INI" "$TARGET_INI"
elif [ -f "$DEFAULT_INI" ]; then
	ln -sf "$DEFAULT_INI" "$TARGET_INI"
else
	ln -sf "$TEMPLATE_INI" "$TARGET_INI"
fi

# 3) Panel resolution
FBSET_GEO=$(fbset -s 2>/dev/null | awk '/^ *geometry/ {print $2" "$3; exit}')
PXRES=${FBSET_GEO%% *}
PYRES=${FBSET_GEO##* }

# Rotation
ROT="$(GET_VAR device sdl/rotation)"

if [ "$ROT" = "1" ]; then
	if [ "$PXRES" -ge "$PYRES" ]; then
		XRES="$PXRES"
		YRES="$PYRES"
	else
		XRES="$PYRES"
		YRES="$PXRES"
	fi
else
	XRES="$PXRES"
	YRES="$PYRES"
fi

# 4) Compressed ROM processing (.zip only)
ZIP_TMPDIR=""
case "$FILE" in
	*.zip | *.ZIP)
		ZIP_TMPDIR="$(mktemp -d)"
		unzip -q "$FILE" -d "$ZIP_TMPDIR"
		for TMPFILE in "$ZIP_TMPDIR"/*; do
			case "$TMPFILE" in
				*.n64 | *.N64 | *.v64 | *.V64 | *.z64 | *.Z64)
					FILE="$TMPFILE"
					break
					;;
			esac
		done
		;;
esac

# 5) Launch Script branch

MK2_SO="mupen64plus-video-glide64mk2.so"
RICE_SO="mupen64plus-video-rice.so"
GL64_SO="mupen64plus-video-GLideN64.so"

# ===================== Early branch: 720x720 + GLideN64 Full via FB_SWITCH =====================
if [ "$CORE" = "ext-mupen64plus-gliden64-full" ] && [ "$XRES" -eq 720 ] && [ "$YRES" -eq 720 ]; then
	FB_SWITCH 320 240 32
	HOME="$EMUDIR" ./mupen64plus --corelib ./libmupen64plus.so.2.0.0 --configdir . \
		--plugindir "$PLUGINDIR" --datadir "$DATADIR" \
		--gfx "$GL64_SO" --set "Video-GLideN64[AspectRatio]=0" --resolution "320x240" "$FILE"
	RET=$?

	[ -n "$ZIP_TMPDIR" ] && rm -rf "$ZIP_TMPDIR"

	FB_SWITCH 720 720 32
	exit $RET
fi

# Build args via positional parameters to avoid word-splitting on flag strings
set -- --plugindir "$PLUGINDIR" --datadir "$DATADIR"

case "$CORE" in
	# Rice 4:3 - 720x720 is the only exception, the rest are calculated in 4:3 width based on height.
	ext-mupen64plus-rice)
		if [ "$XRES" -eq 720 ] && [ "$YRES" -eq 720 ]; then
			set -- "$@" --datadir "$DATADIR" --gfx "$RICE_SO" --resolution "720x540" \
				--set "Video-Rice[VerticalOffset]=90" \
				--set "Video-Rice[ResolutionWidth]=720" \
				--set "Video-Rice[ResolutionHeight]=540"
		else
			set -- "$@" --datadir "$DATADIR" --gfx "$RICE_SO" \
				--resolution "$(((YRES * 4) / 3))x${YRES}" \
				--set "Video-Rice[VerticalOffset]=0" \
				--set "Video-Rice[ResolutionWidth]=$XRES" \
				--set "Video-Rice[ResolutionHeight]=$YRES"
		fi
		;;

	# Rice full → As is the panel resolution
	ext-mupen64plus-rice-full)
		set -- "$@" --gfx "$RICE_SO" --resolution "${XRES}x${YRES}" \
			--set "Video-Rice[VerticalOffset]=0" \
			--set "Video-Rice[ResolutionWidth]=$XRES" \
			--set "Video-Rice[ResolutionHeight]=$YRES"
		;;

	# GLideN64 4:3
	ext-mupen64plus-gliden64)
		set -- "$@" --gfx "$GL64_SO" --set "Video-GLideN64[AspectRatio]=1" --resolution "${XRES}x${YRES}"
		;;

	# GLideN64 full
	ext-mupen64plus-gliden64-full)
		set -- "$@" --gfx "$GL64_SO" --set "Video-GLideN64[AspectRatio]=0" --resolution "${XRES}x${YRES}"
		;;

	# Glide64mk2 4:3
	ext-mupen64plus-glidemk2)
		set -- "$@" --gfx "$MK2_SO" --set "Video-Glide64mk2[aspect]=0" --resolution "${XRES}x${YRES}"
		;;

	# Glide64mk2 full
	ext-mupen64plus-glidemk2-full)
		set -- "$@" --gfx "$MK2_SO" --set "Video-Glide64mk2[aspect]=2" --resolution "${XRES}x${YRES}"
		;;
esac

case "$(GET_VAR "device" "board/name")" in
	mgx* | tui*)
		case "$CORE" in
			ext-mupen64plus-glidemk2 | ext-mupen64plus-glidemk2-full) setalpha 0 ;;
		esac
		;;
esac

HOME="$EMUDIR" ./mupen64plus --corelib ./libmupen64plus.so.2.0.0 --configdir . "$@" "$FILE"

[ -n "$ZIP_TMPDIR" ] && rm -rf "$ZIP_TMPDIR"
