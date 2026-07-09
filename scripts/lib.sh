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

shell_path_literal() {
    local path="$1"
    printf '%s\n' "${path/#$HOME/\$HOME}"
}

ensure_path_entry_on_path() {
    local path_entry="$1"

    case ":$PATH:" in
        *":${path_entry}:"*) ;;
        *) export PATH="${path_entry}:$PATH" ;;
    esac
}

ensure_path_entry_in_rc() {
    local path_entry="$1"
    local comment="$2"
    local rc_file path_literal line

    rc_file="$(shell_rc_file)"
    path_literal="$(shell_path_literal "$path_entry")"
    line="export PATH=\"${path_literal}:\$PATH\""

    touch "$rc_file"
    if ! grep -Fq "$line" "$rc_file"; then
        {
            printf '\n# %s\n' "$comment"
            printf '%s\n' "$line"
        } >>"$rc_file"
        echo "Added ${path_literal} to PATH in $rc_file"
    fi
}

ensure_local_bin_on_path() {
    local local_bin="${HOME}/.local/bin"

    mkdir -p "$local_bin"
    ensure_path_entry_on_path "$local_bin"
    ensure_path_entry_in_rc "$local_bin" "User-local executables for Neovim AI tooling"
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
    npm install -g --prefix "$(npm_global_prefix)" "$@"
}

npm_global_prefix() {
    local prefix

    prefix="$(npm config get prefix 2>/dev/null || true)"
    case "$prefix" in
        ""|undefined|null)
            prefix="${HOME}/.local"
            ;;
    esac

    printf '%s\n' "$prefix"
}

npm_global_bin_dir() {
    printf '%s/bin\n' "$(npm_global_prefix)"
}

npm_global_node_modules_dir() {
    printf '%s/lib/node_modules\n' "$(npm_global_prefix)"
}

ensure_npm_global_bin_on_path() {
    local npm_bin

    npm_bin="$(npm_global_bin_dir)"
    mkdir -p "$npm_bin"
    ensure_path_entry_on_path "$npm_bin"
    ensure_path_entry_in_rc "$npm_bin" "User-local npm global executables"
}
