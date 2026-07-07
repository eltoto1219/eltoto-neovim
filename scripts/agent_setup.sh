#!/usr/bin/env bash
# Installs and configures the AI agent stack: codex, claude, agent
# instructions, skills, axi CLIs, no-mistakes, and treehouse.
# Everything installs user-locally and degrades with a warn; no root needed.
# Runs standalone or from setup.sh (which handles nvim, python, shpool, brew).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

GO_VERSION="1.25.0"
NO_MISTAKES_REPO="https://github.com/eltoto1219/no-mistakes.git"
NO_MISTAKES_DIR="$HOME/.local/share/no-mistakes"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
AXI_PACKAGES=(gh-axi chrome-devtools-axi)

ensure_node() {
    if command_exists npm && command_exists npx; then
        return
    fi

    if command_exists brew; then
        echo "Installing Node.js via user-local brew"
        brew install node || warn "brew install node failed; codex and axi installs will be skipped"
        refresh_shell
    else
        warn "node/npm missing and brew unavailable; codex and axi installs will be skipped"
    fi
}

ensure_go() {
    if command_exists go; then
        return
    fi

    local arch os dest
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            warn "unsupported architecture $(uname -m); skipping Go install (no-mistakes build will be unavailable)"
            return
            ;;
    esac
    case "$OS_NAME" in
        Linux) os="linux" ;;
        Darwin) os="darwin" ;;
        *)
            warn "unsupported OS $OS_NAME; skipping Go install"
            return
            ;;
    esac

    dest="$HOME/.local/go${GO_VERSION}"
    if [[ ! -x "$dest/bin/go" ]]; then
        echo "Installing Go ${GO_VERSION} (user-local)"
        mkdir -p "$dest"
        if ! fetch "https://go.dev/dl/go${GO_VERSION}.${os}-${arch}.tar.gz" | tar -xz --strip-components=1 -C "$dest"; then
            warn "Go download failed; no-mistakes build will be unavailable"
            rm -rf "$dest"
            return
        fi
    fi

    ln -sf "$dest/bin/go" "$HOME/.local/bin/go"
    ln -sf "$dest/bin/gofmt" "$HOME/.local/bin/gofmt"
    refresh_shell
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

    echo "Installing codex"
    install_npm_global_local @openai/codex || warn "codex install failed; run: npm install -g --prefix ~/.local @openai/codex"
    refresh_shell
}

ensure_claude() {
    if command_exists claude; then
        echo "claude is already installed."
        return
    fi

    echo "Installing Claude Code (user-local)"
    fetch https://claude.ai/install.sh | bash || warn "claude install failed; see https://claude.ai/install"
    refresh_shell
}

ensure_gh() {
    if command_exists gh; then
        return
    fi

    if command_exists brew; then
        echo "Installing gh (needed for private skill repos)"
        brew install gh || warn "brew install gh failed; Motive skills will be skipped"
        refresh_shell
    else
        warn "gh missing and brew unavailable; Motive skills will be skipped"
    fi
}

ensure_agent_logins() {
    # Skills and no-mistakes need authenticated agents; do the logins during
    # setup when a terminal is attached, otherwise just say what is missing.
    if command_exists claude && ! claude auth status >/dev/null 2>&1; then
        if [[ -t 0 ]]; then
            echo "Claude is not logged in; starting login"
            claude auth login || warn "claude login failed; run 'claude auth login' later"
        else
            warn "claude is not logged in; run 'claude auth login'"
        fi
    fi

    if command_exists codex && ! codex login status >/dev/null 2>&1; then
        if [[ -t 0 ]]; then
            echo "Codex is not logged in; starting login"
            codex login || warn "codex login failed; run 'codex login' later"
        else
            warn "codex is not logged in; run 'codex login'"
        fi
    fi

    if command_exists gh && ! gh auth status >/dev/null 2>&1; then
        if [[ -t 0 ]]; then
            echo "GitHub CLI is not logged in; starting login (needed for private skill repos)"
            gh auth login || warn "gh login failed; run 'gh auth login' later"
        else
            warn "gh is not logged in; run 'gh auth login' (needed for Motive skills)"
        fi
    fi
}

