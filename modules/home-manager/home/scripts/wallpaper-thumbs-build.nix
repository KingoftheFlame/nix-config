{pkgs}:
pkgs.writeShellScriptBin "wallpaper-thumbs-build" ''
    #!/usr/bin/env bash
    set -euo pipefail

    DIR="''${WALL_DIR:-$HOME/Pictures/Wallpapers}"
    CACHE="''${WALL_CACHE_DIR:-$HOME/.cache/wallthumbs}"
    SIZE="''${WALL_THUMB_SIZE:-256}"
    PARALLEL="''${WALL_PARALLEL:-0}"
    QUIET="0"

    usage() {
      cat <<EOF
  Usage: wallpaper-thumbs-build [options]

  Options:
    -d DIR   Wallpapers directory (default: $HOME/Pictures/Wallpapers)
    -t DIR   Thumbnail cache directory (default: $HOME/.cache/wallthumbs)
    -s N     Thumb size in px (square) (default: 256)
    -p N     Parallel jobs (0 = serial) (default: 0)
    -q       Quiet mode
    -h       Show help
  EOF
    }

    while getopts ":d:t:s:p:qh" opt; do
      case "$opt" in
        d) DIR="$OPTARG" ;;
        t) CACHE="$OPTARG" ;;
        s) SIZE="$OPTARG" ;;
        p) PARALLEL="$OPTARG" ;;
        q) QUIET="1" ;;
        h) usage; exit 0 ;;
        :) echo "Missing argument for -$OPTARG" >&2; exit 2 ;;
        \?) echo "Unknown option -$OPTARG" >&2; usage; exit 2 ;;
      esac
    done

    if [ ! -d "$DIR" ]; then
      echo "Wallpapers directory not found: $DIR" >&2
      exit 1
    fi

    mkdir -p "$CACHE"

    # Gather images deterministically; follow symlinks and ignore errors
    mapfile -t IMAGES < <( { ${pkgs.findutils}/bin/find -L "$DIR" \
        \( -type f -o -xtype f \) \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' -o -iname '*.tiff' \) \
        -print0 2>/dev/null || true; } \
      | ${pkgs.coreutils}/bin/tr '\0' '\n' | ${pkgs.coreutils}/bin/sort )

    if [ "''${#IMAGES[@]}" -eq 0 ]; then
      exit 0
    fi

    # Generate thumbnails (serial loop)
    for img in "''${IMAGES[@]}"; do
      hash=$(${pkgs.coreutils}/bin/printf "%s" "$img" | ${pkgs.openssl}/bin/openssl dgst -sha256 -r | ${pkgs.gawk}/bin/awk '{print $1}')
      out="$CACHE/$hash.png"
      if [ -f "$out" ]; then
        continue
      fi
      ${pkgs.imagemagick}/bin/convert "$img" -auto-orient -thumbnail "''${SIZE}x''${SIZE}>" \
        -background none -gravity center -extent "''${SIZE}x''${SIZE}" "$out" 2>/dev/null || true
      if [ "$QUIET" != "1" ]; then
        echo "thumb: $out"
      fi
    done
''
