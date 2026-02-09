{pkgs}:
pkgs.writeShellScriptBin "keybinds-parser" ''
    #!/usr/bin/env bash
    set -euo pipefail

    MODE="''${1:-hyprland}"
    SUBMODE="''${2:-all}"  # all, keybinds, colors, summary, etc.

    case "$MODE" in
      hyprland)
        # First, try to parse zaneyos bindd entries from Nix config for richer descriptions
        BIND_NIX="$HOME/zaneyos/modules/home/hyprland/binds.nix"
        if [[ -f "$BIND_NIX" ]] && ${pkgs.gnugrep}/bin/grep -q "bindd[ ]*=" "$BIND_NIX"; then
        ${pkgs.gawk}/bin/awk '
  BEGIN {
              print "["; first=1; in_block=0; btype="";
            }
            {
              line=$0
              # Strip trailing comments that are outside of quotes
              gsub(/#[^"]*$/, "", line)
            }
          /bindd[ ]*=/ { in_block=1; btype="bindd"; next }
            /bindmd[ ]*=/ { in_block=1; btype="bindmd"; next }
            in_block {
              if (line ~ /\]/) { in_block=0; next }
              # Find first quoted string on the line
              if (match(line, /"(.*)"/, m)) {
                s=m[1]
                # Split by comma into up to 5 pieces: mods, key, desc, action, params (rest)
                n=split(s, parts, ",")
                # Trim helper
                for (i=1; i<=n; i++) {
                  gsub(/^ +| +$/, "", parts[i])
                }
                mods = (n>=1?parts[1]:"")
                key  = (n>=2?parts[2]:"")
                desc = (n>=3?parts[3]:"")
                act  = (n>=4?parts[4]:"")
                params=""
                if (n>=5) {
                  params = parts[5]
                  for (i=6; i<=n; i++) params = params "," parts[i]
                  gsub(/^ +| +$/, "", params)
                }
                # Normalize display keybind
                display = key
                if (mods != "") display = mods " + " key
                gsub(/\$modifier/, "SUPER", display)

                # Category classification (reuse hyprland categories)
                category = "hyprland"
                low=tolower(act " " params " " desc)
                if (act == "exec" && low ~ /(kitty|ghostty|wezterm|alacritty|foot)/) category="terminal"
                else if (act == "exec" && low ~ /(emacs|code|vscode|editor)/) category="editor"
                else if (act == "exec" && low ~ /(rofi|wofi|dmenu|menu|launcher)/) category="launcher"
                else if (act == "exec" && low ~ /(screenshot|screenshoot|hyprshot)/) category="screenshot"
                else if (act == "exec" && low ~ /wallpaper/) category="wallpaper"
                else if (act == "exec" && low ~ /(volume|brightness|audio|xf86audio|xf86monbrightness|playerctl|wpctl|brightnessctl)/) category="media"
                else if (act == "exec" && low ~ /(browser|chrome|firefox|brave)/) category="browser"
                else if (act ~ /^(workspace|movetoworkspace)$/) category = "workspace"
  else if (act ~ /^(movewindow|swapwindow|movefocus|killactive|togglefloating|fullscreen|pseudo|resizewindow)$/) category = "window"
  else if (act ~ /^(togglesplit|cyclenext|bringactivetotop|exit|workspaceopt)$/) category = "hyprland"
                else if (act == "exec") category = "app"
                # Override category for mouse bindings
                if (key ~ /^mouse:/) category = "mouse"

                # JSON escape fields
                gsub(/\\/, "\\\\", display); gsub(/"/, "\\\"", display)
                gsub(/\\/, "\\\\", desc);    gsub(/"/, "\\\"", desc)
                gsub(/\\/, "\\\\", category); gsub(/"/, "\\\"", category)

                if (!first) printf ",\n"; first=0
                printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", display, desc, category
              }
            }
            END { print "\n]" }
          ' "$BIND_NIX"
        else
          # Parse actual Hyprland config file
          HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"
          if [[ ! -f "$HYPR_CONFIG" ]]; then
            echo "Error: Hyprland config not found at $HYPR_CONFIG" >&2
            exit 1
          fi

          # Extract bind statements and convert to JSON
          ${pkgs.gawk}/bin/awk -F= '
          BEGIN {
            print "["
            first = 1
          }

          /^bind[em]*=/ {
            if (!first) print ","
            first = 0

            # Parse bind line: bind=MODIFIERS,KEY,ACTION,PARAMS
            gsub(/^bind[em]*=/, "")
            split($0, parts, ",")

            if (length(parts) >= 3) {
              modifiers = parts[1]
              key = parts[2]
              action = parts[3]
              params = ""

              # Join remaining parts as parameters
              for (i = 4; i <= length(parts); i++) {
                if (i > 4) params = params ","
                params = params parts[i]
              }

              # Clean up modifiers and key
              gsub(/\$modifier/, "SUPER", modifiers)
              gsub(/^ +| +$/, "", modifiers)
              gsub(/^ +| +$/, "", key)
              gsub(/^ +| +$/, "", action)
              gsub(/^ +| +$/, "", params)

              # Build keybind string
              keybind = modifiers
              if (keybind != "" && key != "") keybind = keybind " + " key
              else if (key != "") keybind = key

              # Build description - improve formatting
              description = action
              if (params != "") description = description " " params

              # Clean up common formatting issues
              gsub(/exec, *exec/, "exec", description)  # Fix duplicate exec
              gsub(/exec, *exec,/, "exec", description)  # Fix "exec, exec," patterns
              gsub(/, *exec,/, ", exec", description)  # Fix ", exec," patterns
              gsub(/, *$/, "", description)  # Remove trailing commas
              gsub(/  +/, " ", description)  # Collapse multiple spaces

              # Format different action types nicely with proper spacing
              if (match(action, /^exec$/) || match(description, /^exec/)) {
                gsub(/^ *exec *,? */, "Run: ", description)
                gsub(/^Run: *exec */, "Run: ", description)  # Clean up "Run: exec"
              } else if (match(action, /^(killactive|togglefloating|fullscreen|pseudo|togglesplit|exit|cyclenext|bringactivetotop)$/)) {
                description = "Action: " action
                if (params != "") description = description " " params
              } else if (match(action, /^(workspace|movetoworkspace)$/)) {
                description = "Workspace: " params
              } else if (match(action, /^(movewindow|swapwindow|movefocus|resizewindow)$/)) {
                description = "Window: " action " " params
              } else if (match(action, /^workspaceopt$/)) {
                description = "Workspace option: " params
              }

              # Final cleanup pass - ensure proper spacing
              gsub(/^Run: *, */, "Run: ", description)  # Fix "Run: , app"
              gsub(/^Run:([^ ])/, "Run: \1", description)  # Ensure space after "Run:"
              gsub(/^Action:([^ ])/, "Action: \1", description)  # Ensure space after "Action:"
              gsub(/^Workspace:([^ ])/, "Workspace: \1", description)  # Ensure space after "Workspace:"
              gsub(/^Window:([^ ])/, "Window: \1", description)  # Ensure space after "Window:"
              gsub(/, *$/, "", description)  # Remove trailing commas again
              gsub(/  +/, " ", description)  # Final space cleanup

              # Categorize based on action/description (improved logic)
              if (match(action, /^exec$/) && match(description, /(terminal|foot|wezterm|ghostty|kitty)/)) category = "terminal"
              else if (match(action, /^exec$/) && match(description, /(emacs|vscode|editor)/)) category = "editor"
              else if (match(action, /^exec$/) && match(description, /(rofi|wofi|dmenu|menu|launcher)/)) category = "launcher"
              else if (match(action, /^exec$/) && match(description, /(screenshot|screenshoot)/)) category = "screenshot"
              else if (match(action, /^exec$/) && match(description, /wallpaper/)) category = "wallpaper"
              else if (match(action, /^exec$/) && match(description, /(volume|brightness|audio|XF86Audio|XF86MonBrightness)/)) category = "media"
              else if (match(action, /^exec$/) && match(description, /(browser|chrome|firefox)/)) category = "browser"
              else if (match(action, /^(workspace|movetoworkspace)$/)) category = "workspace"
              else if (match(action, /^(movewindow|swapwindow|movefocus|killactive|togglefloating|fullscreen|pseudo|resizewindow)$/)) category = "window"
              else if (match(action, /^(togglesplit|cyclenext|bringactivetotop|exit|workspaceopt)$/)) category = "hyprland"
              else if (match(action, /^exec$/)) category = "app"
              else category = "hyprland"
              # Override category for mouse bindings
              if (key ~ /^mouse:/) category = "mouse"

              # Escape quotes and backslashes for JSON
              gsub(/\\/, "\\\\", keybind)
              gsub(/"/, "\\\"", keybind)
              gsub(/\\/, "\\\\", description)
              gsub(/"/, "\\\"", description)
              gsub(/\\/, "\\\\", category)
              gsub(/"/, "\\\"", category)

              printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", keybind, description, category
            }
          }

          END { print "\n]" }
        ' "$HYPR_CONFIG"
        fi
        ;;
      niri)
        # Parse Niri KDL config binds block
        NIRI_CONFIG="$HOME/.config/niri/config.kdl"
        if [[ ! -f "$NIRI_CONFIG" ]]; then
          echo "Error: Niri config not found at $NIRI_CONFIG" >&2
          exit 1
        fi
        ${pkgs.gawk}/bin/awk '
          BEGIN { print "["; first=1; in_binds=0; brace_depth=0 }
          {
            # Strip line comments starting with //
            gsub(/\/\/.*$/, "", $0)
          }

          /^[ ]*binds[ ]*\{/ { in_binds=1; brace_depth=1; next }
          in_binds {
            # Track braces to detect end of binds block
            n_open = gsub(/\{/, "&")
            n_close = gsub(/\}/, "&")
            brace_depth += n_open
            brace_depth -= n_close
            if (brace_depth <= 0) { in_binds=0; next }

            line=$0
            # Skip empty/whitespace-only lines
            if (line ~ /^[ ]*$/) next

            # Extract keybind (first token before whitespace)
            keybind=""; action=""; args=""
            # Remove leading spaces
            sub(/^[ ]+/, "", line)
            # Must contain a { to be a binding
            if (index(line, "{") == 0) next

            kb_part=line
            sub(/[ ]*\{.*$/, "", kb_part)
            # First token is the keybind, ignore any options like cooldown-ms=...
            split(kb_part, toks, /[ ]+/)
            if (length(toks) >= 1) keybind=toks[1]

            # Extract the first command inside braces up to the first ;
            cmd_block=line
            sub(/^.*\{[ ]*/, "", cmd_block)
            sub(/[ ]*\}.*$/, "", cmd_block)
            # Get first statement up to semicolon
            split(cmd_block, stmts, /;/)
            cmd=stmts[1]
            gsub(/^[ ]+|[ ]+$/, "", cmd)

            if (cmd == "") next

            # Parse action and args
            if (match(cmd, /^spawn[ ]+/, m)) {
              action="spawn"
              args=cmd
              sub(/^spawn[ ]+/, "", args)
              # Remove surrounding quotes around program if present
              gsub(/^"|"$/, "", args)
              desc="Run: " args
            } else {
              # Action form like focus-window-down or set-column-width "+10%"
              split(cmd, a, /[ ]+/)
              action=a[1]
              args=""
              if (length(a) > 1) {
                for (i=2; i<=length(a); i++) { if (i>2) args=args " "; args=args a[i] }
              }
              # Clean quotes around args
              gsub(/^"|"$/, "", args)
              desc="Action: " action
              if (args != "") desc=desc " " args
            }

            # Build category
            category="misc"
            if (action == "spawn") {
              low=tolower(args)
              if (low ~ /(kitty|ghostty|wezterm|alacritty|foot)/) category="terminal"
              else if (low ~ /(emacs|code|vscode|nvim|vim)/) category="editor"
              else if (low ~ /(rofi|wofi|dmenu|launcher)/) category="launcher"
              else if (low ~ /(chrome|chromium|firefox|brave|browser)/) category="browser"
              else if (low ~ /(swww|wallpaper)/) category="wallpaper"
              else if (low ~ /(playerctl|wpctl|pactl|pamixer|brightnessctl|volume|brightness)/) category="media"
              else category="app"
            } else {
              if (action ~ /workspace/) category="workspace"
              else if (action ~ /(window|column|pane|tab|floating|fullscreen|center|width|height)/) category="window"
              else if (action ~ /screenshot/) category="screenshot"
              else if (action ~ /(quit|overlay|inhibit)/) category="hyprland"
            }

            # Normalize keybind display
            gsub(/\+/, " + ", keybind)

            # JSON escape
            gsub(/\\/, "\\\\", keybind); gsub(/"/, "\\\"", keybind)
            gsub(/\\/, "\\\\", desc); gsub(/"/, "\\\"", desc)
            gsub(/\\/, "\\\\", category); gsub(/"/, "\\\"", category)

            if (!first) print ","; first=0
            printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", keybind, desc, category
          }
          END { print "\n]" }
        ' "$NIRI_CONFIG"
        ;;
      emacs)
        # Default Doom Emacs leader keybinds
        ${pkgs.jq}/bin/jq -n '[
          {"keybind": "SPC f f", "description": "Find file", "category": "files"},
          {"keybind": "SPC f r", "description": "Recent files", "category": "files"},
          {"keybind": "SPC f s", "description": "Save file", "category": "files"},
          {"keybind": "SPC f S", "description": "Save all files", "category": "files"},
          {"keybind": "SPC f d", "description": "Find directory", "category": "files"},
          {"keybind": "SPC b b", "description": "Switch buffer", "category": "buffers"},
          {"keybind": "SPC b k", "description": "Kill buffer", "category": "buffers"},
          {"keybind": "SPC b r", "description": "Revert buffer", "category": "buffers"},
          {"keybind": "SPC b s", "description": "Save buffer", "category": "buffers"},
          {"keybind": "SPC w v", "description": "Split vertically", "category": "windows"},
          {"keybind": "SPC w s", "description": "Split horizontally", "category": "windows"},
          {"keybind": "SPC w h", "description": "Move to left window", "category": "windows"},
          {"keybind": "SPC w j", "description": "Move to down window", "category": "windows"},
          {"keybind": "SPC w k", "description": "Move to up window", "category": "windows"},
          {"keybind": "SPC w l", "description": "Move to right window", "category": "windows"},
          {"keybind": "SPC w d", "description": "Delete window", "category": "windows"},
          {"keybind": "SPC w o", "description": "Delete other windows", "category": "windows"},
          {"keybind": "SPC s s", "description": "Search current buffer", "category": "search"},
          {"keybind": "SPC s p", "description": "Search project", "category": "search"},
          {"keybind": "SPC s d", "description": "Search directory", "category": "search"},
          {"keybind": "SPC s i", "description": "Search with imenu", "category": "search"},
          {"keybind": "SPC p p", "description": "Switch project", "category": "project"},
          {"keybind": "SPC p f", "description": "Find file in project", "category": "project"},
          {"keybind": "SPC p s", "description": "Search in project", "category": "project"},
          {"keybind": "SPC p r", "description": "Recent project files", "category": "project"},
          {"keybind": "SPC g s", "description": "Git status (Magit)", "category": "git"},
          {"keybind": "SPC g b", "description": "Git blame", "category": "git"},
          {"keybind": "SPC g l", "description": "Git log", "category": "git"},
          {"keybind": "SPC g d", "description": "Git diff", "category": "git"},
          {"keybind": "SPC h k", "description": "Describe key", "category": "help"},
          {"keybind": "SPC h f", "description": "Describe function", "category": "help"},
          {"keybind": "SPC h v", "description": "Describe variable", "category": "help"},
          {"keybind": "SPC h m", "description": "Describe mode", "category": "help"},
          {"keybind": "SPC c c", "description": "Compile", "category": "code"},
          {"keybind": "SPC c d", "description": "Jump to definition", "category": "code"},
          {"keybind": "SPC c r", "description": "Find references", "category": "code"},
          {"keybind": "SPC c f", "description": "Format buffer", "category": "code"},
          {"keybind": "SPC t t", "description": "Toggle theme", "category": "toggle"},
          {"keybind": "SPC t l", "description": "Toggle line numbers", "category": "toggle"},
          {"keybind": "SPC t w", "description": "Toggle word wrap", "category": "toggle"},
          {"keybind": "SPC q q", "description": "Quit Emacs", "category": "quit"},
          {"keybind": "SPC q r", "description": "Restart Emacs", "category": "quit"}
        ]'
        ;;
      kitty)
        # Parse Kitty configuration
        KITTY_CONFIG="$HOME/.config/kitty/kitty.conf"
        if [[ ! -f "$KITTY_CONFIG" ]]; then
          echo "Error: Kitty config not found at $KITTY_CONFIG" >&2
          exit 1
        fi

        case "$SUBMODE" in
          summary)
            # Parse general settings (non-map, non-color lines)
            ${pkgs.gawk}/bin/awk '
              BEGIN {
                print "["
                first = 1
              }

              !/^[ ]*#/ && !/^[ ]*map/ && !/^color[0-9]/ && !/^(fore|back|selection|cursor|url|active_|inactive_|tab_bar|mark[0-9])/ && NF > 0 {
                if (!first) print ","
                first = 0

                key = $1
                value = ""
                for (i = 2; i <= NF; i++) {
                  if (i > 2) value = value " "
                  value = value $i
                }

                # Determine category based on setting name
                if (match(key, /font/)) category = "font"
                else if (match(key, /tab/)) category = "tabs"
                else if (match(key, /window/)) category = "window"
                else if (match(key, /scroll/)) category = "scrolling"
                else if (match(key, /cursor|mouse/)) category = "input"
                else if (match(key, /bell|audio/)) category = "audio"
                else if (match(key, /url|detect/)) category = "urls"
                else category = "general"

                # Escape for JSON
                gsub(/"/, "\\\"&", key)
                gsub(/"/, "\\\"&", value)
                gsub(/\\/, "\\\\\\&", key)
                gsub(/\\/, "\\\\\\&", value)

                printf "{\"setting\":\"%s\",\"value\":\"%s\",\"category\":\"%s\"}", key, value, category
              }

              END { print "\n]" }
            ' "$KITTY_CONFIG"
            ;;
          colors)
            # Parse color settings - match lines with hex colors (including whitespace)
            ${pkgs.gawk}/bin/awk '
              BEGIN {
                print "["
                first = 1
              }

              /^[ ]*[a-zA-Z_][a-zA-Z0-9_]*[ ]+#[0-9a-fA-F]{6}/ {
                if (!first) print ","
                first = 0

                # Extract setting name and hex color value
                gsub(/^[ ]+/, "")
                key = $1
                value = $2

                # Color categorization based on setting name
                if (match(key, /^color[0-9]/)) {
                  if (match(key, /color[08]/)) category = "black"
                  else if (match(key, /color[19]/)) category = "red"
                  else if (match(key, /color[12][05]/)) category = "green"
                  else if (match(key, /color[13][14]/)) category = "yellow"
                  else if (match(key, /color[14][29]/)) category = "blue"
                  else if (match(key, /color[15][37]/)) category = "magenta"
                  else if (match(key, /color[16][46]/)) category = "cyan"
                  else if (match(key, /color[17][58]/)) category = "white"
                  else category = "terminal-colors"
                }
                else if (match(key, /(active_tab|inactive_tab|tab_bar)/)) category = "tabs"
                else if (match(key, /cursor/)) category = "cursor"
                else if (match(key, /selection/)) category = "selection"
                else if (match(key, /(active_border|inactive_border|bell_border)/)) category = "borders"
                else if (match(key, /mark[0-9]/)) category = "marks"
                else if (match(key, /(foreground|background)/)) category = "basic"
                else if (match(key, /url/)) category = "urls"
                else category = "other"

                # Escape for JSON
                gsub(/"/, "\\\"&", key)
                gsub(/"/, "\\\"&", value)

                printf "{\"setting\":\"%s\",\"value\":\"%s\",\"category\":\"%s\"}", key, value, category
              }

              END { print "\n]" }
            ' "$KITTY_CONFIG"
            ;;
          *)
            # Default: keybinds (or "all" for backward compatibility)
            ${pkgs.gawk}/bin/awk '
              BEGIN {
                print "["
                first = 1
              }

              /^[ ]*map/ {
                if (!first) print ","
                first = 0

                # Parse map line
                gsub(/^[ ]*map[ ]+/, "")
                n = split($0, parts, /[ ]+/)

                if (n >= 2) {
                  keybind = parts[1]
                  action = parts[2]
                  args = ""

                  for (i = 3; i <= n; i++) {
                    if (i > 3) args = args " "
                    args = args parts[i]
                  }

                  # Format keybind
                  gsub(/\+/, " + ", keybind)
                  gsub(/ctrl/, "Ctrl", keybind)
                  gsub(/shift/, "Shift", keybind)
                  gsub(/alt/, "Alt", keybind)
                  gsub(/cmd/, "Cmd", keybind)

                  # Build description
                  description = "Action: " action
                  if (args != "") description = description " " args

                  # Categorize
                  if (match(action, /scroll/)) category = "scrolling"
                  else if (match(action, /window|tab|layout/)) category = "window-tabs"
                  else if (match(action, /font|zoom/)) category = "display"
                  else if (match(action, /paste|copy/)) category = "clipboard"
                  else if (match(action, /new_|close_|next_|previous_/)) category = "navigation"
                  else category = "misc"

                  # Escape for JSON
                  gsub(/\\/, "\\\\\\&", keybind)
                  gsub(/"/, "\\\"&", keybind)
                  gsub(/\\/, "\\\\\\&", description)
                  gsub(/"/, "\\\"&", description)

                  printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", keybind, description, category
                }
              }

              END { print "\n]" }
            ' "$KITTY_CONFIG"
            ;;
        esac
        ;;
      wezterm)
        # Parse WezTerm configuration (Lua)
        WEZTERM_CONFIG="$HOME/.config/wezterm/wezterm.lua"
        if [[ ! -f "$WEZTERM_CONFIG" ]]; then
          echo "Error: WezTerm config not found at $WEZTERM_CONFIG" >&2
          exit 1
        fi

        case "$SUBMODE" in
          summary)
            # Extract common top-level settings from Lua config
            ${pkgs.gawk}/bin/awk '
              BEGIN { print "["; first=1 }

              /^[ ]*config\./ {
                key=$0
                gsub(/^[ ]*config\./, "", key)
                # Remove trailing commas and spaces
                gsub(/[ ,]+$/, "", key)

                # Split key and value on =
                split(key, kv, /=/)
                if (length(kv) >= 2) {
                  k=kv[1]; v=kv[2]
                  gsub(/^[ ]+|[ ]+$/, "", k)
                  gsub(/^[ ]+|[ ]+$/, "", v)

                  # Clean quotes
                  gsub(/^"|"$/, "", v)

                  # Determine category
                  if (k ~ /font|font_size/) cat="font"
                  else if (k ~ /color_scheme|colors/) cat="colors"
                  else if (k ~ /window|opacity|padding|use_fancy_tab_bar|hide_tab_bar/) cat="window"
                  else if (k ~ /cursor/) cat="cursor"
                  else if (k ~ /term|max_fps|animation_fps|bold_brightens_ansi_colors/) cat="general"
                  else cat="general"

                  # JSON escape
                  gsub(/\\/, "\\\\", k); gsub(/"/, "\\\"", k)
                  gsub(/\\/, "\\\\", v); gsub(/"/, "\\\"", v)

                  if (!first) print ","; first=0
                  printf "{\"setting\":\"%s\",\"value\":\"%s\",\"category\":\"%s\"}", k, v, cat
                }
              }
              END { print "\n]" }
            ' "$WEZTERM_CONFIG"
            ;;
          colors)
            # Extract color hex codes from config.colors table and tab_bar
            ${pkgs.gawk}/bin/awk '
              BEGIN { print "["; first=1; in_colors=0; in_tab=0 }

              /config\.colors[ ]*=[ ]*\{/ { in_colors=1; next }
              in_colors && /\}/ { in_colors=0 }

              in_colors {
                line=$0
                # Match entries like key = "#hex"
                if (match(line, /([a-zA-Z_]+)[ ]*=[ ]*"#([0-9a-fA-F]{6})"/, m)) {
                  k=m[1]; v="#" m[2]; cat="colors"
                  if (!first) print ","; first=0
                  printf "{\"setting\":\"%s\",\"value\":\"%s\",\"category\":\"%s\"}", k, v, cat
                }
                # Handle nested tab_bar tables
                if (line ~ /tab_bar[ ]*=[ ]*\{/) { in_tab=1 }
                if (in_tab && match(line, /([a-zA-Z_]+)[ ]*=[ ]*"#([0-9a-fA-F]{6})"/, t)) {
                  k=t[1]; v="#" t[2]; cat="tab_bar"
                  if (!first) print ","; first=0
                  printf "{\"setting\":\"%s\",\"value\":\"%s\",\"category\":\"%s\"}", k, v, cat
                }
                if (in_tab && /\}/) { in_tab=0 }
              }
              END { print "\n]" }
            ' "$WEZTERM_CONFIG"
            ;;
          *)
            # keybinds submode: parse config.keys entries
            ${pkgs.gawk}/bin/awk '
              BEGIN { print "["; first=1; in_keys=0 }

              /config\.keys[ ]*=[ ]*\{/ { in_keys=1; next }
              in_keys && /^[ ]*\}/ { in_keys=0; next }

              in_keys && /^[ ]*\{/ {
                # Expect lines like: { key = "t", mods = "ALT", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
                line=$0
                # Extract key
                key=""; mods=""; action=""; args=""
                if (match(line, /key[ ]*=[ ]*"([^"]+)"/, m1)) key=m1[1]
                if (match(line, /mods[ ]*=[ ]*"([^"]+)"/, m2)) mods=m2[1]
                if (match(line, /action[ ]*=[ ]*wezterm\.action\.([A-Za-z_]+)\(([^)]*)\)/, m3)) { action=m3[1]; args=m3[2] }
                else if (match(line, /action[ ]*=[ ]*"([^"]+)"/, m4)) { action=m4[1] }

                if (key != "" && action != "") {
                  # Build keybind string
                  kb=""; if (mods != "") kb=mods; if (key != "") { if (kb != "") kb=kb " + " key; else kb=key }
                  gsub(/ALT/, "Alt", kb)
                  gsub(/CTRL/, "Ctrl", kb)
                  gsub(/SHIFT/, "Shift", kb)

                  # Description
                  desc="Action: " action
                  gsub(/"/, "", args); gsub(/,.*/, "", args)  # Clean up args
                  if (args != "") desc=desc " (" args ")"

                  # Category
                  cat="misc"
                  if (action ~ /SpawnTab|CloseCurrentTab|ActivateTabRelative/) cat="tabs"
                  else if (action ~ /SplitVertical|SplitHorizontal|CloseCurrentPane|ActivatePaneDirection/) cat="panes"
                  else if (action ~ /CopyTo|PasteFrom|Copy|Paste/) cat="clipboard"
                  else if (action ~ /DecreaseFontSize|IncreaseFontSize|ResetFontSize/) cat="display"
                  else if (action ~ /Search|Show|QuickSelect/) cat="navigation"

                  # JSON escape
                  gsub(/\\/, "\\\\", kb); gsub(/"/, "\\\"", kb)
                  gsub(/\\/, "\\\\", desc); gsub(/"/, "\\\"", desc)

                  if (!first) print ","; first=0
                  printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", kb, desc, cat
                }
              }
              END { print "\n]" }
            ' "$WEZTERM_CONFIG"
            ;;
        esac
        ;;
      ghostty)
        # Parse Ghostty configuration (TOML)
        GHOSTTY_CONFIG="$HOME/.config/ghostty/config"
        if [[ ! -f "$GHOSTTY_CONFIG" ]]; then
          echo "Error: Ghostty config not found at $GHOSTTY_CONFIG" >&2
          exit 1
        fi

        case "$SUBMODE" in
          summary)
            # Extract basic settings from config
            ${pkgs.gawk}/bin/awk '
              BEGIN { print "["; first=1 }
              /^[a-zA-Z_]+[ ]*=/ {
                line=$0
                if (match(line, /^([a-zA-Z_]+)[ ]*=[ ]*(.*)/, m)) {
                  k=m[1]; v=m[2]
                  gsub(/^[ ]+|[ ]+$/, "", k)
                  gsub(/^[ ]+|[ ]+$/, "", v)
                  # Clean quotes
                  gsub(/^"|"$/, "", v)

                  # Categorize
                  cat="general"
                  if (k ~ /font|font_size/) cat="font"
                  else if (k ~ /color|palette/) cat="colors"
                  else if (k ~ /window|padding/) cat="window"
                  else if (k ~ /cursor/) cat="cursor"

                  gsub(/\\/, "\\\\", k); gsub(/"/, "\\\"", k)
                  gsub(/\\/, "\\\\", v); gsub(/"/, "\\\"", v)

                  if (!first) print ","; first=0
                  printf "{\"setting\":\"%s\",\"value\":\"%s\",\"category\":\"%s\"}", k, v, cat
                }
              }
              END { print "\n]" }
            ' "$GHOSTTY_CONFIG"
            ;;
          colors)
            # Extract color hex codes
            ${pkgs.gawk}/bin/awk '
              BEGIN { print "["; first=1 }
              /palette|background|foreground/ {
                line=$0
                if (match(line, /^([a-zA-Z_]+)[ ]*=[ ]*#([0-9a-fA-F]{6})/, m)) {
                  k=m[1]; v="#" m[2]
                  if (!first) print ","; first=0
                  printf "{\"setting\":\"%s\",\"value\":\"%s\",\"category\":\"colors\"}", k, v
                }
              }
              END { print "\n]" }
            ' "$GHOSTTY_CONFIG"
            ;;
          *)
            # keybinds submode: parse keybind entries
            ${pkgs.gawk}/bin/awk '
              BEGIN { print "["; first=1 }
              /^keybind/ {
                line=$0
                # Parse: keybind = key:action
                if (match(line, /keybind[ ]*=[ ]*([^:]+):(.*)/, m)) {
                  key=m[1]; action=m[2]
                  gsub(/^[ ]+|[ ]+$/, "", key)
                  gsub(/^[ ]+|[ ]+$/, "", action)

                  # Normalize key notation
                  gsub(/cmd/, "Cmd", key)
                  gsub(/ctrl/, "Ctrl", key)
                  gsub(/shift/, "Shift", key)
                  gsub(/alt/, "Alt", key)
                  gsub(/\+/, " + ", key)

                  # Categorize
                  cat="misc"
                  if (action ~ /copy|paste/) cat="clipboard"
                  else if (action ~ /new|close|tab/) cat="tabs"
                  else if (action ~ /split|pane|focus/) cat="panes"
                  else if (action ~ /font|zoom/) cat="display"

                  gsub(/\\/, "\\\\", key); gsub(/"/, "\\\"", key)
                  gsub(/\\/, "\\\\", action); gsub(/"/, "\\\"", action)

                  if (!first) print ","; first=0
                  printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", key, action, cat
                }
              }
              END { print "\n]" }
            ' "$GHOSTTY_CONFIG"
            ;;
        esac
        ;;
      yazi)
        # Parse Yazi configuration (TOML)
        YAZI_KEYMAP="$HOME/.config/yazi/keymap.toml"
        YAZI_THEME="$HOME/.config/yazi/theme.toml"
        if [[ ! -f "$YAZI_KEYMAP" ]]; then
          echo "Error: Yazi keymap not found at $YAZI_KEYMAP" >&2
          exit 1
        fi
        if [[ ! -f "$YAZI_THEME" ]]; then
          echo "Error: Yazi theme not found at $YAZI_THEME" >&2
          exit 1
        fi

        case "$SUBMODE" in
          summary)
            # Extract basic settings and stats from both files
            ${pkgs.gawk}/bin/awk '
              BEGIN { print "["; first=1 }
              END {
                if (!first) print ","
                printf "{\"setting\":\"keymap_sections\",\"value\":\"%d sections\",\"category\":\"keymaps\"}", sections
                if (colors > 0) {
                  print ","
                  printf "{\"setting\":\"theme_colors\",\"value\":\"%d colors\",\"category\":\"theme\"}", colors
                }
                if (bindings > 0) {
                  print ","
                  printf "{\"setting\":\"total_keybindings\",\"value\":\"%d bindings\",\"category\":\"keymaps\"}", bindings
                }
                print "\n]"
              }
              # Count keymap sections and bindings
              /^\[\[[a-zA-Z_]+\.keymap\]\]/ { sections++; bindings++ }
              # Count theme colors
              /fg = "#[0-9a-fA-F]{6}"/ { colors++ }
              /bg = "#[0-9a-fA-F]{6}"/ { colors++ }
            ' "$YAZI_KEYMAP" "$YAZI_THEME"
            ;;
          colors)
            # Extract color hex codes from theme.toml
            ${pkgs.gawk}/bin/awk '
              BEGIN { print "["; first=1; in_section="" }

              # Track current TOML section
              /^\[([^\[]*)\]/ {
                gsub(/\[|\]/, "", $0)
                in_section=$0
                next
              }

              # Match color definitions with hex values
              /^[a-zA-Z_]+ = .*#[0-9a-fA-F]{6}/ {
                line=$0
                # Extract setting name and hex color
                if (match(line, /^([a-zA-Z_]+) = .*"(#[0-9a-fA-F]{6})"/, m)) {
                  setting=m[1]
                  color=m[2]

                  # Determine category based on TOML section
                  cat="theme"
                  if (in_section == "mgr") cat="manager"
                  else if (in_section == "mode") cat="mode"
                  else if (in_section == "status") cat="status"
                  else if (in_section == "filetype") cat="filetype"
                  else if (match(in_section, /^(input|pick|confirm|cmp|tasks|which|help|notify)$/)) cat=in_section

                  if (!first) print ","; first=0
                  printf "{\"setting\":\"%s\",\"value\":\"%s\",\"category\":\"%s\"}", setting, color, cat
                }
              }
              END { print "\n]" }
            ' "$YAZI_THEME"
            ;;
          *)
            # keybinds submode: parse keymap.toml entries
            ${pkgs.gawk}/bin/awk '
              BEGIN { print "["; first=1; current_section="" }

              # Match keymap sections like [[cmp.keymap]]
              /^\[\[([a-zA-Z_]+)\.keymap\]\]/ {
                gsub(/\[\[|\]\]/, "", $0)
                gsub(/\.keymap/, "", $0)
                current_section=$0
                next
              }

              # Extract keymap entries within sections
              current_section != "" {
                if (/^desc = /) {
                  gsub(/^desc = "|"+$/, "", $0)
                  desc=$0
                }
                else if (/^on = /) {
                  gsub(/^on = "|"+$/, "", $0)
                  keybind=$0
                  # Convert key notation
                  gsub(/<C-/, "Ctrl+", keybind)
                  gsub(/<A-/, "Alt+", keybind)
                  gsub(/<S-/, "Shift+", keybind)
                  gsub(/</, "", keybind)
                  gsub(/>/, "", keybind)
                }
                else if (/^run = / && keybind != "" && desc != "") {
                  gsub(/^run = "|"+$/, "", $0)
                  action=$0

                  # Build description
                  description=desc
                  if (action != "" && action != desc) description=desc " (" action ")"

                  # Determine category based on section
                  cat="misc"
                  if (current_section == "manager") cat="file-management"
                  else if (current_section == "cmp") cat="completion"
                  else if (current_section == "confirm") cat="dialogs"
                  else if (current_section == "help") cat="help"
                  else if (current_section == "input") cat="input"
                  else cat=current_section

                  # JSON escape
                  gsub(/\\/, "\\\\", keybind); gsub(/"/, "\\\"", keybind)
                  gsub(/\\/, "\\\\", description); gsub(/"/, "\\\"", description)

                  if (!first) print ","; first=0
                  printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", keybind, description, cat

                  # Reset for next entry
                  keybind=""; desc=""; action=""
                }
              }
              END { print "\n]" }
            ' "$YAZI_KEYMAP"
            ;;
        esac
        ;;
      sway)
        # Parse Sway config (bindsym/bindcode) from ~/.config/sway/config with fallback to repo config
        SWAY_CONFIG="$HOME/.config/sway/config"
        if [[ ! -f "$SWAY_CONFIG" ]]; then
          SWAY_CONFIG="$HOME/zaneyos/modules/home/gui/sway/files/config_cuerdos"
          if [[ ! -f "$SWAY_CONFIG" ]]; then
            echo "Error: Sway config not found at ~/.config/sway/config or repo fallback" >&2
            exit 1
          fi
        fi

        # Collect included files (single level) so we parse actual bindings even when config uses includes
        FILES=("$SWAY_CONFIG")
        # Extract include lines and expand ~ and globs
        while IFS= read -r inc; do
          # Strip leading 'include'
          path="''${inc#*include }"
          # Strip surrounding quotes if present
          case "''${path}" in
            \"*\") path="''${path#\"}"; path="''${path%\"}" ;;
            \'*\') path="''${path#\'}"; path="''${path%\'}" ;;
          esac
          # Expand ~ to $HOME (robustly replace leading '~/')
          path="''${path/#~\//$HOME/}"
          # Expand globs into array items
          for f in $path; do
            if [[ -f "$f" ]]; then FILES+=("$f"); fi
          done
        done < <(${pkgs.gnugrep}/bin/grep -E '^[[:space:]]*include[[:space:]]+' "$SWAY_CONFIG" | ${pkgs.gnused}/bin/sed 's/[[:space:]]\\+/ /g')

        ${pkgs.gawk}/bin/awk '
          BEGIN {
            print "["; first=1;
            var_left=""; var_down=""; var_up=""; var_right="";
          }
          /^[ ]*#/ { next }
          # Capture a few common variables for substitution (left/down/up/right/mod already handled separately)
          /^[ ]*set[ ]+\$left[ ]+/ { v=$0; sub(/^[ ]*set[ ]+\$left[ ]+/, "", v); gsub(/[\t ]+$/, "", v); var_left=v; next }
          /^[ ]*set[ ]+\$down[ ]+/ { v=$0; sub(/^[ ]*set[ ]+\$down[ ]+/, "", v); gsub(/[\t ]+$/, "", v); var_down=v; next }
          /^[ ]*set[ ]+\$up[ ]+/   { v=$0; sub(/^[ ]*set[ ]+\$up[ ]+/,   "", v); gsub(/[\t ]+$/, "", v); var_up=v;   next }
          /^[ ]*set[ ]+\$right[ ]+/{ v=$0; sub(/^[ ]*set[ ]+\$right[ ]+/,"", v); gsub(/[\t ]+$/, "", v); var_right=v; next }
          {
            line=$0
            # Collapse multiple spaces/tabs
            gsub(/[\t ]+/, " ", line)
            # Match bindsym or bindcode lines
            if (line ~ /^[ ]*bind(sym|code)[ ]+/) {
              # Remove the leading keyword
              sub(/^[ ]*bind(sym|code)[ ]+/, "", line)

              # Tokenize and skip option flags (tokens starting with '-')
              n=split(line, a, /[ ]+/)
              if (n < 2) next
              idx=1
              while (idx <= n && a[idx] ~ /^-/) idx++
              if (idx > n) next

              kb=a[idx]
              cmd=""
              for (i=idx+1; i<=n; i++) { if (i>idx+1) cmd=cmd " "; cmd=cmd a[i] }

              # Normalize keybind display
              gsub(/\$mod\+?/, "Super+", kb)
              if (var_left  != "") gsub(/\$left/,  var_left,  kb)
              if (var_down  != "") gsub(/\$down/,  var_down,  kb)
              if (var_up    != "") gsub(/\$up/,    var_up,    kb)
              if (var_right != "") gsub(/\$right/, var_right, kb)
              gsub(/\+\+/, "+", kb)
              gsub(/\+/, " + ", kb)
              gsub(/Control|Ctrl/, "Ctrl", kb)
              gsub(/Mod1/, "Alt", kb)

              # Build description
              desc=cmd
              if (desc ~ /^exec[ ]+/) {
                sub(/^exec[ ]+/, "Run: ", desc)
              }

              # Categorize
              low=tolower(cmd)
              cat="sway"
              if (low ~ /(kitty|ghostty|wezterm|alacritty|foot|st)( |$)/ || low ~ /exec[ ]+(kitty|ghostty|wezterm|alacritty|foot|st)/) cat="terminal"
              else if (low ~ /(emacs|code|vscode|nvim|vim|geany)/) cat="editor"
              else if (low ~ /(rofi|wofi|dmenu|launcher)/) cat="launcher"
              else if (low ~ /(grim|slurp|grimshot|screenshot)/) cat="screenshot"
              else if (low ~ /(wpctl|pamixer|pactl|brightnessctl|volume|brightness|playerctl|xf86audio|xf86monbrightness)/) cat="media"
              else if (low ~ /(chrome|chromium|firefox|brave|browser)/) cat="browser"
              else if (low ~ /\bworkspace\b/) cat="workspace"
              else if (low ~ /(move|focus|kill|floating|fullscreen|layout|splith|splitv|resize)/) cat="window"

              # JSON escape
              gsub(/\\/, "\\\\", kb); gsub(/"/, "\\\"", kb)
              gsub(/\\/, "\\\\", desc); gsub(/"/, "\\\"", desc)
              gsub(/\\/, "\\\\", cat); gsub(/"/, "\\\"", cat)

              if (!first) print ","; first=0
              printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", kb, desc, cat
            }
          }
          END { print "\n]" }
        ' "''${FILES[@]}"
        ;;
      bspwm)
        # BSPWM uses sxhkd for keybindings; parse ~/.config/sxhkd/sxhkdrc
        SXHKDRC="$HOME/.config/sxhkd/sxhkdrc"
        if [[ ! -f "$SXHKDRC" ]]; then
          echo "Error: sxhkdrc not found at $SXHKDRC" >&2
          exit 1
        fi
        ${pkgs.gawk}/bin/awk '
          BEGIN { print "["; first=1; in_cmd=0; current_keys=""; desc="" }
          /^[ ]*#/ { next }
          {
            if (!in_cmd) {
              # Key line: collect entire line as keybind
              line=$0
              gsub(/^[ ]+|[ ]+$/, "", line)
              if (line == "") next
              current_keys=line
              in_cmd=1
              next
            } else {
              # Command line(s) start with leading spaces or tabs
              if ($0 ~ /^[ \t]+/) {
                cmd=$0
                gsub(/^[ \t]+/, "", cmd)
                # Skip empty command lines
                if (cmd == "") next
                # Build description
                desc="Run: " cmd
                # Category heuristic
                low=tolower(cmd)
                cat="app"
                if (low ~ /(kitty|wezterm|alacritty|foot|st)/) cat="terminal"
                else if (low ~ /(emacs|code|vscode|gedit|nvim|vim)/) cat="editor"
                else if (low ~ /(rofi|wofi|dmenu)/) cat="launcher"
                else if (low ~ /(bspc|desktop|node|window|monocle|tiled|fullscreen)/) cat="window"
                else if (low ~ /(wm|bspwm)/) cat="bspwm"

                # Normalize keys
                kb=current_keys
                gsub(/-/, "+", kb)
                gsub(/super/, "Super", kb)
                gsub(/alt/, "Alt", kb)
                gsub(/ctrl/, "Ctrl", kb)
                gsub(/shift/, "Shift", kb)

                # JSON escape
                gsub(/\\/, "\\\\", kb); gsub(/"/, "\\\"", kb)
                gsub(/\\/, "\\\\", desc); gsub(/"/, "\\\"", desc)
                gsub(/\\/, "\\\\", cat); gsub(/"/, "\\\"", cat)

                if (!first) print ","; first=0
                printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", kb, desc, cat

                # Reset for next block
                in_cmd=0; current_keys=""; desc=""
                next
              } else {
                # Unexpected line; reset state
                in_cmd=0
              }
            }
          }
          END { print "\n]" }
        ' "$SXHKDRC"
        ;;
      i3)
        # i3 setup uses sxhkd in this project; parse ~/.config/i3/sxhkd/sxhkdrc
        SXHKDRC_I3="$HOME/.config/i3/sxhkd/sxhkdrc"
        if [[ ! -f "$SXHKDRC_I3" ]]; then
          echo "Error: sxhkdrc for i3 not found at $SXHKDRC_I3" >&2
          exit 1
        fi
        ${pkgs.gawk}/bin/awk '
          BEGIN { print "["; first=1; in_cmd=0; current_keys=""; desc="" }
          /^[ ]*#/ { next }
          {
            if (!in_cmd) {
              line=$0
              gsub(/^[ ]+|[ ]+$/, "", line)
              if (line == "") next
              current_keys=line
              in_cmd=1
              next
            } else {
              if ($0 ~ /^[ \t]+/) {
                cmd=$0
                gsub(/^[ \t]+/, "", cmd)
                if (cmd == "") next
                desc="Run: " cmd
                low=tolower(cmd)
                cat="app"
                if (low ~ /(kitty|wezterm|alacritty|foot|st|ghostty)/) cat="terminal"
                else if (low ~ /(emacs|code|vscode|gedit|nvim|vim|geany)/) cat="editor"
                else if (low ~ /(rofi|wofi|dmenu)/) cat="launcher"
                else if (low ~ /(thunar|nautilus|dolphin)/) cat="app"
                else if (low ~ /(flameshot|screenshot)/) cat="screenshot"
                else if (low ~ /(pamixer|pactl|wpctl|brightnessctl|xbacklight|xf86audio|xf86monbrightness)/) cat="media"
                else if (low ~ /(chrome|chromium|firefox|brave|browser)/) cat="browser"
                else if (low ~ /i3-msg[ ]+workspace/) cat="workspace"
                else if (low ~ /i3-msg[ ]+(move|focus|kill|floating|fullscreen|scratchpad)/) cat="window"
                else if (low ~ /i3-msg/) cat="window"

                kb=current_keys
                gsub(/-/, "+", kb)
                gsub(/super/, "Super", kb)
                gsub(/alt/, "Alt", kb)
                gsub(/ctrl/, "Ctrl", kb)
                gsub(/shift/, "Shift", kb)

                gsub(/\\/, "\\\\", kb); gsub(/"/, "\\\"", kb)
                gsub(/\\/, "\\\\", desc); gsub(/"/, "\\\"", desc)
                gsub(/\\/, "\\\\", cat); gsub(/"/, "\\\"", cat)

                if (!first) print ","; first=0
                printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", kb, desc, cat

                in_cmd=0; current_keys=""; desc=""
                next
              } else {
                in_cmd=0
              }
            }
          }
          END { print "\n]" }
        ' "$SXHKDRC_I3"
        ;;
      dwm)
        # DWM setup uses sxhkd as well; parse ~/.config/suckless/sxhkd/sxhkdrc
        SXHKDRC_DWM="$HOME/.config/suckless/sxhkd/sxhkdrc"
        if [[ ! -f "$SXHKDRC_DWM" ]]; then
          echo "Error: sxhkdrc for DWM not found at $SXHKDRC_DWM" >&2
          exit 1
        fi
        ${pkgs.gawk}/bin/awk '
          BEGIN { print "["; first=1; in_cmd=0; current_keys=""; desc="" }
          /^[ ]*#/ { next }
          {
            if (!in_cmd) {
              # Key line: collect entire line as keybind
              line=$0
              gsub(/^[ ]+|[ ]+$/, "", line)
              if (line == "") next
              current_keys=line
              in_cmd=1
              next
            } else {
              # Command line(s) start with leading spaces or tabs
              if ($0 ~ /^[ \t]+/) {
                cmd=$0
                gsub(/^[ \t]+/, "", cmd)
                # Skip empty command lines
                if (cmd == "") next
                # Build description
                desc="Run: " cmd
                # Category heuristic
                low=tolower(cmd)
                cat="app"
                if (low ~ /(kitty|wezterm|alacritty|foot|st)/) cat="terminal"
                else if (low ~ /(emacs|code|vscode|gedit|nvim|vim)/) cat="editor"
                else if (low ~ /(rofi|wofi|dmenu)/) cat="launcher"
                else if (low ~ /(dwmc|dwm|wm)/) cat="dwm"

                # Normalize keys
                kb=current_keys
                gsub(/-/, "+", kb)
                gsub(/super/, "Super", kb)
                gsub(/alt/, "Alt", kb)
                gsub(/ctrl/, "Ctrl", kb)
                gsub(/shift/, "Shift", kb)

                # JSON escape
                gsub(/\\/, "\\\\", kb); gsub(/"/, "\\\"", kb)
                gsub(/\\/, "\\\\", desc); gsub(/"/, "\\\"", desc)
                gsub(/\\/, "\\\\", cat); gsub(/"/, "\\\"", cat)

                if (!first) print ","; first=0
                printf "{\"keybind\":\"%s\",\"description\":\"%s\",\"category\":\"%s\"}", kb, desc, cat

                # Reset for next block
                in_cmd=0; current_keys=""; desc=""
                next
              } else {
                # Unexpected line; reset state
                in_cmd=0
              }
            }
          }
          END { print "\n]" }
        ' "$SXHKDRC_DWM"
        ;;

      *)
        echo "Unknown mode: $MODE" >&2
        exit 1
        ;;
    esac
''
