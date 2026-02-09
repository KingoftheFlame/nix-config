{pkgs}:
pkgs.writeShellScriptBin "cheatsheets-parser" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Default paths (ported to ZaneyOS repo location)
    CHEATSHEETS_DIR="$HOME/zaneyos/cheatsheets"

    # Handle arguments
    MODE="''${1:-files}"
    CATEGORY="''${2:-emacs}"
    LANGUAGE="''${3:-en}"

    usage() {
      cat <<EOF
  Usage: cheatsheets-parser [MODE] [CATEGORY] [LANGUAGE]

  MODE: files|content|categories
  CATEGORY: emacs|hyprland|kitty|wezterm|yazi|nix|root|etc.
  LANGUAGE: en|es

  Examples:
    cheatsheets-parser files emacs en       # List English emacs cheatsheet files
    cheatsheets-parser content emacs en     # Get content for all English emacs files
  EOF
    }

    # Function to extract clean filename
    get_clean_filename() {
      local filepath="$1"
      local basename=$(basename "$filepath")

      # Remove category prefix (e.g., "emacs.")
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

        # Handle special "root" category for files in cheatsheets/ root directory
        if [[ "$CATEGORY" == "root" ]]; then
          # Find markdown files directly in cheatsheets root directory
          if [[ -d "$CHEATSHEETS_DIR" ]]; then
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
            done < <(${pkgs.findutils}/bin/find "$CHEATSHEETS_DIR" -maxdepth 1 -name "*.md" -print0 | ${pkgs.coreutils}/bin/sort -z)
          fi
        # Find all markdown files in the specified category directory
        elif [[ -d "$CHEATSHEETS_DIR/$CATEGORY" ]]; then
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
          done < <(${pkgs.findutils}/bin/find "$CHEATSHEETS_DIR/$CATEGORY" -name "*.md" -print0 | ${pkgs.coreutils}/bin/sort -z)
        fi

        echo "]"
        ;;

      "content")
        # Get content of a specific file or all files in category
        FILENAME="''${4:-}"

        if [[ -n "$FILENAME" ]]; then
          # Single file content
          if [[ -f "$CHEATSHEETS_DIR/$CATEGORY/$FILENAME" ]]; then
            cat "$CHEATSHEETS_DIR/$CATEGORY/$FILENAME"
          else
            echo "File not found: $CHEATSHEETS_DIR/$CATEGORY/$FILENAME" >&2
            exit 1
          fi
        else
          # All files metadata with content
          echo "["
          first=true

          if [[ -d "$CHEATSHEETS_DIR/$CATEGORY" ]]; then
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
            done < <(${pkgs.findutils}/bin/find "$CHEATSHEETS_DIR/$CATEGORY" -name "*.md" -print0 | ${pkgs.coreutils}/bin/sort -z)
          fi

          echo "]"
        fi
        ;;

      "categories")
        # List available categories
        echo "["
        first=true

        # Always include "root" category for files in cheatsheets/ root directory
        if [[ -d "$CHEATSHEETS_DIR" ]] && [[ $(${pkgs.findutils}/bin/find "$CHEATSHEETS_DIR" -maxdepth 1 -name "*.md" | wc -l) -gt 0 ]]; then
          echo "    \"root\""
          first=false
        fi

        if [[ -d "$CHEATSHEETS_DIR" ]]; then
          for dir in "$CHEATSHEETS_DIR"/*; do
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
