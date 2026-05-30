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
        for f in profiles/*.Brewfile profiles/*.uv profiles/*.zshrc profiles/*.extensions; do
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

# Helper function to extract base tool name from a package specifier (e.g., 'ruff==0.3.0' -> 'ruff')
get_tool_name() {
    echo "$1" | cut -d'=' -f1 | cut -d'>' -f1 | cut -d'<' -f1 | cut -d'@' -f1 | cut -d';' -f1 | cut -d'[' -f1 | xargs
}

# Helper function to list installed uv tool package names
get_installed_uv_tools() {
    uv tool list 2>/dev/null | awk '/^[^[:space:]-]/ {print $1}'
}

# Helper function to read extension IDs from profile config file (Bash 3.2 compatible)
get_profile_extensions() {
    local profile_file="profiles/$1.extensions"
    if [[ -f "$profile_file" ]]; then
        # Read file, ignore empty lines and comment lines
        grep -v -E '^#|^$' "$profile_file"
    fi
}

# Helper function to extract base extension ID from an extension specifier
get_extension_name() {
    echo "$1" | cut -d'@' -f1 | xargs
}

# Helper function to list installed IDE extension IDs
get_installed_extensions() {
    "$1" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]'
}

# Helper function to check whether a newline-delimited list contains a value
list_contains_line() {
    local needle="$1"
    grep -F -x -- "$needle" >/dev/null
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
        installed_uv_tools=$(get_installed_uv_tools)
        IFS=' ' read -r -a ALL_CLEANUP_PROFILES <<< "$(get_all_available_profiles)"
        for profile in "${ALL_CLEANUP_PROFILES[@]}"; do
            if [[ ! " ${PROFILES[*]} " == *" ${profile} "* ]]; then
                inactive_tools=$(get_profile_uv_tools "$profile")
                for tool in $inactive_tools; do
                    tool_name=$(get_tool_name "$tool")
                    # Verify this tool is NOT declared in any of the active profiles
                    is_active=false
                    for active_p in "${PROFILES[@]}"; do
                        active_tools=$(get_profile_uv_tools "$active_p")
                        for active_t in $active_tools; do
                            active_tool_name=$(get_tool_name "$active_t")
                            if [[ "$active_tool_name" == "$tool_name" ]]; then
                                is_active=true
                                break 2
                            fi
                        done
                    done

                    if [[ "$is_active" == "false" ]] && printf '%s\n' "$installed_uv_tools" | list_contains_line "$tool_name"; then
                        echo "   🧹 Uninstalling $tool_name (profile '$profile' inactive)..."
                        uv tool uninstall "$tool_name" &>/dev/null || true
                        installed_uv_tools=$(printf '%s\n' "$installed_uv_tools" | grep -F -x -v -- "$tool_name" || true)
                    fi
                done
            fi
        done
    fi
else
    echo "⚠️  uv is not installed. Skipping Python tool setup."
fi

# 7. Install IDE Extensions
echo "🔌 Installing IDE extensions..."

# Ensure Antigravity IDE is configured to use the VS Code Marketplace
product_json="/Applications/Antigravity IDE.app/Contents/Resources/app/product.json"
if [[ -f "$product_json" ]]; then
    if grep -q "open-vsx.org" "$product_json"; then
        echo "   🔧 Configuring Antigravity IDE to use VS Code Marketplace..."
        python3 -c '
import json
path = "/Applications/Antigravity IDE.app/Contents/Resources/app/product.json"
try:
    with open(path, "r") as f:
        data = json.load(f)
    data["extensionsGallery"] = {
        "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
        "cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",
        "itemUrl": "https://marketplace.visualstudio.com/items"
    }
    with open(path, "w") as f:
        json.dump(data, f, indent=4)
    print("   ✅ VS Code Marketplace configured successfully.")
except Exception as e:
    print(f"   ⚠️  Could not configure VS Code Marketplace: {e}")
' 2>/dev/null || true
    fi
fi
VSCODE_CMD=""
if command -v code &> /dev/null; then
    VSCODE_CMD="code"
fi

AGY_CMD=""
if command -v agy-ide &> /dev/null; then
    AGY_CMD="agy-ide"
elif command -v antigravity-ide &> /dev/null; then
    AGY_CMD="antigravity-ide"
elif [[ -x "/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide" ]]; then
    AGY_CMD="/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide"
fi

if [[ -n "$VSCODE_CMD" || -n "$AGY_CMD" ]]; then
    # Collect and deduplicate extensions to install
    declare -a VSCODE_ARGS=()
    declare -a AGY_ARGS=()
    for profile in "${PROFILES[@]}"; do
        ext_file="profiles/${profile}.extensions"
        if [[ -f "$ext_file" ]]; then
            while IFS= read -r ext || [[ -n "$ext" ]]; do
                # Strip comments and trim whitespace
                ext="${ext%%#*}"
                ext=$(echo "$ext" | xargs)

                if [[ -n "$ext" ]]; then
                    # Avoid duplicate arguments
                    already_added=false
                    for arg in "${VSCODE_ARGS[@]}"; do
                        if [[ "$arg" == "$ext" ]]; then
                            already_added=true
                            break
                        fi
                    done
                    if [[ "$already_added" == "false" ]]; then
                        VSCODE_ARGS+=("--install-extension" "$ext")
                        AGY_ARGS+=("--install-extension" "$ext")
                    fi
                fi
            done < "$ext_file"
        fi
    done

    # Bulk install in VS Code
    if [[ -n "$VSCODE_CMD" && ${#VSCODE_ARGS[@]} -gt 0 ]]; then
        echo "   Installing extensions in VS Code..."
        output=$("$VSCODE_CMD" "${VSCODE_ARGS[@]}" 2>&1) && exit_code=0 || exit_code=$?
        if [[ $exit_code -ne 0 ]] && ! echo "$output" | grep -E -q "successfully installed|already installed"; then
            echo "   ⚠️  Could not install some extensions in VS Code."
            echo "      Details: $(echo "$output" | head -n 3)"
        fi
        sleep 1
    fi

    # Bulk install in Antigravity IDE
    if [[ -n "$AGY_CMD" && ${#AGY_ARGS[@]} -gt 0 ]]; then
        echo "   Installing extensions in Antigravity IDE..."
        output=$("$AGY_CMD" "${AGY_ARGS[@]}" 2>&1) && exit_code=0 || exit_code=$?
        if [[ $exit_code -ne 0 ]] && ! echo "$output" | grep -E -q "successfully installed|already installed"; then
            echo "   ⚠️  Could not install some extensions in Antigravity IDE."
            echo "      Details: $(echo "$output" | head -n 3)"
        fi
        sleep 1
    fi

    # Clean up extensions from inactive profiles (if --cleanup is active)
    if [[ "$CLEANUP" == "true" ]]; then
        VSCODE_INSTALLED_EXTENSIONS=""
        AGY_INSTALLED_EXTENSIONS=""
        if [[ -n "$VSCODE_CMD" ]]; then
            VSCODE_INSTALLED_EXTENSIONS=$(get_installed_extensions "$VSCODE_CMD")
        fi
        if [[ -n "$AGY_CMD" ]]; then
            AGY_INSTALLED_EXTENSIONS=$(get_installed_extensions "$AGY_CMD")
        fi

        IFS=' ' read -r -a ALL_CLEANUP_PROFILES <<< "$(get_all_available_profiles)"
        for profile in "${ALL_CLEANUP_PROFILES[@]}"; do
            if [[ ! " ${PROFILES[*]} " == *" ${profile} "* ]]; then
                inactive_exts=$(get_profile_extensions "$profile")
                for ext in $inactive_exts; do
                    ext_name=$(get_extension_name "$ext")
                    ext_key=$(echo "$ext_name" | tr '[:upper:]' '[:lower:]')
                    # Verify this extension is NOT declared in any of the active profiles
                    is_active=false
                    for active_p in "${PROFILES[@]}"; do
                        active_exts=$(get_profile_extensions "$active_p")
                        for active_ext in $active_exts; do
                            active_ext_name=$(get_extension_name "$active_ext")
                            active_ext_key=$(echo "$active_ext_name" | tr '[:upper:]' '[:lower:]')
                            if [[ "$active_ext_key" == "$ext_key" ]]; then
                                is_active=true
                                break 2
                            fi
                        done
                    done

                    if [[ "$is_active" == "false" ]]; then
                        if [[ -n "$VSCODE_CMD" ]] && printf '%s\n' "$VSCODE_INSTALLED_EXTENSIONS" | list_contains_line "$ext_key"; then
                            echo "   🧹 Uninstalling $ext_name in VS Code (profile '$profile' inactive)..."
                            "$VSCODE_CMD" --uninstall-extension "$ext_name" >/dev/null 2>&1 || true
                            VSCODE_INSTALLED_EXTENSIONS=$(printf '%s\n' "$VSCODE_INSTALLED_EXTENSIONS" | grep -F -x -v -- "$ext_key" || true)
                            sleep 1
                        fi
                        if [[ -n "$AGY_CMD" ]] && printf '%s\n' "$AGY_INSTALLED_EXTENSIONS" | list_contains_line "$ext_key"; then
                            echo "   🧹 Uninstalling $ext_name in Antigravity IDE (profile '$profile' inactive)..."
                            "$AGY_CMD" --uninstall-extension "$ext_name" >/dev/null 2>&1 || true
                            AGY_INSTALLED_EXTENSIONS=$(printf '%s\n' "$AGY_INSTALLED_EXTENSIONS" | grep -F -x -v -- "$ext_key" || true)
                            sleep 1
                        fi
                    fi
                done
            fi
        done
    fi
else
    echo "   ⚠️  No VS Code or Antigravity IDE CLI found. Skipping extension installation."
fi

# 8. Check for macOS updates
echo "🔍 Checking for macOS updates..."
updates=$(softwareupdate -l 2>&1) || true
if echo "$updates" | grep -q -E "Software Update found| \* "; then
    echo "   ⚠️  macOS updates are available!"
    echo "$updates" | grep -E '^[[:space:]]*\*' | sed -E 's/^[[:space:]]*\*[[:space:]]*//' | while read -r line; do
        echo "      👉 $line"
    done
    echo "   ℹ️  Please install them via System Settings or run 'sudo softwareupdate -i -a' manually."
