{pkgs}:
pkgs.writeShellScriptBin "qs-vid-wallpapers-apply" ''
  #!/usr/bin/env bash
  set -euo pipefail

  [ -n "''${QS_DEBUG:-}" ] && set -x
  DEBUG="''${QS_DEBUG:-}"
  log() { if [ -n "$DEBUG" ]; then echo "[qs-vid-apply] $*" >&2; fi }

  PRINT_ONLY=0
  SHELL_ONLY=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --print-only) PRINT_ONLY=1; shift ;;
      --shell-only) SHELL_ONLY=1; shift ;;
      *) break ;;
    esac
  done

  BACKEND="''${WALLPAPER_BACKEND:-mpvpaper}"

  if [ $SHELL_ONLY -eq 1 ]; then
    log "Shell-only perf run"
    QS_DEBUG= QS_SHELL_ONLY=1 QS_PERF="''${QS_PERF:-}" qs-vid-wallpapers 2> >(cat >&2) || true
    exit 0
  fi

  if [ $PRINT_ONLY -eq 1 ]; then
    log "Print-only run; auto-quit picker"
    if [ -n "''${QS_PERF:-}" ]; then
      QS_AUTO_QUIT=1 QS_PERF="''${QS_PERF:-}" QS_DEBUG=1 qs-vid-wallpapers "$@" || true
    else
      sel="$(QS_AUTO_QUIT=1 QS_DEBUG= qs-vid-wallpapers "$@" || true)"
      log "Selected=$sel"
    fi
    exit 0
  fi

  out="$(QS_DEBUG= QS_AUTO_QUIT= QS_PERF= qs-vid-wallpapers "$@" || true)"
  sel=$(${pkgs.coreutils}/bin/printf "%s\n" "$out" | ${pkgs.gawk}/bin/awk -F'SELECT:' '/SELECT:/{print $2}' | ${pkgs.coreutils}/bin/tail -n1)
  audio=$(${pkgs.coreutils}/bin/printf "%s\n" "$out" | ${pkgs.gawk}/bin/awk -F'AUDIO:' '/AUDIO:/{print $2}' | ${pkgs.coreutils}/bin/tail -n1)

  # Fallback: some picker builds output only the path; if so, treat it as selection
  if [ -z "''${sel:-}" ] && [ -n "''${out:-}" ] && [ -f "''${out}" ]; then
    sel="$out"
  fi

  if [ -z "''${sel:-}" ]; then
    log "No selection received; exiting"
    exit 0
  fi

  # default to OFF if not provided by picker
  if [ -z "''${audio:-}" ]; then
    audio="OFF"
  fi

  log "Backend=$BACKEND"
  log "Selected=$sel"
  log "Audio=$audio"

  # Force mpvpaper for video wallpapers
  if [ "''${BACKEND}" != "mpvpaper" ]; then
    log "Forcing BACKEND=mpvpaper for video wallpapers (was: $BACKEND)"
    BACKEND="mpvpaper"
  fi

  case "$BACKEND" in
    mpvpaper)
      log "Stopping swww-daemon, hyprpaper, mpvpaper if running"
      ${pkgs.procps}/bin/pkill -x swww-daemon >/dev/null 2>&1 || true
      ${pkgs.procps}/bin/pkill -x hyprpaper >/dev/null 2>&1 || true
      ${pkgs.procps}/bin/pkill -x mpvpaper >/dev/null 2>&1 || true
      log "Sleeping briefly before starting mpvpaper"
      ${pkgs.coreutils}/bin/sleep 0.2
      # Build mpv options string based on audio toggle
      # Use both --loop-file and --loop for maximum compatibility
      opts="--loop-file=inf --loop=inf --image-display-duration=inf --no-osc --no-osd-bar --keep-open=yes"
      if [ """$audio""" != "ON" ]; then
        opts="--no-audio $opts"
      fi
      if [ -n "$DEBUG" ]; then
        ${pkgs.mpvpaper}/bin/mpvpaper \
          -o "$opts" \
          '*' "$sel" &
      else
        ${pkgs.mpvpaper}/bin/mpvpaper \
          -o "$opts" \
          '*' "$sel" >/dev/null 2>&1 &
      fi
      disown
      log "mpvpaper launched"
      exit 0
      ;;

    *)
      echo "Unknown BACKEND: $BACKEND" >&2
      exit 2
      ;;
  esac
''
