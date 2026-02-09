{pkgs}:
pkgs.writeShellScriptBin "qs-docs" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Configurable defaults via env
    CATEGORY="''${DOCS_CATEGORY:-AI}"
    LANGUAGE="''${DOCS_LANGUAGE:-en}"

    usage() {
      cat <<EOF
  Usage: qs-docs [options]

  Options:
    -c CATEGORY   Category to display (AI|Hyprpanel|Zed|ddubsos) (default: AI)
    -l LANGUAGE   Language (en|es) (default: en)
    -h            Show this help
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

    while getopts ":c:l:h" opt; do
      case "$opt" in
        c) CATEGORY="$OPTARG" ;;
        l) LANGUAGE="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "Missing argument for -$OPTARG" >&2; exit 2 ;;
        \\?) echo "Unknown option -$OPTARG" >&2; usage; exit 2 ;;
      esac
    done

    # Validate category (dynamically check if directory exists or is "root")
    if [[ "$CATEGORY" != "root" && ! -d "$HOME/ddubsos/docs/$CATEGORY" ]]; then
      echo "Error: Category directory '$CATEGORY' not found in docs/" >&2
      echo "Available categories:" >&2
      echo "  root" >&2
      ls -1 "$HOME/ddubsos/docs/" | grep -E '^[a-zA-Z]' | head -10 >&2
      exit 1
    fi

    # Validate language
    if [[ "$LANGUAGE" != "en" && "$LANGUAGE" != "es" ]]; then
      echo "Error: Invalid language '$LANGUAGE'. Use 'en' or 'es'" >&2
      exit 1
    fi

    # Perf timing helpers
    now_ms() { ${pkgs.coreutils}/bin/date +%s%3N; }
    if [ -n "''${QS_PERF:-}" ]; then t0=$(now_ms); fi

    tmpdir=$(${pkgs.coreutils}/bin/mktemp -d)
    files_json="$tmpdir/files.json"
    categories_json="$tmpdir/categories.json"
    qml="$tmpdir/docs.qml"

    # Helper: convert all markdown to HTML for better rendering fidelity
    convert_markdown_sets() {
      # Simple on-disk cache to speed up launches
      CACHE_ROOT="''${XDG_CACHE_HOME:-$HOME/.cache}/qs-html/docs"

      # Iterate all generated files_*.json manifests
      for json in "$tmpdir"/files_*.json; do
        [ -f "$json" ] || continue
        name=$(basename "$json")
        # files_<category>_<lang>.json
        category="''${name#files_}"
        category="''${category%_*}"
        language="''${name##*_}"
        language="''${language%.json}"
        outdir="$tmpdir/html/$category/$language"
        cachedir="$CACHE_ROOT/$category/$language"
        ${pkgs.coreutils}/bin/mkdir -p "$outdir" "$cachedir"
        # Extract paths from JSON
        while IFS= read -r src; do
          [ -n "$src" ] || continue
          base="$(basename "$src")"
          base_noext="''${base%.*}"
          out="$outdir/''${base_noext}.html"
          cache="$cachedir/''${base_noext}.html"

          # If cache is newer than source, reuse it
          if [ -f "$cache" ] && [ "$cache" -nt "$src" ]; then
            ${pkgs.coreutils}/bin/cp -f "$cache" "$out"
            continue
          fi

          # Convert with pandoc (GitHub-Flavored Markdown) to a temp file, then update cache and out
          tmp_html="$out.tmp"
          if ${pkgs.pandoc}/bin/pandoc -f gfm -t html5 --wrap=none "$src" -o "$tmp_html" 2>/dev/null; then
            ${pkgs.coreutils}/bin/cp -f "$tmp_html" "$out"
            ${pkgs.coreutils}/bin/cp -f "$tmp_html" "$cache"
            ${pkgs.coreutils}/bin/rm -f "$tmp_html"
          else
            # Fallback: escape and wrap in <pre>
            esc=$(<"$src" ${pkgs.gnused}/bin/sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
            printf '<pre style=\"white-space:pre-wrap;\">%s</pre>' \"$esc\" | ${pkgs.coreutils}/bin/tee \"$out\" > \"$cache\" >/dev/null
          fi
        done < <(${pkgs.jq}/bin/jq -r '.[] | .path // empty' "$json" 2>/dev/null)
      done
    }

    # Generate data
    if [ -n "''${QS_PERF:-}" ]; then t1=$(now_ms); fi
    ${pkgs.callPackage ./docs-parser.nix {}}/bin/docs-parser files "$CATEGORY" "$LANGUAGE" > "$files_json"
    ${pkgs.callPackage ./docs-parser.nix {}}/bin/docs-parser categories > "$categories_json"

    # Generate files for all categories and languages for switching
    # First generate root directory files
    for lang in en es; do
      ${pkgs.callPackage ./docs-parser.nix {}}/bin/docs-parser files "root" "$lang" > "$tmpdir/files_root_''${lang}.json" 2>/dev/null || echo '[]' > "$tmpdir/files_root_''${lang}.json"
    done

    # Then dynamically discover all category directories
    if [ -d "$HOME/ddubsos/docs" ]; then
      for category_dir in "$HOME/ddubsos/docs"/*/; do
        if [ -d "$category_dir" ]; then
          category=$(basename "$category_dir")
          for lang in en es; do
            ${pkgs.callPackage ./docs-parser.nix {}}/bin/docs-parser files "$category" "$lang" > "$tmpdir/files_''${category}_''${lang}.json" 2>/dev/null || echo '[]' > "$tmpdir/files_''${category}_''${lang}.json"
          done
        fi
      done
    fi

    # Convert all discovered Markdown files to HTML for RichText rendering
    convert_markdown_sets

    if [ -n "''${QS_PERF:-}" ]; then t2=$(now_ms); echo "[perf] json_ms=$((t2 - t1))" >&2; fi

    # Optional: shell-only mode for perf (skip QML)
    if [ -n "''${QS_SHELL_ONLY:-}" ]; then
      if [ -n "''${QS_PERF:-}" ]; then echo "[perf] shell_only=1 total_ms=$((t2 - t0))" >&2; fi
      exit 0
    fi

    # Derive QML flags from env
    PERF_BOOL=false; [ -n "''${QS_PERF:-}" ] && PERF_BOOL=true
    AUTO_QUIT_BOOL=false; [ -n "''${QS_AUTO_QUIT:-}" ] && AUTO_QUIT_BOOL=true

    # Create QML interface
    cat > "$qml" <<QML_TEMPLATE
  import QtQuick 2.15
  import QtQuick.Window 2.15
  import QtQuick.Controls 2.15

  Window {
    id: win
    visible: true
    width: 1280
    height: 1000
    title: "Documentation Viewer"
    flags: Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"

    property bool perfEnabled: $PERF_BOOL
    property bool autoQuit: $AUTO_QUIT_BOOL
    property double qStart: 0

    // Current state
    property string selectedCategory: "$CATEGORY"
    property string selectedLanguage: "$LANGUAGE"
    property string selectedFile: ""
    property string fileContent: ""
    property string htmlContent: ""
    property string displayedContent: ""
    property string searchQuery: ""

    // Search state
    property int searchCount: 0
    property int currentMatchIndex: 0
    property var matchPositions: [] // array of [start,end] in plain text indices

    // Data
    property var docsFiles: []
    property bool filesLoaded: false
    property var availableCategories: []

    // List models
    ListModel { id: filesModel }
    ListModel { id: matchesModel }

    // File paths
    property string filesJsonPath: "$files_json"
    property string categoriesJsonPath: "$categories_json"
    property string tmpDir: "$tmpdir"

    // Load files for current category and language
    function loadDocsFiles() {
      console.log("Loading files for:", selectedCategory, selectedLanguage);

      var fileName = "files_" + selectedCategory + "_" + selectedLanguage + ".json";
      var filePath = tmpDir + "/" + fileName;

      const xhr = new XMLHttpRequest();
      xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
          if (xhr.status === 200 || xhr.status === 0) {
            try {
              const result = JSON.parse(xhr.responseText);
              console.log("Files loaded:", result.length, "files");
              win.docsFiles = result;
              win.filesLoaded = true;

              // Populate the ListModel
              filesModel.clear();
              for (var i = 0; i < result.length; i++) {
                var file = result[i];
                console.log("Adding file:", file.filename, "clean_name:", file.clean_name);
                filesModel.append({
                  filename: file.filename || "",
                  clean_name: file.clean_name || "",
                  title: file.title || "",
                  category: file.category || "",
                  language: file.language || "",
                  path: file.path || ""
                });
              }

              if (result.length > 0 && (!win.selectedFile || win.selectedFile === "")) {
                win.selectedFile = result[0].filename;
                win.loadFileContent(result[0].filename);
              }
            } catch (e) {
              console.error("Failed to parse files JSON:", e);
              console.log("Response text:", xhr.responseText);
              win.docsFiles = [];
              win.filesLoaded = true;
              // Clear the model on parse error
              filesModel.clear();
            }
          } else {
            console.error("Failed to load files, status:", xhr.status);
            console.log("File path:", filePath);
            win.docsFiles = [];
            win.filesLoaded = true;
            filesModel.clear();
          }
        }
      };
      xhr.open("GET", "file://" + filePath);
      xhr.send();
    }

    // Load content of specific file
    function loadFileContent(filename) {
      console.log("Loading content for:", filename);

      // Handle root directory files
      var filePath;
      if (selectedCategory === "root") {
        filePath = "/home/dwilliams/ddubsos/docs/" + filename;
      } else {
        filePath = "/home/dwilliams/ddubsos/docs/" + selectedCategory + "/" + filename;
      }

      const xhr = new XMLHttpRequest();
      xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
          if (xhr.status === 200 || xhr.status === 0) {
            win.fileContent = xhr.responseText;
            win.selectedFile = filename;

            // Also load pre-converted HTML for better rendering
            var base = filename.replace(/\.[^.]+$/, "");
            var htmlPath = win.tmpDir + "/html/" + win.selectedCategory + "/" + win.selectedLanguage + "/" + base + ".html";
            const xhr2 = new XMLHttpRequest();
            xhr2.onreadystatechange = function() {
              if (xhr2.readyState === XMLHttpRequest.DONE) {
                if (xhr2.status === 200 || xhr2.status === 0) {
                  win.htmlContent = xhr2.responseText;
                } else {
                  win.htmlContent = "";
                }
                win.updateSearch(); // recompute matches and content after html load
              }
            };
            xhr2.open("GET", "file://" + htmlPath);
            xhr2.send();
          } else {
            win.fileContent = "Error loading file: " + filename;
            win.htmlContent = "";
            win.displayedContent = "Error loading file: " + filename;
            win.matchPositions = [];
            win.searchCount = 0;
            win.currentMatchIndex = 0;
          }
        }
      };
      xhr.open("GET", "file://" + filePath);
      xhr.send();
    }

    // Load available categories
    function loadCategories() {
      const xhr = new XMLHttpRequest();
      xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
          if (xhr.status === 200 || xhr.status === 0) {
            try {
              const result = JSON.parse(xhr.responseText);
              win.availableCategories = result;
            } catch (e) {
              console.error("Failed to parse categories JSON:", e);
              win.availableCategories = ["AI", "Hyprpanel", "Zed", "ddubsos"];
            }
          }
        }
      };
      xhr.open("GET", "file://" + categoriesJsonPath);
      xhr.send();
    }

    // Switch category
    function switchCategory(newCategory) {
      selectedCategory = newCategory;
      selectedFile = "";
      fileContent = "";
      loadDocsFiles();
    }

    // Switch language
    function switchLanguage(newLanguage) {
      selectedLanguage = newLanguage;
      selectedFile = "";
      fileContent = "";
      loadDocsFiles();
    }

    // Escape HTML for safe RichText rendering
    function escapeHtml(s) {
      return s
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/\"/g, "&quot;")
        .replace(/'/g, "&#39;");
    }


    function rebuildDisplayedContent() {
      if (!fileContent || fileContent.length === 0) {
        displayedContent = "";
        return;
      }
      // Prefer pre-converted HTML if available; fallback to escaped pre
      if (htmlContent && htmlContent.length > 0) {
        displayedContent = htmlContent;
      } else {
        displayedContent = "<pre style=\"white-space:pre-wrap;\">" + escapeHtml(fileContent) + "</pre>";
      }
    }

    // Update search matches and rebuild content
    function updateSearch() {
      matchPositions = [];
      searchCount = 0;
      currentMatchIndex = 0;

      // Clear matches list by default
      matchesModel.clear();

      if (!fileContent || !searchQuery || searchQuery.trim() === "") {
        rebuildDisplayedContent();
        return;
      }
      var needle = String(searchQuery).toLowerCase();
      if (needle.length === 0) {
        rebuildDisplayedContent();
        return;
      }
      var hay = String(fileContent).toLowerCase();
      var idx = 0;
      while (true) {
        var pos = hay.indexOf(needle, idx);
        if (pos === -1) break;
        matchPositions.push([pos, pos + needle.length]);
        idx = pos + needle.length;
      }

      searchCount = matchPositions.length;

      // Build matches list with context snippets
      for (var j = 0; j < matchPositions.length; j++) {
        var s = matchPositions[j][0];
        var e = matchPositions[j][1];
        var ctxStart = Math.max(0, s - 80);
        var ctxEnd = Math.min(fileContent.length, e + 80);
        var snippet = fileContent.slice(ctxStart, ctxEnd).replace(/\n/g, " ");
        matchesModel.append({ idx: j, start: s, snippet: snippet });
      }

      currentMatchIndex = (searchCount > 0) ? 0 : 0;
      rebuildDisplayedContent();
    }

    function scrollToApproximatePosition(pos) {
      var flick = contentScroll && contentScroll.contentItem ? contentScroll.contentItem : null;
      if (!flick || !fileContent || fileContent.length === 0) return;
      var ratio = Math.max(0, Math.min(1, pos / fileContent.length));
      var maxY = Math.max(0, flick.contentHeight - contentScroll.height);
      flick.contentY = ratio * maxY;
    }

    function jumpToMatch(index) {
      if (searchCount <= 0) return;
      var clamped = Math.max(0, Math.min(searchCount - 1, index));
      currentMatchIndex = clamped;
      var start = matchPositions[currentMatchIndex][0];
      scrollToApproximatePosition(start);
      if (typeof matchesList !== 'undefined' && matchesList) {
        matchesList.positionViewAtIndex(currentMatchIndex, ListView.Center);
      }
    }

    function gotoNextMatch() {
      if (searchCount <= 0) return;
      var next = (currentMatchIndex + 1) % searchCount;
      jumpToMatch(next);
    }

    function gotoPrevMatch() {
      if (searchCount <= 0) return;
      var prev = (currentMatchIndex - 1 + searchCount) % searchCount;
      jumpToMatch(prev);
    }

    Component.onCompleted: {
      qStart = Date.now();
      if (perfEnabled) console.log("[perf] q0_window_created");
      loadCategories();
      loadDocsFiles();
      updateSearch();
    }

    // App-wide shortcuts
    Shortcut {
      sequences: [ "Escape" ]
      context: Qt.ApplicationShortcut
      onActivated: Qt.quit()
    }

    Shortcut {
      sequences: [ "N", "Right" ]
      context: Qt.ApplicationShortcut
      onActivated: win.gotoNextMatch()
    }

    Shortcut {
      sequences: [ "P", "Left" ]
      context: Qt.ApplicationShortcut
      onActivated: win.gotoPrevMatch()
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

      Row {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Left sidebar
        Rectangle {
          id: sidebar
          width: 400
          height: parent.height
          radius: 8
          color: "#BB111111"
          border.width: 1
          border.color: "#444444"

          Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Category buttons
            Text {
              text: "Categories"
              color: "#66ccff"
              font.pixelSize: 16
              font.bold: true
            }

            Flow {
              width: parent.width
              spacing: 6

              Repeater {
                model: availableCategories

                Button {
                  property string categoryName: modelData || ""
                  text: categoryName.charAt(0).toUpperCase() + categoryName.slice(1)
                  width: Math.max(80, text.length * 8 + 16)
                  height: 32
                  background: Rectangle {
                    color: win.selectedCategory === categoryName ? "#66ccff" : "#333333"
                    radius: 6
                    border.width: 1
                    border.color: "#555555"
                  }
                  contentItem: Text {
                    text: parent.text
                    color: win.selectedCategory === categoryName ? "#000000" : "#cccccc"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }
                  onClicked: {
                    win.switchCategory(categoryName);
                  }
                }
              }
            }

            // Language toggle
            Row {
              spacing: 8

              Text {
                text: "Language:"
                color: "#cccccc"
                anchors.verticalCenter: parent.verticalCenter
              }

              Button {
                text: "EN"
                width: 40
                height: 28
                background: Rectangle {
                  color: win.selectedLanguage === "en" ? "#66ccff" : "#333333"
                  radius: 4
                  border.width: 1
                  border.color: "#555555"
                }
                contentItem: Text {
                  text: parent.text
                  color: win.selectedLanguage === "en" ? "#000000" : "#cccccc"
                  font.pixelSize: 11
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
                onClicked: win.switchLanguage("en")
              }

              Button {
                text: "ES"
                width: 40
                height: 28
                background: Rectangle {
                  color: win.selectedLanguage === "es" ? "#66ccff" : "#333333"
                  radius: 4
                  border.width: 1
                  border.color: "#555555"
                }
                contentItem: Text {
                  text: parent.text
                  color: win.selectedLanguage === "es" ? "#000000" : "#cccccc"
                  font.pixelSize: 11
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
                onClicked: win.switchLanguage("es")
              }
            }

            // File list
            Text {
              text: "Files"
              color: "#66ccff"
              font.pixelSize: 14
              font.bold: true
            }

            ScrollView {
              width: parent.width
              height: parent.height - 160
              clip: true

              ListView {
                id: filesList
                model: filesModel
                spacing: 4

                delegate: Rectangle {
                  property string fileName: model.filename || ""
                  property string cleanName: model.clean_name || fileName
                  property string fileTitle: model.title || ""

                  width: filesList.width - 20
                  height: 40
                  radius: 6
                  color: win.selectedFile === fileName ? "#66ccff" : "transparent"
                  border.width: 1
                  border.color: win.selectedFile === fileName ? "#66ccff" : "#333333"

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.border.color = "#66ccff"
                    onExited: parent.border.color = win.selectedFile === fileName ? "#66ccff" : "#333333"
                    onClicked: {
                      if (fileName) {
                        win.loadFileContent(fileName);
                      }
                    }
                  }

                  Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Text {
                      text: cleanName || fileName || "Unknown file"
                      color: win.selectedFile === fileName ? "#000000" : "#ffffff"
                      font.pixelSize: 13
                      font.bold: true
                      width: parent.width
                      elide: Text.ElideRight
                    }

                    Text {
                      text: fileTitle || ""
                      color: win.selectedFile === fileName ? "#333333" : "#cccccc"
                      font.pixelSize: 10
                      width: parent.width
                      elide: Text.ElideRight
                      visible: text !== ""
                    }
                  }
                }
              }
            }
          }
        }

        // Main content area
        Rectangle {
          id: contentArea
          width: parent.width - sidebar.width - 16
          height: parent.height
          radius: 8
          color: "#BB111111"
          border.width: 1
          border.color: "#444444"

          Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Search bar
            Rectangle {
              width: parent.width
              height: 36
              radius: 6
              border.width: 1
              border.color: "#66ccff"
              color: "#BB000000"

              Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Rectangle {
                  width: parent.width - 220
                  height: parent.height
                  color: "transparent"

                  TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 4
                    color: "white"
                    font.pixelSize: 14
                    onTextChanged: {
                      win.searchQuery = text;
                      win.updateSearch();
                    }
                    Keys.onPressed: (ev) => {
                      if (ev.key === Qt.Key_N || ev.key === Qt.Key_Right) { win.gotoNextMatch(); ev.accepted = true; }
                      else if (ev.key === Qt.Key_P || ev.key === Qt.Key_Left) { win.gotoPrevMatch(); ev.accepted = true; }
                    }
                  }

                  Text {
                    text: "Search in file..."
                    color: "#88ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    visible: searchInput.text.length === 0
                  }
                }

                Text {
                  text: (win.searchCount > 0 ? "[" + (win.currentMatchIndex + 1) + "/" + win.searchCount + "]" : "[0/0]")
                  color: win.searchCount > 0 ? "#00e676" : "#ff5252"
                  font.pixelSize: 14
                  verticalAlignment: Text.AlignVCenter
                }

                Item {
                  width: 5
                  height: 1
                }

                Button {
                  text: "Prev"
                  width: 60
                  height: parent.height - 4
                  onClicked: win.gotoPrevMatch()
                  enabled: win.searchCount > 0
                  background: Rectangle {
                    color: parent.enabled ? "#333333" : "#222222"
                    radius: 4
                    border.width: 1
                    border.color: "#555555"
                  }
                  contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#ffffff" : "#888888"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }
                }
                Button {
                  text: "Next"
                  width: 60
                  height: parent.height - 4
                  onClicked: win.gotoNextMatch()
                  enabled: win.searchCount > 0
                  background: Rectangle {
                    color: parent.enabled ? "#333333" : "#222222"
                    radius: 4
                    border.width: 1
                    border.color: "#555555"
                  }
                  contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#ffffff" : "#888888"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }
                }

                CheckBox {
                  id: matchesToggle
                  text: "Matches"
                  checked: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            // Content and matches view
            Row {
              id: contentRow
              width: parent.width
              height: parent.height - 48
              spacing: 12

              // Main content
              ScrollView {
                id: contentScroll
                width: matchesPanel.visible ? parent.width - matchesPanel.width - 12 : parent.width
                height: parent.height
                clip: true

                TextEdit {
                  id: contentDisplay
                  text: win.displayedContent
                  textFormat: TextEdit.RichText
                  color: "#ffffff"
                  font.family: "monospace"
                  font.pixelSize: 13
                  readOnly: true
                  selectByMouse: true
                  wrapMode: TextEdit.Wrap
                  persistentSelection: true
                  Keys.onPressed: (ev) => {
                    if (ev.key === Qt.Key_N || ev.key === Qt.Key_Right) { win.gotoNextMatch(); ev.accepted = true; }
                    else if (ev.key === Qt.Key_P || ev.key === Qt.Key_Left) { win.gotoPrevMatch(); ev.accepted = true; }
                  }
                }
              }

              // Matches panel
              Rectangle {
                id: matchesPanel
                width: visible ? 320 : 0
                height: parent.height
                radius: 6
                color: "#BB000000"
                border.width: 1
                border.color: "#555555"
                visible: win.searchCount > 0 && matchesToggle.checked

                Column {
                  anchors.fill: parent
                  anchors.margins: 8
                  spacing: 8

                  Text {
                    text: "Matches (" + win.searchCount + ")"
                    color: "#66ccff"
                    font.pixelSize: 13
                    font.bold: true
                  }

                  ScrollView {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    clip: true

                    ListView {
                      id: matchesList
                      model: matchesModel
                      spacing: 6
                      delegate: Rectangle {
                        property int matchIndex: model.idx || index
                        property string snippet: model.snippet || ""
                        width: matchesList.width - 12
                        height: Math.min(snippetText.implicitHeight + 16, 100)
                        radius: 6
                        color: win.currentMatchIndex === matchIndex ? "#66ccff" : "transparent"
                        border.width: 1
                        border.color: win.currentMatchIndex === matchIndex ? "#66ccff" : "#333333"

                        MouseArea {
                          anchors.fill: parent
                          onClicked: win.jumpToMatch(matchIndex)
                        }

                        Column {
                          anchors.fill: parent
                          anchors.margins: 8
                          spacing: 4

                          Text {
                            text: "#" + (matchIndex + 1)
                            color: win.currentMatchIndex === matchIndex ? "#000000" : "#bbbbbb"
                            font.pixelSize: 10
                          }
                          Text {
                            id: snippetText
                            text: snippet
                            textFormat: Text.PlainText
                            color: win.currentMatchIndex === matchIndex ? "#000000" : "#dddddd"
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  QML_TEMPLATE

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
        echo "[qs-docs] CATEGORY=$CATEGORY" >&2
        echo "[qs-docs] LANGUAGE=$LANGUAGE" >&2
        echo "[qs-docs] QML_BIN=$QML_BIN" >&2
        echo "[qs-docs] QML_FILE=$qml" >&2
      } || true
      [ -n "''${QS_PERF:-}" ] && echo "[perf] pre_qml_ms=$(( $(now_ms) - t2 ))" >&2
      exec "$QML_BIN" "$qml"
    fi

    # Run QML runtime
    [ -n "''${QS_PERF:-}" ] && echo "[perf] pre_qml_ms=$(( $(now_ms) - t2 ))" >&2
    output=$({ "$QML_BIN" "$qml" 2>&1 || true; })

    # Handle any output if needed
    if [ -n "''${output:-}" ]; then
      echo "$output"
    fi
''