seed_agent_file() {
    # $1 = repo template, $2 = live destination. Creates the live file when
    # missing; when it differs, offers append/overwrite/keep.
    local src="$1" dst="$2"
    local choice

    if [[ ! -f "$dst" ]]; then
        cp "$src" "$dst"
        echo "Created $dst from $src"
        return
    fi
    cmp -s "$src" "$dst" && return

    choice="k"
    if [[ -t 0 ]]; then
        read -r -p "$dst differs from the repo copy. [a]ppend repo copy / [o]verwrite / [k]eep (default k): " choice
    fi
    case "$choice" in
        a|A)
            printf '\n' >>"$dst"
            cat "$src" >>"$dst"
            echo "Appended repo copy to $dst"
            ;;
        o|O)
            cp "$src" "$dst"
            echo "Overwrote $dst with repo copy"
            ;;
        *)
            echo "Keeping existing $dst"
            ;;
    esac
}

ensure_agent_instructions() {
    # ~/.claude/CLAUDE.md is the single source of agent instructions;
    # ~/AGENTS.md and ~/.codex/AGENTS.md symlink to it so claude and codex
    # read the same file on any machine. OPINIONS.md and VOICE.md are
    # referenced by those instructions, so they get seeded too.
    local dst="$HOME/.claude/CLAUDE.md"
    local choice link

    mkdir -p "$HOME/.claude" "$HOME/.codex"

    seed_agent_file "$ROOT_DIR/agent/CLAUDE.md" "$dst"
    seed_agent_file "$ROOT_DIR/agent/OPINIONS.md" "$HOME/OPINIONS.md"
    seed_agent_file "$ROOT_DIR/agent/VOICE.md" "$HOME/VOICE.md"

    for link in "$HOME/AGENTS.md" "$HOME/.codex/AGENTS.md"; do
        if [[ -e "$link" && ! -L "$link" ]]; then
            choice="k"
            if [[ -t 0 ]]; then
                read -r -p "$link is a regular file. [a]ppend its content into ~/.claude/CLAUDE.md then symlink / [o]verwrite with symlink / [k]eep (default k): " choice
            fi
            case "$choice" in
                a|A)
                    printf '\n' >>"$dst"
                    cat "$link" >>"$dst"
                    ;;
                o|O) ;;
                *)
                    warn "$link left as a regular file; symlink it to ~/.claude/CLAUDE.md manually"
                    continue
                    ;;
            esac
            rm -f "$link"
        fi
        ln -sfn "$dst" "$link"
    done
    echo "~/AGENTS.md and ~/.codex/AGENTS.md point at ~/.claude/CLAUDE.md"
}

ensure_claude_plugins() {
    if ! command_exists claude; then
        warn "claude missing; skipping plugin install"
        return
    fi

    if ! claude plugin marketplace list 2>/dev/null | grep -q 'ponytail'; then
        echo "Adding ponytail plugin marketplace"
        claude plugin marketplace add DietrichGebert/ponytail || { warn "could not add ponytail marketplace"; return; }
    fi

    if ! grep -q '"ponytail@ponytail"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
        echo "Installing ponytail plugin"
        claude plugin install ponytail@ponytail || warn "ponytail install failed; run: claude plugin install ponytail@ponytail"
    fi
}

