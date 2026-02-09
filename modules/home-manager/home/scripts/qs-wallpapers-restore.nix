{pkgs}:
pkgs.writeShellScriptBin "qs-wallpapers-restore" ''
  #!/usr/bin/env bash
  set -euo pipefail

  [ -n "''${QS_DEBUG:-}" ] && set -x
  DEBUG="''${QS_DEBUG:-}"
  log() { if [ -n "$DEBUG" ]; then echo "[qs-restore] $*" >&2; fi }

  # Read state
  STATE_FILE_JSON="''${XDG_STATE_HOME:-$HOME/.local/state}/qs-wallpapers/current.json"
  STATE_FILE_TXT="''${XDG_STATE_HOME:-$HOME/.local/state}/qs-wallpapers/current_wallpaper"

  PATH_J=""
  BACKEND_J=""
  if [ -f "$STATE_FILE_JSON" ]; then
    PATH_J="$(${pkgs.jq}/bin/jq -r '.path // ""' "$STATE_FILE_JSON" 2>/dev/null || true)"
    BACKEND_J="$(${pkgs.jq}/bin/jq -r '.backend // ""' "$STATE_FILE_JSON" 2>/dev/null || true)"
  elif [ -f "$STATE_FILE_TXT" ]; then
    PATH_J="$(${pkgs.coreutils}/bin/head -n1 "$STATE_FILE_TXT" 2>/dev/null || true)"
  fi

  if [ -z "''${PATH_J:-}" ] || [ ! -f "$PATH_J" ]; then
    log "No valid saved wallpaper path; exiting"
    exit 0
  fi

  # Update hyprlock wallpaper link if tool is available
  if command -v hyprlock-update-wallpaper-link >/dev/null 2>&1; then
    hyprlock-update-wallpaper-link >/dev/null 2>&1 || true
  fi

  # Order: recorded backend first, then swww -> hyprpaper -> mpvpaper -> waypaper
  ORDER_DEFAULT="swww,hyprpaper,mpvpaper,waypaper"
  ORDER_COMBINED="$BACKEND_J,$ORDER_DEFAULT"
  # De-duplicate while preserving order (awk trick)
  ORDER=$({ echo "$ORDER_COMBINED" | ${pkgs.coreutils}/bin/tr ',' '\n' | ${pkgs.gawk}/bin/awk 'NF{ if (!seen[$0]++) print $0 }' | ${pkgs.coreutils}/bin/tr '\n' ','; echo; } | ${pkgs.coreutils}/bin/tr -s ',' | ${pkgs.gnused}/bin/sed 's/^,\|,$//g')
  if [ -n "''${QS_RESTORE_ORDER:-}" ]; then
    ORDER="''${QS_RESTORE_ORDER}"
  fi
  log "ORDER=$ORDER"

  # Helpers
  wait_for_proc() {
    local name="$1"; local timeout="''${2:-10}"; local i
    for i in $(${pkgs.coreutils}/bin/seq 1 "$timeout"); do
      if ${pkgs.procps}/bin/pgrep -x "$name" >/dev/null 2>&1; then return 0; fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    return 1
  }

  start_swww() {
    # Honor Hyprpanel requirement: do not start swww-daemon before Hyprpanel
    local wait_sec="''${QS_RESTORE_WAIT_HYPRPANEL_SECONDS:-15}"
    if ${pkgs.procps}/bin/pgrep -x hyprpanel >/dev/null 2>&1; then
      log "hyprpanel detected; proceeding"
    else
      # If waybar is already running, it's fine to proceed immediately
      if ${pkgs.procps}/bin/pgrep -x waybar >/dev/null 2>&1; then
        log "waybar detected; proceeding without waiting for hyprpanel"
      else
        log "Waiting up to ''${wait_sec}s for hyprpanel before starting swww-daemon"
        wait_for_proc hyprpanel "$wait_sec" || log "hyprpanel not detected after ''${wait_sec}s; proceeding"
      fi
    fi

    # Stop conflicting daemons if we intend to use swww
    ${pkgs.procps}/bin/pkill -x mpvpaper >/dev/null 2>&1 || true
    ${pkgs.procps}/bin/pkill -x hyprpaper >/dev/null 2>&1 || true

    if ! ${pkgs.swww}/bin/swww query >/dev/null 2>&1; then
      log "Starting swww-daemon"
      ${pkgs.swww}/bin/swww-daemon >/dev/null 2>&1 & disown
      for i in $(${pkgs.coreutils}/bin/seq 1 50); do
        if ${pkgs.swww}/bin/swww query >/dev/null 2>&1; then break; fi
        ${pkgs.coreutils}/bin/sleep 0.1
      done
    fi
    # Robust resize: use explicit WALLPAPER_RESIZE if provided; otherwise try fill -> fit -> crop
    if [ -n "''${WALLPAPER_RESIZE:-}" ]; then
      log "swww img --resize ''${WALLPAPER_RESIZE} $PATH_J"
      ${pkgs.swww}/bin/swww img --resize "''${WALLPAPER_RESIZE}" "$PATH_J"
    else
      log "Trying swww resize modes: fill -> fit -> crop"
      ${pkgs.swww}/bin/swww img --resize fill "$PATH_J" || \
      ${pkgs.swww}/bin/swww img --resize fit  "$PATH_J" || \
      ${pkgs.swww}/bin/swww img --resize crop "$PATH_J"
    fi
  }

  start_hyprpaper() {
    ${pkgs.procps}/bin/pkill -x mpvpaper >/dev/null 2>&1 || true
    ${pkgs.procps}/bin/pkill -x swww-daemon >/dev/null 2>&1 || true
    _TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d)
    _CFG="$_TMPDIR/hyprpaper.conf"
    {
      echo "ipc=on"
      echo "splash=false"
    } > "$_CFG"
    ${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[].name' | while read -r mon; do
      echo "preload = $PATH_J" >> "$_CFG"
      echo "wallpaper = $mon,$PATH_J" >> "$_CFG"
    done
    log "Starting hyprpaper"
    ${pkgs.hyprpaper}/bin/hyprpaper -c "$_CFG" >/dev/null 2>&1 & disown
  }

  start_mpvpaper() {
    ${pkgs.procps}/bin/pkill -x swww-daemon >/dev/null 2>&1 || true
    ${pkgs.procps}/bin/pkill -x hyprpaper >/dev/null 2>&1 || true
    local MPV_OPTS="--no-audio --loop-file=inf --image-display-duration=inf --no-osc --no-osd-bar --keep-open=yes --keepaspect=yes --panscan=1.0"
    log "Starting mpvpaper"
    ${pkgs.mpvpaper}/bin/mpvpaper -o "$MPV_OPTS" '*' "$PATH_J" >/dev/null 2>&1 & disown
  }

  start_waypaper() {
    if command -v waypaper >/dev/null 2>&1; then
      log "Trying waypaper"
      waypaper --backend swww --wallpaper "$PATH_J" >/dev/null 2>&1 || return 1
    else
      return 1
    fi
  }

  IFS=',' read -r -a tools <<<"$ORDER"
  for t in "''${tools[@]}"; do
    case "$t" in
      swww)       start_swww && exit 0 || log "swww failed; falling back" ;;
      hyprpaper)  start_hyprpaper && exit 0 || log "hyprpaper failed; falling back" ;;
      mpvpaper)   start_mpvpaper && exit 0 || log "mpvpaper failed; falling back" ;;
      waypaper)   start_waypaper && exit 0 || log "waypaper failed; falling back" ;;
      *)          : ;;
    esac
  done

  log "All restore methods failed"
  exit 1
''
