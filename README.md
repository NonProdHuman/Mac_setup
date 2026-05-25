# Mac Setup

This is an idempotent setup project for configuring a macOS environment. It uses [Homebrew](https://brew.sh/) to manage software installations and scripts to set system and shell defaults.

## Features

*   **Modular Profiles:** Automated installation of CLI tools, GUI applications, and Mac App Store apps divided into separate profiles (e.g., `basic` for core tools, `productivity` for office/media apps, `developer` for coding, `gaming` for games).
*   **Dynamic Discovery:** Adding a profile is as simple as dropping a file (like `profiles/<name>.Brewfile` or `profiles/<name>.uv`) into the profiles directory—no script editing required.
*   **Zsh Usability & Auto-Completion:** Pre-configured auto-suggestions, tab-completions, and a lightweight, native Git branch prompt without bloated shell frameworks.
*   **System Customization:** Sensible macOS defaults for trackpad (tap-to-click, secondary click), keyboard (high repeat rate), Finder, screenshot output, and plain-text TextEdit.
*   **Touch ID for Sudo:** Bio-authenticated privilege elevation in the terminal that survives macOS system updates.
*   **Cleanup Guard:** Automatic detection and optional uninstallation of packages, global `uv` tools, and IDE extensions not defined in your active profiles.
*   **IDE Extension Syncing:** Automatically installs and manages editor extensions for both VS Code and Antigravity IDE based on active profiles. It automatically patches Antigravity IDE to use the official VS Code Marketplace, ensuring compatibility with proprietary extensions.

---

## Usage

1. Open Terminal.
2. Navigate to this directory.
3. Run the setup orchestrator:

```bash
./setup.sh
```

### Profile Configuration
The orchestrator automatically saves your active profiles to a local `.active_profiles` file (which is git-ignored).
*   **Select Profiles:** Specify which profiles you want on this machine (e.g., `developer` and `productivity`):
    ```bash
    ./setup.sh --profile developer,productivity
    ```
    *This will save these selections to `.active_profiles`. Subsequent runs of `./setup.sh` will remember and apply them automatically.*
*   **Reset to Standard:** Reset the machine back to only core tools (clears `.active_profiles`):
    ```bash
    ./setup.sh --profile basic
    ```
*   **Enable Cleanup:** Uninstall any packages, `uv` tools, and IDE extensions not declared in your active profiles:
    ```bash
    ./setup.sh --cleanup
    ```

---

## Creating Custom Profiles
You can easily create your own profiles. The setup script dynamically discovers any configuration files in the `profiles/` directory.

To see how these are structured, you can refer to the provided `example` profile:
*   **`profiles/<name>.Brewfile`:** Homebrew formulas, casks, and Mac App Store apps. (See [example.Brewfile](profiles/example.Brewfile))
*   **`profiles/<name>.uv`:** Python command-line tools to install globally via `uv`. (See [example.uv](profiles/example.uv))
*   **`profiles/<name>.zshrc`:** Shell configurations, aliases, and environment variables. (See [example.zshrc](profiles/example.zshrc))
*   **`profiles/<name>.extensions`:** Extension IDs (`publisher.name`) for VS Code and Antigravity IDE. (See [example.extensions](profiles/example.extensions))

*All files are optional; a profile can contain any subset of these configs. Optional version pinning is supported for `.uv` package specifiers (e.g. `ruff==0.3.0` or `black>=24.0.0`) and `.extensions` IDs (e.g. `publisher.name@version`).*

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
