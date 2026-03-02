# Shared interactive zsh setup. Platform-specific values are sourced from
# ~/.config/dotfiles/platform via zsh/.platform-<platform>.
setopt prompt_subst

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

for file in "$DOTFILES_DIR/zsh/.exports" "$DOTFILES_DIR/zsh/.aliases" "$DOTFILES_DIR/zsh/.functions"; do
    [[ -f "$file" ]] && source "$file"
done

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
zstyle ':omz:update' mode reminder
fpath=("$DOTFILES_DIR/zsh/completions" $fpath)

[[ -d "$ZSH" ]] && source "$ZSH/oh-my-zsh.sh"

DOTFILES_PLATFORM_FILE="$HOME/.config/dotfiles/platform"
if [[ -f "$DOTFILES_PLATFORM_FILE" ]]; then
    DOTFILES_PLATFORM="$(<"$DOTFILES_PLATFORM_FILE")"
    [[ -f "$DOTFILES_DIR/zsh/.platform-$DOTFILES_PLATFORM" ]] && source "$DOTFILES_DIR/zsh/.platform-$DOTFILES_PLATFORM"
fi

[[ -f "$DOTFILES_DIR/zsh/.platform-common" ]] && source "$DOTFILES_DIR/zsh/.platform-common"
