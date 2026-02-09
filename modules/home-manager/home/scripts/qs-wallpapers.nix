{pkgs}:
pkgs.writeShellScriptBin "qs-wallpapers" ''
    #!/usr/bin/env bash
    set -euo pipefail


    # Configurable defaults via env
    DIR="''${WALL_DIR:-$HOME/Pictures/Wallpapers}"
    CACHE="''${WALL_CACHE_DIR:-$HOME/.cache/wallthumbs}"
    SIZE="''${WALL_THUMB_SIZE:-200}"

    usage() {
      cat <<EOF
  Usage: qs-wallpapers [options]

  Options:
    -d DIR   Wallpapers directory (default: $HOME/Pictures/Wallpapers)
    -t DIR   Thumbnail cache directory (default: $HOME/.cache/wallthumbs)
    -s N     Thumbnail size in px (square) (default: 200)
    -h       Show this help
  EOF
    }

    # Pre-handle long flags so getopts doesn't complain
    if [ "''${1:-}" = "--shell-only" ]; then
      QS_SHELL_ONLY=1
      shift || true
    fi

    while getopts ":d:t:s:h" opt; do
      case "$opt" in
        d) DIR="$OPTARG" ;;
        t) CACHE="$OPTARG" ;;
        s) SIZE="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "Missing argument for -$OPTARG" >&2; exit 2 ;;
        \?) echo "Unknown option -$OPTARG" >&2; usage; exit 2 ;;
      esac
    done

    if [ ! -d "$DIR" ]; then
      echo "Wallpapers directory not found: $DIR" >&2
      DIR_MISSING=1
    else
      DIR_MISSING=0
    fi

    mkdir -p "$CACHE"

    # Prebuild thumbs quickly (quiet)
    ${pkgs.coreutils}/bin/env \
      WALL_DIR="$DIR" WALL_CACHE_DIR="$CACHE" WALL_THUMB_SIZE="$SIZE" \
      ${pkgs.callPackage ./wallpaper-thumbs-build.nix {}}/bin/wallpaper-thumbs-build -q >/dev/null 2>&1 || true

    # Perf timing helpers
    now_ms() { ${pkgs.coreutils}/bin/date +%s%3N; }
    if [ -n "''${QS_PERF:-}" ]; then t0=$(now_ms); fi

    # Collect images deterministically, tolerate symlink loops and permission errors
    mapfile -t IMAGES < <( { ${pkgs.findutils}/bin/find -L "$DIR" \
        \( -type f -o -xtype f \) \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' -o -iname '*.tiff' \) \
        -print0 2>/dev/null || true; } \
      | ${pkgs.coreutils}/bin/tr '\0' '\n' | ${pkgs.coreutils}/bin/sort )
    if [ -n "''${QS_PERF:-}" ]; then t1=$(now_ms); echo "[perf] find_ms=$((t1 - t0))" >&2; fi

    if [ "''${#IMAGES[@]}" -eq 0 ]; then
      if [ -n "''${QS_DEBUG:-}" ]; then
        echo "[qs-wallpapers] No images found in $DIR (followed symlinks); launching empty UI" >&2
      fi
      EMPTY=1
    else
      EMPTY=0
    fi

    tmpdir=$(${pkgs.coreutils}/bin/mktemp -d)
    json="$tmpdir/walls.json"
    qml="$tmpdir/walls.qml"

    # If a prebuilt manifest exists, reuse it to avoid rebuilding JSON at runtime
    manifest="$CACHE/walls.json"
    if [ -f "$manifest" ]; then
      ${pkgs.coreutils}/bin/cp -f "$manifest" "$json"
      if [ -n "''${QS_PERF:-}" ]; then t2=$(now_ms); echo "[perf] json_ms(prebuilt)=0" >&2; fi
    else
      # Build JSON with path, name (no ext), and thumb path; ensure thumb exists
      printf "[" > "$json"
      first=1
      for img in "''${IMAGES[@]}"; do
        # Faster hash (path string) using sha256sum instead of openssl
        hash=$(${pkgs.coreutils}/bin/printf "%s" "$img" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d" " -f1)
        thumb="$CACHE/$hash.png"
        if [ ! -f "$thumb" ]; then
          ${pkgs.imagemagick}/bin/convert "$img" -auto-orient -thumbnail "''${SIZE}x''${SIZE}>" \
            -background none -gravity center -extent "''${SIZE}x''${SIZE}" "$thumb" 2>/dev/null || true
        fi
        base=$(${pkgs.coreutils}/bin/basename "$img")
        name="''${base%.*}"
        if [ $first -eq 0 ]; then printf "," >> "$json"; fi
        first=0
        printf "{\"path\":\"%s\",\"name\":\"%s\",\"thumb\":\"%s\"}" \
          "$(${pkgs.coreutils}/bin/printf "%s" "$img" | ${pkgs.gnused}/bin/sed 's/\\/\\\\/g;s/"/\\"/g')" \
          "$(${pkgs.coreutils}/bin/printf "%s" "$name" | ${pkgs.gnused}/bin/sed 's/\\/\\\\/g;s/"/\\"/g')" \
          "$(${pkgs.coreutils}/bin/printf "%s" "$thumb" | ${pkgs.gnused}/bin/sed 's/\\/\\\\/g;s/"/\\"/g')" \
          >> "$json"
      done
      printf "]" >> "$json"
      if [ -n "''${QS_PERF:-}" ]; then t2=$(now_ms); echo "[perf] json_ms=$((t2 - t1))" >&2; fi
    fi

    # Optional: shell-only mode for perf (skip QML)
    if [ "''${1:-}" = "--shell-only" ] || [ -n "''${QS_SHELL_ONLY:-}" ]; then
      if [ -n "''${QS_PERF:-}" ]; then echo "[perf] shell_only=1 total_ms=$((t2 - t0))" >&2; fi
      exit 0
    fi

    # Derive QML flags from env
    PERF_BOOL=false; [ -n "''${QS_PERF:-}" ] && PERF_BOOL=true
    AUTO_QUIT_BOOL=false; [ -n "''${QS_AUTO_QUIT:-}" ] && AUTO_QUIT_BOOL=true
    NOIM_BOOL=false; [ "''${EMPTY:-0}" -eq 1 ] && NOIM_BOOL=true
    NODIR_BOOL=false; [ "''${DIR_MISSING:-0}" -eq 1 ] && NODIR_BOOL=true

    # QML UI: grid of thumbnails with labels, tight margins, scrollable
    # Embedded JSON in QML to avoid XHR and file I/O
    cat > "$qml" <<QML
  import QtQuick 2.15
  import QtQuick.Window 2.15
  import Qt5Compat.GraphicalEffects

  Window {
    id: win
    visible: true
    width: 1200
    height: 800
    title: "Wallpapers"
    flags: Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"

    property int thumbSize: ''${SIZE}
    property int cellPadding: 6
    property bool perfEnabled: ''${PERF_BOOL}
    property bool autoQuit: ''${AUTO_QUIT_BOOL}
    property bool noImages: ''${NOIM_BOOL}
    property bool firstDelegateLogged: false
    property double qStart: 0
    property string dirPath: "''${DIR}"
    property bool dirMissing: ''${NODIR_BOOL}
    // internal calc to horizontally center columns
    property int cw: thumbSize + (cellPadding * 2)
    // account for 12px frame margin on left/right (total 24)
    property int hpad: Math.floor(((width - 24) - Math.floor((width - 24) / cw) * cw) / 2)
    property string searchQuery: ""

    // Inline data to avoid XHR and file IO
    property var imagesData: $(cat "$json");

    // Case-insensitive filter on name or path
    function filterImages(q) {
      if (!q || q.trim() === "") return imagesData;
      const s = q.toLowerCase();
      return imagesData.filter(it =>
        (it.name && it.name.toLowerCase().indexOf(s) !== -1) ||
        (it.path && it.path.toLowerCase().indexOf(s) !== -1)
      );
    }

    ListModel { id: imagesModel }

    // Return a new array sorted by display name (case-insensitive)
    function sortedByName(arr) {
      return arr.slice().sort(function(a, b) {
        const an = (a && a.name ? a.name : "").toLowerCase();
        const bn = (b && b.name ? b.name : "").toLowerCase();
        if (an < bn) return -1;
        if (an > bn) return 1;
        return 0;
      });
    }

    function populateModel(arr) {
      const start = Date.now();
      imagesModel.clear();
      const sorted = sortedByName(arr);
      for (let i = 0; i < sorted.length; i++) {
        imagesModel.append(sorted[i]);
      }
      if (perfEnabled) console.log("[perf] q2_inline_model_appended count=" + imagesModel.count + " total_ms=" + (Date.now() - qStart));
      if (autoQuit) Qt.quit();
    }

    Component.onCompleted: {
      qStart = Date.now();
      if (perfEnabled) console.log("[perf] q0_window_created");
      if (perfEnabled) console.log("[perf] q1_inline_data");
      populateModel(imagesData);
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
      border.width: 2
      border.color: "#66ccff"
      color: "#DD000000"

      // Search bar (rounded)
      Rectangle {
        id: searchBar
        anchors.top: parent.top
        anchors.margins: 12
        width: parent.width / 3
        anchors.horizontalCenter: parent.horizontalCenter
        height: 40
        radius: 10
        border.width: 1
        border.color: "#66ccff"
        color: "#BB000000"
        antialiasing: true
        smooth: true
        gradient: Gradient {
          GradientStop { position: 0.0; color: "#3344aadd" }
          GradientStop { position: 1.0; color: "#223366aa" }
        }
        clip: true

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
            // Filter then sort by name inside populateModel
            populateModel(filterImages(text));
          }
        }

        Text {
          text: "Search…"
          color: "#88ffffff"
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: 16
          visible: searchInput.text.length === 0
        }
      }

      // Empty-state overlay when no images are found
      Item {
        id: emptyOverlay
        anchors.fill: parent
        visible: noImages
        Column {
          anchors.centerIn: parent
          spacing: 8
          Text { text: dirMissing ? "Directory not found" : "No images found"; color: "white"; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter }
          Text { text: dirPath; color: "#cccccc"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
          Text { text: dirMissing ? "Create the directory or pass -d DIR / set WALL_DIR" : "Tip: pass -d DIR or set WALL_DIR to your wallpapers folder"; color: "#aaaaaa"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
        }
      }
      GridView {
      id: grid
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: searchBar.bottom
      anchors.bottom: parent.bottom
      anchors.leftMargin: hpad
      anchors.rightMargin: hpad
      anchors.topMargin: 8
      anchors.bottomMargin: 8
      model: imagesModel
      interactive: true
      focus: true
      Keys.onEscapePressed: Qt.quit()
      cellWidth: thumbSize + (cellPadding * 2)
      cellHeight: thumbSize + (cellPadding * 2) + 18
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      flow: GridView.FlowLeftToRight

      delegate: Item {
        width: grid.cellWidth
        height: grid.cellHeight
        Component.onCompleted: {
          if (!win.firstDelegateLogged && win.perfEnabled) {
            console.log("[perf] q5_first_delegate total_ms=" + (Date.now() - win.qStart));
            win.firstDelegateLogged = true;
          }
        }

        Column {
          anchors.fill: parent
          anchors.margins: cellPadding
          spacing: 0

          Rectangle {
            width: thumbSize
            height: thumbSize
            color: "transparent"
            radius: 10
            border.width: 0
            border.color: "#66ccff"
            clip: true

            Image {
              id: thumbImg
              anchors.fill: parent
              anchors.margins: 2
              source: thumb
              fillMode: Image.PreserveAspectFit
              smooth: true
              antialiasing: true
              layer.enabled: true
              layer.effect: OpacityMask {
                maskSource: Rectangle {
                  width: thumbImg.width
                  height: thumbImg.height
                  radius: 10
                }
              }
            }

            MouseArea {
              id: mouse
              anchors.fill: parent
              hoverEnabled: true
              onEntered: parent.border.width = 2
              onExited: parent.border.width = 0
              onClicked: { parent.border.width = 2; console.log("SELECT:" + path); Qt.quit(); }
            }
          }

          Text {
            text: name
            color: "white"
            font.pixelSize: 12
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            width: thumbSize
          }
        }
      }
      }
    }
  }
  QML

    # Prepare QML runtime environment (Qt6)
    export QT_QPA_PLATFORM="wayland;xcb"
    export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
    export QT_PLUGIN_PATH="${pkgs.qt6.qtbase}/lib/qt-6/plugins:${pkgs.qt6.qtwayland}/lib/qt-6/plugins"
    export QML_IMPORT_PATH="${pkgs.qt6.qtbase}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.qt6.qt5compat}/lib/qt-6/qml:${pkgs.qt6.qtsvg}/lib/qt-6/qml"
    export QML2_IMPORT_PATH="$QML_IMPORT_PATH"

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
        echo "[qs-wallpapers] DIR=$DIR" >&2
        echo "[qs-wallpapers] CACHE=$CACHE" >&2
        echo "[qs-wallpapers] SIZE=$SIZE" >&2
        echo "[qs-wallpapers] IMAGES_COUNT=''${#IMAGES[@]}" >&2
        echo "[qs-wallpapers] QML_BIN=$QML_BIN" >&2
        echo "[qs-wallpapers] QML_FILE=$qml" >&2
        echo "[qs-wallpapers] QML_IMPORT_PATH=$QML_IMPORT_PATH" >&2
      } || true
      [ -n "''${QS_PERF:-}" ] && echo "[perf] pre_qml_ms=$(( $(now_ms) - t2 ))" >&2
      exec "$QML_BIN" "$qml"
    fi

    # Run QML runtime and capture selection from console
    [ -n "''${QS_PERF:-}" ] && echo "[perf] pre_qml_ms=$(( $(now_ms) - t2 ))" >&2
    sel=$({ "$QML_BIN" "$qml" 2>&1 || true; } | ${pkgs.gawk}/bin/awk -F'SELECT:' '/SELECT:/{print $2}' | ${pkgs.coreutils}/bin/tail -n1)

    if [ -n "''${sel:-}" ]; then
      printf "%s\n" "$sel"
    fi
''
