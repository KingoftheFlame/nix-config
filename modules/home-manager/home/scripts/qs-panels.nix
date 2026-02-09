{pkgs}:
pkgs.writeShellScriptBin "qs-panels" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Detect current active panel/bar (robust matching, no regex metachar)
    active=""
    if pgrep -x hyprpanel >/dev/null 2>&1; then active="hyprpanel"; fi
    if pgrep -x waybar >/dev/null 2>&1; then active="waybar"; fi
    if pgrep -x dms >/dev/null 2>&1 || pgrep -fa dms | grep -q "\bdms\b.*\brun\b"; then active="dms"; fi
  if pgrep -fa quickshell | grep -q "noctalia-shell"; then active="noctalia"; fi

    tmpdir=$(${pkgs.coreutils}/bin/mktemp -d)
    qml="$tmpdir/panels.qml"

    # Style parameters
    WIDTH=440; HEIGHT=220

    cat > "$qml" <<QML
  import QtQuick 2.15
  import QtQuick.Window 2.15
  import Qt5Compat.GraphicalEffects

  Window {
    id: win
    visible: true
    width: $WIDTH
    height: $HEIGHT
    title: "Panels"
    flags: Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"

    property string active: "$active"

    Shortcut { sequences: ["Escape" ]; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 12
      radius: 12
      border.width: 2
      border.color: "#66ccff"
      color: "#DD000000"

      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Text {
          text: "Active: " + (win.active === "" ? "(none)" : win.active)
          color: "white"
          font.pixelSize: 14
          horizontalAlignment: Text.AlignHCenter
          width: parent.width
        }

        Grid {
          id: grid
          columns: 2
          columnSpacing: 10
          rowSpacing: 10
          anchors.horizontalCenter: parent.horizontalCenter

          Repeater {
            model: [
              { key: "noctalia", label: "Noctalia" },
              { key: "dms",      label: "DMS" },
              { key: "waybar",   label: "Waybar" },
              { key: "hyprpanel",label: "Hyprpanel" }
            ]
            delegate: Rectangle {
              width: 180; height: 52
              radius: 10
              border.width: (modelData.key === win.active ? 3 : 1)
              border.color: (modelData.key === win.active ? "#88ff88" : "#66ccff")
              color: "#BB000000"

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.border.width = (modelData.key === win.active ? 3 : 2)
                onExited: parent.border.width = (modelData.key === win.active ? 3 : 1)
                onClicked: { console.log("SELECT:" + modelData.key); Qt.quit(); }
              }

              Text {
                text: modelData.label + (modelData.key === win.active ? " (active)" : "")
                anchors.centerIn: parent
                color: "white"
                font.pixelSize: 16
              }
            }
          }
        }
      }
    }
  }
  QML

    # Prepare QML runtime env (Qt6), mirroring qs-wallpapers style
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

    # Run QML and capture selection from console
  # Capture selection robustly from console output
  sel=$({ "$QML_BIN" "$qml" 2>&1 || true; } \
    | ${pkgs.gnugrep}/bin/grep -o 'SELECT:[A-Za-z0-9_-]*' \
    | ${pkgs.coreutils}/bin/tail -n 1 \
    | ${pkgs.coreutils}/bin/cut -d: -f2 \
    | ${pkgs.coreutils}/bin/tr -d '\r' \
    | ${pkgs.gnused}/bin/sed 's/^\s\+//;s/\s\+$//' )

  # Fallback debug: write last log when empty selection
  if [ -z "${sel:-}" ]; then
    mkdir -p "$HOME/.cache"
    { "$QML_BIN" "$qml" 2>&1 || true; } > "$HOME/.cache/qs-panels.lastlog" || true
  fi

  # Resolve runner path explicitly to avoid PATH issues inside QML-launched env
  run_and_exit() {
    local bin
    bin=$(command -v "$1" || true)
    if [ -n "$bin" ]; then
      exec "$bin"
    else
      echo "Error: $1 not found" >&2
      exit 1
    fi
  }

  case "${sel:-}" in
    noctalia) run_and_exit noctalia-run ;;
    dms)      run_and_exit dms-run ;;
    waybar)   run_and_exit waybar-run ;;
    hyprpanel)run_and_exit hyprpanel-run ;;
    *)        exit 0 ;;
  esac
''
