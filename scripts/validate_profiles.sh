#!/usr/bin/env bash
# Profile validator script for mac_setup.
# Checks that profiles/ contains valid syntax and matches .active_profiles.example.

set -e

echo "🧪 Validating profiles..."

errors=0

# Helper to log errors
log_error() {
    echo "❌ Error: $1"
    errors=$((errors + 1))
}

# 1. Validate files in profiles/ directory
if [[ -d "profiles" ]]; then
    for f in profiles/*; do
        # Skip if no files match
        [[ -e "$f" ]] || continue

        filename=$(basename "$f")
        ext="${filename##*.}"

        # Skip hidden files
        if [[ "$filename" == .* ]]; then
            continue
        fi

        # Check extensions
        if [[ "$ext" != "Brewfile" && "$ext" != "uv" && "$ext" != "zshrc" ]]; then
            log_error "Unknown file type in profiles directory: $filename"
            continue
        fi

        # Validate Brewfile syntax
        if [[ "$ext" == "Brewfile" ]]; then
            line_num=0
            while IFS= read -r line || [[ -n "$line" ]]; do
                line_num=$((line_num + 1))
                # Strip comments and trim whitespace
                trimmed="${line%%#*}"
                trimmed=$(echo "$trimmed" | xargs)

                if [[ -n "$trimmed" ]]; then
                    # Check if line starts with valid brew command
                    if [[ ! "$trimmed" =~ ^(brew|cask|mas|tap)[[:space:]] ]]; then
                        log_error "Invalid line in $filename:$line_num: '$trimmed'. Must start with brew, cask, mas, or tap."
                    fi
                fi
            done < "$f"
        fi

        # Validate uv file syntax
        if [[ "$ext" == "uv" ]]; then
            line_num=0
            while IFS= read -r line || [[ -n "$line" ]]; do
                line_num=$((line_num + 1))
                trimmed="${line%%#*}"
                trimmed=$(echo "$trimmed" | xargs)

                if [[ -n "$trimmed" ]]; then
                    # Check if line contains spaces or invalid chars for package names
                    if [[ "$trimmed" =~ [[:space:]] ]]; then
                        log_error "Invalid line in $filename:$line_num: '$trimmed'. Package names cannot contain spaces."
                    elif [[ ! "$trimmed" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
                        log_error "Invalid package name in $filename:$line_num: '$trimmed'. Only alphanumeric, dot, underscore, and hyphen characters are allowed."
                    fi
                fi
            done < "$f"
        fi
    done
fi

# 2. Validate .active_profiles.example
if [[ -f ".active_profiles.example" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line=$(echo "$line" | xargs)
        if [[ -n "$line" ]]; then
            # Verify at least one profile file exists
            if [[ ! -f "profiles/${line}.Brewfile" && ! -f "profiles/${line}.uv" && ! -f "profiles/${line}.zshrc" ]]; then
                log_error "Example profile '${line}' listed in .active_profiles.example does not exist in profiles/ folder."
            fi
        fi
    done < ".active_profiles.example"
fi

if [[ $errors -gt 0 ]]; then
    echo "❌ Profile validation failed with $errors error(s)."
    exit 1
else
    echo "✅ All profiles are valid."
    exit 0
fi
