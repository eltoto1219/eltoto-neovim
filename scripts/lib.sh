# Shared helpers for scripts/setup.sh and scripts/agent_setup.sh.
# Source this file; do not execute it.

OS_NAME="$(uname -s)"

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

fetch() {
    if command_exists curl; then
        curl -fsSL "$1"
    else
        wget -qO- "$1"
    fi
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

install_npm_global_local() {
    npm install -g --prefix "${HOME}/.local" "$@"
}
