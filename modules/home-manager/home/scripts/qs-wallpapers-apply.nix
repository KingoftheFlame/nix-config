{pkgs}:
pkgs.writeShellScriptBin "qs-wallpapers-apply" ''
  #!/usr/bin/env bash
  set -euo pipefail

  [ -n "''${QS_DEBUG:-}" ] && set -x
  DEBUG="''${QS_DEBUG:-}"
  log() { if [ -n "$DEBUG" ]; then echo "[qs-apply] $*" >&2; fi }

  PRINT_ONLY=0
  SHELL_ONLY=0
  RESTORE_ONLY=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --print-only) PRINT_ONLY=1; shift ;;
      --shell-only) SHELL_ONLY=1; shift ;;
      --restore)    RESTORE_ONLY=1; shift ;;
      *) break ;;
    esac
  done

  if [ $RESTORE_ONLY -eq 1 ]; then
    log "Restore requested; delegating to qs-wallpapers-restore"
    exec qs-wallpapers-restore
  fi

  BACKEND="''${WALLPAPER_BACKEND:-}"
  # Auto-detect sensible default backend per compositor when not provided via env
  if [ -z "''${BACKEND:-}" ]; then
    if [ "''${XDG_SESSION_DESKTOP:-}" = "Niri" ] || [ "''${XDG_CURRENT_DESKTOP:-}" = "Niri" ] || command -v niri >/dev/null 2>&1; then
      BACKEND="swww"
    else
      BACKEND="mpvpaper"
    fi
  fi

  if [ $SHELL_ONLY -eq 1 ]; then
    log "Shell-only perf run"
    QS_DEBUG= QS_SHELL_ONLY=1 QS_PERF="''${QS_PERF:-}" qs-wallpapers 2> >(cat >&2) || true
    exit 0
  fi

  # Run the picker with QS_DEBUG disabled so it prints the selection to stdout
  if [ $PRINT_ONLY -eq 1 ]; then
    log "Print-only run; auto-quit picker"
    if [ -n "''${QS_PERF:-}" ]; then
      # In perf mode, run picker in debug so QML [perf] logs are emitted to stderr
      QS_AUTO_QUIT=1 QS_PERF="''${QS_PERF:-}" QS_DEBUG=1 qs-wallpapers "$@" || true
    else
      sel="$(QS_AUTO_QUIT=1 QS_DEBUG= qs-wallpapers "$@" || true)"
      log "Selected=$sel"
    fi
    exit 0
  fi

  # Ensure any env-driven auto-quit/perf flags don't leak into normal runs
  sel="$(QS_DEBUG= QS_AUTO_QUIT= QS_PERF= qs-wallpapers "$@" || true)"

  if [ -z "''${sel:-}" ]; then
    log "No selection received; exiting"
    exit 0
  fi

  log "Backend=$BACKEND"
  log "Selected=$sel"

  # Persist current selection for restore-on-login
  STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/qs-wallpapers"
  STATE_FILE_JSON="$STATE_DIR/current.json"
  STATE_FILE_TXT="$STATE_DIR/current_wallpaper"
  ${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR"

  json_escape() { ${pkgs.gnused}/bin/sed 's/\\\\/\\\\\\\\/g;s/"/\\\\"/g'; }
  sel_esc="$(${pkgs.coreutils}/bin/printf '%s' "$sel" | json_escape)"

  tmp_json="$STATE_FILE_JSON.tmp"
  ${pkgs.coreutils}/bin/printf '{"path":"%s","backend":"%s","timestamp":%s}\n' \
    "$sel_esc" "$BACKEND" "$(${pkgs.coreutils}/bin/date +%s)" > "$tmp_json"
  ${pkgs.coreutils}/bin/mv -f "$tmp_json" "$STATE_FILE_JSON"

  tmp_txt="$STATE_FILE_TXT.tmp"
  ${pkgs.coreutils}/bin/printf '%s\n' "$sel" > "$tmp_txt"
  ${pkgs.coreutils}/bin/mv -f "$tmp_txt" "$STATE_FILE_TXT"

  # Maintain a convenient symlink for other tools and themes
  PIC_DIR="$HOME/Pictures"
  CUR_LINK="$PIC_DIR/current_wallpaper"
  ${pkgs.coreutils}/bin/mkdir -p "$PIC_DIR"
  ${pkgs.coreutils}/bin/ln -sfn "$sel" "$CUR_LINK" || true

  # Update hyprlock wallpaper link if tool is available
  if command -v hyprlock-update-wallpaper-link >/dev/null 2>&1; then
    hyprlock-update-wallpaper-link >/dev/null 2>&1 || true
  fi

  case "$BACKEND" in
    mpvpaper)
      # Stop other wallpaper daemons to avoid conflicts
      log "Stopping swww-daemon, hyprpaper, mpvpaper if running"
      ${pkgs.procps}/bin/pkill -x swww-daemon >/dev/null 2>&1 || true
      ${pkgs.procps}/bin/pkill -x hyprpaper >/dev/null 2>&1 || true
      ${pkgs.procps}/bin/pkill -x mpvpaper >/dev/null 2>&1 || true
      # Give the compositor a moment to release layers
      log "Sleeping briefly before starting mpvpaper"
      ${pkgs.coreutils}/bin/sleep 0.2
      # Apply to all monitors; replace '*' with a specific output if desired
      # Ensure images cover the output by enabling aspect-preserving zoom + crop
      MPV_OPTS="--no-audio --loop-file=inf --image-display-duration=inf --no-osc --no-osd-bar --keep-open=yes --keepaspect=yes --panscan=1.0"
      if [ -n "$DEBUG" ]; then
        ${pkgs.mpvpaper}/bin/mpvpaper \
          -o "$MPV_OPTS" \
          '*' "$sel" &
      else
        ${pkgs.mpvpaper}/bin/mpvpaper \
          -o "$MPV_OPTS" \
          '*' "$sel" >/dev/null 2>&1 &
      fi
      disown
      log "mpvpaper launched"
      exit 0
      ;;

    swww)
      ${pkgs.procps}/bin/pkill -x mpvpaper >/dev/null 2>&1 || true
      # Start swww-daemon if needed (newer swww has no 'init' subcommand)
      if ! ${pkgs.swww}/bin/swww query >/dev/null 2>&1; then
        log "Starting swww-daemon"
        ${pkgs.swww}/bin/swww-daemon >/dev/null 2>&1 & disown
        # wait briefly for the daemon to be ready
        for i in $(${pkgs.coreutils}/bin/seq 1 50); do
          if ${pkgs.swww}/bin/swww query >/dev/null 2>&1; then
            log "swww-daemon ready"
            break
          fi
          ${pkgs.coreutils}/bin/sleep 0.1
        done
      fi
      # Stop hyprpaper as well to avoid any conflict with layer surfaces
      ${pkgs.procps}/bin/pkill -x hyprpaper >/dev/null 2>&1 || true

      # Robust resize: if WALLPAPER_RESIZE is set, use it; otherwise try fill -> fit -> crop
      run_swww_img() {
        if [ -n "''${WALLPAPER_RESIZE:-}" ]; then
          log "swww img --resize ''${WALLPAPER_RESIZE} $sel"
          ${pkgs.swww}/bin/swww img --resize "''${WALLPAPER_RESIZE}" "$sel"
          return $?
        fi
        log "Trying swww resize modes: fill -> fit -> crop"
        ${pkgs.swww}/bin/swww img --resize fill "$sel" || \
        ${pkgs.swww}/bin/swww img --resize fit  "$sel" || \
        ${pkgs.swww}/bin/swww img --resize crop "$sel"
      }

      # Niri: generic apply has proven to work more reliably than per-output here
      run_swww_img
      exit $?
      ;;

    hyprpaper)
      ${pkgs.procps}/bin/pkill -x mpvpaper >/dev/null 2>&1 || true
      ${pkgs.procps}/bin/pkill -x swww-daemon >/dev/null 2>&1 || true
      # Generate a minimal hyprpaper config and start it
      _TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d)
      _CFG="$_TMPDIR/hyprpaper.conf"
      {
        echo "ipc=on"
        echo "splash=false"
      } > "$_CFG"
      # Add preload/wallpaper lines for each monitor
      ${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[].name' | while read -r mon; do
        echo "preload = $sel" >> "$_CFG"
        echo "wallpaper = $mon,$sel" >> "$_CFG"
      done
      log "Starting hyprpaper with config $_CFG"
      if [ -n "$DEBUG" ]; then
        ${pkgs.hyprpaper}/bin/hyprpaper -c "$_CFG" &
      else
        ${pkgs.hyprpaper}/bin/hyprpaper -c "$_CFG" >/dev/null 2>&1 &
      fi
      disown
      exit 0
      ;;

    *)
      echo "Unknown BACKEND: $BACKEND" >&2
      exit 2
      ;;
  esac
''
