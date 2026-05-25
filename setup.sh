#!/usr/bin/env bash

# Mac Setup Orchestrator Script
# This script is designed to be idempotent and can be run multiple times safely.

# Stop on errors
set -e

# Parse options
CLEANUP=false
CONFIG_FILE=".active_profiles"
PROFILES=("basic")
PROFILES_OVERRIDDEN=false

# Load saved profiles from local config if it exists (handles newlines and commas)
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip comments and trim whitespace
        line="${line%%#*}"
        line=$(echo "$line" | xargs)
        if [[ -n "$line" ]]; then
            # Split comma-separated values if multiple are on the same line
            IFS=',' read -r -a split_line <<< "$line"
            PROFILES+=("${split_line[@]}")
        fi
    done < "$CONFIG_FILE"
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --profile)
            if [[ -n "$2" && "$2" != --* ]]; then
                # If command-line profile is specified, we override any saved profiles
                if [[ "$PROFILES_OVERRIDDEN" == "false" ]]; then
                    PROFILES=("basic")
                    PROFILES_OVERRIDDEN=true
                fi

                # Split comma-separated profiles into an array
                IFS=',' read -r -a extra_profiles <<< "$2"

                # Add profiles to list, ignoring 'basic' or 'none'
                for p in "${extra_profiles[@]}"; do
                    if [[ "$p" != "basic" && "$p" != "none" ]]; then
                        PROFILES+=("$p")
                    fi
                done

                # Save the new profile configuration, one per line (excluding 'basic')
                true > "$CONFIG_FILE"
                for p in "${PROFILES[@]}"; do
                    if [[ "$p" != "basic" ]]; then
                        echo "$p" >> "$CONFIG_FILE"
                    fi
                done

                # Delete config file if empty
                if [[ ! -s "$CONFIG_FILE" ]]; then
                    rm -f "$CONFIG_FILE"
                fi

                shift 2
            else
                echo "❌ Error: --profile requires a value"
                exit 1
            fi
            ;;
        *)
            echo "❌ Error: Unknown argument $1"
            exit 1
            ;;
    esac
done

# --- Helper Functions ---

