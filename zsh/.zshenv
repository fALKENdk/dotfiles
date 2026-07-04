# Sourced by zsh for EVERY invocation: login, interactive, scripts, and the
# non-interactive subshells GUI apps spawn (Cursor, VS Code, IntelliJ, etc.).
# Keep this file FAST: it runs on every `zsh -c`. No nvm.sh sourcing here -
# that adds ~1.5s per invocation. We only put the resolved default node bin
# on PATH so child processes that exec `node` directly find it. The full
# nvm function lives in .zshrc (interactive shells only).

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

[[ -f "$DOTFILES_DIR/zsh/.exports" ]] && source "$DOTFILES_DIR/zsh/.exports"

# nvm: PATH-only shim. Reads $NVM_DIR/alias/default and prepends that
# version's bin to PATH without sourcing nvm.sh (which is slow). The full
# `nvm` shell function is loaded in .zshrc for interactive use.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/alias/default" ]]; then
    () {
        local target version_dir
        target="$(<"$NVM_DIR/alias/default")"
        while [[ -s "$NVM_DIR/alias/$target" ]]; do
            target="$(<"$NVM_DIR/alias/$target")"
        done
        if [[ "$target" == lts/* ]]; then
            for version_dir in "$NVM_DIR"/versions/node/v*; do
                [[ -d "$version_dir" ]] && target="${version_dir##*/}"
            done
        fi
        [[ "$target" != v* && -d "$NVM_DIR/versions/node/v$target" ]] && target="v$target"
        [[ -d "$NVM_DIR/versions/node/$target/bin" ]] && \
            export PATH="$NVM_DIR/versions/node/$target/bin:$PATH"
    }
fi
