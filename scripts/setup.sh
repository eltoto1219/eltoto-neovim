#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
REQS_FILE="$ROOT_DIR/reqs.txt"
FONT_SCRIPT="$ROOT_DIR/scripts/font_setup.sh"
OS_NAME="$(uname -s)"
PACKAGE_MANAGER=""
PYTHON_BIN=""
INSTALL_ALL_DEPENDENCIES=0

warn() {
    printf 'warning: %s\n' "$1" >&2
}

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

refresh_shell() {
    hash -r
}

default_shell_name() {
    local shell_path="${SHELL:-}"

    if [[ -n "$shell_path" ]]; then
        basename "$shell_path"
        return
    fi

    case "$OS_NAME" in
        Darwin) echo "zsh" ;;
        *) echo "bash" ;;
    esac
}

shell_rc_file() {
    local shell_name
    shell_name="$(default_shell_name)"

    case "$shell_name" in
        zsh) echo "$HOME/.zshrc" ;;
        bash) echo "$HOME/.bashrc" ;;
        *) echo "$HOME/.profile" ;;
    esac
}

ensure_openai_api_key_placeholder() {
    local rc_file
    local openai_api_key=""
    rc_file="$(shell_rc_file)"

    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
        echo "OPENAI_API_KEY is already set in the current environment."
        return
    fi

    if [[ -f "$rc_file" ]] && grep -q 'OPENAI_API_KEY' "$rc_file"; then
        echo "OPENAI_API_KEY already exists in $rc_file."
        return
    fi

    if [[ -t 0 ]]; then
        printf 'Enter OPENAI_API_KEY (leave empty to keep placeholder): '
        read -r -s openai_api_key
        printf '\n'
    fi

    touch "$rc_file"
    {
        printf '\n# OpenAI API key for Codex / Avante\n'
        printf 'export OPENAI_API_KEY="%s"\n' "$openai_api_key"
    } >>"$rc_file"

    echo "Added OPENAI_API_KEY placeholder to $rc_file"
}

ensure_local_bin_on_path() {
    local local_bin="${HOME}/.local/bin"
    local rc_file

    rc_file="$(shell_rc_file)"
    mkdir -p "$local_bin"

    case ":$PATH:" in
        *":${local_bin}:"*) ;;
        *) export PATH="${local_bin}:$PATH" ;;
    esac

    touch "$rc_file"
    if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$rc_file"; then
        {
            printf '\n# User-local executables for Neovim AI tooling\n'
            printf 'export PATH="$HOME/.local/bin:$PATH"\n'
        } >>"$rc_file"
        echo "Added ~/.local/bin to PATH in $rc_file"
    fi
}

ensure_vi_mode_in_shell_rcs() {
    local rc_file
    local -a rc_files=(
        "$HOME/.profile"
        "$HOME/.bashrc"
        "$HOME/.zshrc"
    )

    for rc_file in "${rc_files[@]}"; do
        touch "$rc_file"

        if grep -Eq '^[[:space:]]*(set[[:space:]]+-o[[:space:]]+vi|bindkey[[:space:]]+-v)\b' "$rc_file"; then
            continue
        fi

        {
            printf '\n# Enable vi mode in the shell\n'
            printf 'set -o vi\n'
        } >>"$rc_file"

        echo "Enabled vi mode in $rc_file"
    done
}

ensure_vim_alias_in_shell_rcs() {
    local rc_file
    local -a rc_files=(
        "$HOME/.profile"
        "$HOME/.bashrc"
        "$HOME/.zshrc"
    )

    for rc_file in "${rc_files[@]}"; do
        touch "$rc_file"

        if grep -Eq "^[[:space:]]*alias[[:space:]]+vim=['\"]?nvim['\"]?[[:space:]]*$" "$rc_file"; then
            continue
        fi

        {
            printf '\n# Use Neovim when launching vim\n'
            printf 'alias vim="nvim"\n'
        } >>"$rc_file"

        echo "Added vim -> nvim alias in $rc_file"
    done
}

