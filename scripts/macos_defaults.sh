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


# --- Keyboard & Input ---

echo "  -> Enabling key repeat when holding down keys"
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

echo "  -> Setting very fast key repeat rate and short delay"
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15


# --- Dock ---

echo "  -> Setting Dock to auto-hide"
defaults write com.apple.dock autohide -bool true

echo "  -> Setting Dock icon size"
defaults write com.apple.dock tilesize -int 36

echo "  -> Enabling Dock magnification"
defaults write com.apple.dock magnification -bool true

echo "  -> Setting Dock magnification size"
defaults write com.apple.dock largesize -int 64


# --- Finder ---

echo "  -> Enabling Desktop Stacks (Group by Kind)"
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:GroupBy Kind" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :DesktopViewSettings:GroupBy string Kind" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null

echo "  -> Show hidden files in Finder by default"
defaults write com.apple.finder AppleShowAllFiles -bool true

echo "  -> Show path bar in Finder"
defaults write com.apple.finder ShowPathbar -bool true

echo "  -> Show status bar in Finder"
defaults write com.apple.finder ShowStatusBar -bool true

echo "  -> Show all filename extensions"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

echo "  -> Keep folders at the top when sorting files by name"
defaults write com.apple.finder _FXSortFoldersFirst -bool true

echo "  -> Disable warning when changing file extensions"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false


# --- Screen Capture ---

echo "  -> Creating Screenshots directory under Pictures"
mkdir -p "$HOME/Pictures/Screenshots"

echo "  -> Setting screenshot location to ~/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"

echo "  -> Setting screenshot format to JPG"
defaults write com.apple.screencapture type -string "jpg"


# --- TextEdit ---

echo "  -> Setting TextEdit to open in plain text mode by default"
defaults write com.apple.TextEdit RichText -int 0

echo "  -> Setting TextEdit encoding to UTF-8"
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4


# --- Touch ID for sudo ---
if [[ ! -f "/etc/pam.d/sudo_local" ]]; then
    echo "🔒 Configuring Touch ID for sudo (requires password)..."
    sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
    sudo sed -i '' 's/#auth/auth/' /etc/pam.d/sudo_local
elif ! grep -q "^auth[[:space:]]\+sufficient[[:space:]]\+pam_tid.so" /etc/pam.d/sudo_local; then
    echo "🔒 Enabling Touch ID for sudo (requires password)..."
    sudo sed -i '' 's/#auth[[:space:]]\+sufficient[[:space:]]\+pam_tid.so/auth       sufficient     pam_tid.so/' /etc/pam.d/sudo_local
fi

# --- iTerm2 ---
echo "⚙️  Configuring iTerm2 to allow Touch ID in sudo sessions..."
defaults write com.googlecode.iterm2 BootstrapDaemon -bool false


# --- Apply Changes ---
echo "Restarting affected applications (Dock, Finder, SystemUIServer)..."

# Kill affected apps so they restart with new settings
for app in "Dock" "Finder" "SystemUIServer"; do
  killall "${app}" &> /dev/null || true
done

echo "macOS defaults applied."
