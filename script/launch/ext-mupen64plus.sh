#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

(
  LOG_INFO "$0" 0 "Content Launch" "DETAIL"
  LOG_INFO "$0" 0 "NAME" "$NAME"
  LOG_INFO "$0" 0 "CORE" "$CORE"
  LOG_INFO "$0" 0 "FILE" "$FILE"
) &

HOME="$(GET_VAR "device" "board/home")"
export HOME

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
    
    cp "$DEVICE_CFG" "$MP64_CFG"
    
    if [ $? -ne 0 ]; then
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
  CONTROLLERNAME="$(/opt/muos/bin/sdl2-jstest --list 2>/dev/null \
    | sed -n "s/^Joystick Name:[[:space:]]*'\(.*\)'.*$/\1/p" \
    | head -n1)"
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
    ' "$TEMPLATE_INI" > "$SAMPLE_INI"
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


# 3) Panel resolution (for numeric parsing; for Rice centering calculations)
eval "$(fbset -s 2>/dev/null | awk '/^ *geometry/ {print "PXRES="$2";PYRES="$3}')" || true

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

# 4:3 width by panel height (ex 720x480 → 640)
W43=$(((YRES * 4) / 3))

# 4) Compressed ROM processing (.zip only)
case "$FILE" in
  *.zip|*.ZIP)
    TMPDIR="$(mktemp -d)"
    unzip -q "$FILE" -d "$TMPDIR"
    for TMPFILE in "$TMPDIR"/*; do
      case "$TMPFILE" in
        *.n64|*.N64|*.v64|*.V64|*.z64|*.Z64) FILE="$TMPFILE"; break ;;
      esac
    done
    ;;
esac

# 5) Launch Script branch

MK2_SO="mupen64plus-video-glide64mk2.so"
RICE_SO="mupen64plus-video-rice.so"
GL64_SO="mupen64plus-video-GLideN64.so"

# Rice only: UI-level resolution/fullscreen flag (to maintain center alignment)
BASE="--plugindir $PLUGINDIR --datadir $DATADIR"
EXTRA_ARGS=""

# ===================== [Added] Early branch start =====================
# Purpose: Only when it's 720x720 + GLideN64 Full, run via FB_SWITCH path and exit immediately
if [ "$CORE" = "ext-mupen64plus-gliden64-full" ] && [ "$XRES" -eq 720 ] && [ "$YRES" -eq 720 ]; then
  # Original method: enter FB_SWITCH → specify GLideN64 Full params → run
  FB_SWITCH 320 240 32
  HOME="$EMUDIR" ./mupen64plus --corelib ./libmupen64plus.so.2.0.0 --configdir . \
    --plugindir "$PLUGINDIR" --datadir "$DATADIR" \
    --gfx "$GL64_SO" --set "Video-GLideN64[AspectRatio]=0" --resolution "320x240" "$FILE"
  RET=$?

  # Clean up extracted zip (if any)
  [ -n "$TMPDIR" ] && rm -r "$TMPDIR"

  # Restore panel native mode (720x720)
  FB_SWITCH 720 720 32

  exit $RET
fi
# ===================== [Added] Early branch end =====================

case "$CORE" in
  # Rice 4:3 — 720x720 is the only exception, the rest are calculated in 4:3 width based on height.
  ext-mupen64plus-rice)
  if [ "$XRES" -eq 720 ] && [ "$YRES" -eq 720 ]; then
    EXTRA_ARGS="$BASE --datadir $DATADIR --gfx $RICE_SO --resolution 720x540 --set Video-Rice[VerticalOffset]=90 --set Video-Rice[ResolutionWidth]=720 --set Video-Rice[ResolutionHeight]=540"
  else
    EXTRA_ARGS="$BASE --datadir $DATADIR --gfx $RICE_SO --resolution $(((YRES*4)/3))x${YRES} --set Video-Rice[VerticalOffset]=0 --set Video-Rice[ResolutionWidth]=$XRES --set Video-Rice[ResolutionHeight]=$YRES"
  fi
  ;;

  # Rice full → As is the panel resolution
  ext-mupen64plus-rice-full)
    EXTRA_ARGS="$BASE --gfx $RICE_SO --resolution ${XRES}x${YRES} --set Video-Rice[VerticalOffset]=0 --set Video-Rice[ResolutionWidth]=$XRES --set Video-Rice[ResolutionHeight]=$YRES"
    ;;

  # GLideN64 4:3
  ext-mupen64plus-gliden64)
    EXTRA_ARGS="$BASE --gfx $GL64_SO --set Video-GLideN64[AspectRatio]=1 --resolution ${XRES}x${YRES}"
    ;;

  # GLideN64 full
  ext-mupen64plus-gliden64-full)
    EXTRA_ARGS="$BASE --gfx $GL64_SO --set Video-GLideN64[AspectRatio]=0 --resolution ${XRES}x${YRES}"
    ;;

  # Glide64mk2 4:3
  ext-mupen64plus-glidemk2)
    EXTRA_ARGS="$BASE --gfx $MK2_SO --set Video-Glide64mk2[aspect]=0 --resolution ${XRES}x${YRES}"
    ;;

  # Glide64mk2 full
  ext-mupen64plus-glidemk2-full)
    EXTRA_ARGS="$BASE --gfx $MK2_SO --set Video-Glide64mk2[aspect]=2 --resolution ${XRES}x${YRES}"
    ;;
esac

case "$(GET_VAR "device" "board/name")" in
  mgx* | tui*)
    case "$CORE" in
      ext-mupen64plus-glidemk2|ext-mupen64plus-glidemk2-full)
        setalpha 0 || true
        ;;
    esac
    ;;
esac

HOME="$EMUDIR" ./mupen64plus --corelib ./libmupen64plus.so.2.0.0 --configdir . $EXTRA_ARGS "$FILE"

# Clean up temp files if we unzipped the file
[ -n "$TMPDIR" ] && rm -r "$TMPDIR"