ensure_tmux_repo_config() {
    local repo_tmux_conf="$ROOT_DIR/tmux.conf"
    local user_tmux_conf="$HOME/.tmux.conf"

    if [[ ! -f "$repo_tmux_conf" ]]; then
        return
    fi

    touch "$user_tmux_conf"
    if ! grep -Fq "$repo_tmux_conf" "$user_tmux_conf"; then
        {
            printf '\n# eltoto.nvim tmux integration\n'
            printf 'source-file "%s"\n' "$repo_tmux_conf"
        } >>"$user_tmux_conf"
        echo "Added repo-local tmux config include to $user_tmux_conf"
    fi

    if command_exists tmux; then
        tmux start-server >/dev/null 2>&1 || true
        tmux source-file "$repo_tmux_conf" >/dev/null 2>&1 || true
    fi
}

maybe_run_copilot_setup() {
    local choice

    if ! command_exists nvim; then
        return
    fi

    choice="$(prompt_yes_no "Run :Copilot setup now?")"
    if [[ "$choice" != "yes" ]]; then
        return
    fi

    echo "Opening Neovim for Copilot setup"
    nvim "+Copilot setup"
}

install_npm_global_local() {
    npm install -g --prefix "${HOME}/.local" "$@"
}

ensure_codex() {
    if command_exists codex; then
        echo "codex is already installed."
        return
    fi

    if ! command_exists npm; then
        warn "npm is not installed; skipping codex installation"
        return
    fi

    ensure_local_bin_on_path
    echo "Installing codex"
    install_npm_global_local @openai/codex
}

detect_package_manager() {
    case "$OS_NAME" in
        Darwin)
            if command_exists brew; then
                echo "brew"
                return
            fi
            ;;
        Linux)
            for manager in apt-get dnf yum pacman zypper apk; do
                if command_exists "$manager"; then
                    echo "$manager"
                    return
                fi
            done
            ;;
    esac

    echo ""
}

run_package_install() {
    local package_manager="$1"
    shift

    case "$package_manager" in
        brew)
            brew install "$@"
            ;;
        apt-get)
            sudo apt-get update
            sudo apt-get install -y "$@"
            ;;
        dnf)
            sudo dnf install -y "$@"
            ;;
        yum)
            sudo yum install -y "$@"
            ;;
        pacman)
            sudo pacman -Sy --noconfirm "$@"
            ;;
        zypper)
            sudo zypper install -y "$@"
            ;;
        apk)
            sudo apk add "$@"
            ;;
        *)
            return 1
            ;;
    esac
}