elif echo "$updates" | grep -q "No new software available"; then
    echo "   ✅ macOS is up to date."
else
    echo "   ⚠️  Could not check for macOS updates (tool returned unexpected output or failed)."
fi
echo ""

# 9. Check and upgrade Mac App Store apps
if command -v mas &> /dev/null; then
    echo "🔍 Checking for Mac App Store updates..."
    outdated_apps=$(mas outdated 2>/dev/null) || true
    if [[ -n "$outdated_apps" ]]; then
        echo "   ⚠️  Outdated Mac App Store apps found:"
        echo "$outdated_apps" | while read -r line; do
            echo "      👉 $line"
        done
        echo "   📦 Upgrading Mac App Store apps..."
        mas upgrade || echo "   ⚠️  Some App Store updates could not be completed automatically (you may need to sign in to the App Store)."
    else
        echo "   ✅ All Mac App Store apps are up to date."
    fi
    echo ""
fi

if [[ -n "$UNLISTED_WARNING" ]]; then
    echo ""
    echo "⚠️  WARNING: Unlisted Packages Found"
    echo "The following packages are currently installed but not defined in your Brewfile:"
    # shellcheck disable=SC2001
    echo "$UNLISTED_WARNING" | sed 's/^/   /g'
    echo "👉 Run './setup.sh --cleanup' to remove them."
    echo ""
fi

echo "🎉 Mac Setup completed successfully!"
