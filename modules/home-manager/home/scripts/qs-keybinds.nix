{pkgs}:
pkgs.writeShellScriptBin "qs-keybinds" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Configurable defaults via env
    MODE="''${KEYBINDS_MODE:-hyprland}"

    usage() {
      cat <<EOF
  Usage: qs-keybinds [options]

  Options:
    -m MODE  Mode to display (hyprland|emacs|kitty|wezterm|ghostty|yazi) (default: hyprland)
    -h       Show this help
  EOF
    }

    # Pre-handle long flags so getopts doesn't complain
    ARGS=()
    while [[ $# -gt 0 ]]; do
      case $1 in
        --shell-only)
          QS_SHELL_ONLY=1
          shift
          ;;
        *)
          ARGS+=("$1")
          shift
          ;;
      esac
    done
    set -- "''${ARGS[@]}"

    while getopts ":m:h" opt; do
      case "$opt" in
        m) MODE="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "Missing argument for -$OPTARG" >&2; exit 2 ;;
        \\?) echo "Unknown option -$OPTARG" >&2; usage; exit 2 ;;
      esac
    done

    # Validate mode
    if [[ "$MODE" != "hyprland" && "$MODE" != "emacs" && "$MODE" != "kitty" && "$MODE" != "wezterm" && "$MODE" != "ghostty" && "$MODE" != "yazi" ]]; then
      echo "Error: Invalid mode '$MODE'. Use 'hyprland', 'emacs', 'kitty', 'wezterm', 'ghostty', or 'yazi'" >&2
      exit 1
    fi

    # Perf timing helpers
    now_ms() { ${pkgs.coreutils}/bin/date +%s%3N; }
    if [ -n "''${QS_PERF:-}" ]; then t0=$(now_ms); fi

    tmpdir=$(${pkgs.coreutils}/bin/mktemp -d)
    json="$tmpdir/keybinds.json"
    qml="$tmpdir/keybinds.qml"

    # Generate data based on mode
    if [ -n "''${QS_PERF:-}" ]; then t1=$(now_ms); fi

    # Detect WM availability (simple heuristics)
    HAS_HYPR=0; { [ -f "$HOME/.config/hypr/hyprland.conf" ] || command -v Hyprland >/dev/null 2>&1 || command -v hyprland >/dev/null 2>&1; } && HAS_HYPR=1 || true

    # Allow host-stateful overrides via env (set to 0/1). These can be wired from hosts/<hostname>/variables.nix
    [ -n "''${QS_HAS_HYPR:-}" ] && HAS_HYPR="''${QS_HAS_HYPR}"

    MODE_AVAILABLE=1

    # Original keybinds data generation with graceful fallback when mode is unavailable
    if ${pkgs.callPackage ./keybinds-parser.nix {}}/bin/keybinds-parser "$MODE" > "$json"; then
      :
    else
      echo "[]" > "$json"
      MODE_AVAILABLE=0
    fi

    # For Kitty, WezTerm, Ghostty, and Yazi modes, also generate submode data when available
    if [ "$MODE_AVAILABLE" -eq 1 ] && { [ "$MODE" = "kitty" ] || [ "$MODE" = "wezterm" ] || [ "$MODE" = "ghostty" ] || [ "$MODE" = "yazi" ]; }; then
      ${pkgs.callPackage ./keybinds-parser.nix {}}/bin/keybinds-parser "$MODE" "summary" > "$tmpdir/summary.json" || true
      ${pkgs.callPackage ./keybinds-parser.nix {}}/bin/keybinds-parser "$MODE" "keybinds" > "$tmpdir/keybinds.json" || true
      ${pkgs.callPackage ./keybinds-parser.nix {}}/bin/keybinds-parser "$MODE" "colors" > "$tmpdir/colors.json" || true
    fi

    if [ -n "''${QS_PERF:-}" ]; then t2=$(now_ms); echo "[perf] json_ms=$((t2 - t1))" >&2; fi

    # Optional: shell-only mode for perf (skip QML)
    if [ -n "''${QS_SHELL_ONLY:-}" ]; then
      if [ -n "''${QS_PERF:-}" ]; then echo "[perf] shell_only=1 total_ms=$((t2 - t0))" >&2; fi
      exit 0
    fi

    # Derive QML flags from env
    PERF_BOOL=false; [ -n "''${QS_PERF:-}" ] && PERF_BOOL=true
    AUTO_QUIT_BOOL=false; [ -n "''${QS_AUTO_QUIT:-}" ] && AUTO_QUIT_BOOL=true

    # Helper to robustly convert env values (including quoted or string forms) to QML booleans
    emit_bool() {
      local v="''${1-}"
      # Strip literal quotes and whitespace
      v="''${v//\"/}"
      v="''${v//\'/}"
      v="''${v//[[:space:]]/}"
      # Normalize and match common truthy values
      case "''${v,,}" in
        1|true|yes|on) echo true ;;
        *) echo false ;;
      esac
    }

    # Get window title based on mode
    case "$MODE" in
      hyprland) WINDOW_TITLE="Hyprland Keybinds" ;;
      emacs) WINDOW_TITLE="Emacs Leader Keybinds" ;;
      kitty) WINDOW_TITLE="Kitty Configuration" ;;
      wezterm) WINDOW_TITLE="WezTerm Configuration" ;;
      ghostty) WINDOW_TITLE="Ghostty Configuration" ;;
      yazi) WINDOW_TITLE="Yazi Configuration" ;;
    esac

    # QML UI: Use template replacement to safely embed JSON
    # Create QML template with placeholder
    cat > "$qml" <<'QML_TEMPLATE'
  import QtQuick 2.15
  import QtQuick.Window 2.15
  import QtQuick.Controls 2.15

  Window {
    id: win
    visible: true
    width: Screen.width * 0.7
    height: Screen.height * 0.7
    x: (Screen.width - width) / 2
    y: (Screen.height - height) / 2
    title: "WINDOW_TITLE_PLACEHOLDER"
    flags: Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    property bool perfEnabled: PERF_BOOL_PLACEHOLDER
    property bool autoQuit: AUTO_QUIT_BOOL_PLACEHOLDER
    property bool firstDelegateLogged: false
    property double qStart: 0
    property string searchQuery: ""
    property string selectedMode: "MODE_PLACEHOLDER"
    property string selectedCategory: "all"
    property string selectedSubMode: "all"  // For app-specific sub-categories
    property bool modeAvailable: MODE_AVAILABLE_PLACEHOLDER

    // Load keybinds data at runtime
    property var keybindsData: []
    property bool dataLoaded: false
    property string jsonDataFile: "JSON_FILE_PLACEHOLDER"

    // Load keybinds data from temp file (generated by shell script)
    function loadKeybindsData() {
      if (dataLoaded) return;

      // The shell script will write JSON to a temp file for us to read
      const xhr = new XMLHttpRequest();
      xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
          if (xhr.status === 200 || xhr.status === 0) { // 0 for local files
            try {
                const result = JSON.parse(xhr.responseText);
                win.keybindsData = result;
                win.dataLoaded = true;
                win.selectedCategory = "all";  // Reset category filter
                win.populateModel(win.keybindsData);
                if (perfEnabled) console.log("[perf] q2_data_loaded count=" + result.length);
            } catch (e) {
              console.error("Failed to parse keybinds JSON:", e);
              win.keybindsData = [];
              win.dataLoaded = true;
              win.populateModel([]);
            }
          } else {
            console.error("Failed to load keybinds data, status:", xhr.status);
            win.keybindsData = [];
            win.dataLoaded = true;
            win.populateModel([]);
          }
        }
      };

      // Load from the JSON file that the shell script will create for us
      xhr.open("GET", "file://" + jsonDataFile);
      xhr.send();
    }

    // Load keybinds data with specific submode (for app-specific views)
    function loadKeybindsDataWithSubMode(submode) {
      console.log("Loading submode:", submode);

      // Determine which JSON file to load based on submode
      var fileName = "keybinds.json";
      if (submode === "summary") fileName = "summary.json";
      else if (submode === "keybinds") fileName = "keybinds.json";
      else if (submode === "colors") fileName = "colors.json";

      var filePath = jsonDataFile.replace("keybinds.json", fileName);

      const xhr = new XMLHttpRequest();
      xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
          if (xhr.status === 200 || xhr.status === 0) { // 0 for local files
            try {
              let result = JSON.parse(xhr.responseText);
              // Normalize summary/colors data into { keybind, description, category }
              if (Array.isArray(result) && result.length > 0 && result[0].setting !== undefined) {
                result = result.map(function(it) {
                  return {
                    keybind: it.setting,
                    description: it.value,
                    category: it.category || "general"
                  };
                });
              }
              win.keybindsData = result;
              win.selectedSubMode = submode;
              win.populateModel(result);
              if (perfEnabled) console.log("[perf] submode_data_loaded count=" + result.length + " submode=" + submode);
            } catch (e) {
              console.error("Failed to parse submode JSON:", e);
              win.keybindsData = [];
              win.populateModel([]);
            }
          } else {
            console.error("Failed to load submode data, status:", xhr.status);
            win.keybindsData = [];
            win.populateModel([]);
          }
        }
      };

      xhr.open("GET", "file://" + filePath);
      xhr.send();
    }

    // Filter keybinds based on search query and category
    function filterKeybinds(q, category) {
      let filtered = keybindsData;

      // Apply category filter first
      if (category && category !== "all") {
        filtered = filtered.filter(it => it.category === category);
      }

      // Then apply search filter
      if (q && q.trim() !== "") {
        const s = q.toLowerCase();
        filtered = filtered.filter(it =>
          (it.keybind && it.keybind.toLowerCase().indexOf(s) !== -1) ||
          (it.description && it.description.toLowerCase().indexOf(s) !== -1) ||
          (it.category && it.category.toLowerCase().indexOf(s) !== -1)
        );
      }

      return filtered;
    }

    // Get unique categories from current keybinds data
    function getCategories() {
      // For Kitty, WezTerm, Ghostty, and Yazi modes, show app-specific sub-modes instead of regular categories
      if (selectedMode === "kitty" || selectedMode === "wezterm" || selectedMode === "ghostty" || selectedMode === "yazi") {
        return ["all", "summary", "keybinds", "colors"];
      }

      // For other modes, extract categories from data
      const cats = new Set(["all"]);
      keybindsData.forEach(it => {
        if (it.category) cats.add(it.category);
      });
      return Array.from(cats).sort((a, b) => {
        if (a === "all") return -1;
        if (b === "all") return 1;
        return a.localeCompare(b);
      });
    }

    ListModel { id: keybindsModel }

    // Sort keybinds by category then by keybind
    function sortedKeybinds(arr) {
      return arr.slice().sort(function(a, b) {
        const catA = (a && a.category ? a.category : "").toLowerCase();
        const catB = (b && b.category ? b.category : "").toLowerCase();
        if (catA !== catB) {
          if (catA < catB) return -1;
          if (catA > catB) return 1;
        }
        const bindA = (a && a.keybind ? a.keybind : "").toLowerCase();
        const bindB = (b && b.keybind ? b.keybind : "").toLowerCase();
        if (bindA < bindB) return -1;
        if (bindA > bindB) return 1;
        return 0;
      });
    }

    function populateModel(arr) {
      const start = Date.now();
      keybindsModel.clear();
      const sorted = sortedKeybinds(arr);
      for (let i = 0; i < sorted.length; i++) {
        keybindsModel.append(sorted[i]);
      }
      // Reset scroll position after repopulating to avoid content jumping into header
      if (typeof listView !== 'undefined' && listView.contentY !== undefined) {
        listView.contentY = 0;
      }
      if (perfEnabled) console.log("[perf] q2_inline_model_appended count=" + keybindsModel.count + " total_ms=" + (Date.now() - qStart));
      if (autoQuit) Qt.quit();
    }

    Component.onCompleted: {
      qStart = Date.now();
      if (perfEnabled) console.log("[perf] q0_window_created");
      if (perfEnabled) console.log("[perf] q1_loading_data");

      loadKeybindsData();
    }

    // App-wide ESC shortcut; does not depend on focus
    Shortcut {
      sequences: [ "Escape" ]
      context: Qt.ApplicationShortcut
      onActivated: Qt.quit()
    }

    Rectangle {
      id: frame
      anchors.fill: parent
      anchors.margins: 12
      radius: 12
      border.width: 0
      border.color: "#00000000"
      color: "#DD000000"
      clip: true

      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header with search
        Column {
          id: headerSection
          width: parent.width
          spacing: 8

          // Top row: Search bar
          Row {
            id: topRow
            width: parent.width
            spacing: 16

            // Search bar
            Rectangle {
              id: searchBar
              width: parent.width
              height: 36
              radius: 8
              border.width: 1
              border.color: "#66ccff"
              color: "#BB000000"

              TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.margins: 12
                color: "white"
                font.pixelSize: 14
                focus: true
                Keys.onEscapePressed: Qt.quit()
                onTextChanged: {
                  win.searchQuery = text;
                  populateModel(filterKeybinds(text, win.selectedCategory));
                }
              }

              Text {
                text: "Search keybinds..."
                color: "#88ffffff"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 16
                visible: searchInput.text.length === 0
              }
            }
          }

          // Second row: Application UIs and Window Managers
          Row {
            id: modeButtonsRowApps
            width: parent.width
            spacing: 8

            Button {
              text: "Hyprland"
              width: 120
              height: 36
              background: Rectangle {
                color: selectedMode === "hyprland" ? "#66ccff" : "#444444"
                radius: 6
                border.width: 1
                border.color: "#66ccff"
              }
              contentItem: Text {
                text: parent.text
                color: selectedMode === "hyprland" ? "#000000" : "#ffffff"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: { console.log("MODE:hyprland"); Qt.quit(); }
            }

            Button {
              id: emacsBtn
              text: "Emacs"
              width: 120
              height: 36
              background: Rectangle {
                color: selectedMode === "emacs" ? "#66ccff" : "#444444"
                radius: 6
                border.width: 1
                border.color: "#66ccff"
              }
              contentItem: Text {
                text: parent.text
                color: selectedMode === "emacs" ? "#000000" : "#ffffff"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: { console.log("MODE:emacs"); Qt.quit(); }
            }

            Button {
              text: "Kitty"
              width: 120
              height: 36
              background: Rectangle {
                color: selectedMode === "kitty" ? "#66ccff" : "#444444"
                radius: 6
                border.width: 1
                border.color: "#66ccff"
              }
              contentItem: Text {
                text: parent.text
                color: selectedMode === "kitty" ? "#000000" : "#ffffff"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: { console.log("MODE:kitty"); Qt.quit(); }
            }

            Button {
              text: "WezTerm"
              width: 120
              height: 36
              background: Rectangle {
                color: selectedMode === "wezterm" ? "#66ccff" : "#444444"
                radius: 6
                border.width: 1
                border.color: "#66ccff"
              }
              contentItem: Text {
                text: parent.text
                color: selectedMode === "wezterm" ? "#000000" : "#ffffff"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: { console.log("MODE:wezterm"); Qt.quit(); }
            }

            Button {
              text: "Ghostty"
              width: 120
              height: 36
              background: Rectangle {
                color: selectedMode === "ghostty" ? "#66ccff" : "#444444"
                radius: 6
                border.width: 1
                border.color: "#66ccff"
              }
              contentItem: Text {
                text: parent.text
                color: selectedMode === "ghostty" ? "#000000" : "#ffffff"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: { console.log("MODE:ghostty"); Qt.quit(); }
            }

            Button {
              text: "Yazi"
              width: 120
              height: 36
              background: Rectangle {
                color: selectedMode === "yazi" ? "#66ccff" : "#444444"
                radius: 6
                border.width: 1
                border.color: "#66ccff"
              }
              contentItem: Text {
                text: parent.text
                color: selectedMode === "yazi" ? "#000000" : "#ffffff"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: { console.log("MODE:yazi"); Qt.quit(); }
            }
          }
        }

        // Conditional content based on mode
        Item {
          width: parent.width
          height: parent.height - headerSection.height - 12  // Account for dynamic header height and spacing

          // Keybinds interface
          Column {
            anchors.fill: parent
            spacing: 12

            // Unavailable mode notice
            Rectangle {
              visible: !win.modeAvailable
              width: parent.width
              height: 28
              radius: 6
              color: "#55333333"
              border.width: 1
              border.color: "#88444444"
              Text {
                text: "This mode isn't available on this host."
                anchors.centerIn: parent
                color: "#ffdddd"
                font.pixelSize: 12
              }
            }

            // Category filter buttons
            Flow {
              width: parent.width
              spacing: 8

              Repeater {
                model: dataLoaded ? getCategories() : []

                Button {
                  text: modelData === "all" ? "All" : (modelData.charAt(0).toUpperCase() + modelData.slice(1))
                  width: Math.max(60, text.length * 8 + 16)
                  height: 28
                  background: Rectangle {
                    color: win.selectedCategory === modelData ? "#66ccff" : "#333333"
                    radius: 4
                    border.width: 1
                    border.color: "#555555"
                  }
                  contentItem: Text {
                    text: parent.text
                    color: win.selectedCategory === modelData ? "#000000" : "#cccccc"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }
                  onClicked: {
                    win.selectedCategory = modelData;

                    // For Kitty, WezTerm, Ghostty, and Yazi modes, reload data with submode instead of just filtering
                    if ((win.selectedMode === "kitty" || win.selectedMode === "wezterm" || win.selectedMode === "ghostty" || win.selectedMode === "yazi") && modelData !== "all") {
                      win.selectedSubMode = modelData;
                      win.loadKeybindsDataWithSubMode(modelData);
                    } else {
                      win.populateModel(win.filterKeybinds(win.searchQuery, modelData));
                    }
                  }
                }
              }
          }

            // Keybinds list
            ListView {
              id: listView
              width: parent.width
              height: parent.height - 40  // Adjusted for category buttons row
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              model: keybindsModel
              focus: true
              Keys.onEscapePressed: Qt.quit()

              delegate: Rectangle {
                width: listView.width
                height: 48
                color: "transparent"
                border.width: 0
                border.color: "#66ccff"
                radius: 6

                MouseArea {
                  id: mouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: parent.border.width = 1
                  onExited: parent.border.width = 0
                  onClicked: {
                    parent.border.width = 1;
                    console.log("KEYBIND:" + model.keybind + "|" + model.description);
                    Qt.quit();
                  }
                }

                Row {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: 16
                  anchors.rightMargin: 16
                  spacing: 16

                  // Category indicator
                  Rectangle {
                    width: 80
                    height: 24
                    radius: 12
                    color: getCategoryColor(model.category || "")
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      text: model.category || ""
                      color: "#000000"
                      font.pixelSize: 10
                      font.bold: true
                      anchors.centerIn: parent
                    }
                  }

                  // Keybind (or setting name for colors)
                  Text {
                    id: keyText
                    text: model.keybind || ""
                    color: "#66ccff"
                    font.pixelSize: 14
                    font.family: "monospace"
                    font.bold: true
                    // Make key column wider for long combos while keeping a max share of the row
                    // Increase lower bound further and allow up to 55% of row
                    width: Math.min(Math.max(emacsBtn.width * 3.2, (keyText.paintedWidth || 0) + 36, 320), listView.width * 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  // Color swatch (only for hex color values)
                  Rectangle {
                    width: 32
                    height: 24
                    radius: 4
                    color: (model.description && model.description.match && model.description.match(/^#[0-9a-fA-F]{6}$/)) ? model.description : "transparent"
                    border.width: (model.description && model.description.match && model.description.match(/^#[0-9a-fA-F]{6}$/)) ? 1 : 0
                    border.color: "#666666"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (model.description && model.description.match && model.description.match(/^#[0-9a-fA-F]{6}$/))
                  }

                  // Description (with special formatting for hex colors)
                  Text {
                    text: {
                      var desc = model.description || "";
                      // For hex colors, show both hex value and color name hints
                      if (desc.match && desc.match(/^#[0-9a-fA-F]{6}$/)) {
                        return desc + " " + getColorName(desc);
                      }
                      return desc;
                    }
                    color: "#ffffff"
                    font.pixelSize: 14
                    // Compute remaining width dynamically: listView width - margins - category - keybind - color swatch - spacings
                    width: Math.max(100, listView.width - (16 + 16 + 80 + keyText.width + 32 + 16*3))
                    wrapMode: Text.WordWrap
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }
          }
        }
      }
    }

    function getCategoryColor(category) {
      switch (category.toLowerCase()) {
        // Emacs categories
        case "files": return "#4CAF50";
        case "project": return "#2196F3";
        case "buffers": return "#FF9800";
        case "windows": return "#9C27B0";
        case "search": return "#F44336";
        case "git": return "#795548";
        case "help": return "#607D8B";
        case "code": return "#E91E63";
        case "quit": return "#FF5722";
        case "toggle": return "#8BC34A";

        // Hyprland categories
        case "terminal": return "#4CAF50";
        case "editor": return "#E91E63";
        case "launcher": return "#FF9800";
        case "browser": return "#2196F3";
        case "app": return "#9C27B0";
        case "screenshot": return "#FF5722";
        case "wallpaper": return "#795548";
        case "media": return "#607D8B";
        case "window": return "#FFC107";
        case "workspace": return "#00BCD4";
        case "hyprland": return "#CDDC39";
        case "sway": return "#80CBC4";
        case "mouse": return "#4DB6AC";

        // Kitty color categories
        case "basic": return "#9E9E9E";
        case "tabs": return "#673AB7";
        case "cursor": return "#FF5722";
        case "selection": return "#2196F3";
        case "borders": return "#795548";
        case "marks": return "#E91E63";
        case "urls": return "#009688";
        case "black": return "#424242";
        case "red": return "#F44336";
        case "green": return "#4CAF50";
        case "yellow": return "#FFEB3B";
        case "blue": return "#2196F3";
        case "magenta": return "#E91E63";
        case "cyan": return "#00BCD4";
        case "white": return "#FAFAFA";
        case "terminal-colors": return "#607D8B";

        // Yazi categories
        case "manager": return "#4CAF50";
        case "completion": return "#2196F3";
        case "dialogs": return "#FF9800";
        case "input": return "#9C27B0";
        case "file-management": return "#607D8B";
        case "theme": return "#E91E63";
        case "keymaps": return "#795548";
        case "status": return "#00BCD4";
        case "filetype": return "#8BC34A";
        case "mode": return "#FFC107";
        case "confirm": return "#FF5722";
        case "help": return "#9E9E9E";

        default: return "#757575";
      }
    }

    function getColorName(hexColor) {
      if (!hexColor || !hexColor.match(/^#[0-9a-fA-F]{6}$/)) return "";

      const hex = hexColor.toLowerCase();

      // Common color name mappings for Catppuccin theme
      const colorNames = {
        "#1e1e2e": "(base)",
        "#11111b": "(crust)",
        "#181825": "(mantle)",
        "#cdd6f4": "(text)",
        "#f5e0dc": "(rosewater)",
        "#b4befe": "(lavender)",
        "#6c7086": "(overlay1)",
        "#f9e2af": "(yellow)",
        "#cba6f7": "(mauve)",
        "#74c7ec": "(sky)",
        "#45475a": "(surface1)",
        "#585b70": "(surface2)",
        "#f38ba8": "(pink)",
        "#a6e3a1": "(green)",
        "#89b4fa": "(blue)",
        "#f5c2e7": "(flamingo)",
        "#94e2d5": "(teal)",
        "#bac2de": "(subtext1)",
        "#a6adc8": "(subtext0)"
      };


      return colorNames[hex] || "";
    }
  }
  QML_TEMPLATE

    # Now replace placeholders with actual values
    ${pkgs.gnused}/bin/sed -i "s/WINDOW_TITLE_PLACEHOLDER/$WINDOW_TITLE/g" "$qml"
    ${pkgs.gnused}/bin/sed -i "s/PERF_BOOL_PLACEHOLDER/$PERF_BOOL/g" "$qml"
    ${pkgs.gnused}/bin/sed -i "s/AUTO_QUIT_BOOL_PLACEHOLDER/$AUTO_QUIT_BOOL/g" "$qml"
    ${pkgs.gnused}/bin/sed -i "s/MODE_PLACEHOLDER/$MODE/g" "$qml"
    ${pkgs.gnused}/bin/sed -i "s|JSON_FILE_PLACEHOLDER|$json|g" "$qml"
    ${pkgs.gnused}/bin/sed -i "s/MODE_AVAILABLE_PLACEHOLDER/$(emit_bool \"$MODE_AVAILABLE\")/g" "$qml"


    # Prepare QML runtime environment (Qt6)

    # Prepare QML runtime environment (Qt6)
    export QT_QPA_PLATFORM="wayland;xcb"
    export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
    export QT_PLUGIN_PATH="${pkgs.qt6.qtbase}/lib/qt-6/plugins:${pkgs.qt6.qtwayland}/lib/qt-6/plugins"
    export QML_IMPORT_PATH="${pkgs.qt6.qtbase}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.qt6.qt5compat}/lib/qt-6/qml:${pkgs.qt6.qtsvg}/lib/qt-6/qml"
    export QML2_IMPORT_PATH="$QML_IMPORT_PATH"
    export QML_XHR_ALLOW_FILE_READ="1"

    QML_BIN="${pkgs.qt6.qtdeclarative}/bin/qml"
    if ! [ -x "$QML_BIN" ]; then
      if [ -x "${pkgs.qt6.qtdeclarative}/bin/qml6" ]; then
        QML_BIN="${pkgs.qt6.qtdeclarative}/bin/qml6"
      elif command -v qml >/dev/null 2>&1; then
        QML_BIN=$(command -v qml)
      elif command -v qml6 >/dev/null 2>&1; then
        QML_BIN=$(command -v qml6)
      elif command -v qmlscene >/dev/null 2>&1; then
        QML_BIN=$(command -v qmlscene)
      fi
    fi

    # Debug mode: run QML directly and do not filter output
    if [ -n "''${QS_DEBUG:-}" ]; then
      {
        echo "[qs-keybinds] MODE=$MODE" >&2
        echo "[qs-keybinds] QML_BIN=$QML_BIN" >&2
        echo "[qs-keybinds] QML_FILE=$qml" >&2
        echo "[qs-keybinds] QML_IMPORT_PATH=$QML_IMPORT_PATH" >&2
      } || true
      [ -n "''${QS_PERF:-}" ] && echo "[perf] pre_qml_ms=$(( $(now_ms) - t2 ))" >&2
      exec "$QML_BIN" "$qml"
    fi

    # Run QML runtime and capture selection from console
    [ -n "''${QS_PERF:-}" ] && echo "[perf] pre_qml_ms=$(( $(now_ms) - t2 ))" >&2
    output=$({ "$QML_BIN" "$qml" 2>&1 || true; })

    # Handle mode switching
    mode_result=$(echo "$output" | ${pkgs.gawk}/bin/awk -F'MODE:' '/MODE:/{print $2}' | ${pkgs.coreutils}/bin/tail -n1)
    if [ -n "''${mode_result:-}" ]; then
      exec "$0" -m "$mode_result"
    fi

    # Handle keybind selection
    keybind_result=$(echo "$output" | ${pkgs.gawk}/bin/awk -F'KEYBIND:' '/KEYBIND:/{print $2}' | ${pkgs.coreutils}/bin/tail -n1)
    if [ -n "''${keybind_result:-}" ]; then
      keybind=$(echo "$keybind_result" | ${pkgs.coreutils}/bin/cut -d'|' -f1)
      description=$(echo "$keybind_result" | ${pkgs.coreutils}/bin/cut -d'|' -f2-)

      # Copy keybind to clipboard
      echo -n "$keybind" | ${pkgs.wl-clipboard}/bin/wl-copy

      # Show notification
      ${pkgs.libnotify}/bin/notify-send "Keybind Copied" "$keybind\\n$description" -i keyboard -t 3000

      printf "Copied to clipboard: %s\\n" "$keybind"
    fi
''
