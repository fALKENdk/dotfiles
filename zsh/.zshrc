# Interactive zsh setup. PATH and env vars live in .zshenv so they reach
# non-interactive subshells too (GUI apps, IDE child processes, scripts).
# Platform branching (secrets store) happens inline in .platform-common.
setopt prompt_subst

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

[[ -f "$DOTFILES_DIR/zsh/.functions" ]] && source "$DOTFILES_DIR/zsh/.functions"

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git same-dir-tab)
zstyle ':omz:update' mode reminder
fpath=("$DOTFILES_DIR/zsh/completions" $fpath)

# Docker Desktop completions. Added to fpath BEFORE oh-my-zsh sources its
# compinit, so they're picked up without re-running compinit afterwards.
[[ -d "$HOME/.docker/completions" ]] && fpath=("$HOME/.docker/completions" $fpath)

[[ -d "$ZSH" ]] && source "$ZSH/oh-my-zsh.sh"

[[ -f "$DOTFILES_DIR/zsh/.platform-common" ]] && source "$DOTFILES_DIR/zsh/.platform-common"

# nvm: load the full function + completions for interactive use. .zshenv
# only sets PATH; this is where the `nvm` command becomes available.
() {
    local nvm_script="${HOMEBREW_PREFIX:-}/opt/nvm/nvm.sh"
    [[ -s "$nvm_script" ]] || nvm_script="${NVM_DIR:-$HOME/.nvm}/nvm.sh"
    # Source nvm.sh fully so `nvm current` and friends report correctly.
    # .zshenv already added the default bin to PATH; sourcing nvm.sh in
    # interactive shells (~200ms) is fine - non-interactive subshells skip it.
    [[ -s "$nvm_script" ]] && source "$nvm_script"

    local nvm_completion="${HOMEBREW_PREFIX:-}/opt/nvm/etc/bash_completion.d/nvm"
    [[ -s "$nvm_completion" ]] || nvm_completion="${NVM_DIR:-$HOME/.nvm}/bash_completion"
    [[ -s "$nvm_completion" ]] && source "$nvm_completion"
}

# Respect project .nvmrc files: switch node on `cd`. Only runs when nvm loaded
# (interactive shells) and only calls `nvm use` when the version differs, so the
# per-cd cost is just a cheap upward .nvmrc lookup.
if command -v nvm_find_nvmrc >/dev/null 2>&1; then
    autoload -U add-zsh-hook
    _load_nvmrc() {
        local nvmrc_path nvmrc_node_version
        nvmrc_path="$(nvm_find_nvmrc)"
        if [[ -n "$nvmrc_path" ]]; then
            nvmrc_node_version="$(nvm version "$(cat "$nvmrc_path")")"
            if [[ "$nvmrc_node_version" == "N/A" ]]; then
                nvm install
            elif [[ "$nvmrc_node_version" != "$(nvm version)" ]]; then
                nvm use --silent
            fi
        elif [[ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" && "$(nvm version)" != "$(nvm version default)" ]]; then
            nvm use default --silent
        fi
    }
    add-zsh-hook chpwd _load_nvmrc
    _load_nvmrc
fi
