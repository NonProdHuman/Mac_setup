#!/usr/bin/env bash

# macOS System Preferences Script
# Applies sensible defaults for macOS.
# Many of these require a restart of the affected application (like Dock or Finder) to take effect.

echo "Configuring macOS defaults..."

# --- Trackpad & Mouse ---

echo "  -> Disabling 'Natural' scrolling direction"
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

echo "  -> Enabling Tap to Click on Trackpad"
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

echo "  -> Enabling Two-Finger Secondary Click (Right Click)"
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true
defaults write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true


# --- Dock ---

echo "  -> Setting Dock to auto-hide"
defaults write com.apple.dock autohide -bool true

echo "  -> Setting Dock icon size"
defaults write com.apple.dock tilesize -int 36

echo "  -> Enabling Dock magnification"
defaults write com.apple.dock magnification -bool true

echo "  -> Setting Dock magnification size"
defaults write com.apple.dock largesize -int 64


# --- Finder (Optional/Examples) ---
# echo "  -> Show hidden files in Finder by default"
# defaults write com.apple.finder AppleShowAllFiles -bool true
#
# echo "  -> Show path bar in Finder"
# defaults write com.apple.finder ShowPathbar -bool true


# --- Apply Changes ---
echo "Restarting affected applications (Dock, Finder, SystemUIServer)..."

# Kill affected apps so they restart with new settings
for app in "Dock" "Finder" "SystemUIServer"; do
  killall "${app}" &> /dev/null || true
done

echo "macOS defaults applied."
