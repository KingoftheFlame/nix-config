{pkgs}:
pkgs.writeShellScriptBin "docs-parser" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Default paths
    DOCS_DIR="$HOME/ddubsos/docs"

    # Handle arguments
    MODE="''${1:-files}"
    CATEGORY="''${2:-AI}"
    LANGUAGE="''${3:-en}"

    usage() {
      cat <<EOF
  Usage: docs-parser [MODE] [CATEGORY] [LANGUAGE]

  MODE: files|content
  CATEGORY: AI|Hyprpanel|Zed|ddubsos|etc.
  LANGUAGE: en|es

  Examples:
    docs-parser files AI en       # List English AI docs files
    docs-parser content AI en     # Get content for all English AI files
  EOF
    }

    # Function to extract clean filename
    get_clean_filename() {
      local filepath="$1"
      local basename=$(basename "$filepath")

      # Remove category prefix (e.g., "AI.")
      basename=$(echo "$basename" | sed 's/^[^.]*\.//')

      # Remove language suffix (.es.md or .md)
      basename=$(echo "$basename" | sed 's/\.es\.md$//' | sed 's/\.md$//')

      # Remove common suffixes
      basename=$(echo "$basename" | sed 's/\.cheatsheet$//' | sed 's/\.top10$//')

      echo "$basename"
    }

    # Function to detect language from filename
    get_language() {
      local filepath="$1"
      if [[ "$filepath" == *.es.md ]]; then
        echo "es"
      else
        echo "en"
      fi
    }

    # Function to get category from path
    get_category() {
      local filepath="$1"
      local dir=$(dirname "$filepath")
      echo $(basename "$dir")
    }

    # Function to extract title from markdown file
    get_title_from_file() {
      local filepath="$1"

      if [[ -f "$filepath" ]]; then
        # Look for the first H1 header in the file
        local title=$(${pkgs.gnugrep}/bin/grep -m1 "^# " "$filepath" 2>/dev/null | sed 's/^# //' || echo "")
        if [[ -n "$title" ]]; then
          echo "$title"
        else
          # Fallback to clean filename
          get_clean_filename "$filepath"
        fi
      else
        get_clean_filename "$filepath"
      fi
    }

    # Main processing
    case "$MODE" in
      "files")
        # Generate JSON list of available files for a category
        echo "["

        # Handle special "root" category for files in docs/ root directory
        if [[ "$CATEGORY" == "root" ]]; then
          # Find markdown files directly in docs root directory
          if [[ -d "$DOCS_DIR" ]]; then
            first=true

            while IFS= read -r -d "" filepath; do
              file_lang=$(get_language "$filepath")

              # Filter by requested language
              if [[ "$file_lang" == "$LANGUAGE" ]]; then
                clean_name=$(get_clean_filename "$filepath")
                title=$(get_title_from_file "$filepath")

                if [[ "$first" == "true" ]]; then
                  first=false
                else
                  echo ","
                fi

                cat <<JSON_ENTRY
          {
            "filename": "$(basename "$filepath")",
            "clean_name": "$clean_name",
            "title": "$title",
            "category": "root",
            "language": "$file_lang",
            "path": "$filepath"
          }
  JSON_ENTRY
              fi
            done < <(${pkgs.findutils}/bin/find "$DOCS_DIR" -maxdepth 1 -name "*.md" -print0 | ${pkgs.coreutils}/bin/sort -z)
          fi
        # Find all markdown files in the specified category directory
        elif [[ -d "$DOCS_DIR/$CATEGORY" ]]; then
          first=true

          while IFS= read -r -d "" filepath; do
            file_lang=$(get_language "$filepath")

            # Filter by requested language
            if [[ "$file_lang" == "$LANGUAGE" ]]; then
              clean_name=$(get_clean_filename "$filepath")
              title=$(get_title_from_file "$filepath")

              if [[ "$first" == "true" ]]; then
                first=false
              else
                echo ","
              fi

              cat <<JSON_ENTRY
      {
        "filename": "$(basename "$filepath")",
        "clean_name": "$clean_name",
        "title": "$title",
        "category": "$CATEGORY",
        "language": "$file_lang",
        "path": "$filepath"
      }
  JSON_ENTRY
            fi
          done < <(${pkgs.findutils}/bin/find "$DOCS_DIR/$CATEGORY" -name "*.md" -print0 | ${pkgs.coreutils}/bin/sort -z)
        fi

        echo "]"
        ;;

      "content")
        # Get content of a specific file or all files in category
        FILENAME="''${4:-}"

        if [[ -n "$FILENAME" ]]; then
          # Single file content
          if [[ -f "$DOCS_DIR/$CATEGORY/$FILENAME" ]]; then
            cat "$DOCS_DIR/$CATEGORY/$FILENAME"
          else
            echo "File not found: $DOCS_DIR/$CATEGORY/$FILENAME" >&2
            exit 1
          fi
        else
          # All files metadata with content
          echo "["
          first=true

          if [[ -d "$DOCS_DIR/$CATEGORY" ]]; then
            while IFS= read -r -d "" filepath; do
              file_lang=$(get_language "$filepath")

              # Filter by requested language
              if [[ "$file_lang" == "$LANGUAGE" ]]; then
                clean_name=$(get_clean_filename "$filepath")
                title=$(get_title_from_file "$filepath")
                content=$(cat "$filepath" | ${pkgs.jq}/bin/jq -R -s .)

                if [[ "$first" == "true" ]]; then
                  first=false
                else
                  echo ","
                fi

                cat <<JSON_ENTRY
          {
            "filename": "$(basename "$filepath")",
            "clean_name": "$clean_name",
            "title": "$title",
            "category": "$CATEGORY",
            "language": "$file_lang",
            "path": "$filepath",
            "content": $content
          }
  JSON_ENTRY
              fi
            done < <(${pkgs.findutils}/bin/find "$DOCS_DIR/$CATEGORY" -name "*.md" -print0 | ${pkgs.coreutils}/bin/sort -z)
          fi

          echo "]"
        fi
        ;;

      "categories")
        # List available categories
        echo "["
        first=true

        # Always include "root" category for files in docs/ root directory
        if [[ -d "$DOCS_DIR" ]] && [[ $(${pkgs.findutils}/bin/find "$DOCS_DIR" -maxdepth 1 -name "*.md" | wc -l) -gt 0 ]]; then
          echo "    \"root\""
          first=false
        fi

        if [[ -d "$DOCS_DIR" ]]; then
          for dir in "$DOCS_DIR"/*; do
            if [[ -d "$dir" ]]; then
              category=$(basename "$dir")

              if [[ "$first" == "true" ]]; then
                first=false
              else
                echo ","
              fi

              echo "    \"$category\""
            fi
          done
        fi

        echo "]"
        ;;

      *)
        echo "Error: Unknown mode '$MODE'" >&2
        usage >&2
        exit 1
        ;;
    esac
''
