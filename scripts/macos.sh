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
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

# Trackpad: secondary click in bottom-right corner.
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1

killall Finder Dock >/dev/null 2>&1 || true
echo "macOS defaults applied."
