#!/usr/bin/env bash

# Mac Setup Orchestrator Script
# This script is designed to be idempotent and can be run multiple times safely.

# Stop on errors
set -e

echo "🚀 Starting Mac Setup..."

# 1. Install Homebrew if it isn't installed
if ! command -v brew &> /dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Check if we are on Apple Silicon and need to add brew to PATH for this session
    if [[ $(uname -m) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew is already installed."
    # Optionally update brew
    # brew update
fi

# 2. Install software via Brewfile
if [[ -f "Brewfile" ]]; then
    echo "📦 Installing software from Brewfile..."
    # Run brew bundle to install everything
    brew bundle --file=Brewfile
else
    echo "⚠️  No Brewfile found in the current directory."
fi

# 3. Apply macOS defaults
if [[ -f "macos_defaults.sh" ]]; then
    echo "⚙️  Applying macOS system preferences..."
    # Source the file so it runs in the current shell, or execute it
    bash macos_defaults.sh
else
    echo "⚠️  No macos_defaults.sh found in the current directory."
fi

# 4. Set up dotfiles
echo "📄 Setting up dotfiles..."
if [[ -f "zshrc" ]]; then
    # Backup existing if it's not a symlink pointing to our repo
    if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
        echo "   Backing up existing ~/.zshrc to ~/.zshrc.backup"
        mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
    fi
    echo "   Symlinking zshrc to ~/.zshrc"
    ln -sf "$(pwd)/zshrc" "$HOME/.zshrc"
else
    echo "⚠️  No zshrc found in the current directory."
fi

echo "🎉 Mac Setup completed successfully!"
