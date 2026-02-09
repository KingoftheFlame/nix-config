{pkgs}:
pkgs.writeShellScriptBin "launch-nwg-menu" ''
  set -euo pipefail
  exec nwg-menu \
    -isl 32 -iss 18 -k -ml 10 -mt 0 -va top \
    -s "$HOME/.config/nwg-menu/style.css" \
    -cmd-lock string "hyprlock" \
    -cmd-logout "hyprctl dispatch exit"
''
