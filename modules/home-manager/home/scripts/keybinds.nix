{pkgs}:
pkgs.writeShellScriptBin "list-keybinds" ''
  # check if rofi is already running
  if pidof rofi > /dev/null; then
    pkill rofi
  fi

  msg='☣️ NOTE ☣️: Clicking with Mouse or Pressing ENTER will have NO function'

  # Parse keybind entries from the Nix config and format for rofi display
  BIND_NIX="$HOME/zaneyos/modules/home/hyprland/binds.nix"
  if [[ -f "$BIND_NIX" ]]; then
    display_keybinds=$(
      ${pkgs.gawk}/bin/awk '
        # Track when we enter any keybind array
        /noctaliaBind/ { in_block = 1; next }
        /rofiBind/ { in_block = 1; next }
        /bindd[ ]*=/ && /\[/ { in_block = 1; next }

        in_block {
          # Check for end of array
          if (/^[ ]*\]/) {
            in_block = 0
            next
          }

          # Extract quoted string from line
          if (match($0, /"([^"]+)"/, arr)) {
            line = arr[1]

            # Split by comma to get: mods, key, desc, action, params
            n = split(line, parts, ",")
            if (n >= 3) {
              # Extract and trim each part
              mods = parts[1]
              key = parts[2]
              desc = parts[3]

              gsub(/^[ \t]+|[ \t]+$/, "", mods)
              gsub(/^[ \t]+|[ \t]+$/, "", key)
              gsub(/^[ \t]+|[ \t]+$/, "", desc)

              # Build display keybind
              if (mods != "" && key != "") {
                display = mods " + " key
                gsub(/\$modifier/, "SUPER", display)
                gsub(/ +/, " ", display)

                # Output: "KEYBIND: Description"
                if (desc != "") {
                  printf "%s: %s\n", display, desc
                }
              }
            }
          }
        }
      ' "$BIND_NIX"
    )
  else
    # Fallback: Show error message
    display_keybinds="Error: Keybinds file not found at $BIND_NIX"
  fi

  # use rofi to display the keybinds with the modified content
  echo "$display_keybinds" | rofi -dmenu -i -config ~/.config/rofi/config-long.rasi -mesg "$msg"

''
