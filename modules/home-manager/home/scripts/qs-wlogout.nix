{
  pkgs,
  inputs ? null,
}: let
  icons = pkgs.runCommand "qs-wlogout-icons" {} ''
    mkdir -p $out
    cp ${./qs-wlogout-icons}/* $out/
  '';
in
  pkgs.writeShellScriptBin "qs-wlogout" ''
      #!/usr/bin/env bash
      set -euo pipefail

      [ -n "''${QS_DEBUG:-}" ] && set -x
      DEBUG="''${QS_DEBUG:-}"
      log() { if [ -n "$DEBUG" ]; then echo "[qs-wlogout] $*" >&2; fi }

      # Configurable defaults via env
      ICONS_DIR="''${QS_WLOGOUT_ICONS_DIR:-$HOME/.local/share/qs-wlogout/icons}"
      QML_DIR="''${QS_WLOGOUT_QML_DIR:-$HOME/.local/share/qs-wlogout}"
      SPANISH="''${QS_WLOGOUT_SPANISH:-0}"

      usage() {
        cat <<EOF
    Usage: qs-wlogout [options]

    Options:
      -i DIR   Icons directory (default: $HOME/.local/share/qs-wlogout/icons)
      -q DIR   QML files directory (default: $HOME/.local/share/qs-wlogout)
      -es      Display text in Spanish (Español)
      -h       Show this help

    Environment variables:
      QS_DEBUG             Enable debug output
      QS_WLOGOUT_ICONS_DIR Override icons directory
      QS_WLOGOUT_QML_DIR   Override QML directory
      QS_WLOGOUT_SPANISH   Set to '1' to use Spanish text
    EOF
      }

      # Handle -es as a special case and filter it out
      temp_args=""
      for arg in "$@"; do
        if [ "$arg" = "-es" ]; then
          SPANISH=1
        else
          temp_args="$temp_args $arg"
        fi
      done

      # Reset positional parameters
      eval "set -- $temp_args"

      while getopts ":i:q:h" opt; do
        case "$opt" in
          i) ICONS_DIR="$OPTARG" ;;
          q) QML_DIR="$OPTARG" ;;
          h) usage; exit 0 ;;
          :) echo "Missing argument for -$OPTARG" >&2; exit 2 ;;
          \?) echo "Unknown option -$OPTARG" >&2; usage; exit 2 ;;
        esac
      done

      # Ensure required directories exist
      mkdir -p "$(dirname "$ICONS_DIR")"
      mkdir -p "$ICONS_DIR"
      mkdir -p "$QML_DIR"

      # Copy icons if they don't exist
      if [ ! -f "$ICONS_DIR/lock.png" ]; then
        log "Copying default icons to $ICONS_DIR"
        cp -r ${icons}/* "$ICONS_DIR/" 2>/dev/null || {
          log "Failed to copy icons from nix store, creating fallback icons"
          # Fallback: create minimal icon set
          for icon in lock logout suspend hibernate shutdown reboot; do
            ${pkgs.imagemagick}/bin/convert -size 64x64 xc:white -fill black -gravity center -pointsize 16 -annotate +0+0 "$icon" "$ICONS_DIR/$icon.png" 2>/dev/null || true
          done
        }
      fi

      # Create temporary QML files
      tmpdir=$(${pkgs.coreutils}/bin/mktemp -d)
      main_qml="$tmpdir/main.qml"

      log "ICONS_DIR=$ICONS_DIR"
      log "QML_DIR=$QML_DIR"
      log "Main QML=$main_qml"

      # No need for separate LogoutButton.qml - using inline data in main.qml

      # Generate main.qml (standard Qt QML application)
      cat > "$tmpdir/main.qml" <<QML_MAIN
    import QtQuick 2.15
    import QtQuick.Window 2.15
    import QtQuick.Layouts 1.15
    import QtQuick.Controls 2.15

    ApplicationWindow {
        id: window
        visible: true
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Dialog
        color: "transparent"

        // Set application properties for Hyprland identification
        title: "qs-wlogout"

        Component.onCompleted: {
            // Focus the window for keyboard input
            window.requestActivate();
        }

        property color backgroundColor: "transparent"  // Make overlay transparent
        property color menuBackgroundColor: "#aa000000"  // Semi-transparent menu background
        property color buttonColor: "#1e1e1e"
        property color buttonHoverColor: "#3700b3"
        property string iconsPath: "$ICONS_DIR"

        // Size window to match menu content only
        width: 520  // Slightly larger than menu to allow for positioning
        height: 320

        // Button definitions with Spanish support
        property bool useSpanish: $SPANISH == "1"

        property var buttons: useSpanish ? [
            { command: "loginctl lock-session", keybind: Qt.Key_L, text: "Bloquear", icon: "lock" },
            { command: "hyprctl dispatch exit", keybind: Qt.Key_E, text: "Cerrar Sesión", icon: "logout" },
            { command: "systemctl suspend", keybind: Qt.Key_U, text: "Suspender", icon: "suspend" },
            { command: "systemctl hibernate", keybind: Qt.Key_H, text: "Hibernar", icon: "hibernate" },
            { command: "systemctl poweroff", keybind: Qt.Key_S, text: "Apagar", icon: "shutdown" },
            { command: "systemctl reboot", keybind: Qt.Key_R, text: "Reiniciar", icon: "reboot" }
        ] : [
            { command: "loginctl lock-session", keybind: Qt.Key_L, text: "Lock", icon: "lock" },
            { command: "hyprctl dispatch exit", keybind: Qt.Key_E, text: "Logout", icon: "logout" },
            { command: "systemctl suspend", keybind: Qt.Key_U, text: "Suspend", icon: "suspend" },
            { command: "systemctl hibernate", keybind: Qt.Key_H, text: "Hibernate", icon: "hibernate" },
            { command: "systemctl poweroff", keybind: Qt.Key_S, text: "Shutdown", icon: "shutdown" },
            { command: "systemctl reboot", keybind: Qt.Key_R, text: "Reboot", icon: "reboot" }
        ]

        function executeCommand(command) {
            console.log("EXEC:" + command);
            Qt.quit();
        }

        // Menu container fills entire window with semi-transparent background
        Rectangle {
            id: menuContainer
            anchors.fill: parent
            anchors.margins: 10  // Small margin for 3D effect
            color: menuBackgroundColor
            radius: 20
            border.width: 1
            border.color: "#33ffffff"
            focus: true

            Keys.onPressed: {
                if (event.key === Qt.Key_Escape) {
                    Qt.quit();
                } else {
                    for (var i = 0; i < window.buttons.length; i++) {
                        if (event.key === window.buttons[i].keybind) {
                            window.executeCommand(window.buttons[i].command);
                            return;
                        }
                    }
                }
            }

            // Click outside buttons to close
            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()

            GridLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    columns: 3
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: window.buttons

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: 100
                            Layout.minimumHeight: 100
                            color: mouseArea.containsMouse ? buttonHoverColor : buttonColor
                            radius: 12
                            border.color: mouseArea.containsMouse ? "#66ffffff" : "#33ffffff"
                            border.width: 1

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: window.executeCommand(modelData.command)
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 12

                                Image {
                                    id: buttonIcon
                                    source: "file://" + window.iconsPath + "/" + modelData.icon + ".png"
                                    width: 48
                                    height: 48
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    fillMode: Image.PreserveAspectFit
                                }

                                Text {
                                    text: modelData.text
                                    font.pointSize: 14
                                    font.bold: true
                                    color: "white"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    QML_MAIN


      # Setup Qt6 environment with proper app identification
      export QT_QPA_PLATFORM="wayland;xcb"
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export QT_PLUGIN_PATH="${pkgs.qt6.qtbase}/lib/qt-6/plugins:${pkgs.qt6.qtwayland}/lib/qt-6/plugins"
      export QML_IMPORT_PATH="${pkgs.qt6.qtbase}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.qt6.qt5compat}/lib/qt-6/qml:${pkgs.qt6.qtsvg}/lib/qt-6/qml"
      export QML2_IMPORT_PATH="$QML_IMPORT_PATH"

      # Set Wayland application ID for proper window identification
      export QT_WAYLAND_APP_ID="qs-wlogout"
      export WAYLAND_APP_ID="qs-wlogout"

      # Find QML binary (using Qt6 QML runtime like other qs-* scripts)
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
        else
          echo "Error: Qt QML runtime not found" >&2
          echo "Make sure Qt6 is installed and qtdeclarative is available" >&2
          exit 1
        fi
      fi

      log "QML_BIN=$QML_BIN"

      # Debug mode: show more info and don't hide output
      if [ -n "''${QS_DEBUG:-}" ]; then
        echo "[qs-wlogout] ICONS_DIR=$ICONS_DIR" >&2
        echo "[qs-wlogout] QML_DIR=$QML_DIR" >&2
        echo "[qs-wlogout] QML_BIN=$QML_BIN" >&2
        echo "[qs-wlogout] Main QML=$main_qml" >&2
        exec "$QML_BIN" "$main_qml"
      fi

      # Run QML application and capture command execution from console output
      out=$({ "$QML_BIN" "$main_qml" 2>&1 || true; })
      exec_cmd=$(printf "%s\n" "$out" | ${pkgs.gawk}/bin/awk -F'EXEC:' '/EXEC:/{print $2}' | ${pkgs.coreutils}/bin/tail -n1)

      if [ -n "''${exec_cmd:-}" ]; then
        log "Executing: $exec_cmd"
        exec ${pkgs.bash}/bin/bash -c "$exec_cmd"
      fi
  ''