packages_for_tool() {
    local package_manager="$1"
    local tool="$2"

    case "$package_manager:$tool" in
        brew:git) echo "git" ;;
        brew:nvim) echo "neovim" ;;
        brew:python3) echo "python" ;;
        brew:curl_or_wget) echo "curl" ;;
        brew:curl) echo "curl" ;;
        brew:wget) echo "wget" ;;
        brew:unzip) echo "unzip" ;;
        brew:tar) echo "gnu-tar" ;;
        brew:rg) echo "ripgrep" ;;
        brew:tmux) echo "tmux" ;;
        brew:node) echo "node" ;;
        brew:gcc) echo "gcc" ;;
        brew:compiler) echo "gcc" ;;
        brew:make) echo "make" ;;
        apt-get:git) echo "git" ;;
        apt-get:nvim) echo "neovim" ;;
        apt-get:python3) echo "python3" ;;
        apt-get:venv) echo "python3-venv" ;;
        apt-get:curl_or_wget) echo "curl" ;;
        apt-get:curl) echo "curl" ;;
        apt-get:wget) echo "wget" ;;
        apt-get:unzip) echo "unzip" ;;
        apt-get:tar) echo "tar" ;;
        apt-get:rg) echo "ripgrep" ;;
        apt-get:tmux) echo "tmux" ;;
        apt-get:node) echo "nodejs npm" ;;
        apt-get:gcc) echo "build-essential" ;;
        apt-get:compiler) echo "build-essential" ;;
        apt-get:make) echo "build-essential" ;;
        dnf:git|yum:git) echo "git" ;;
        dnf:nvim|yum:nvim) echo "neovim" ;;
        dnf:python3|yum:python3) echo "python3" ;;
        dnf:venv|yum:venv) echo "python3" ;;
        dnf:curl_or_wget|yum:curl_or_wget) echo "curl" ;;
        dnf:curl|yum:curl) echo "curl" ;;
        dnf:wget|yum:wget) echo "wget" ;;
        dnf:unzip|yum:unzip) echo "unzip" ;;
        dnf:tar|yum:tar) echo "tar" ;;
        dnf:rg|yum:rg) echo "ripgrep" ;;
        dnf:tmux|yum:tmux) echo "tmux" ;;
        dnf:node|yum:node) echo "nodejs npm" ;;
        dnf:gcc|yum:gcc) echo "gcc make" ;;
        dnf:compiler|yum:compiler) echo "gcc make" ;;
        dnf:make|yum:make) echo "make" ;;
        pacman:git) echo "git" ;;
        pacman:nvim) echo "neovim" ;;
        pacman:python3) echo "python" ;;
        pacman:venv) echo "python" ;;
        pacman:curl_or_wget) echo "curl" ;;
        pacman:curl) echo "curl" ;;
        pacman:wget) echo "wget" ;;
        pacman:unzip) echo "unzip" ;;
        pacman:tar) echo "tar" ;;
        pacman:rg) echo "ripgrep" ;;
        pacman:tmux) echo "tmux" ;;
        pacman:node) echo "nodejs npm" ;;
        pacman:gcc) echo "base-devel" ;;
        pacman:compiler) echo "base-devel" ;;
        pacman:make) echo "base-devel" ;;
        zypper:git) echo "git" ;;
        zypper:nvim) echo "neovim" ;;
        zypper:python3) echo "python3" ;;
        zypper:venv) echo "python3-virtualenv" ;;
        zypper:curl_or_wget) echo "curl" ;;
        zypper:curl) echo "curl" ;;
        zypper:wget) echo "wget" ;;
        zypper:unzip) echo "unzip" ;;
        zypper:tar) echo "tar" ;;
        zypper:rg) echo "ripgrep" ;;
        zypper:tmux) echo "tmux" ;;
        zypper:node) echo "nodejs npm" ;;
        zypper:gcc) echo "gcc make" ;;
        zypper:compiler) echo "gcc make" ;;
        zypper:make) echo "make" ;;
        apk:git) echo "git" ;;
        apk:nvim) echo "neovim" ;;
        apk:python3) echo "python3" ;;
        apk:venv) echo "py3-virtualenv" ;;
        apk:curl_or_wget) echo "curl" ;;
        apk:curl) echo "curl" ;;
        apk:wget) echo "wget" ;;
        apk:unzip) echo "unzip" ;;
        apk:tar) echo "tar" ;;
        apk:rg) echo "ripgrep" ;;
        apk:tmux) echo "tmux" ;;
        apk:node) echo "nodejs npm" ;;
        apk:gcc) echo "build-base" ;;
        apk:compiler) echo "build-base" ;;
        apk:make) echo "build-base" ;;
        *)
            echo ""
            ;;
    esac
}

