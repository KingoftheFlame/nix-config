{pkgs}:
pkgs.writeShellScriptBin "qs-vid-wallpapers" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Configurable defaults via env
    DIR="''${WALL_DIR:-$HOME/Pictures/Wallpapers}"
    CACHE="''${VID_WALL_CACHE_DIR:-$HOME/.cache/vidthumbs}"
    SIZE="''${VID_WALL_THUMB_SIZE:-200}"

    usage() {
      cat <<EOF
  Usage: qs-vid-wallpapers [options]

  Options:
    -d DIR   Video wallpapers directory (default: $HOME/Pictures/Wallpapers)
    -t DIR   Thumbnail cache directory (default: $HOME/.cache/vidthumbs)
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
      echo "Video wallpapers directory not found: $DIR" >&2
      DIR_MISSING=1
    else
      DIR_MISSING=0
    fi

    mkdir -p "$CACHE"

    # Perf timing helpers
    now_ms() { ${pkgs.coreutils}/bin/date +%s%3N; }
    if [ -n "''${QS_PERF:-}" ]; then t0=$(now_ms); fi

    # Collect videos deterministically
    mapfile -t VIDEOS < <( { ${pkgs.findutils}/bin/find -L "$DIR" \
        \( -type f -o -xtype f \) \
        \( -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.mp4v' -o \
           -iname '*.mov' -o -iname '*.webm' -o -iname '*.avi' -o \
           -iname '*.mkv' -o -iname '*.mpeg' -o -iname '*.mpg' -o \
           -iname '*.wmv' -o -iname '*.avchd' -o -iname '*.flv' -o \
           -iname '*.ogv' -o -iname '*.m2ts' -o -iname '*.ts' -o \
           -iname '*.3gp' -o -iname '*.avif' -o -iname '*.AVIF' \) \
        -print0 2>/dev/null || true; } \
      | ${pkgs.coreutils}/bin/tr '\0' '\n' | ${pkgs.coreutils}/bin/sort -f )
    if [ -n "''${QS_PERF:-}" ]; then t1=$(now_ms); echo "[perf] find_ms=$((t1 - t0))" >&2; fi

    if [ "''${#VIDEOS[@]}" -eq 0 ]; then
      if [ -n "''${QS_DEBUG:-}" ]; then
        echo "[qs-vid-wallpapers] No videos found in $DIR (followed symlinks); launching empty UI" >&2
      fi
      EMPTY=1
    else
      EMPTY=0
    fi

    tmpdir=$(${pkgs.coreutils}/bin/mktemp -d)
    json="$tmpdir/walls.json"
    qml="$tmpdir/walls.qml"

    # Build JSON with path, name (no ext), and thumb path; ensure thumb exists
    printf "[" > "$json"
    first=1
    for vid in "''${VIDEOS[@]}"; do
      hash=$(${pkgs.coreutils}/bin/printf "%s" "$vid" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d" " -f1)
      thumb="$CACHE/$hash.png"
      if [ ! -f "$thumb" ]; then
        # Use ffmpegthumbnailer for speed; tolerate errors
        ${pkgs.ffmpegthumbnailer}/bin/ffmpegthumbnailer -i "$vid" -o "$thumb" -s "$SIZE" -q 8 2>/dev/null || true
        # Some formats like AVIF (animated) may fail; fallback to ffmpeg if available
        if [ ! -f "$thumb" ]; then
          ${pkgs.ffmpeg}/bin/ffmpeg -y -v error -i "$vid" -frames:v 1 -vf "scale='min(iw,$SIZE)':-1:force_original_aspect_ratio=decrease,pad=$SIZE:$SIZE:(ow-iw)/2:(oh-ih)/2" "$thumb" 2>/dev/null || true
        fi
      fi
      base=$(${pkgs.coreutils}/bin/basename "$vid")
      name="''${base%.*}"
      if [ $first -eq 0 ]; then printf "," >> "$json"; fi
      first=0
      printf "{\"path\":\"%s\",\"name\":\"%s\",\"thumb\":\"%s\"}" \
        "$(${pkgs.coreutils}/bin/printf "%s" "$vid" | ${pkgs.gnused}/bin/sed 's/\\/\\\\/g;s/"/\\"/g')" \
        "$(${pkgs.coreutils}/bin/printf "%s" "$name" | ${pkgs.gnused}/bin/sed 's/\\/\\\\/g;s/"/\\"/g')" \
        "$(${pkgs.coreutils}/bin/printf "%s" "$thumb" | ${pkgs.gnused}/bin/sed 's/\\/\\\\/g;s/"/\\"/g')" \
        >> "$json"
    done
    printf "]" >> "$json"
    if [ -n "''${QS_PERF:-}" ]; then t2=$(now_ms); echo "[perf] json_ms=$((t2 - t1))" >&2; fi

    # Functions to detect/kill video-only mpvpaper instances robustly (order-independent)
    video_mpv_active() {
      ${pkgs.procps}/bin/pgrep -f -a mpvpaper | ${pkgs.gawk}/bin/awk 'BEGIN{IGNORECASE=1}
        {
          for (i = 2; i <= NF; i++) {
            t = $i
            if (t == "-o") { i++; continue }
            if (t ~ /\.(mp4|m4v|mp4v|mov|webm|avi|mkv|mpeg|mpg|wmv|avchd|flv|ogv|m2ts|ts|3gp)$/) { found=1; exit }
          }
        }
        END { exit found?0:1 }' >/dev/null 2>&1
    }

    kill_video_mpv() {
      pids=$(${pkgs.procps}/bin/pgrep -f -a mpvpaper | ${pkgs.gawk}/bin/awk 'BEGIN{IGNORECASE=1}
        {
          pid=$1
          for (i = 2; i <= NF; i++) {
            t = $i
            if (t == "-o") { i++; continue }
            if (t ~ /\.(mp4|m4v|mp4v|mov|webm|avi|mkv|mpeg|mpg|wmv|avchd|flv|ogv|m2ts|ts|3gp)$/) { print pid; break }
          }
        }' | ${pkgs.coreutils}/bin/tr '\n' ' ')
      if [ -n "''${pids:-}" ]; then
        # shellcheck disable=SC2086
        ${pkgs.coreutils}/bin/kill $pids >/dev/null 2>&1 || true
      fi
    }

    # Optional: shell-only mode for perf (skip QML)
    if [ "''${1:-}" = "--shell-only" ] || [ -n "''${QS_SHELL_ONLY:-}" ]; then
      [ -n "''${QS_PERF:-}" ] && echo "[perf] shell_only=1 total_ms=$((t2 - t0))" >&2
      exit 0
    fi

    # Derive QML flags from env
    PERF_BOOL=false; [ -n "''${QS_PERF:-}" ] && PERF_BOOL=true
    AUTO_QUIT_BOOL=false; [ -n "''${QS_AUTO_QUIT:-}" ] && AUTO_QUIT_BOOL=true
    NOIM_BOOL=false; [ "''${EMPTY:-0}" -eq 1 ] && NOIM_BOOL=true
    NODIR_BOOL=false; [ "''${DIR_MISSING:-0}" -eq 1 ] && NODIR_BOOL=true

    # QML UI builder (recompute status each time)
    write_qml() {
      if video_mpv_active; then MPV_ACTIVE_BOOL=true; else MPV_ACTIVE_BOOL=false; fi
      cat > "$qml" <<QML
  import QtQuick 2.15
  import QtQuick.Window 2.15
  import Qt5Compat.GraphicalEffects

  Window {
    id: win
    visible: true
    width: 1200
    height: 800
    title: "Video Wallpapers"
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
    property int cw: thumbSize + (cellPadding * 2)
    property int hpad: Math.floor(((width - 24) - Math.floor((width - 24) / cw) * cw) / 2)
    property string searchQuery: ""
    property bool mpvActive: ''${MPV_ACTIVE_BOOL}
    property bool disableAudio: true

    property var imagesData: $(cat "$json");

    function filterImages(q) {
      if (!q || q.trim() === "") return imagesData;
      const s = q.toLowerCase();
      return imagesData.filter(it =>
        (it.name && it.name.toLowerCase().indexOf(s) !== -1) ||
        (it.path && it.path.toLowerCase().indexOf(s) !== -1)
      );
    }

    ListModel { id: imagesModel }

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
    }

    Component.onCompleted: {
      qStart = Date.now();
      if (perfEnabled) console.log("[perf] q0_window_created");
      if (perfEnabled) console.log("[perf] q1_inline_data");
      populateModel(imagesData);
    }

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

      // Header with status and action
      Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        height: 44
        radius: 10
        color: "#BB000000"
        border.width: 1
        border.color: "#66ccff"

        Row {
          id: headerRow
          anchors.fill: parent
          anchors.margins: 10
          spacing: 12

          Rectangle {
            id: statusDot
            width: 12
            height: 12
            radius: 6
            color: mpvActive ? "#22c55e" : "#ef4444"
            anchors.verticalCenter: parent.verticalCenter
          }

          // Status badge with stronger highlight for ACTIVE
          Rectangle {
            id: statusBadge
            radius: 9
            height: parent.height - 8
            width: statusText.implicitWidth + 24
            antialiasing: true
            smooth: true
            border.width: 1
            border.color: mpvActive ? "#66dd88" : "#dd6666"
            gradient: Gradient {
              GradientStop { position: 0.0; color: mpvActive ? "#66bbff66" : "#66ff6666" }
              GradientStop { position: 1.0; color: mpvActive ? "#3388cc44" : "#33884444" }
            }
            Text {
              id: statusText
              anchors.centerIn: parent
              text: mpvActive ? "MPVPaper: ACTIVE" : "MPVPaper: INACTIVE"
              color: mpvActive ? "#ffffff" : "#ffeeeeee"
              font.pixelSize: 14
              font.bold: true
            }
          }

          Item { width: 12; height: 1 }

          // Audio toggle (Disable sound)
          Rectangle {
            id: audioToggle
            radius: 9
            border.width: 1
            border.color: "#8888ff"
            height: parent.height - 8
            width: toggleText.implicitWidth + 36
            antialiasing: true
            smooth: true
            gradient: Gradient {
              GradientStop { position: 0.0; color: "#3344aadd" }
              GradientStop { position: 1.0; color: "#223366aa" }
            }
            Row {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: 10
              spacing: 8
              Rectangle {
                id: chk
                width: 14; height: 14; radius: 3
                border.width: 1
                border.color: "#cccccc"
                color: disableAudio ? "#22c55e" : "#ef4444"
              }
              Text {
                id: toggleText
                text: "Disable sound"
                color: "white"
                font.pixelSize: 13
                font.bold: true
              }
            }
            MouseArea {
              anchors.fill: parent
              onClicked: disableAudio = !disableAudio
            }
          }

          Item { width: 12; height: 1 }

          Rectangle {
            id: killBtn
            visible: mpvActive
            radius: 9
            border.width: 1
            border.color: "#ff7777"
            height: parent.height - 8
            width: killText.implicitWidth + 28
            antialiasing: true
            smooth: true
            gradient: Gradient {
              GradientStop { position: 0.0; color: "#ccff6666" }
              GradientStop { position: 1.0; color: "#66aa0000" }
            }

            Text {
              id: killText
              anchors.centerIn: parent
              text: "Stop Video Wallpaper"
              color: "white"
              font.pixelSize: 13
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              onClicked: { console.log("ACTION:KILL_MPV_VID"); Qt.quit(); }
            }
          }

          Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 0; height: 1; }

          // Spacer (fixed width). Remove Layout.fillWidth to avoid QtQuick.Layouts dependency
          Item { id: spacer; width: 1; height: 1 }
        }
      }

      // Search bar (rounded)
      Rectangle {
        id: searchBar
        anchors.top: header.bottom
        anchors.margins: 12
        width: parent.width / 3
        anchors.horizontalCenter: parent.horizontalCenter
        height: 40
        radius: 10
        color: "#88000000"
        border.width: 1
        border.color: "#66ccff"
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

      // Empty-state overlay when no files are found
      Item {
        id: emptyOverlay
        anchors.fill: parent
        visible: noImages
        Column {
          anchors.centerIn: parent
          spacing: 8
          Text { text: dirMissing ? "Directory not found" : "No videos found"; color: "white"; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter }
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
                onClicked: { parent.border.width = 2; console.log("SELECT:" + path); console.log("AUDIO:" + (win.disableAudio ? "OFF" : "ON")); Qt.quit(); }
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
    }

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
        echo "[qs-vid-wallpapers] DIR=$DIR" >&2
        echo "[qs-vid-wallpapers] CACHE=$CACHE" >&2
        echo "[qs-vid-wallpapers] SIZE=$SIZE" >&2
        echo "[qs-vid-wallpapers] VIDEOS_COUNT=''${#VIDEOS[@]}" >&2
        echo "[qs-vid-wallpapers] QML_BIN=$QML_BIN" >&2
        echo "[qs-vid-wallpapers] QML_FILE=$qml" >&2
        echo "[qs-vid-wallpapers] QML_IMPORT_PATH=$QML_IMPORT_PATH" >&2
      } || true
      [ -n "''${QS_PERF:-}" ] && echo "[perf] pre_qml_ms=$(( $(now_ms) - t2 ))" >&2
      write_qml
      exec "$QML_BIN" "$qml"
    fi

    # Run QML runtime and capture selection or action from console
    [ -n "''${QS_PERF:-}" ] && echo "[perf] pre_qml_ms=$(( $(now_ms) - t2 ))" >&2

    while :; do
      write_qml
      out=$({ "$QML_BIN" "$qml" 2>&1 || true; })
      action=$(printf "%s\n" "$out" | ${pkgs.gawk}/bin/awk -F'ACTION:' '/ACTION:/{print $2}' | ${pkgs.coreutils}/bin/tail -n1)
      sel=$(printf "%s\n" "$out" | ${pkgs.gawk}/bin/awk -F'SELECT:' '/SELECT:/{print $2}' | ${pkgs.coreutils}/bin/tail -n1)

      if [ "''${action:-}" = "KILL_MPV_VID" ]; then
        kill_video_mpv
        # wait briefly for processes to terminate to avoid stale status
        for i in $(${pkgs.coreutils}/bin/seq 1 10); do
          if ! video_mpv_active; then break; fi
          ${pkgs.coreutils}/bin/sleep 0.05
        done
        # loop to rebuild QML with updated status and continue showing UI
        continue
      fi

      if [ -n "''${sel:-}" ]; then
        printf "%s\n" "$sel"
        break
      fi

      # No action, no selection: exit loop
      break
    done
''
