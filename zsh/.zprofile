# Login shells only. Runs AFTER /etc/zprofile (which calls
# /usr/libexec/path_helper -s and reorders PATH by prepending /etc/paths and
# /etc/paths.d/*). We re-prepend our managed directories here so login shells
# end up with the same PATH ordering as non-login subshells set up by .zshenv.
#
# Non-login subshells skip /etc/zprofile entirely, so this file isn't needed
# for IDE-spawned children - their PATH is already correct from .zshenv.
#
# Order matters: later prepends end up earlier in PATH. We put nvm last so
# its node/npm shadow any other node (e.g. a brew node pulled in transitively
# by bitwarden-cli).

typeset -U path

if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    [[ -d "$HOMEBREW_PREFIX/sbin" ]] && path=("$HOMEBREW_PREFIX/sbin" $path)
    [[ -d "$HOMEBREW_PREFIX/bin" ]] && path=("$HOMEBREW_PREFIX/bin" $path)
fi

[[ -n "${DOTNET_ROOT:-}" && -d "$DOTNET_ROOT" ]] && path=("$DOTNET_ROOT" $path)
[[ -d "$HOME/.dotnet/tools" ]] && path=("$HOME/.dotnet/tools" $path)
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)

if [[ -n "${NVM_DIR:-}" && -s "$NVM_DIR/alias/default" ]]; then
    _nvm_default="$(<"$NVM_DIR/alias/default")"
    _nvm_resolved_version=""
    if command -v nvm >/dev/null 2>&1; then
        _nvm_resolved_version="$(nvm version "$_nvm_default" 2>/dev/null)"
    fi
    if [[ -n "$_nvm_resolved_version" && "$_nvm_resolved_version" != "N/A" ]]; then
        _nvm_bin="$NVM_DIR/versions/node/$_nvm_resolved_version/bin"
        [[ -d "$_nvm_bin" ]] && path=("$_nvm_bin" $path)
        unset _nvm_bin
    fi
    unset _nvm_default _nvm_resolved_version
fi

export PATH