install_hint() {
    local tool="$1"

    case "$OS_NAME:$tool" in
        Darwin:git) echo "brew install git" ;;
        Darwin:nvim) echo "brew install neovim" ;;
        Darwin:python3) echo "brew install python" ;;
        Darwin:curl) echo "brew install curl" ;;
        Darwin:wget) echo "brew install wget" ;;
        Darwin:unzip) echo "brew install unzip" ;;
        Darwin:tar) echo "brew install gnu-tar" ;;
        Darwin:rg) echo "brew install ripgrep" ;;
        Darwin:tmux) echo "brew install tmux" ;;
        Darwin:node) echo "brew install node" ;;
        Darwin:gcc) echo "xcode-select --install" ;;
        Darwin:clang) echo "xcode-select --install" ;;
        Darwin:make) echo "xcode-select --install" ;;
        Linux:git) echo "Install git with your package manager (for example: sudo apt install git)" ;;
        Linux:nvim) echo "Install neovim with your package manager (for example: sudo apt install neovim)" ;;
        Linux:python3) echo "Install python3 with your package manager (for example: sudo apt install python3)" ;;
        Linux:venv) echo "Install python venv support (for example: sudo apt install python3-venv)" ;;
        Linux:curl) echo "Install curl with your package manager (for example: sudo apt install curl)" ;;
        Linux:wget) echo "Install wget with your package manager (for example: sudo apt install wget)" ;;
        Linux:unzip) echo "Install unzip with your package manager (for example: sudo apt install unzip)" ;;
        Linux:tar) echo "Install tar with your package manager (for example: sudo apt install tar)" ;;
        Linux:rg) echo "Install ripgrep with your package manager (for example: sudo apt install ripgrep)" ;;
        Linux:tmux) echo "Install tmux with your package manager (for example: sudo apt install tmux)" ;;
        Linux:node) echo "Install Node.js with your package manager (for example: sudo apt install nodejs npm)" ;;
        Linux:gcc) echo "Install build tools (for example: sudo apt install build-essential)" ;;
        Linux:clang) echo "Install clang with your package manager (for example: sudo apt install clang)" ;;
        Linux:make) echo "Install make/build tools (for example: sudo apt install build-essential)" ;;
        *)
            echo "Install ${tool} with your system package manager"
            ;;
    esac
}

tool_label() {
    local tool="$1"

    case "$tool" in
        curl_or_wget) echo "curl or wget" ;;
        compiler) echo "gcc or clang" ;;
        *) echo "$tool" ;;
    esac
}

prompt_yes_no() {
    local message="$1"
    local reply

    if [[ ! -t 0 ]]; then
        echo "no"
        return 0
    fi

    read -r -p "$message [Y/n/a] " reply

    case "$reply" in
        ""|y|Y|yes|YES|Yes)
            echo "yes"
            ;;
        a|A|all|ALL|All)
            echo "all"
            ;;
        *)
            echo "no"
            ;;
    esac
}

maybe_install_tool() {
    local tool="$1"
    local package_names
    local -a packages=()

    PACKAGE_MANAGER="${PACKAGE_MANAGER:-$(detect_package_manager)}"
    if [[ -z "$PACKAGE_MANAGER" ]]; then
        echo "Could not detect a supported package manager for $(tool_label "$tool")."
        echo "  hint: $(install_hint "$tool")"
        return 1
    fi

    package_names="$(packages_for_tool "$PACKAGE_MANAGER" "$tool")"
    if [[ -z "$package_names" ]]; then
        echo "No automatic install mapping is configured for $(tool_label "$tool")."
        echo "  hint: $(install_hint "$tool")"
        return 1
    fi

    for package_name in $package_names; do
        packages+=("$package_name")
    done

    if ((INSTALL_ALL_DEPENDENCIES)); then
        :
    else
        local choice
        choice="$(prompt_yes_no "Install missing dependency '$(tool_label "$tool")' now using ${PACKAGE_MANAGER}?")"
        case "$choice" in
            all)
                INSTALL_ALL_DEPENDENCIES=1
                ;;
            yes)
                ;;
            *)
                return 1
                ;;
        esac
    fi

    echo "Installing packages for $(tool_label "$tool"): ${packages[*]}"
    run_package_install "$PACKAGE_MANAGER" "${packages[@]}"
    refresh_shell
    return 0
}

find_python() {
    if command_exists python3; then
        command -v python3
        return 0
    fi

    if command_exists python; then
        command -v python
        return 0
    fi

    return 1
}

