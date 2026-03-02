#!/usr/bin/env bash
set -euo pipefail

# Standalone by design — works even before symlinks are created.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Shell startup timing (aim for <200ms)"
for _ in 1 2 3; do
    /usr/bin/time -p zsh -i -c exit >/dev/null
done

echo
echo "==> SSH file permissions"
if [[ -d "$HOME/.ssh" ]]; then
    ls -l "$HOME/.ssh"
else
    echo "$HOME/.ssh does not exist yet."
fi

echo
echo "==> Looking for obvious secret patterns in repo"
if command -v rg >/dev/null 2>&1; then
    rg -n -i --hidden \
        --glob '!.git/**' \
        --glob '!local/**' \
        --glob '!local.example/**' \
        --glob '!scripts/audit.sh' \
        --glob '!scripts/secrets.sh' \
        --glob '!README.md' \
        '(password|_password|token|api[_-]?key|secret)' "$DOTFILES_DIR" || true
else
    echo "Skipped: rg (ripgrep) not installed."
fi

echo
echo "==> ShellCheck lint"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x -e SC1091 "$DOTFILES_DIR"/scripts/*.sh "$DOTFILES_DIR"/scripts/lib/*.sh || true
else
    echo "Skipped: shellcheck not installed."
fi

echo
echo "==> shfmt style"
if command -v shfmt >/dev/null 2>&1; then
    shfmt -d -i 4 -ci -bn "$DOTFILES_DIR"/scripts/*.sh "$DOTFILES_DIR"/scripts/lib/*.sh || true
else
    echo "Skipped: shfmt not installed."
fi

echo
echo "==> Git status"
git -C "$DOTFILES_DIR" status -sb
