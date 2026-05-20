# Mac Setup

This is an idempotent setup project for configuring a macOS environment. It uses [Homebrew](https://brew.sh/) to manage software installations and bash scripts to set macOS system preferences.

## Usage

1. Open Terminal.
2. Navigate to this directory.
3. Run the setup script:

```bash
./setup.sh
```

## Structure

*   **`setup.sh`**: The main orchestrator script. It installs Homebrew if necessary, then invokes the other configuration steps. It is safe to run multiple times.
*   **`Brewfile`**: A list of all command-line tools, applications, and Mac App Store apps to install via `brew bundle`.
    *   To add a new app, add a `brew "name"`, `cask "name"`, or `mas "name", id: 123` line to this file.
*   **`macos_defaults.sh`**: A script containing `defaults write` commands to configure system preferences (e.g., trackpad scrolling, dock auto-hide).

## Updating Configuration

To update your machine after adding new apps to the `Brewfile` or changing settings in `macos_defaults.sh`, simply run `./setup.sh` again. The scripts are designed to only apply necessary changes.

## Manual Configurations

### Step 1: Turn on 1Password Universal Autofill

This gives 1Password permission to inject credentials into native Mac apps, browsers, and even your terminal when running sudo.

1. Open System Settings on your Mac.
2. Go to Privacy & Security -> Accessibility.
3. Toggle the switch ON for 1Password. (If it’s not in the list, click the + button at the bottom and add 1Password from your Applications folder).
4. Once enabled, you can use ⌘\ (Command + Backslash) anywhere on your Mac to instantly autofill a password via 1Password.

### Step 2: Silence Apple's Native Autofill Prompts

To keep Apple's Passwords app from constantly popping up and stepping on 1Password's toes when you click into a login field, you need to turn it off:

1. Go back to System Settings -> Autofill & Passwords.
2. Click the Autofill button (or look at the top settings depending on your exact macOS version).
3. Uncheck/turn off "Passwords and passkeys".
