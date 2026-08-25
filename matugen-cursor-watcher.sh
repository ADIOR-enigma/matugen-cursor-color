#!/usr/bin/env bash
# =============================================================================
# Matugen Cursor Watcher Daemon
#
# This script runs perpetually in the background. It uses inotifywait to 
# monitor the Lua file that Matugen generates. When Matugen updates the file 
# with new colors, this daemon instantly triggers the cursor compiler script.
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
readonly WATCH_DIR="$HOME/.config/matugen/generated"
readonly WATCH_FILE="hyprland-colors.lua"
readonly BUILD_SCRIPT="$HOME/.config/hypr/scripts/matugen-cursor.sh"
readonly LOG_FILE="/tmp/matugen-cursor.log"

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------
log() { 
  echo "[watcher] $(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

cleanup() { 
  log "Shutting down the watcher daemon safely."
  exit 0
}

# Trap termination signals so the script exits cleanly
trap cleanup SIGINT SIGTERM EXIT

# -----------------------------------------------------------------------------
# Main Loop
# -----------------------------------------------------------------------------
main() {
  log "--- Starting Watcher Daemon ---"
  
  # Ensure the directory exists so inotifywait doesn't fail
  mkdir -p "$WATCH_DIR"
  
  # Verify inotifywait is installed
  if ! command -v inotifywait >/dev/null 2>&1; then
    log "CRITICAL ERROR: 'inotifywait' is not installed. Please install 'inotify-tools'."
    exit 1
  fi

  # Monitor the directory for close_write, moved_to, and create events.
  # This ensures we catch Matugen updates whether it writes in-place or uses atomic temp file replacement.
  inotifywait -m -e close_write -e moved_to -e create --format '%f' "$WATCH_DIR" 2>/dev/null | \
  while read -r file; do
    if [[ "$file" == "$WATCH_FILE" ]]; then
      log "Detected a color update in $WATCH_FILE! Triggering cursor compilation..."
      # Spawn the build script in the background so we immediately resume watching
      bash "$BUILD_SCRIPT" &
    fi
  done
}

main