# Helper function to dynamically list all profiles in the profiles/ folder (excluding 'basic')
get_all_available_profiles() {
    local name
    local profiles=()
    if [[ -d "profiles" ]]; then
        for f in profiles/*.Brewfile profiles/*.uv profiles/*.zshrc; do
            if [[ -e "$f" ]]; then
                name=$(basename "$f")
                name="${name%.*}"
                if [[ "$name" != "basic" && "$name" != "*" ]]; then
                    profiles+=("$name")
                fi
            fi
        done
    fi
    # Deduplicate profile list
    echo "${profiles[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

# Helper function to read uv tools from profile config file (Bash 3.2 compatible)
get_profile_uv_tools() {
    local profile_file="profiles/$1.uv"
    if [[ -f "$profile_file" ]]; then
        # Read file, ignore empty lines and comment lines
        grep -v -E '^#|^$' "$profile_file"
    fi
}

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
COMPILED_BREWFILE=".Brewfile.compiled"

# Ensure we clean up any leftovers on exit
trap 'rm -f "$COMPILED_BREWFILE" &> /dev/null' EXIT

echo "   Active profiles: ${PROFILES[*]}"

# Consolidate all active Brewfiles
echo "# Consolidated Brewfile" > "$COMPILED_BREWFILE"
for profile in "${PROFILES[@]}"; do
    profile_file="profiles/${profile}.Brewfile"
    if [[ -f "$profile_file" ]]; then
        echo "   Adding profile: $profile"
        cat "$profile_file" >> "$COMPILED_BREWFILE"
        echo "" >> "$COMPILED_BREWFILE" # Ensure a trailing newline
    else
        echo "⚠️  Warning: Profile file $profile_file not found. Skipping."
    fi
done

if [[ -f "$COMPILED_BREWFILE" ]]; then
    echo "📦 Installing software from consolidated profiles..."
    brew bundle --file="$COMPILED_BREWFILE"

    echo "🔍 Checking for unlisted packages..."
    if [[ "$CLEANUP" == "true" ]]; then
        echo "🧹 Uninstalling unlisted packages..."
        brew bundle cleanup --file="$COMPILED_BREWFILE" --force
    else
        # Run dry-run, redirect stderr to prevent setup aborting on set -e
        unlisted=$(brew bundle cleanup --file="$COMPILED_BREWFILE" 2>/dev/null) || true
        # Clean up output formatting
        filtered_unlisted=$(echo "$unlisted" | grep -v -E "JSON API|Run \`brew bundle cleanup")

        if echo "$filtered_unlisted" | grep -q "Would uninstall"; then
            UNLISTED_WARNING="$filtered_unlisted"
            echo "   ⚠️  Unlisted packages detected. Summary will be shown at the end."
        else
            echo "   ✅ All installed packages match the active profiles."
        fi
    fi
else
    echo "❌ Error: Failed to compile Brewfile."
    exit 1
fi

# 3. Apply macOS defaults
if [[ -f "scripts/macos_defaults.sh" ]]; then
    echo "⚙️  Applying macOS system preferences..."
    # Source the file so it runs in the current shell, or execute it
    bash scripts/macos_defaults.sh
else
    echo "⚠️  No macos_defaults.sh found in the scripts directory."
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

    # Symlink active profile-specific Zsh configs
    for profile in "${PROFILES[@]}"; do
        if [[ -f "profiles/${profile}.zshrc" ]]; then
            echo "   Symlinking profile config: ~/.zshrc.${profile}"
            ln -sf "$(pwd)/profiles/${profile}.zshrc" "$HOME/.zshrc.${profile}"
        fi
    done

    # Remove configs for inactive profiles
    IFS=' ' read -r -a ALL_PROFILES <<< "$(get_all_available_profiles)"
    for profile in "${ALL_PROFILES[@]}"; do
        if [[ ! " ${PROFILES[*]} " == *" ${profile} "* ]]; then
            if [[ -L "$HOME/.zshrc.${profile}" ]]; then
                echo "   Removing inactive profile config: ~/.zshrc.${profile}"
                rm -f "$HOME/.zshrc.${profile}"
            fi
        fi
    done
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

    # Install tools for all active profiles
    for profile in "${PROFILES[@]}"; do
        tools=$(get_profile_uv_tools "$profile")
        for tool in $tools; do
            echo "   Installing $tool..."
            uv tool install "$tool" || true
        done
    done

    # Setup git hooks if pre-commit is installed
    if [[ -f "$HOME/.local/bin/pre-commit" ]]; then
        "$HOME/.local/bin/pre-commit" install
    fi

    # Clean up tools from inactive profiles (if --cleanup is active)
    if [[ "$CLEANUP" == "true" ]]; then
        IFS=' ' read -r -a ALL_CLEANUP_PROFILES <<< "$(get_all_available_profiles)"
        for profile in "${ALL_CLEANUP_PROFILES[@]}"; do
            if [[ ! " ${PROFILES[*]} " == *" ${profile} "* ]]; then
                inactive_tools=$(get_profile_uv_tools "$profile")
                for tool in $inactive_tools; do
                    # Verify this tool is NOT declared in any of the active profiles
                    is_active=false
                    for active_p in "${PROFILES[@]}"; do
                        active_tools=$(get_profile_uv_tools "$active_p")
                        if [[ " $active_tools " == *" $tool "* ]]; then
                            is_active=true
                            break
                        fi
                    done

                    if [[ "$is_active" == "false" ]]; then
                        echo "   🧹 Uninstalling $tool (profile '$profile' inactive)..."
                        uv tool uninstall "$tool" &>/dev/null || true
                    fi
                done
            fi
        done
    fi
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