install_skills_from_repo() {
    # $1 = clone command (runs with a target dir appended); rest = skill
    # names. Clones once, only when at least one skill is missing, then finds
    # each skill directory anywhere in the clone and copies it whole.
    local clone_cmd="$1"
    shift
    local -a missing=()
    local name tmp src

    for name in "$@"; do
        [[ -d "$CLAUDE_SKILLS_DIR/$name" ]] || missing+=("$name")
    done
    ((${#missing[@]})) || return 0

    tmp="$(mktemp -d)"
    if ! eval "$clone_cmd \"$tmp/repo\"" >/dev/null 2>&1; then
        warn "could not clone repo for skills: ${missing[*]}"
        rm -rf "$tmp"
        return
    fi

    for name in "${missing[@]}"; do
        src="$(find "$tmp/repo" -maxdepth 4 -type d -name "$name" -not -path '*/.git/*' | head -1)"
        if [[ -z "$src" || ! -f "$src/SKILL.md" ]]; then
            warn "skill $name not found in cloned repo"
            continue
        fi
        mkdir -p "$CLAUDE_SKILLS_DIR"
        cp -r "$src" "$CLAUDE_SKILLS_DIR/$name"
        echo "Installed skill $name"
    done
    rm -rf "$tmp"
}

motive_skill_list() {
    grep -vE '^[[:space:]]*(#|$)' "$ROOT_DIR/agent/motive-skills.txt"
}

ensure_skills() {
    if ! command_exists git; then
        warn "git missing; skipping skill installs"
        return
    fi

    install_skills_from_repo \
        "git clone --quiet --depth 1 https://github.com/anthropics/skills" \
        skill-creator
    install_skills_from_repo \
        "git clone --quiet --depth 1 https://github.com/vercel-labs/skills" \
        find-skills

    if command_exists gh && gh auth status >/dev/null 2>&1; then
        # The Motive set lives in agent/motive-skills.txt; installed as plain
        # file copies, so none of the skill manager's telemetry hooks run.
        local -a motive_skills=()
        while IFS= read -r skill; do
            motive_skills+=("$skill")
        done < <(motive_skill_list)
        install_skills_from_repo \
            "gh repo clone KeepTruckin/motive-agent-skills" \
            "${motive_skills[@]}"
    else
        warn "gh not authenticated; skipping Motive skills (run 'gh auth login', then re-run this script)"
    fi
}

ensure_axi() {
    if ! command_exists npm; then
        warn "npm missing; skipping axi installs"
        return
    fi

    # Pick up any additional axi skill already installed on this machine so
    # its CLI gets (re)installed too.
    local -a packages=("${AXI_PACKAGES[@]}")
    local dir name pkg known
    for dir in "$CLAUDE_SKILLS_DIR"/*axi*; do
        [[ -d "$dir" ]] || continue
        name="$(basename "$dir")"
        known=0
        for pkg in "${packages[@]}"; do
            [[ "$pkg" == "$name" ]] && known=1
        done
        ((known)) || packages+=("$name")
    done

    for pkg in "${packages[@]}"; do
        if ! command_exists "$pkg"; then
            echo "Installing $pkg (user-local npm)"
            if ! install_npm_global_local "$pkg"; then
                warn "npm install $pkg failed"
                continue
            fi
            refresh_shell
        fi

        # axi packages ship their agent skill inside the npm package; keep the
        # installed copy in sync with the CLI version.
        local skill_src="$HOME/.local/lib/node_modules/$pkg/skills/$pkg"
        if [[ -d "$skill_src" ]]; then
            mkdir -p "$CLAUDE_SKILLS_DIR"
            rm -rf "${CLAUDE_SKILLS_DIR:?}/$pkg"
            cp -r "$skill_src" "$CLAUDE_SKILLS_DIR/$pkg"
        fi
    done
}

ensure_no_mistakes() {
    if ! command_exists go; then
        warn "go missing; skipping no-mistakes install"
        return
    fi
    if ! command_exists git; then
        warn "git missing; skipping no-mistakes install"
        return
    fi

    # Replace clones of anything other than the fork.
    if [[ -d "$NO_MISTAKES_DIR/.git" ]]; then
        local origin
        origin="$(git -C "$NO_MISTAKES_DIR" remote get-url origin 2>/dev/null || true)"
        if [[ "$origin" != "$NO_MISTAKES_REPO" ]]; then
            echo "Replacing old no-mistakes clone (origin was: ${origin:-unknown})"
            rm -rf "$NO_MISTAKES_DIR"
        fi
    fi

    local before="" after
    if [[ ! -d "$NO_MISTAKES_DIR/.git" ]]; then
        echo "Cloning no-mistakes fork"
        mkdir -p "$(dirname "$NO_MISTAKES_DIR")"
        git clone --quiet "$NO_MISTAKES_REPO" "$NO_MISTAKES_DIR" || { warn "no-mistakes clone failed"; return; }
    else
        before="$(git -C "$NO_MISTAKES_DIR" rev-parse HEAD)"
        git -C "$NO_MISTAKES_DIR" pull --ff-only --quiet || warn "no-mistakes pull failed; building the current checkout"
    fi
    after="$(git -C "$NO_MISTAKES_DIR" rev-parse HEAD)"

    # Rebuilding restarts the daemon, so only build when the source moved or
    # the binary is missing.
    if [[ "$before" != "$after" || ! -x "$HOME/go/bin/no-mistakes" ]]; then
        echo "Building no-mistakes"
        if ! make -C "$NO_MISTAKES_DIR" install; then
            warn "no-mistakes build failed"
            return
        fi
    else
        echo "no-mistakes is up to date."
    fi
    ln -sf "$HOME/go/bin/no-mistakes" "$HOME/.local/bin/no-mistakes"

    # The fork ships its agent skill in-repo; keep the installed copy in sync.
    if [[ -f "$NO_MISTAKES_DIR/skills/no-mistakes/SKILL.md" ]]; then
        mkdir -p "$CLAUDE_SKILLS_DIR"
        rm -rf "${CLAUDE_SKILLS_DIR:?}/no-mistakes"
        cp -r "$NO_MISTAKES_DIR/skills/no-mistakes" "$CLAUDE_SKILLS_DIR/no-mistakes"
    fi

    # Remove stale binaries from older install methods that would shadow the
    # fork build; only touch files under $HOME.
    local p
    for p in $(which -a no-mistakes 2>/dev/null | sort -u); do
        [[ "$p" == "$HOME/.local/bin/no-mistakes" || "$p" == "$HOME/go/bin/no-mistakes" ]] && continue
        if [[ "$p" == "$HOME"/* ]]; then
            echo "Removing stale no-mistakes at $p"
            rm -f "$p"
        else
            warn "stale no-mistakes at $p shadows the fork build; remove it manually"
        fi
    done

    local cfg="$HOME/.no-mistakes/config.yaml"
    if [[ ! -f "$cfg" ]]; then
        mkdir -p "$HOME/.no-mistakes"
        cp "$ROOT_DIR/agent/no-mistakes.config.yaml" "$cfg"
        echo "Wrote $cfg (codex-first agents, custom fix_message, pr_signature off)"
    else
        local key
        for key in 'agent: \[codex' 'fix_message:' 'pr_signature: false'; do
            grep -q "$key" "$cfg" || warn "no-mistakes config: expected '$key' in $cfg (repo template: agent/no-mistakes.config.yaml)"
        done
    fi
}

ensure_treehouse() {
    if command_exists treehouse; then
        echo "treehouse is already installed."
        return
    fi

    echo "Installing treehouse (worktree pool manager)"
    fetch https://kunchenguid.github.io/treehouse/install.sh | sh || warn "treehouse install failed; see https://github.com/kunchenguid/treehouse"
}

doctor() {
    local c s ok

    echo
    echo "Agent stack status:"
    for c in nvim python3 brew shpool node npx go gh codex claude no-mistakes treehouse; do
        if command_exists "$c"; then
            printf '  ok       %s\n' "$c"
        else
            printf '  MISSING  %s\n' "$c"
        fi
    done

    for s in skill-creator find-skills no-mistakes "${AXI_PACKAGES[@]}" $(motive_skill_list); do
        if [[ -d "$CLAUDE_SKILLS_DIR/$s" ]]; then
            printf '  ok       skill %s\n' "$s"
        else
            printf '  MISSING  skill %s\n' "$s"
        fi
    done

    if grep -q '"ponytail@ponytail"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
        printf '  ok       plugin ponytail\n'
    else
        printf '  MISSING  plugin ponytail\n'
    fi

    for c in "$HOME/AGENTS.md" "$HOME/.codex/AGENTS.md"; do
        if [[ -L "$c" ]]; then
            printf '  ok       %s -> %s\n' "$c" "$(readlink "$c")"
        else
            printf '  MISSING  symlink %s\n' "$c"
        fi
    done

    for c in "$HOME/.no-mistakes/config.yaml" "$HOME/OPINIONS.md" "$HOME/VOICE.md"; do
        ok="MISSING "
        [[ -f "$c" ]] && ok="ok      "
        printf '  %s %s\n' "$ok" "$c"
    done
}

ensure_local_bin_on_path
ensure_node
ensure_go
ensure_codex
ensure_claude
ensure_gh
ensure_agent_logins
ensure_agent_instructions
ensure_claude_plugins
ensure_skills
ensure_axi
ensure_no_mistakes
ensure_treehouse
doctor
