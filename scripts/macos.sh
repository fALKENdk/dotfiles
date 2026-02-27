#!/usr/bin/env bash
set -euo pipefail

# Apply opinionated macOS system defaults (Finder, Dock, keyboard).
# Idempotent — safe to re-run. Restarts Finder and Dock to apply changes.

if [[ "${OSTYPE:-}" != darwin* ]]; then
    echo "macos.sh only runs on macOS."
    exit 0
fi

echo "Applying macOS defaults..."

# Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false

# Input/UX
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain InitialKeyRepeat -int 15 # ~225ms before repeat starts (default: 25)
defaults write NSGlobalDomain KeyRepeat -int 2         # ~30ms between repeats (default: 6)

killall Finder Dock >/dev/null 2>&1 || true
echo "macOS defaults applied."
