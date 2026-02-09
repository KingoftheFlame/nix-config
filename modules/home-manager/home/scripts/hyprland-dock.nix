# ~/ddubsos/modules/home/scripts/hyprland-dock.nix
{pkgs}:
pkgs.writeShellScriptBin "dock" ''

  # Change to #!/usr/bin for non NixOS systems
  ##!/bin/bash
  # Author: Don Williams
  # Date: 2025-08-03
  # Revision: 0.1
  #
  # A script to toggle the nwg-dock-hyprland panel.
  #  For hyprland I create a bind to call this script.
  #  It's a toggle.
  #

  # Variables
  # I like nwg-drawer but you can use rofi, wofi, walker, etc
  MENU="nwg-drawer -mb 100 -mt 100 -ml 300 -mr 300"

  # Masked apps won't show in DOCK.
  # I am running pyprland scratchpads
  # They don't show up correctly so I mask it off
  MASK_APPS="kitty-dropterm"

  ICON_SIZE=32
  MARGIN_BOTTOM=10
  MARGIN_LEFT=10
  MARGIN_RIGHT=10
  ROWS=5

  # If running kill it
  if pgrep -f "nwg-dock-hyprland" > /dev/null
  then
      pkill -f "nwg-dock-hyprland"
  else
    # To disable launcher option set -nolauncher
    # nwg-dock-hyprland -i 40 -x -mb 10 -w 3 -nolauncher
    nwg-dock-hyprland -i "$ICON_SIZE" -w "$ROWS" -mb "$MARGIN_BOTTOM" -ml "$MARGIN_LEFT" -mr "$MARGIN_RIGHT" -x -g "$MASK_APPS" -c "$MENU"
  fi

''
