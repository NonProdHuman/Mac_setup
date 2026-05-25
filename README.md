# Mac Setup

This is an idempotent setup project for configuring a macOS environment. It uses [Homebrew](https://brew.sh/) to manage software installations and scripts to set system and shell defaults.

## Features

*   **Software Management:** Automated installation of CLI tools, GUI applications, and Mac App Store apps via a central `Brewfile`.
*   **Zsh Usability & Auto-Completion:** Pre-configured auto-suggestions, tab-completions, and a lightweight, native Git branch prompt without bloated shell frameworks.
*   **System Customization:** Sensible macOS defaults for trackpad (tap-to-click, secondary click), keyboard (high repeat rate), Finder, screenshot output, and plain-text TextEdit.
*   **Touch ID for Sudo:** Bio-authenticated privilege elevation in the terminal that survives macOS system updates.
*   **Cleanup Guard:** Automatic detection and optional uninstallation of packages not defined in the `Brewfile`.

---

## Usage

1. Open Terminal.
2. Navigate to this directory.
3. Run the setup orchestrator:

```bash
./setup.sh
```

### Keeping Your Mac in Sync
This project is fully idempotent—you can run it multiple times safely.
*   To add new software, add the package to the `Brewfile` and run `./setup.sh` again.
*   To uninstall packages that are no longer in your `Brewfile`, run:
    ```bash
    ./setup.sh --cleanup
    ```

---

## Repository Structure

*   [setup.sh](file:///Users/jeff/git/mac_setup/setup.sh): The main orchestrator script. It installs Homebrew, syncs the `Brewfile`, runs the macOS defaults script, configures shell symlinks, and secures Zsh completions.
*   [Brewfile](file:///Users/jeff/git/mac_setup/Brewfile): A curated list of command-line tools, cask apps, and Mac App Store apps to keep installed on your machine.
*   [zshrc](file:///Users/jeff/git/mac_setup/zshrc): Your local shell configuration, linked automatically to `~/.zshrc`.
*   [macos_defaults.sh](file:///Users/jeff/git/mac_setup/macos_defaults.sh): Configuration for system behavior, trackpad gestures, keyboard speed, and terminal preferences.
*   [.pre-commit-config.yaml](file:///Users/jeff/git/mac_setup/.pre-commit-config.yaml): Pre-commit hooks configuration (checks formatting, validates YAML, guards against committing private keys, and runs ShellCheck on bash scripts).

---

## Manual Configurations

### Step 1: Touch ID for Sudo (iTerm2 Requirement)
To allow Touch ID authentication inside iTerm2:
1. Open **iTerm2 Settings** (`Cmd + ,`).
2. Go to **Advanced** and search for `survive` (or look for *Allow sessions to survive logging out and back in*).
3. Set this option to **No** (leaving it enabled prevents the terminal session from accessing your Mac's secure enclave).

### Step 2: Turn on 1Password Universal Autofill
1. Open **System Settings** on your Mac.
2. Go to **Privacy & Security** -> **Accessibility**.
3. Toggle the switch **ON** for 1Password.
4. Once enabled, you can use `⌘\` (Command + Backslash) anywhere on your Mac to instantly autofill passwords.

### Step 3: Silence Apple's Native Autofill Prompts
To keep Apple's system prompts from conflicting with 1Password:
1. Go to **System Settings** -> **Autofill & Passwords**.
2. Click the **Autofill** settings button.
3. Turn **OFF** "Passwords and passkeys".
