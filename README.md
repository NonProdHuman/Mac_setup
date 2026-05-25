# Mac Setup

This is an idempotent setup project for configuring a macOS environment. It uses [Homebrew](https://brew.sh/) to manage software installations and scripts to set system and shell defaults.

## Features

*   **Modular Profiles:** Automated installation of CLI tools, GUI applications, and Mac App Store apps divided into separate profiles (e.g., `basic` for core tools, `productivity` for office/media apps).
*   **Zsh Usability & Auto-Completion:** Pre-configured auto-suggestions, tab-completions, and a lightweight, native Git branch prompt without bloated shell frameworks.
*   **System Customization:** Sensible macOS defaults for trackpad (tap-to-click, secondary click), keyboard (high repeat rate), Finder, screenshot output, and plain-text TextEdit.
*   **Touch ID for Sudo:** Bio-authenticated privilege elevation in the terminal that survives macOS system updates.
*   **Cleanup Guard:** Automatic detection and optional uninstallation of packages not defined in your active profiles.

---

## Usage

1. Open Terminal.
2. Navigate to this directory.
3. Run the setup orchestrator with your desired profiles:

### Option A: Standard (Core tools)
```bash
./setup.sh
```

### Option B: Core + Productivity (Adds MS Office, Zoom, Docker, Calibre, etc.)
```bash
./setup.sh --profile productivity
```

### Option C: Adding Cleanup (Removes any packages not in the active profiles)
```bash
./setup.sh --profile productivity --cleanup
```
---

## Manual Configurations

### Turn on 1Password Universal Autofill
1. Open **System Settings** on your Mac.
2. Go to **Privacy & Security** -> **Accessibility**.
3. Toggle the switch **ON** for 1Password.
4. Once enabled, you can use `⌘\` (Command + Backslash) anywhere on your Mac to instantly autofill passwords.

### Silence Apple's Native Autofill Prompts
To keep Apple's system prompts from conflicting with 1Password:
1. Go to **System Settings** -> **Autofill & Passwords**.
2. Click the **Autofill** settings button.
3. Turn **OFF** "Passwords and passkeys".
