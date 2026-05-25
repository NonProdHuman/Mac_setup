#!/usr/bin/env bash

# Mac Setup Orchestrator Script
# This script is designed to be idempotent and can be run multiple times safely.

# Stop on errors
set -e

# Parse options
CLEANUP=false
for arg in "$@"; do
    if [[ "$arg" == "--cleanup" ]]; then
        CLEANUP=true
    fi
done

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

# 2. Install/Sync software via Brewfile
UNLISTED_WARNING=""
if [[ -f "Brewfile" ]]; then
    echo "📦 Installing software from Brewfile..."
    brew bundle --file=Brewfile

    echo "🔍 Checking for unlisted packages..."
    if [[ "$CLEANUP" == "true" ]]; then
        echo "🧹 Uninstalling unlisted packages..."
        brew bundle cleanup --file=Brewfile --force
    else
        # Run dry-run, redirect stderr to prevent setup aborting on set -e
        unlisted=$(brew bundle cleanup --file=Brewfile 2>/dev/null) || true
        # Clean up output formatting
        filtered_unlisted=$(echo "$unlisted" | grep -v -E "JSON API|Run \`brew bundle cleanup")

        if echo "$filtered_unlisted" | grep -q "Would uninstall"; then
            UNLISTED_WARNING="$filtered_unlisted"
            echo "   ⚠️  Unlisted packages detected. Summary will be shown at the end."
        else
            echo "   ✅ All installed packages match the Brewfile."
        fi
    fi
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

# 5. Secure Zsh completion directories
echo "🔒 Securing Zsh completion directories..."
# Run compaudit in a non-interactive Zsh subshell to get insecure paths without loading .zshrc
insecure_dirs=$(zsh -f -c "fpath=(/opt/homebrew/share/zsh-completions /usr/local/share/zsh-completions \$fpath); autoload -Uz compaudit && compaudit" 2>/dev/null) || true

if [[ -n "$insecure_dirs" ]]; then
    echo "   Removing group/world write permissions from insecure directories..."
    echo "$insecure_dirs" | xargs chmod g-w,o-w || {
        echo "   ⚠️  Could not change permissions automatically. You may need to run:"
        echo "   compaudit | xargs sudo chmod g-w,o-w"
    }
else
    echo "   ✅ Zsh completion directories are secure."
fi

# 6. Install tools via uv
if command -v uv &> /dev/null; then
    echo "⚙️  Installing tools via uv..."
    uv tool install pre-commit || true
    uv tool install yt-dlp || true

    # Setup git hooks
    "$HOME/.local/bin/pre-commit" install
else
    echo "⚠️  uv is not installed. Skipping Python tool setup."
fi

if [[ -n "$UNLISTED_WARNING" ]]; then
    echo ""
    echo "⚠️  WARNING: Unlisted Packages Found"
    echo "The following packages are currently installed but not defined in your Brewfile:"
    echo "$UNLISTED_WARNING" | sed 's/^/   /g'
    echo "👉 Run './setup.sh --cleanup' to remove them."
    echo ""
fi

echo "🎉 Mac Setup completed successfully!"
