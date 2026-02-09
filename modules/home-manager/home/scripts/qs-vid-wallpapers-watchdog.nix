{pkgs}:
pkgs.writeShellScriptBin "qs-vid-wallpapers-watchdog" ''
  #!/usr/bin/env bash
  set -euo pipefail

  [ -n "''${QS_DEBUG:-}" ] && set -x
  DEBUG="''${QS_DEBUG:-}"
  log() { if [ -n "$DEBUG" ]; then echo "[qs-vid-watchdog] $*" >&2; fi }

  log "Starting video wallpaper watchdog"

  # Get the current video wallpaper if any
  STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/qs-wallpapers"
  STATE_FILE_JSON="$STATE_DIR/current.json"

  if [ -f "$STATE_FILE_JSON" ]; then
    CURRENT_VIDEO="$(${pkgs.jq}/bin/jq -r '.path // empty' "$STATE_FILE_JSON" 2>/dev/null || true)"
    if [ -n "$CURRENT_VIDEO" ] && [ -f "$CURRENT_VIDEO" ]; then
      log "Monitoring video wallpaper: $CURRENT_VIDEO"

      # Monitor and restart if needed
      while true; do
        # Check if mpvpaper is running with video files
        if ! ${pkgs.procps}/bin/pgrep -f "mpvpaper.*\.\(mp4|m4v|mp4v|mov|webm|avi|mkv|mpeg|mpg|wmv|avchd|flv|ogv|m2ts|ts|3gp\)" > /dev/null; then
          log "Video wallpaper stopped, restarting..."

          # Get audio preference from state if available
          AUDIO="OFF"

          # Start mpvpaper with same options as the original script
          opts="--loop=inf --no-audio --no-osc --no-osd-bar --keep-open=yes --keepaspect=yes --hwdec=auto"

          ${pkgs.mpvpaper}/bin/mpvpaper \
            -o "$opts" \
            '*' "$CURRENT_VIDEO" >/dev/null 2>&1 &

          # Let it start
          sleep 3
        fi

        # Check every 10 seconds
        sleep 10
      done
    fi
  fi

  log "No video wallpaper to monitor"
''