preflight() {
    local missing_required=()
    local missing_optional=()

    echo "Running preflight checks"

    if ! command_exists git; then
        missing_required+=("git")
    fi

    if ! command_exists python3 && ! command_exists python; then
        missing_required+=("python3")
    fi

    if ! command_exists curl && ! command_exists wget; then
        missing_required+=("curl_or_wget")
    fi

    if ! command_exists unzip; then
        missing_required+=("unzip")
    fi

    if ! command_exists tar; then
        missing_optional+=("tar")
    fi

    if ! command_exists rg; then
        missing_optional+=("rg")
    fi

    if ! command_exists tmux; then
        missing_optional+=("tmux")
    fi

    if ! command_exists node; then
        missing_optional+=("node")
    fi

    if ! command_exists make; then
        missing_optional+=("make")
    fi

    if ! command_exists gcc && ! command_exists clang; then
        missing_optional+=("compiler")
    fi

    if ! command_exists nvim; then
        missing_optional+=("nvim")
    fi

    if ((${#missing_required[@]} > 0)); then
        local item
        for item in "${missing_required[@]}"; do
            maybe_install_tool "$item" || true
        done

        PYTHON_BIN="$(find_python || true)"
        missing_required=()
        if ! command_exists git; then
            missing_required+=("git")
        fi
        if ! command_exists python3 && ! command_exists python; then
            missing_required+=("python3")
        fi
        if ! command_exists curl && ! command_exists wget; then
            missing_required+=("curl_or_wget")
        fi
        if ! command_exists unzip; then
            missing_required+=("unzip")
        fi
    fi

    if ((${#missing_required[@]} > 0)); then
        echo "Missing required dependencies:"
        for item in "${missing_required[@]}"; do
            case "$item" in
                curl_or_wget)
                    echo "  - curl or wget"
                    echo "    hint: $(install_hint curl)"
                    echo "    or:   $(install_hint wget)"
                    ;;
                *)
                    echo "  - $item"
                    echo "    hint: $(install_hint "$item")"
                    ;;
            esac
        done
        exit 1
    fi

    PYTHON_BIN="${PYTHON_BIN:-$(find_python || true)}"
    if ! "$PYTHON_BIN" -m venv --help >/dev/null 2>&1; then
        maybe_install_tool "venv" || true
        PYTHON_BIN="$(find_python || true)"
    fi

    if ! "$PYTHON_BIN" -m venv --help >/dev/null 2>&1; then
        echo "Python is installed, but venv support is missing."
        echo "  hint: $(install_hint venv)"
        exit 1
    fi

    if ((${#missing_optional[@]} > 0)); then
        echo "Missing optional dependencies:"
        for item in "${missing_optional[@]}"; do
            case "$item" in
                compiler)
                    echo "  - gcc or clang"
                    echo "    hint: $(install_hint gcc)"
                    ;;
                *)
                    echo "  - $item"
                    echo "    hint: $(install_hint "$item")"
                    ;;
            esac
        done

        for item in "${missing_optional[@]}"; do
            maybe_install_tool "$item" || true
        done
    fi
}

PYTHON_BIN="$(find_python || true)"

if [[ -z "$PYTHON_BIN" ]]; then
    PACKAGE_MANAGER="$(detect_package_manager)"
fi

preflight

if [[ ! -d "$VENV_DIR" ]]; then
    echo "Creating virtualenv at $VENV_DIR"
    "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip setuptools wheel
python -m pip install -r "$REQS_FILE"
ensure_openai_api_key_placeholder
ensure_vi_mode_in_shell_rcs
ensure_vim_alias_in_shell_rcs
ensure_tmux_repo_config

if [[ -x "$FONT_SCRIPT" ]]; then
    echo "Installing Nerd Font"
    "$FONT_SCRIPT"
fi

if command -v nvim >/dev/null 2>&1; then
    echo "Syncing Neovim plugins"
    nvim --headless "+Lazy! sync" "+qa"
    ensure_codex
    echo "Installing Mason packages"
    nvim --headless "+MasonInstall lua-language-server" "+qa"
    maybe_run_copilot_setup
else
    warn "Neovim is not installed; skipping plugin sync and Mason install"
fi

cat <<EOF
Bootstrap complete.

Repo root: $ROOT_DIR
Virtualenv: $VENV_DIR
Python host: $VENV_DIR/bin/python
EOF
