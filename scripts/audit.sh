#!/usr/bin/env bash
set -euo pipefail

# Standalone by design — works even before symlinks are created.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Shell startup timing (aim for <200ms)"
for _ in 1 2 3; do
    /usr/bin/time -p zsh -i -c exit > /dev/null
done

echo
echo "==> SSH file permissions"
if [[ -d "$HOME/.ssh" ]]; then
    ls -l "$HOME/.ssh"
else
    echo "$HOME/.ssh does not exist yet."
fi

echo
echo "==> Secrets scan (gitleaks)"
if command -v gitleaks > /dev/null 2>&1; then
    gitleaks detect --source "$DOTFILES_DIR" --no-git --verbose || true
else
    echo "Skipped: gitleaks not installed."
fi

echo
echo "==> ShellCheck lint"
if command -v shellcheck > /dev/null 2>&1; then
    shellcheck "$DOTFILES_DIR"/scripts/*.sh "$DOTFILES_DIR"/scripts/lib/*.sh || true
else
    echo "Skipped: shellcheck not installed."
fi

echo
echo "==> shfmt style"
if command -v shfmt > /dev/null 2>&1; then
    shfmt -d "$DOTFILES_DIR"/scripts/*.sh "$DOTFILES_DIR"/scripts/lib/*.sh || true
else
    echo "Skipped: shfmt not installed."
fi

echo
echo "==> Git status"
git -C "$DOTFILES_DIR" status -sb
