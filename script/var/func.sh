#!/bin/sh

# Compatibility loader scheduled for deprecation in a future MustardOS release.
[ -n "${MUOS_FUNC_LOADED-}" ] && return 0
MUOS_FUNC_LOADED=1

MUOS_VAR_ROOT=${MUOS_VAR_DIR:-/opt/muos/script/var}
. "$MUOS_VAR_ROOT/base.sh"
. "$MUOS_VAR_ROOT/config.sh"
. "$MUOS_VAR_ROOT/input.sh"
. "$MUOS_VAR_ROOT/stage.sh"
. "$MUOS_VAR_ROOT/audio.sh"
. "$MUOS_VAR_ROOT/governor.sh"
. "$MUOS_VAR_ROOT/log.sh"
. "$MUOS_VAR_ROOT/service.sh"
. "$MUOS_VAR_ROOT/boot.sh"
. "$MUOS_VAR_ROOT/display.sh"
. "$MUOS_VAR_ROOT/retro.sh"
. "$MUOS_VAR_ROOT/theme.sh"
. "$MUOS_VAR_ROOT/runtime.sh"
. "$MUOS_VAR_ROOT/storage.sh"
unset MUOS_VAR_ROOT
