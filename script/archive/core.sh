#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$MUOS_SHARE_DIR"
ARC_LABEL="RetroArch Cores"

ARC_EXTRACT() {
    DEST="$ARC_DIR"
    LABEL="$ARC_LABEL"
}

ARC_EXTRACT_POST() {
      printf "Updating Cores...\n"
    chmod -R +x "$ARC_DIR/core" >/dev/null 2>&1
}