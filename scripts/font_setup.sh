#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
FONT_VERSION="v3.4.0"
FONT_ZIP="Hack.zip"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${FONT_ZIP}"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

detect_font_dir() {
    case "$(uname -s)" in
        Darwin)
            printf '%s\n' "$HOME/Library/Fonts"
            ;;
        Linux)
            printf '%s\n' "$HOME/.local/share/fonts"
            ;;
        *)
            echo "Unsupported OS: $(uname -s)" >&2
            exit 1
            ;;
    esac
}

download_font_archive() {
    local destination="$1"

    if command -v curl >/dev/null 2>&1; then
        curl -fL "$FONT_URL" -o "$destination"
        return
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -O "$destination" "$FONT_URL"
        return
    fi

    echo "curl or wget is required to download fonts." >&2
    exit 1
}

install_fonts() {
    local archive_path="$TMP_DIR/$FONT_ZIP"
    local extract_dir="$TMP_DIR/extracted"
    local font_dir

    font_dir="$(detect_font_dir)"
    mkdir -p "$font_dir" "$extract_dir"

    echo "Downloading Hack Nerd Font ${FONT_VERSION}"
    download_font_archive "$archive_path"

    echo "Extracting fonts"
    unzip -oq "$archive_path" -d "$extract_dir"

    echo "Installing fonts to $font_dir"
    find "$extract_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "$font_dir"/ \;

    if command -v fc-cache >/dev/null 2>&1; then
        echo "Refreshing font cache"
        fc-cache -f "$font_dir"
    fi

    echo "Font installation complete"
}

install_fonts
